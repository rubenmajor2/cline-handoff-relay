#!/usr/bin/env python3
"""
cline_prose_trap_watchdog.py — detect the rule-41 prose-trap in real time

Per .clinerules/41 (2026-05-22 addendum). 48% of last-7d YOLO trips are the
"colon-trailed prose, no tool block" class. The model writes "Now reload FPM:"
or "Retry:" or "Reindexing the MCP." without an accompanying tool_use block,
Cline injects [ERROR] You did not use a tool, and 2 more no-tool turns = YOLO.

This watchdog runs every 20s, scans the LATEST Cline task's ui_messages.json,
looks at the last ~6 messages. If it sees:
  - an assistant `say:text` not followed by `say:tool` / `use_mcp_server` /
    `say:api_req_started` for the next tool turn
  - AND that text ends in `:` / `.` and matches a prose-trap fingerprint
    (trailing colon, or matches a forbidden first-word from rule 41)
  - AND no [ERROR] You did not use a tool re-prompt has already fired against it
it pops an osascript notification AND plays a Sosumi sound so Ruben can
intervene before the second strike lands.

When a prose-trap IS detected and the [ERROR] re-prompt fired, also log it
to /tmp/cline_prose_trap.log + writes a row to
/tmp/cline_prose_trap_status.json so Ruben can `cat` it from a shell.

Reversal: launchctl unload ~/Library/LaunchAgents/com.ruben.cline-prose-trap-watchdog.plist
"""
import json
import os
import glob
import time
import subprocess
import re
from typing import Optional

HOME = os.path.expanduser("~")
TASKS_DIR = os.path.join(HOME, "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks")
STATUS_FILE = "/tmp/cline_prose_trap_status.json"
LOG_FILE = os.path.join(HOME, "Library/Logs/cline_prose_trap.log")
NOTIFIED_FILE = "/tmp/cline_prose_trap_notified.json"  # task_id+ts dedup

# Trap fingerprints — text that strongly implies "tool comes next" but isn't a tool
TRAP_TAIL_RE = re.compile(r"[:.]\s*$")
TRAP_PHRASE_RE = re.compile(
    r"\b(now\s+(reload|reindex|verify|check|confirm|patch|update|stamp|run|fix|deploy)"
    r"|next\s+(i'?ll|step|move)"
    r"|reindexing|reloading|stamping|patching|deploying|confirming|verifying"
    r"|let me (check|try|see|wait|verify|confirm)"
    r"|retry\b|hmm,?\s|looks like|seems\s|apparently)",
    re.IGNORECASE,
)

# Cline's own [ERROR] injection
ERROR_INJECT_RE = re.compile(r"\[ERROR\] You did not use a tool", re.IGNORECASE)

def log(msg: str) -> None:
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(f"[{time.strftime('%Y-%m-%dT%H:%M:%S%z')}] {msg}\n")
    except Exception:
        pass

def get_latest_task() -> Optional[str]:
    try:
        dirs = sorted(glob.glob(TASKS_DIR + "/*"), key=os.path.getmtime, reverse=True)
        for d in dirs:
            ui = os.path.join(d, "ui_messages.json")
            if os.path.isfile(ui) and os.path.getmtime(ui) > time.time() - 600:
                return d
    except Exception as e:
        log(f"get_latest_task error: {e}")
    return None

def load_notified() -> dict:
    try:
        with open(NOTIFIED_FILE) as f:
            return json.load(f)
    except Exception:
        return {}

def save_notified(d: dict) -> None:
    try:
        with open(NOTIFIED_FILE, "w") as f:
            json.dump(d, f)
    except Exception:
        pass

def notify(title: str, msg: str, sound: bool = True) -> None:
    try:
        snd = ' sound name "Sosumi"' if sound else ""
        subprocess.run(
            ["osascript", "-e", f'display notification "{msg}" with title "{title}"{snd}'],
            timeout=5, check=False,
        )
    except Exception as e:
        log(f"notify error: {e}")

def scan_task(task_dir: str, notified: dict) -> Optional[dict]:
    ui = os.path.join(task_dir, "ui_messages.json")
    try:
        with open(ui) as f:
            msgs = json.load(f)
    except Exception:
        return None
    if not msgs or len(msgs) < 3:
        return None

    task_id = os.path.basename(task_dir)
    # Walk backward through last ~10 messages, find the last assistant say:text
    # that has NO subsequent tool / use_mcp_server / api_req_started carrying a
    # tool result. If [ERROR] You did not use a tool has been injected for it,
    # this is a confirmed strike — notify (once per task per ts).
    tail = msgs[-15:]
    last_text = None
    last_text_ts = None
    saw_error_after = False
    saw_tool_after = False
    for m in tail:
        t = m.get("type")
        say = m.get("say") or ""
        ts = m.get("ts")
        text = m.get("text") or ""
        if t == "say" and say == "text" and text.strip() and not text.startswith("["):
            # candidate prose turn
            last_text = text
            last_text_ts = ts
            saw_error_after = False
            saw_tool_after = False
            continue
        if last_text is None:
            continue
        # we're after the candidate
        if t == "say" and say in ("tool", "use_mcp_server", "command", "browser_action"):
            saw_tool_after = True
        if t == "ask" and m.get("ask") in ("tool", "use_mcp_server", "command", "command_output"):
            saw_tool_after = True
        if t == "say" and say == "api_req_started":
            req = text
            if ERROR_INJECT_RE.search(req):
                saw_error_after = True

    if last_text is None or saw_tool_after:
        return None
    if not saw_error_after:
        # text turn but no ERROR yet — only fire if it looks like a trap fingerprint
        # (defensive: avoid spamming on normal narration that DOES get a tool next turn,
        # but we already checked saw_tool_after=False)
        is_trap = bool(TRAP_TAIL_RE.search(last_text.strip())) or bool(TRAP_PHRASE_RE.search(last_text[:300]))
        if not is_trap:
            return None
        severity = "WARN"
    else:
        # Cline already injected the ERROR — this is the danger zone, strike 1 of 3
        severity = "STRIKE1"

    dedup_key = f"{task_id}:{last_text_ts}"
    if notified.get(dedup_key):
        return None
    notified[dedup_key] = int(time.time())
    save_notified(notified)
    return {
        "task_id": task_id,
        "ts": last_text_ts,
        "severity": severity,
        "snippet": last_text[:240].replace("\n", " | "),
    }

def main():
    task = get_latest_task()
    if not task:
        return
    notified = load_notified()
    # Trim notified dict if huge
    if len(notified) > 500:
        cutoff = int(time.time()) - 86400
        notified = {k: v for k, v in notified.items() if v > cutoff}
    hit = scan_task(task, notified)
    status = {
        "ts": int(time.time()),
        "task_id": os.path.basename(task),
        "hit": hit,
    }
    try:
        with open(STATUS_FILE, "w") as f:
            json.dump(status, f, indent=2)
    except Exception:
        pass
    if hit:
        sev = hit["severity"]
        snippet = hit["snippet"][:80]
        title = "Cline prose-trap (rule 41)" if sev == "STRIKE1" else "Cline prose-trap WARN"
        msg = f"{sev}: {snippet}"
        notify(title, msg, sound=(sev == "STRIKE1"))
        log(f"task={hit['task_id']} sev={sev} snippet={hit['snippet']}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"top-level error: {e}")

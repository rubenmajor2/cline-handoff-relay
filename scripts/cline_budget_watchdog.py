#!/usr/bin/env python3
"""
cline_budget_watchdog.py — track per-task context budget and warn before condense

Per orchestrator_idea #5354 (Layer 1, P1, approved). Companion to Phase 3 (#5351).

Watches the LATEST Cline task's ui_messages.json. Computes per-turn token usage
from the last `api_req_started` entry and tags it GREEN/YELLOW/RED/IMMINENT.
Writes status to /tmp/cline_budget_status.json and rotates a log at
~/Library/Logs/cline_budget.log.

Triggers macOS notification first time a task crosses 800K (RED) and again at
900K (IMMINENT). Notification text steers the agent (you) to durable-artifact
the current state before condense fires.

Runs as launchd agent (com.emsu.cline-budget-watchdog) every 60s.
Reversal: launchctl unload ~/Library/LaunchAgents/com.emsu.cline-budget-watchdog.plist
"""
import json
import os
import glob
import time
import subprocess
import sys
from typing import Optional

HOME = os.path.expanduser("~")
TASKS_DIR = os.path.join(HOME, "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks")
STATUS_FILE = "/tmp/cline_budget_status.json"
LOG_FILE = os.path.join(HOME, "Library/Logs/cline_budget.log")
NOTIFIED_FILE = "/tmp/cline_budget_notified.json"  # tracks which tasks already got RED/IMMINENT notice

# Thresholds (input + cache_read + cache_write tokens summed for latest req)
GREEN_MAX   = 500_000
YELLOW_MAX  = 800_000
RED_MAX     = 900_000
# > RED_MAX = IMMINENT

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
        return dirs[0] if dirs else None
    except Exception as e:
        log(f"err listing tasks: {e}")
        return None

def get_latest_req_tokens(task_dir: str) -> Optional[dict]:
    ui = os.path.join(task_dir, "ui_messages.json")
    if not os.path.exists(ui):
        return None
    try:
        with open(ui) as f:
            data = json.load(f)
    except Exception as e:
        log(f"err reading {ui}: {e}")
        return None

    latest = None
    for m in data:
        if m.get("type") == "say" and m.get("say") == "api_req_started":
            try:
                d = json.loads(m.get("text", "{}"))
                latest = d
            except Exception:
                pass
    if not latest:
        return None

    in_tok    = latest.get("tokensIn", 0) or 0
    out_tok   = latest.get("tokensOut", 0) or 0
    cache_r   = latest.get("cacheReads", 0) or 0
    cache_w   = latest.get("cacheWrites", 0) or 0
    cost      = latest.get("cost", 0.0) or 0.0
    # The "in-context" budget that risks condense is roughly cache_reads + new tokens
    # cache_writes happen on the new content path, so they count too
    context_size = in_tok + cache_r + cache_w
    return {
        "tokensIn": in_tok,
        "tokensOut": out_tok,
        "cacheReads": cache_r,
        "cacheWrites": cache_w,
        "cost": cost,
        "context_size": context_size,
    }

def classify(ctx: int) -> str:
    if ctx < GREEN_MAX:  return "GREEN"
    if ctx < YELLOW_MAX: return "YELLOW"
    if ctx < RED_MAX:    return "RED"
    return "IMMINENT"

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

def macos_notify(title: str, msg: str) -> None:
    try:
        # Use AppleScript display notification; quiet failure if Mac headless or display unavailable
        subprocess.run([
            "osascript", "-e",
            f'display notification "{msg}" with title "{title}" sound name "Submarine"'
        ], timeout=5, check=False)
    except Exception as e:
        log(f"notify err: {e}")

def main():
    task_dir = get_latest_task()
    if not task_dir:
        return
    task_id = os.path.basename(task_dir)
    tokens = get_latest_req_tokens(task_dir)
    if not tokens:
        return

    tier = classify(tokens["context_size"])
    status = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "task_id": task_id,
        "tier": tier,
        "context_size": tokens["context_size"],
        "in": tokens["tokensIn"],
        "cache_r": tokens["cacheReads"],
        "cache_w": tokens["cacheWrites"],
        "cost": round(tokens["cost"], 4),
        "thresholds": {"GREEN": GREEN_MAX, "YELLOW": YELLOW_MAX, "RED": RED_MAX},
    }
    with open(STATUS_FILE, "w") as f:
        json.dump(status, f, indent=2)
    # P1 — idea #7377: also write per-task file so concurrent tasks don't clobber each other
    per_task_file = f"/tmp/cline_budget_status_TASK{task_id}.json"
    with open(per_task_file, "w") as f:
        json.dump(status, f, indent=2)

    # Notification logic: only fire once per task per tier (RED, IMMINENT)
    if tier in ("RED", "IMMINENT"):
        notified = load_notified()
        key = f"{task_id}:{tier}"
        if key not in notified:
            if tier == "RED":
                title = "Cline budget RED (>800K)"
                msg   = "Write current state to HANDOFF/ledger/idea before next risky tool. Condense risk approaching."
            else:
                title = "Cline budget IMMINENT (>900K)"
                msg   = "Auto-condense imminent. Save state NOW. Use attempt_completion + pickup prompt to spawn fresh window."
            macos_notify(title, msg)
            notified[key] = status["ts"]
            # Prune entries older than 24h to keep file tiny
            cutoff = time.time() - 86400
            notified = {k: v for k, v in notified.items() if isinstance(v, str)}
            save_notified(notified)
            log(f"NOTIFIED {tier} task={task_id} ctx={tokens['context_size']}")
        else:
            log(f"tier={tier} task={task_id} ctx={tokens['context_size']} (already notified)")
    else:
        log(f"tier={tier} task={task_id} ctx={tokens['context_size']}")

if __name__ == "__main__":
    main()

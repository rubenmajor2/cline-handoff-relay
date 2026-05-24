#!/usr/bin/env python3
"""
strike_watch.py — Strike-1 early-warning for the no-tool-use YOLO triple.

Source: 2026-05-24 — Ruben "still bunches of yolos on newly opened tasks".
yolo_learner already catches the YOLO triple (strike 3 of 3) but the user
only sees it AFTER the task is dead. This watcher scans every active Cline
task's api_conversation_history.json for FRESH `[ERROR] You did not use a tool`
injections from Cline and fires an osascript banner the moment strike 1
happens — so Ruben can intervene before strike 3 kills the task.

Behavior:
  - Scans all tasks modified in the last 30 minutes.
  - Counts unique [ERROR] You did not use a tool injections per task.
  - Fires notification at strike 1 (the SAME injection seen once) — so the
    next no-tool turn could YOLO.
  - State file at /tmp/cline_strike_watch_state.json tracks per-task seen
    strike count so each strike only notifies once.
  - Safe to run every minute via launchd; idempotent on state.

Pairs with rule 41 (the colon-trailed announcement test) — the notification
text quotes the binary check so the model sees it in its own context if it's
mid-stream.

Exit codes:
  0 — ran cleanly (regardless of strikes found)
  1 — fatal error (state file unreadable, dir missing)
"""

import json
import os
import sys
import time
import subprocess
from datetime import datetime, timedelta

TASKS_DIR = os.path.expanduser(
    "~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
)
STATE_FILE = "/tmp/cline_strike_watch_state.json"
LOG_FILE = "/tmp/cline_strike_watch.log"
ERROR_MARKER = "[ERROR] You did not use a tool"
SCAN_WINDOW_MIN = 30  # only look at tasks modified in last N min
ALERT_AT_STRIKE = 1   # fire on strike 1 (so 2 more strikes available)


def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}\n"
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line)
    except Exception:
        pass


def load_state():
    if not os.path.exists(STATE_FILE):
        return {}
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    try:
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f, indent=2)
        os.replace(tmp, STATE_FILE)
    except Exception as e:
        log(f"state save failed: {e}")


def count_strikes(task_id):
    """Return (strike_count, last_user_text_snippet) for a task.
    Counts consecutive [ERROR] injections at the tail of the conversation."""
    hist_path = os.path.join(TASKS_DIR, task_id, "api_conversation_history.json")
    if not os.path.exists(hist_path):
        return 0, ""
    try:
        with open(hist_path) as f:
            hist = json.load(f)
    except Exception:
        return 0, ""

    # Walk from the end backwards. Count consecutive user messages that
    # contain ERROR_MARKER. As soon as we hit a user msg without it (real
    # user input) or an assistant msg, stop.
    strikes = 0
    last_real_user_text = ""
    for msg in reversed(hist):
        role = msg.get("role")
        content = msg.get("content")
        text_blob = ""
        if isinstance(content, list):
            for blk in content:
                t = blk.get("text") or ""
                text_blob += t
        elif isinstance(content, str):
            text_blob = content

        if role == "user":
            if ERROR_MARKER in text_blob:
                strikes += 1
                continue
            else:
                last_real_user_text = text_blob[:120]
                break
        elif role == "assistant":
            # Hit a real assistant turn — stop counting (the run is interleaved).
            # But if we already counted strikes, those ARE consecutive from tail.
            break
    return strikes, last_real_user_text


def notify(title, message):
    try:
        # Escape quotes for AppleScript
        title_s = title.replace('"', "'")
        msg_s = message.replace('"', "'").replace("\\", "")
        applescript = (
            f'display notification "{msg_s}" with title "{title_s}" '
            f'sound name "Sosumi"'
        )
        subprocess.run(
            ["osascript", "-e", applescript],
            capture_output=True, text=True, timeout=5
        )
        log(f"notify: {title} — {message[:80]}")
    except Exception as e:
        log(f"notify failed: {e}")


def main():
    if not os.path.isdir(TASKS_DIR):
        log(f"tasks dir missing: {TASKS_DIR}")
        return 1

    cutoff = time.time() - (SCAN_WINDOW_MIN * 60)
    state = load_state()
    now_iso = datetime.now().isoformat()

    candidate_tasks = []
    try:
        for entry in os.listdir(TASKS_DIR):
            tdir = os.path.join(TASKS_DIR, entry)
            if not os.path.isdir(tdir):
                continue
            hist = os.path.join(tdir, "api_conversation_history.json")
            if not os.path.exists(hist):
                continue
            try:
                mtime = os.path.getmtime(hist)
                if mtime > cutoff:
                    candidate_tasks.append((entry, mtime))
            except Exception:
                continue
    except Exception as e:
        log(f"listdir failed: {e}")
        return 1

    if not candidate_tasks:
        log(f"no active tasks in last {SCAN_WINDOW_MIN} min")
        save_state(state)
        return 0

    log(f"scanning {len(candidate_tasks)} active task(s)")

    for task_id, mtime in candidate_tasks:
        strikes, last_user = count_strikes(task_id)
        if strikes == 0:
            # Reset state for this task — clean recovery
            if task_id in state and state[task_id].get("last_strike_count", 0) > 0:
                log(f"task {task_id}: strikes reset to 0 (recovered)")
                state[task_id]["last_strike_count"] = 0
                state[task_id]["last_seen"] = now_iso
            continue

        prev = state.get(task_id, {})
        prev_count = prev.get("last_strike_count", 0)

        # Only notify when strike count INCREASES (so each new strike pings once)
        if strikes > prev_count and strikes >= ALERT_AT_STRIKE:
            remaining = max(0, 3 - strikes)
            urgency = "⚠️" if strikes == 1 else "🚨" if strikes == 2 else "💀"
            title = f"{urgency} Cline strike {strikes}/3 — {remaining} left before YOLO"
            body = (
                f"task ...{task_id[-6:]}: model emitted prose, no tool. "
                f"{remaining} strike(s) left. Open the task and tell it to call a tool."
            )
            notify(title, body)

        state[task_id] = {
            "last_strike_count": strikes,
            "last_seen": now_iso,
            "last_user_text_snippet": last_user,
        }
        log(f"task {task_id}: strikes={strikes} (was {prev_count})")

    # Garbage collect: drop state entries older than 6 hours
    cutoff_state = (datetime.now() - timedelta(hours=6)).isoformat()
    state = {k: v for k, v in state.items() if v.get("last_seen", "") > cutoff_state}

    save_state(state)
    return 0


if __name__ == "__main__":
    sys.exit(main())

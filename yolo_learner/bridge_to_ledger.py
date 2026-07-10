#!/usr/bin/env python3
"""
bridge_to_ledger.py — mirror YOLO-tripped tasks into cline_task_ledger.md
so they appear on the "Open Tasks" tab at ruben_executor_live.php.

Problem this fixes:
  - Normal task exits go through attempt_completion, which appends a row
    to ~/Documents/Cline/cline_task_ledger.md per rule 03.
  - YOLO-mode trips kill a task BEFORE attempt_completion can fire, so
    those tasks were invisible on the Open Tasks tab. ~185/mo lost.

What this does:
  - Reads yolo_trips.sqlite for every distinct task_id that ever tripped.
  - Reads the current cline_task_ledger.md.
  - For each tripped task_id that is NOT already represented in the
    ledger, appends a `blocked` row using:
      when  = detected_at of the most recent trip (PT)
      topic = first 55 chars of last_user_msg_start (the user prompt
              at the moment it died) — or a triple summary if empty
      status= blocked
      cue   = short triple category + first 180 chars of last user msg
  - Idempotent: re-running adds nothing new unless new trips happened.
  - Exits 0 even on failure (launchd-safe).

Called by run.sh immediately BEFORE push_ledger.sh so the fresh rows
get pushed to WOPR in the same cycle.
"""
from __future__ import annotations

import os
import re
import sqlite3
import sys
import time
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
DB = HOME / "Documents/Cline/yolo_learner/yolo_trips.sqlite"
LEDGER = HOME / "Documents/Cline/cline_task_ledger.md"
LOG = Path("/tmp/cline_ledger_push.log")


def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S %Z")
    line = f"[{ts}] bridge_to_ledger: {msg}\n"
    try:
        LOG.open("a").write(line)
    except Exception:
        pass
    print(line.rstrip())


def summarize_triple(triple: str | None) -> str:
    """Compress the ' > ' separated cat list into a short tag."""
    if not triple:
        return "yolo-trip"
    parts = [p.strip() for p in triple.split(">") if p.strip()]
    if not parts:
        return "yolo-trip"
    # map long names to short tags
    def short(cat: str) -> str:
        c = cat.lower()
        if "no-tool-use" in c: return "no-tool-use"
        if "timeout" in c: return "timeout"
        if "overloaded" in c or "rate-limit" in c: return "api-overload"
        if "ssh" in c: return "ssh"
        if "permission denied" in c: return "perm-denied"
        if "file/path does not exist" in c or "file/path" in c: return "bad-path"
        if "mysql" in c: return "mysql"
        if "search block" in c or "replace" in c: return "replace-mismatch"
        if "command not found" in c or "shell" in c: return "cmd-not-found"
        if "generic execution" in c: return "tool-error"
        return c[:20]

    shorts = [short(p) for p in parts]
    # Collapse runs: ["timeout","no-tool-use","no-tool-use"] -> "timeout > no-tool-use x2"
    out = []
    i = 0
    while i < len(shorts):
        j = i
        while j + 1 < len(shorts) and shorts[j + 1] == shorts[i]:
            j += 1
        run_len = j - i + 1
        if run_len > 1:
            out.append(f"{shorts[i]} x{run_len}")
        else:
            out.append(shorts[i])
        i = j + 1
    return " > ".join(out)


def parse_ledger_task_ids(ledger_path: Path) -> set[str]:
    """Return the set of task_ids (bare, no '#') already in the ledger."""
    if not ledger_path.exists():
        return set()
    ids: set[str] = set()
    rx = re.compile(r"\|\s*#([^|\s]+)\s*\|")
    for line in ledger_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.startswith("- "):
            continue
        m = rx.search(line)
        if m:
            ids.add(m.group(1).strip())
    return ids


def clean_one_line(s: str | None, max_len: int) -> str:
    """First line of s, collapsed whitespace, trimmed to max_len, no pipes."""
    if not s:
        return ""
    # take first non-empty line
    line = ""
    for raw in s.splitlines():
        raw = raw.strip()
        if raw:
            line = raw
            break
    # sanitize — ledger is pipe-delimited
    line = line.replace("|", "/").replace("\t", " ")
    line = re.sub(r"\s+", " ", line).strip()
    if len(line) > max_len:
        line = line[: max_len - 1].rstrip() + "…"
    return line


def main() -> int:
    if not DB.exists():
        log(f"no db at {DB}, skipping")
        return 0
    if not LEDGER.exists():
        log(f"no ledger at {LEDGER}, will create on first row")

    existing = parse_ledger_task_ids(LEDGER)
    log(f"ledger has {len(existing)} distinct task_ids already")

    conn = sqlite3.connect(DB)
    # Pick the MOST RECENT trip per task_id so we only add one row per task.
    # Use row_number-ish approach: fetch all, group in Python.
    rows = conn.execute(
        """
        SELECT task_id, trip_index, detected_at, triple, last_user_msg_start, resumed
        FROM trips
        ORDER BY task_id, detected_at DESC, trip_index DESC
        """
    ).fetchall()
    conn.close()

    # Dedupe to one-per-task (the newest).
    latest: dict[str, tuple] = {}
    for tid, idx, det, triple, lastmsg, resumed in rows:
        if tid not in latest:
            latest[tid] = (idx, det, triple, lastmsg, resumed)

    to_append: list[str] = []
    for tid, (idx, det, triple, lastmsg, resumed) in latest.items():
        if tid in existing:
            continue  # already in ledger (from this bridge, a clean exit, or prior run)
        # Build ledger line:
        # "- YYYY-MM-DD HH:MM | #<task_id> | <topic> | blocked | <cue>"
        # use PT because server + ledger convention (rule 04). time.localtime
        # on the Mac is ET, not PT — convert.
        # Easier: detected_at is a unix epoch (UTC). Convert to America/Los_Angeles.
        try:
            from zoneinfo import ZoneInfo
            from datetime import datetime, timezone
            dt = datetime.fromtimestamp(int(det), tz=timezone.utc).astimezone(ZoneInfo("America/Los_Angeles"))
            when_str = dt.strftime("%Y-%m-%d %H:%M")
        except Exception:
            # fallback: Mac localtime
            when_str = time.strftime("%Y-%m-%d %H:%M", time.localtime(int(det)))

        triple_short = summarize_triple(triple or "")
        last_msg_short = clean_one_line(lastmsg, 140)
        topic_core = clean_one_line(lastmsg, 55) or f"yolo trip ({triple_short})"
        topic = f"yolo-dead: {topic_core}"

        cue_parts: list[str] = []
        cue_parts.append(f"yolo trip ({triple_short})")
        if last_msg_short:
            cue_parts.append(f"last msg: {last_msg_short}")
        if resumed:
            cue_parts.append("resumed at least once")
        cue = " · ".join(cue_parts)
        cue = cue.replace("|", "/")

        line = f"- {when_str} | #{tid} | {topic} | blocked | {cue}"
        to_append.append(line)

    if not to_append:
        log("no new yolo-tripped tasks to bridge, ledger is up to date")
        return 0

    # Sort oldest first so they land chronologically at the tail.
    to_append.sort()

    # Append with a one-time header comment if this is our first bridge run.
    header = ""
    if not LEDGER.exists():
        header = "# Cline Task Ledger\n\n"
    with LEDGER.open("a", encoding="utf-8") as f:
        if header:
            f.write(header)
        f.write("\n")
        for ln in to_append:
            f.write(ln + "\n")

    log(f"appended {len(to_append)} yolo-dead rows to {LEDGER}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log(f"exception: {e}")
        sys.exit(0)

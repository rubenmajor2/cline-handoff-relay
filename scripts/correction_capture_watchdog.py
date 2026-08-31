#!/usr/bin/env python3
"""
correction_capture_watchdog.py — auto-capture Ruben corrections (idea #29013).

The human_corrections ledger (idea #28961) depended on agents remembering to call
clinerules_record_human_correction when Ruben corrected a claim. Honor-system
capture is the same defect class rule 301 had before its mechanical gates.

This watchdog makes capture MECHANICAL for the Cline surface:
  - Every 120s, scan recent Cline task ui_messages.json files (mtime < 24h).
  - Find user feedback messages containing correction language
    ("that is false", "that's wrong", "not true", "you claimed X but",
     "that never happened", "you said X but", "incorrect", "you lied").
  - Pair each with the immediately preceding assistant completion/claim text.
  - INSERT into the clinerules MCP SQLite human_corrections table
    (surface='cline_auto') with a dedup guard (same task + same correction
    text prefix = skip).

Runs as launchd agent com.emsu.correction-capture-watchdog. Log: /tmp/correction_capture.log
"""
import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

HOME = Path.home()
TASKS_DIR = HOME / "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
DB_PATH = HOME / ".clinerules-mcp/index.sqlite"
LOG = Path("/tmp/correction_capture.log")
LOOKBACK_SECS = 24 * 3600

# Correction language RUBEN uses when an agent claim was false. Deliberately
# conservative: high-precision phrases only, so the human ledger stays clean.
CORRECTION_RE = re.compile(
    r"(?:that(?:'s| is) (?:false|wrong|not true|incorrect|a lie)"
    r"|not true\b"
    r"|you (?:claimed|said|told me|stated) .{0,80}\b(?:but|however|which is|and that)"
    r"|that (?:never happened|did not happen|didn't happen)"
    r"|(?:this|that) is (?:fabricat|gaslight)"
    r"|you (?:lied|made that up|fabricated)"
    r"|claim .{0,40}(?:was|is) false"
    r"|false claim)",
    re.IGNORECASE,
)

# Exclusions: text ABOUT correction systems (building/discussing them), not a correction.
META_RE = re.compile(
    r"(?:correction (?:meter|ledger|capture|watchdog)|human_corrections|R2\d{4}|idea #\d+"
    r"|clinerules_record_human_correction|false-claim meter|gate_blocks)",
    re.IGNORECASE,
)

def log(msg: str) -> None:
    with LOG.open("a") as f:
        f.write(time.strftime("%Y-%m-%dT%H:%M:%S ") + msg + "\n")

def extract_text(msg) -> str:
    """ui_messages entries carry text in 'text' (may be JSON-wrapped)."""
    t = msg.get("text") or ""
    if isinstance(t, str) and t.startswith("{"):
        try:
            inner = json.loads(t)
            t = inner.get("response") or inner.get("text") or t
        except Exception:
            pass
    return t if isinstance(t, str) else ""

def scan_task(task_dir: Path, con: sqlite3.Connection) -> int:
    ui = task_dir / "ui_messages.json"
    if not ui.exists():
        return 0
    try:
        msgs = json.loads(ui.read_text(errors="replace"))
    except Exception:
        return 0
    if not isinstance(msgs, list):
        return 0
    task_id = task_dir.name
    inserted = 0
    last_assistant = ""
    for m in msgs:
        if not isinstance(m, dict):
            continue
        mtype = m.get("type")
        say = m.get("say") or ""
        ask = m.get("ask") or ""
        text = extract_text(m)
        if not text:
            continue
        if mtype == "say" and say in ("text", "completion_result"):
            last_assistant = text
            continue
        # User feedback arrives as ask-responses / user_feedback says.
        is_user = (mtype == "say" and say == "user_feedback") or (mtype == "ask" and ask == "")
        if not is_user:
            continue
        if not CORRECTION_RE.search(text) or META_RE.search(text):
            continue
        correction = text.strip()[:1000]
        claim = (last_assistant.strip()[:1000]) or "(prior agent claim not captured)"
        # Dedup: same task + same correction prefix already recorded
        row = con.execute(
            "SELECT 1 FROM human_corrections WHERE task_id = ? AND substr(correction_text,1,120) = ? LIMIT 1",
            (task_id, correction[:120]),
        ).fetchone()
        if row:
            continue
        con.execute(
            "INSERT INTO human_corrections (task_id, rule_id, surface, claim_text, correction_text) VALUES (?,?,?,?,?)",
            (task_id, None, "cline_auto", claim, correction),
        )
        inserted += 1
    if inserted:
        con.commit()
    return inserted

def capture_auto_probes(task_dir: Path, con: sqlite3.Connection) -> int:
    """
    Anti-laundering half of idea #29011 (Ruben 2026-08-31: 'could a small probe
    be used to falsely claim something has been verified?'). Self-logged probes
    can launder fake (verified:) markers via token overlap, because the agent
    writes both the marker and the probe. This function machine-captures the
    task's ACTUAL tool calls from api_conversation_history.json into
    session_probes with source='auto'. The validator's freshness gate prefers
    the auto set when it exists, so an agent cannot launder evidence through
    a ledger it does not control.
    """
    hist = task_dir / "api_conversation_history.json"
    if not hist.exists():
        return 0
    try:
        msgs = json.loads(hist.read_text(errors="replace"))
    except Exception:
        return 0
    if not isinstance(msgs, list):
        return 0
    task_id = task_dir.name
    # Dedup: track how many auto probes already stored, only append new ones.
    existing = con.execute(
        "SELECT COUNT(*) FROM session_probes WHERE task_id = ? AND source = 'auto'",
        (task_id,),
    ).fetchone()[0]
    tool_events = []
    for m in msgs:
        if not isinstance(m, dict):
            continue
        content = m.get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use":
                name = str(block.get("name") or "")[:200]
                args = json.dumps(block.get("input") or {})[:400]
                tool_events.append((name, args))
            elif block.get("type") == "tool_result":
                # Capture a snippet of what the tool RETURNED — the strongest artifact.
                c = block.get("content")
                snippet = ""
                if isinstance(c, str):
                    snippet = c[:400]
                elif isinstance(c, list):
                    for part in c:
                        if isinstance(part, dict) and part.get("type") == "text":
                            snippet = str(part.get("text") or "")[:400]
                            break
                if snippet and tool_events:
                    name, args = tool_events[-1]
                    tool_events[-1] = (name, (args + " => " + snippet)[:900])
    if len(tool_events) <= existing:
        return 0
    inserted = 0
    for name, artifact in tool_events[existing:]:
        if not name:
            continue
        con.execute(
            "INSERT INTO session_probes (task_id, tool, artifact, source) VALUES (?,?,?, 'auto')",
            (task_id, name, artifact),
        )
        inserted += 1
    if inserted:
        con.commit()
    return inserted

def main() -> int:
    if not DB_PATH.exists():
        log(f"DB missing at {DB_PATH}; clinerules MCP not initialized yet")
        return 1
    if not TASKS_DIR.exists():
        log(f"tasks dir missing at {TASKS_DIR}")
        return 1
    con = sqlite3.connect(str(DB_PATH), timeout=10)
    con.execute("PRAGMA busy_timeout = 5000")
    now = time.time()
    total = 0
    probes = 0
    scanned = 0
    for task_dir in TASKS_DIR.iterdir():
        if not task_dir.is_dir():
            continue
        try:
            if now - task_dir.stat().st_mtime > LOOKBACK_SECS:
                continue
        except OSError:
            continue
        scanned += 1
        try:
            total += scan_task(task_dir, con)
            probes += capture_auto_probes(task_dir, con)
        except sqlite3.OperationalError as e:
            log(f"sqlite busy on {task_dir.name}: {e}")
    con.close()
    log(f"scan complete: {scanned} recent task(s), {total} new correction(s), {probes} auto probe(s) captured")
    return 0

if __name__ == "__main__":
    sys.exit(main())

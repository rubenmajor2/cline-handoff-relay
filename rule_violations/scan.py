#!/usr/bin/env python3
"""
Cline rule-violation scanner.

Mirrors yolo_learner/scan.py but for two specific .clinerules:
- Rule 17 (subagent use on research/multi-step builds)
- Rule 95 (30s tool wall — scp+nohup pattern for remote long-running work)

Walks ~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks
and detects "should-have-but-didn't" cases.

Idempotent (DB primary key on task_id+violation_index). Designed to run every
30 minutes via launchd, alongside yolo_learner.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import time
from collections import Counter
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
# Cross-platform task dir lookup (Mac VS Code or Linux code-server)
_MAC_TASKS = HOME / "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
_LINUX_TASKS = HOME / ".local/share/code-server/User/globalStorage/saoudrizwan.claude-dev/tasks"
if _MAC_TASKS.exists():
    TASKS = _MAC_TASKS
elif _LINUX_TASKS.exists():
    TASKS = _LINUX_TASKS
else:
    TASKS = _MAC_TASKS  # default; scan.py will log "no tasks dir" if absent
STATE_DIR = HOME / "Documents/Cline/rule_violations"
DB = STATE_DIR / "violations.sqlite"
PATTERNS_OUT = STATE_DIR / "patterns.json"
LOG = Path("/tmp/cline_rule_violations.log")

STATE_DIR.mkdir(parents=True, exist_ok=True)


def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S %Z")
    line = f"[{ts}] {msg}\n"
    try:
        LOG.open("a").write(line)
    except Exception:
        pass
    print(line.rstrip())


def db_connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS violations (
            task_id TEXT NOT NULL,
            violation_index INTEGER NOT NULL,
            detected_at INTEGER NOT NULL,
            rule TEXT NOT NULL,
            kind TEXT NOT NULL,
            evidence TEXT,
            user_msg_start TEXT,
            PRIMARY KEY (task_id, violation_index)
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS scan_meta (
            k TEXT PRIMARY KEY,
            v TEXT
        )
    """)
    conn.commit()
    return conn


# ---------------------------------------------------------------------------
# Heuristics — kept conservative. Better to under-count than spam false-positives.
# ---------------------------------------------------------------------------

# Rule 17: research/multi-step keywords in user message that should trigger subagent dispatch
SUBAGENT_TRIGGERS = re.compile(
    r"\b(research|verify|look up|investigate|find out where|"
    r"why does|why is|what does .* mean|"
    r"known issue|known bug|"
    r"plan a (build|migration|deploy|rollout)|"
    r"diagnose|root cause|root-cause|"
    r"compare .* (and|vs|versus) |"
    r"survey|audit|inventory of|"
    r"use subagent|use subagents|parallel research|"
    r"scaling|scale to|how many|architecture|architectural|"
    r"how should|what is the right way)",
    re.IGNORECASE,
)

# Rule 17: Ruben explicit asks
EXPLICIT_SUBAGENT_ASK = re.compile(
    r"(use\s+subagent|use\s+sub-agent|dispatch\s+subagent|"
    r"parallel\s+research|in\s+parallel|fan\s*out|"
    r"i\s+want\s+you\s+to\s+(use|verify|research|check))",
    re.IGNORECASE,
)

# Rule 95: detection patterns for risky long-running remote work
# A command that ssh's to wopr/artemis/server doing a multi-step thing
# without nohup/disown/&/scp-script pattern.
SSH_REMOTE_RE = re.compile(
    r'<execute_command>.*?<command>(.*?)</command>',
    re.DOTALL | re.IGNORECASE,
)

NOHUP_PATTERN = re.compile(r"\b(nohup|disown|tmux|screen|systemd-run|at\s+now)\b", re.IGNORECASE)

REMOTE_HINT = re.compile(
    r"(ssh\s+(wopr|artemis|emsuserver)|"
    r"crmGAx0mcp0ssh_command|"
    r"git\s+(push|pull|fetch|clone)\s+(http|https|origin)|"
    r"npm\s+(install|run\s+build|publish)|"
    r"composer\s+(install|update)|"
    r"php\s+/var/www|"
    r"apt(-get)?\s+install|"
    r"systemctl\s+(reload|restart|status)\s+\S+|"
    r"unity\s+-batchmode|"
    r"docker\s+(build|push|pull|run)\s)",
    re.IGNORECASE,
)

# A command is "long-running risky" if it has a remote hint AND lacks
# nohup/disown/scp-script pattern AND is on a single ssh line (not pre-staged
# with scp + nohup launch pattern from rule 95).
def looks_like_unguarded_remote(cmd: str) -> bool:
    if not REMOTE_HINT.search(cmd):
        return False
    # already using nohup/disown/tmux/screen — fine
    if NOHUP_PATTERN.search(cmd):
        return False
    # explicit timeout wrapper — operator was being careful
    if re.search(r"\btimeout\s+\d", cmd):
        return False
    # ssh with redirect to log + & — close enough to the pattern
    if re.search(r"&\s*disown|&\s*$|>\s*/tmp/.*\.log\s+2>&1\s*&", cmd, re.MULTILINE):
        return False
    # short read-only commands
    if re.search(r"^\s*ssh\s+\S+\s+['\"]?(uptime|free\b|hostname|whoami|date|"
                 r"systemctl is-active|cat /var/tmp/|tail -[0-9]+ /var/log/|"
                 r"ls\s|stat\s|echo\s)", cmd):
        return False
    return True


# Find user messages (task starts + follow-ups) and the assistant turns that
# follow them. Did Cline call use_subagents in the next ~5 turns? Did Cline
# call execute_command with a long-running remote command without nohup?

def payload_text(m: dict) -> str:
    parts: list[str] = []
    for k in ("text", "request", "response", "output"):
        v = m.get(k)
        if isinstance(v, str):
            parts.append(v)
    return "\n".join(parts)


def is_user_msg(m: dict) -> bool:
    t = m.get("type")
    say = m.get("say")
    return t == "ask" or (t == "say" and say in ("user_feedback", "task"))


def scan_task(conn: sqlite3.Connection, task_id: str) -> int:
    p = TASKS / task_id / "ui_messages.json"
    if not p.exists():
        return 0
    try:
        data = json.load(p.open())
    except Exception as e:
        log(f"  skip {task_id}: {e}")
        return 0

    inserted = 0
    violation_idx = 0

    # Walk: for each user message, look at the next ~12 assistant turns.
    for i, m in enumerate(data):
        if not is_user_msg(m):
            continue
        user_text = (m.get("text", "") or "").strip()
        if not user_text:
            continue
        user_low = user_text.lower()

        # Look-ahead window: collect assistant text + tool uses for next ~30 messages
        window_text_parts: list[str] = []
        used_subagents = False
        bad_remote_cmds: list[str] = []
        for j in range(i + 1, min(i + 30, len(data))):
            mm = data[j]
            if is_user_msg(mm):
                break  # next user turn — end of window
            wt = payload_text(mm)
            window_text_parts.append(wt)
            if "<use_subagents>" in wt or '"name": "use_subagents"' in wt or "use_subagents(" in wt:
                used_subagents = True
            for cmd_match in SSH_REMOTE_RE.finditer(wt):
                cmd = cmd_match.group(1).strip()
                if looks_like_unguarded_remote(cmd):
                    bad_remote_cmds.append(cmd[:300])
        window_text = "\n".join(window_text_parts)

        # ---- Rule 17 violations ----
        # Strong signal: Ruben explicitly asked for subagents and they weren't used
        explicit_ask = bool(EXPLICIT_SUBAGENT_ASK.search(user_low))
        # Weaker signal: the user msg has research/multi-step keywords AND
        # the response is non-trivial (has tool uses) AND no subagent call
        research_signal = bool(SUBAGENT_TRIGGERS.search(user_low)) and len(window_text) > 800

        if (explicit_ask or research_signal) and not used_subagents:
            # Skip if window is tiny — probably a quick Q/A
            if len(window_text) < 300 and not explicit_ask:
                pass
            else:
                violation_idx += 1
                cur = conn.execute(
                    "SELECT 1 FROM violations WHERE task_id=? AND violation_index=?",
                    (task_id, violation_idx),
                ).fetchone()
                if not cur:
                    kind = "explicit_ask_ignored" if explicit_ask else "research_no_subagent"
                    conn.execute("""
                        INSERT INTO violations
                          (task_id, violation_index, detected_at, rule, kind,
                           evidence, user_msg_start)
                        VALUES (?, ?, ?, 'rule_17', ?, ?, ?)
                    """, (task_id, violation_idx, int(time.time()), kind,
                          user_text[:500], user_text[:120]))
                    inserted += 1

        # ---- Rule 95 violations ----
        for bad in bad_remote_cmds:
            violation_idx += 1
            cur = conn.execute(
                "SELECT 1 FROM violations WHERE task_id=? AND violation_index=?",
                (task_id, violation_idx),
            ).fetchone()
            if not cur:
                conn.execute("""
                    INSERT INTO violations
                      (task_id, violation_index, detected_at, rule, kind,
                       evidence, user_msg_start)
                    VALUES (?, ?, ?, 'rule_95', 'unguarded_remote_cmd', ?, ?)
                """, (task_id, violation_idx, int(time.time()),
                      bad, user_text[:120]))
                inserted += 1

    conn.commit()
    return inserted


def main() -> int:
    if not TASKS.exists():
        log(f"tasks dir not found: {TASKS}")
        return 1
    conn = db_connect()
    last_seen_row = conn.execute(
        "SELECT v FROM scan_meta WHERE k='last_task_mtime'"
    ).fetchone()
    last_seen = float(last_seen_row[0]) if last_seen_row else 0.0

    newest_mtime = last_seen
    total_inserted = 0
    folder_names = sorted(os.listdir(TASKS), reverse=True)
    for d in folder_names:
        full = TASKS / d
        if not full.is_dir():
            continue
        try:
            mt = full.stat().st_mtime
        except FileNotFoundError:
            continue
        if mt < last_seen - 60:
            continue
        newest_mtime = max(newest_mtime, mt)
        n = scan_task(conn, d)
        if n:
            total_inserted += n
            log(f"  task {d}: +{n} new violation(s)")

    conn.execute(
        "INSERT OR REPLACE INTO scan_meta(k,v) VALUES('last_task_mtime', ?)",
        (str(newest_mtime),),
    )
    conn.commit()

    now = int(time.time())
    window_7d = now - 7 * 86400
    window_30d = now - 30 * 86400

    def counts_since(ts: int) -> dict:
        rule_counts = Counter()
        kind_counts = Counter()
        total = 0
        for row in conn.execute(
            "SELECT rule, kind FROM violations WHERE detected_at >= ?", (ts,)
        ):
            rule, kind = row
            rule_counts[rule] += 1
            kind_counts[kind] += 1
            total += 1
        return {
            "total": total,
            "by_rule": dict(rule_counts.most_common()),
            "by_kind": dict(kind_counts.most_common()),
        }

    out = {
        "generated_at": now,
        "generated_at_iso": time.strftime(
            "%Y-%m-%d %H:%M:%S %Z", time.localtime(now)
        ),
        "scanned_new_violations": total_inserted,
        "total_in_db": conn.execute(
            "SELECT COUNT(*) FROM violations"
        ).fetchone()[0],
        "last_7_days": counts_since(window_7d),
        "last_30_days": counts_since(window_30d),
        "all_time": counts_since(0),
    }
    PATTERNS_OUT.write_text(json.dumps(out, indent=2))
    log(
        f"scan complete: +{total_inserted} new, total in db = {out['total_in_db']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

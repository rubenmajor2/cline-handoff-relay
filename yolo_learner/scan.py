#!/usr/bin/env python3
"""
YOLO trip scanner + learner.

Scans ~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks
for Cline task folders, finds every "[YOLO MODE] Task failed" trip, classifies
the three failures that preceded it, and persists to a SQLite DB. Idempotent:
re-running only processes new trips it hasn't seen before.

Then emits /Users/rubenmajor/Documents/Cline/yolo_learner/patterns.json with
current counts so the rule-writer can turn them into a .clinerules entry.

Designed to be called by launchd every 30 minutes. Zero user interaction.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import time
import urllib.request
import urllib.error
from collections import Counter, defaultdict
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
STATE_DIR = HOME / "Documents/Cline/yolo_learner"
DB = STATE_DIR / "yolo_trips.sqlite"
PATTERNS_OUT = STATE_DIR / "patterns.json"
LOG = Path("/tmp/yolo_learner.log")

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
        CREATE TABLE IF NOT EXISTS trips (
            task_id TEXT NOT NULL,
            trip_index INTEGER NOT NULL,
            detected_at INTEGER NOT NULL,
            cat_1 TEXT,
            cat_2 TEXT,
            cat_3 TEXT,
            file_hint TEXT,
            tool_hint TEXT,
            triple TEXT,
            resumed INTEGER DEFAULT 0,
            turns_since_user INTEGER DEFAULT -1,
            last_user_msg_start TEXT,
            task_running_log_snapshot TEXT,
            PRIMARY KEY (task_id, trip_index)
        )
    """)
    # additive columns for DBs that already exist
    for col, ddl in [
        ("resumed", "ALTER TABLE trips ADD COLUMN resumed INTEGER DEFAULT 0"),
        ("turns_since_user", "ALTER TABLE trips ADD COLUMN turns_since_user INTEGER DEFAULT -1"),
        ("last_user_msg_start", "ALTER TABLE trips ADD COLUMN last_user_msg_start TEXT"),
        ("task_running_log_snapshot", "ALTER TABLE trips ADD COLUMN task_running_log_snapshot TEXT"),
    ]:
        try:
            conn.execute(ddl)
        except sqlite3.OperationalError:
            pass  # already exists
    conn.execute("""
        CREATE TABLE IF NOT EXISTS scan_meta (
            k TEXT PRIMARY KEY,
            v TEXT
        )
    """)
    conn.commit()
    return conn


def classify(text: str) -> str | None:
    if not text:
        return None
    low = text.lower()
    # "You did not use a tool in your previous response!" — biggest silent killer.
    # The model typed prose instead of calling a tool; Cline re-prompts; 3 re-prompts
    # in a row = YOLO trip. Often fires on "let me reload PHP-FPM" or "now test"
    # reasoning without actually firing the tool use block.
    if "did not use a tool in your previous response" in low:
        return "no-tool-use: model typed prose instead of calling a tool"
    # replace_in_file SEARCH failures
    if ("the search block" in low and ("did not match" in low or "does not match" in low)) \
            or "no sufficient match" in low \
            or "diff edit mismatch" in low \
            or "could not find an exact match" in low \
            or ("tool execution failed" in low and "replace_in_file" in low):
        return "replace_in_file: SEARCH did not match file"
    # tool args
    if "did not provide a value" in low:
        return "tool: missing required parameter"
    # filesystem
    if "enoent" in low or "no such file" in low or "file not found" in low:
        return "file/path does not exist"
    # ===== KAIZEN-ported categories (2026-05-09) =====
    # Lessons learned from KAIZEN's ruben_executor catalog (28 active recipes).
    # These categories show up in Cline task history but were previously
    # falling through to generic "tool: generic execution error" or "timeout".
    # See .clinerules/23-kaizen-mcp-failure-classifier.md for the policy layer.

    # safe-deploy sha drift — file changed between plan and execution.
    # KAIZEN: gate_refused_safe_deploy, 156 fires/7d on RUBEN. Same pattern when
    # Cline uses emsu-operations safe_deploy_file. Fix: re-read + recompute sha256.
    if "safe-deploy rc=30" in low or "safe_deploy gate" in low \
            or ("expected-sha256" in low and ("mismatch" in low or "did not match" in low)) \
            or "sha mismatch" in low:
        return "safe-deploy: sha drift, re-read file before retry"
    # safe-deploy flag whitelist violation. KAIZEN: destructive_step_failed.
    # Valid flags: --target --content --expected-sha256 --check --force.
    # NOT --src --source --srcfile --from --in.
    if "safe-deploy" in low and ("unknown arg" in low or "unrecognized option" in low
            or "--src" in low or "--source" in low or "--srcfile" in low):
        return "safe-deploy: invalid flag (use --target/--content/--expected-sha256)"
    # SQL unknown column — wrote columns that don't exist on target table.
    # KAIZEN: cross_table_column_pollution + sql_schema_mismatch.
    if "unknown column" in low or "doesn't exist" in low or "does not exist" in low \
            and ("column" in low or "table" in low):
        if "unknown column" in low or ("column" in low and "doesn't exist" in low):
            return "sql: unknown column (DESCRIBE target table first)"
    # PHP syntax error before deploy. KAIZEN: php_syntax_error. Fix: php -l first.
    if "php parse error" in low or "php syntax error" in low \
            or ("syntax error" in low and ("unexpected" in low or "expected expression" in low)) \
            or "strict_types declaration must be" in low:
        return "php: syntax error (run php -l before deploy)"
    # Plan with no terminal action — all read-only steps, nothing shipped.
    # KAIZEN: plan_shape_invalid (443 fires/7d, top RUBEN failure). The Cline
    # equivalent is "investigated forever, never wrote/shipped/sent anything."
    if "plan_shape_invalid" in low or "no terminal action" in low \
            or "zero steps" in low or "_salvaged" in low:
        return "plan: no terminal action (must include safe_deploy/sql_execute/write/send)"
    # Placeholder content left in step args. KAIZEN: step_content_placeholder.
    if "<derived_from_step" in low or "<full file content from step" in low \
            or "placeholder_content_not_resolved" in low:
        return "step: placeholder content not resolved"
    # Worker silent death (true OOM, not API error). KAIZEN: worker_silent_death.
    # Cline equivalent: ext-host OOM mid-task (rule 97). Fix: shorter plan,
    # delegate exploration, avoid reading large files into context.
    if "worker silently died" in low or "ext-host crashed" in low \
            or ("javascript heap out of memory" in low):
        return "worker: silent death / ext-host OOM (shorten plan, see rule 97)"
    # Anthropic credit exhausted — distinct from rate limit, NO retry.
    # KAIZEN: anthropic_credit_exhausted, escalate_no_retry.
    if "credit balance" in low or " 402" in low or "insufficient credit" in low:
        return "api: credit exhausted (escalate, no retry)"
    # ===== end KAIZEN-ported =====

    # FPM reload sudoers wall — was hidden in 'permission denied' / 'timeout' before.

    # This must come BEFORE the generic permission-denied + timeout branches.
    # Source: WOPR sudoers explicitly negates `systemctl reload php8.3-fpm`.
    # Fix: callers should use kill -USR2 or /usr/local/bin/emsu-safe-phpfpm-restart.sh.
    #
    # 2026-05-09 TIGHTENED (cline #fpm-yolo-classifier-falsepositive-2026-05-09):
    # The previous version matched ANY message containing "systemctl reload php"
    # near "php-fpm". That caught .clinerules/99-yolo-prevention-learned.md itself
    # (which DOCUMENTS the forbidden command) plus this scan.py file plus
    # write_rule.py — every time the bubble-loader pushed those into a Cline task
    # context, scan.py mislabeled unrelated YOLOs as "fpm-reload".
    # The MCP SIGUSR2 fix shipped 2026-05-05 and is working; the trips since then
    # are noise. Now require an actual rejection signal:
    #   "Sorry, user emsuserver is not allowed to execute" — sudoers verbatim
    #   "is not in the sudoers file"                       — alt sudoers msg
    # Both phrases only ever appear in real tool-call failure output, never docs.
    if ("php8.3-fpm" in low or "php-fpm" in low) and (
        ("not allowed to execute" in low and "emsuserver" in low)
        or "is not in the sudoers" in low
    ):
        return "fpm-reload: sudoers blocks systemctl, use kill -USR2 wrapper"
    if "eacces" in low or "permission denied" in low:
        return "permission denied (wrote to server path locally?)"
    # shell
    if "command not found" in low:
        return "shell: command not found"
    # mysql / ssh
    if "mysql query failed" in low:
        return "mysql query failed"
    if "ssh" in low and ("timed out" in low or "connection refused" in low):
        return "ssh: connect/timeout"
    if "port 2222" in low and "timeout" in low:
        return "ssh: port 2222 timeout"
    # api (dominant cause)
    if "overloaded_error" in low or "overloaded" in low or "rate_limit" in low \
            or "rate limit" in low or " 429" in low or " 529" in low:
        return "api: overloaded/rate-limit"
    # browser
    if "browser_action" in low and ("error" in low or "failed" in low):
        return "browser_action: failed"
    # generic timeout
    if "timeout" in low or "timed out" in low:
        return "timeout"
    if "error executing" in low:
        return "tool: generic execution error"
    if "invalid parameter" in low:
        return "tool: invalid parameter"
    if "does not have access to" in low:
        return "tool: not allowed"
    if "result missing" in low:
        return "tool: result missing"
    return None


def payload_text(m: dict) -> str:
    parts: list[str] = []
    for k in ("text", "request", "response", "output", "error"):
        v = m.get(k)
        if isinstance(v, str):
            parts.append(v)
    if m.get("say") == "tool" and isinstance(m.get("text"), str):
        try:
            inner = json.loads(m["text"])
            if isinstance(inner, dict):
                for v in inner.values():
                    if isinstance(v, str):
                        parts.append(v)
        except Exception:
            pass
    return "\n".join(parts)


TOOL_RE = re.compile(r'<(replace_in_file|write_to_file|read_file|execute_command|search_files|list_files|browser_action|use_mcp_tool|access_mcp_resource)>')
FILE_RE = re.compile(r'(/[A-Za-z0-9_./-]+\.(?:php|py|js|ts|tsx|md|json|html|css|sh|sql))')


RESUME_MARKERS = ("[task resumption]", "task was interrupted", "pick up task")


# Rule 81 integration: fetch running-log context for newly-detected trips via
# the emsu-operations HTTP bridge at 127.0.0.1:7831. Best-effort — if the
# bridge is down or returns an error, the scanner still records the trip
# without the snapshot. Adds ~150-300ms per NEW trip (idempotency check
# means re-scans don't re-fetch).
BRIDGE_URL = "http://127.0.0.1:7831/api/tools/get_task_running_log"
BRIDGE_KEY = "emsu-mcp-2026-a4b7c9d2e1f6"


def fetch_running_log_snapshot(task_id: str) -> str | None:
    """Return JSON string of the last ~10 milestones for this task, or None.
    Task id is normalized lowercase + no leading #.
    """
    tid_norm = task_id.lstrip('#').lower()
    # Defensive: bridge requires alphanum + dash/underscore
    if not re.match(r'^[a-z0-9_-]+$', tid_norm):
        return None
    try:
        req = urllib.request.Request(
            BRIDGE_URL,
            data=json.dumps({"task_id": tid_norm, "limit": 10}).encode(),
            headers={
                "Content-Type": "application/json",
                "X-Emsu-Mcp-Key": BRIDGE_KEY,
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            body = r.read().decode(errors='replace')
            parsed = json.loads(body)
            if parsed.get('success') and parsed.get('result'):
                # Compact: strip the verbose header, keep the rows
                txt = parsed['result']
                # remove the "=== RUNNING LOG ===" line
                lines = [ln for ln in txt.splitlines() if not ln.startswith("===")]
                snippet = "\n".join(lines).strip()
                if snippet and "id\tmilestone_type" not in snippet[:20]:
                    # No data rows (just header missing means empty result)
                    return None
                # Truncate at 2KB to keep sqlite happy
                return snippet[:2048] if snippet else None
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError, json.JSONDecodeError):
        return None
    return None


def scan_trip(data: list, i: int) -> dict:
    errs: list[str] = []
    tool_hint = None
    file_hint = None
    j = i - 1
    scanned = 0
    while j >= 0 and len(errs) < 3 and scanned < 60:
        mm = data[j]
        txt = payload_text(mm)
        c = classify(txt)
        if c:
            errs.append(c)
        if not tool_hint:
            m = TOOL_RE.search(txt or "")
            if m:
                tool_hint = m.group(1)
        if not file_hint:
            fm = FILE_RE.search(txt or "")
            if fm:
                file_hint = fm.group(1)
        j -= 1
        scanned += 1
    errs.reverse()

    # Resume signature: was the most-recent user message "continue", a
    # [TASK RESUMPTION] banner, or did the task start fresh?
    resumed = 0
    turns_since_user = 0
    last_user_msg_start = ""
    last_user_text = ""
    k = i - 1
    while k >= 0:
        mm = data[k]
        t = mm.get("type")
        say = mm.get("say")
        if t == "say" and say in ("text", "tool"):
            turns_since_user += 1
        if t == "ask" or (t == "say" and say in ("user_feedback", "task")):
            last_user_text = (mm.get("text", "") or "").strip()
            break
        k -= 1
    if last_user_text:
        lu = last_user_text.lower()
        last_user_msg_start = last_user_text[:120]
        # explicit resume marker
        if any(m in lu for m in RESUME_MARKERS):
            resumed = 1
        # Ruben-style "continue" opener
        elif re.match(r'\s*continue(\s*\|\s*|\s*\n\s*)continue', lu) \
                or lu.strip() == "continue" \
                or lu.startswith("continue\n") \
                or lu.startswith("continue |"):
            resumed = 1
    return {
        "cats": errs,
        "tool": tool_hint,
        "file": file_hint,
        "resumed": resumed,
        "turns_since_user": turns_since_user,
        "last_user_msg_start": last_user_msg_start,
    }


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
    trip_idx = 0
    for i, m in enumerate(data):
        if m.get("type") == "say" and m.get("say") == "error" \
                and "YOLO MODE" in (m.get("text", "") or ""):
            trip_idx += 1
            # idempotency: skip if already recorded
            cur = conn.execute("SELECT 1 FROM trips WHERE task_id=? AND trip_index=?",
                               (task_id, trip_idx)).fetchone()
            if cur:
                continue
            info = scan_trip(data, i)
            cats = info["cats"]
            cats = cats + [None] * (3 - len(cats))
            triple = " > ".join([c or "(none)" for c in cats[:3]])
            # Rule 81: fetch running-log snapshot for this task (best-effort)
            snapshot = fetch_running_log_snapshot(task_id)
            conn.execute("""
                INSERT OR REPLACE INTO trips
                  (task_id, trip_index, detected_at, cat_1, cat_2, cat_3,
                   file_hint, tool_hint, triple, resumed, turns_since_user,
                   last_user_msg_start, task_running_log_snapshot)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (task_id, trip_idx, int(time.time()),
                  cats[0], cats[1], cats[2],
                  info["file"], info["tool"], triple,
                  info.get("resumed", 0),
                  info.get("turns_since_user", -1),
                  info.get("last_user_msg_start", ""),
                  snapshot))
            inserted += 1
    conn.commit()
    return inserted


def main() -> int:
    if not TASKS.exists():
        log(f"tasks dir not found: {TASKS}")
        return 1
    conn = db_connect()
    last_seen_row = conn.execute("SELECT v FROM scan_meta WHERE k='last_task_mtime'").fetchone()
    last_seen = float(last_seen_row[0]) if last_seen_row else 0.0

    # Walk every task folder. Cheap enough (~700 folders); DB dedupes trips.
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
        if mt < last_seen - 60:  # small slack, folders can be written to
            # already processed, assume no new trips
            # (but we'll still dedupe in DB if we do hit it)
            continue
        newest_mtime = max(newest_mtime, mt)
        n = scan_task(conn, d)
        if n:
            total_inserted += n
            log(f"  task {d}: +{n} new trip(s)")

    conn.execute("INSERT OR REPLACE INTO scan_meta(k,v) VALUES('last_task_mtime', ?)",
                 (str(newest_mtime),))
    conn.commit()

    # Emit patterns.json: counts in last 7 days, 30 days, all-time
    now = int(time.time())
    window_7d = now - 7 * 86400
    window_30d = now - 30 * 86400

    def counts_since(ts: int) -> dict:
        cats = Counter()
        triples = Counter()
        tools = Counter()
        files = Counter()
        total = 0
        resumed_n = 0
        turn_bucket = Counter()
        for row in conn.execute("""
            SELECT cat_1, cat_2, cat_3, tool_hint, file_hint, triple,
                   resumed, turns_since_user
              FROM trips
             WHERE detected_at >= ?
        """, (ts,)):
            c1, c2, c3, tool, fhint, triple, resumed, tsu = row
            for c in (c1, c2, c3):
                if c: cats[c] += 1
            if triple: triples[triple] += 1
            if tool: tools[tool] += 1
            if fhint:
                ext = fhint.rsplit(".", 1)[-1] if "." in fhint else ""
                if ext: files[ext] += 1
            total += 1
            if resumed: resumed_n += 1
            if tsu is not None and tsu >= 0:
                turn_bucket[min(int(tsu), 10)] += 1
        return {
            "total_trips": total,
            "categories": cats.most_common(),
            "triples": triples.most_common(15),
            "tools": tools.most_common(),
            "file_exts": files.most_common(),
            "resumed_count": resumed_n,
            "resumed_pct": round(100 * resumed_n / total, 1) if total else 0,
            "turns_since_user_hist": sorted(turn_bucket.items()),
        }

    out = {
        "generated_at": now,
        "generated_at_iso": time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(now)),
        "scanned_new_trips": total_inserted,
        "total_trips_in_db": conn.execute("SELECT COUNT(*) FROM trips").fetchone()[0],
        "last_7_days": counts_since(window_7d),
        "last_30_days": counts_since(window_30d),
        "all_time": counts_since(0),
    }
    PATTERNS_OUT.write_text(json.dumps(out, indent=2))
    log(f"scan complete: +{total_inserted} trips, total in db = {out['total_trips_in_db']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

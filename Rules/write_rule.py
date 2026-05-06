#!/usr/bin/env python3
"""
Rule writer. Reads the patterns.json emitted by scan.py and writes a living
.clinerules file:

    /Users/rubenmajor/Documents/Cline/Rules/99-yolo-prevention-learned.md

Future Cline sessions load this automatically. That's how the learning becomes
behavior: the rules file is the feedback loop.

Zero interaction. Safe to re-run whenever scan.py runs.
"""
import json
import os
import time
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
PATTERNS = HOME / "Documents/Cline/yolo_learner/patterns.json"
RULE_FILE = HOME / "Documents/Cline/Rules/99-yolo-prevention-learned.md"

# Static "how to avoid" playbook per category. Living reference; the scanner
# decides which ones to surface based on frequency.
PLAYBOOK = {
    "api: overloaded/rate-limit": [
        "Anthropic is overloaded, not a logic problem.",
        "Wait 30-60 seconds and retry ONCE. If the next call also fails, STOP.",
        "Do not fire 3 tool calls back-to-back hoping the API comes back — that burns the consecutive-mistakes budget.",
        "If two overloaded errors hit in a row, write a one-line status to the user and idle until they prompt again.",
    ],
    "timeout": [
        "A tool timed out. Do NOT immediately retry the same command — the underlying service is slow, not the call shape.",
        "If it's SSH to WOPR, try a bounded substitute first: `ssh_command` with shorter work, or split the query.",
        "If it's a MySQL/Moodle query, add LIMIT, check indexes, or ask RUBEN MCP for a pre-built tool that wraps it.",
        "Never retry a timed-out command 3 times in a row — that's an automatic YOLO trip.",
    ],
    "fpm-reload: sudoers blocks systemctl, use kill -USR2 wrapper": [
        "**Root cause:** WOPR sudoers explicitly DENIES `sudo systemctl reload php8.3-fpm` and `restart php8.3-fpm`. The negation rules in `/etc/sudoers.d/emsuserver` block these by design.",
        "**Symptom:** any code calling `sudo systemctl reload php8.3-fpm` returns rc=1 with `Sorry, user emsuserver is not allowed to execute ...`. Often misclassifies as `timeout` if SSH stalls before the error returns, or as `permission denied`.",
        "**Common offender:** the emsu-operations MCP `safe_deploy_file` (ssh.ts) used to call this directly — patched 2026-05-05 to use SIGUSR2.",
        "**Correct ways to reload FPM (pick one):**",
        "  1. MCP tool `reload_php_fpm` — already uses `kill -USR2 $(cat /var/run/php/php8.3-fpm.pid)`.",
        "  2. `/usr/local/bin/emsu-safe-phpfpm-restart.sh <reason>` — rate-limited (45s cooldown), writes state file, recommended for crons.",
        "  3. `/usr/local/bin/emsu-fpm-guard reload <reason>` — guard with cooldown + audit log.",
        "  4. Raw: `sudo kill -USR2 $(cat /var/run/php/php8.3-fpm.pid)` — only if you really need bypass.",
        "**NEVER:** `sudo systemctl reload php8.3-fpm` or `sudo systemctl restart php8.3-fpm`. They will always fail.",
        "**If you just hit this once:** do NOT retry the same systemctl call — switch to one of the wrappers above.",
    ],
    "permission denied (wrote to server path locally?)": [
        "Classic mistake: tried to `write_to_file` to a `/var/www/...` path — that's a SERVER path, not local.",
        "Local writes must go to `/Users/rubenmajor/...`, `/tmp/...`, or a git clone on Desktop.",
        "For server files, use `ssh_command` with `cat > /var/www/... <<'EOF' ... EOF` or `emsu-operations` MCP tools.",
        "Before writing, sanity-check the path prefix: `/var/`, `/etc/`, `/opt/` = server, never local.",
    ],
    "replace_in_file: SEARCH did not match file": [
        "The SEARCH block didn't match the file byte-for-byte.",
        "ALWAYS `read_file` immediately before `replace_in_file`. Never trust recall from more than 3 messages ago.",
        "Do not include `read_file`'s `42 | ` line-number prefixes in SEARCH blocks — that's metadata.",
        "Keep SEARCH blocks 3-8 lines, unique, copy-pasted from the read you just did.",
        "For edits over ~10 lines, use `write_to_file` (whole-file overwrite) — no mismatch failure mode.",
        "For server-side edits, prefer `ssh_command` with sed/heredoc over `replace_in_file` entirely.",
    ],
    "file/path does not exist": [
        "You typed a wrong path. Common: `/Desktop/...` vs `/Esktop/...` typos, or forgetting `/Users/rubenmajor/`.",
        "Before any write/read to an unknown file, `list_files` its parent directory to confirm existence.",
        "Stop retrying the same wrong path. Re-check with `ls` via `execute_command` or `list_files`.",
    ],
    "mysql query failed": [
        "Query syntax or schema issue. Don't retry identical query hoping for different result.",
        "Read the actual error text. Usually: missing table, bad column name, quoting issue.",
        "Use `emsu-operations` `describe_table` or `list_tables` before guessing.",
    ],
    "ssh: connect/timeout": [
        "WOPR might be under load or dropping connections. Check `emsu-operations` `server_status` first.",
        "If SSH is flaky, batch multiple commands into one ssh_command call instead of 3 separate ones.",
    ],
    "ssh: port 2222 timeout": [
        "Port 2222 SSH timing out — WOPR's SSH daemon may be degraded.",
        "Try `emsu-operations` `server_status` once. If that also fails, stop and report, don't retry a 3rd time.",
    ],
    "tool: missing required parameter": [
        "You called a tool without a required parameter. Re-read the tool signature before retrying.",
        "Do not retry with the same missing param — check the tool's input schema first.",
    ],
    "shell: command not found": [
        "Binary isn't in PATH or isn't installed. Don't retry.",
        "Check with `which <cmd>` or `command -v <cmd>` first, or use a known-installed alternative.",
    ],
    "browser_action: failed": [
        "Browser session may be stale. Close and relaunch, don't retry the same click blindly.",
    ],
    "tool: generic execution error": [
        "Read the actual error text instead of retrying. Usually the message tells you exactly what's wrong.",
    ],
    "tool: invalid parameter": [
        "Parameter value is wrong type or format. Read the tool schema, fix the param, then retry once.",
    ],
    "tool: result missing": [
        "Tool ran but no result came back — the terminal may have been busy.",
        "Wait a few seconds and re-check, OR shift to a different approach. Do not retry immediately.",
    ],
    "tool: not allowed": [
        "Permission/config issue. Do not retry — fix the underlying access problem first.",
    ],
}

HEADER = """# YOLO Prevention — Learned from Actual Trips

**Auto-generated by `~/Documents/Cline/yolo_learner/write_rule.py`.**
**Do NOT hand-edit — your changes will be overwritten.**

This file exists because on {when} a scan of the last Cline task history
showed `{new_this_scan}` new "[YOLO MODE] Task failed: Too many consecutive mistakes (3)"
trips this scan, against `{trips30}` cumulative in the last 30 days
(`{trips7}` in the last 7 days). The cumulative number doesn't grow unless
this scan's delta is non-zero — so a quiet day looks like "0 new this scan,
268 cumulative", not a fresh flood. Each trip kills a task mid-work and
forces Ruben to restart. This rule is the accumulated
playbook for avoiding the specific failure modes that caused them, ranked by
how often they show up.

## The one meta-rule

If the SAME tool call fails 2 times in a row, the 3rd attempt WILL trip YOLO
and end the task. So:

- **Two failures of the same kind = stop and change approach.** Do not attempt
  a third retry of the same command/SEARCH/path/query. Either report to the
  user, switch tools, re-read the file, or idle.
- **Two API overloaded errors in a row = stop and idle.** Anthropic is
  overloaded; the third call has ~0% chance of succeeding and 100% chance of
  ending the session. Post a short "Anthropic is hiccuping, pausing" and wait
  for the user.

"""


def fmt_rank_line(i: int, cat: str, n: int, total: int) -> str:
    pct = (100.0 * n / total) if total else 0.0
    return f"{i}. **{cat}** — {n} trips ({pct:.0f}%)"


def section_for(cat: str) -> str:
    lines = PLAYBOOK.get(cat)
    if not lines:
        return f"### {cat}\n\n_No specific playbook yet. First fix: re-read the actual error text before retrying._\n"
    body = "\n".join(f"- {l}" for l in lines)
    return f"### {cat}\n\n{body}\n"


def main() -> int:
    if not PATTERNS.exists():
        print(f"no patterns file at {PATTERNS} — run scan.py first")
        return 1
    data = json.loads(PATTERNS.read_text())

    w7 = data["last_7_days"]
    w30 = data["last_30_days"]
    wall = data["all_time"]

    total = wall["total_trips"] or 0
    cats = wall["categories"] or []
    triples = wall["triples"] or []

    now = time.strftime("%Y-%m-%d %H:%M %Z")
    out = [HEADER.format(
        when=now,
        trips7=w7["total_trips"],
        trips30=w30["total_trips"],
        new_this_scan=data["scanned_new_trips"],
    )]

    out.append(f"## Top failure modes (all-time, {total} trips)\n")
    for i, (cat, n) in enumerate(cats, 1):
        out.append(fmt_rank_line(i, cat, n, total))
    out.append("")

    out.append("## Most common triple-failure patterns\n")
    out.append("These are the exact `fail > fail > fail` sequences that have ended tasks:\n")
    for pat, n in triples[:10]:
        out.append(f"- `{pat}` — {n} time(s)")
    out.append("")

    out.append("## Playbook per failure mode\n")
    out.append("Sorted by how often each one has tripped YOLO. If you're about to retry something, find the matching section below and follow it instead.\n")

    seen = set()
    for cat, _ in cats:
        if cat in seen:
            continue
        seen.add(cat)
        out.append(section_for(cat))

    out.append("## What's auto-updated\n")
    out.append(f"- Last update: {now}")
    out.append(f"- Trips tracked total: {data['total_trips_in_db']}")
    out.append(f"- New trips this scan: {data['scanned_new_trips']}")
    out.append(f"- Database: `~/Documents/Cline/yolo_learner/yolo_trips.sqlite`")
    out.append(f"- Scan log: `/tmp/yolo_learner.log`")
    out.append("")
    out.append("## Changing the playbook\n")
    out.append("Edit `PLAYBOOK` in `~/Documents/Cline/yolo_learner/write_rule.py`, then re-run it. The file you're reading will regenerate.\n")

    RULE_FILE.parent.mkdir(parents=True, exist_ok=True)
    RULE_FILE.write_text("\n".join(out))
    print(f"wrote {RULE_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

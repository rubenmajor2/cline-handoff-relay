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
    "no-tool-use: model typed prose instead of calling a tool": [
        "**Root cause:** after a tool result comes back, the model emits an assistant turn containing ONLY prose (e.g. `Deployed. Now reload FPM:`, `Updated. Confirming with a SELECT:`, `Saved. Next I'll patch the route:`) with NO tool_use block. Cline re-prompts \"use a tool,\" model re-narrates, third no-tool-use strike trips YOLO. This is the #1 failure mode in the trip database — ~45% of all trips and ~85% of `no-tool-use > no-tool-use > no-tool-use` triples follow this exact shape (see rule 41).",
        "**Fix (bright-line, rule 41):** after ANY successful destructive tool result (safe_deploy_file, sql_execute INSERT/UPDATE, write_to_file, send_email, post_imessage, etc.), the NEXT assistant turn MUST contain at least one tool_use block. Words like \"Deployed. Now reload FPM\" or \"Updated. Now update HANDOFF\" are status descriptions — the model is announcing the next step but not executing it. Either emit the tool call in the SAME turn as the narration, OR call `attempt_completion` if the work is genuinely done. Never close a post-deploy turn with words alone.",
        "**Stop rule:** if you find yourself typing `Deployed.`, `Updated.`, `Inserted.`, `Patched.`, `Saved.`, `Posted.`, or `Sent.` as the FIRST word of an assistant turn after a successful destructive tool result — STOP. Continue with one of: (a) the next tool call (preferred), (b) `attempt_completion` (if done). Never with words alone. Never with a colon-terminated \"Next step:\" clause.",
        "**Mid-task narration trap:** announcing what you're about to do without doing it is the symptom. \"Let me check the cron logs:\" with no tool call is identical from Cline's perspective to forgetting to call a tool. Just call it.",
        "**Two prose turns in a row = YOLO incoming:** if you emit one assistant turn with no tool_use and Cline re-prompts, the THIRD turn must contain a tool_use OR `attempt_completion`. Re-narrating the same intent in different words is the death spiral. Switch from prose to tool action.",
        "**Capability-gap variant (rule 73):** if you genuinely don't have the right tool to do what you described, emit `attempt_completion` with a status of \"blocked — need tool X\" instead of re-narrating. Don't loop trying to describe the action; ship the blocker as a completion.",
    ],
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
    # ===== KAIZEN-ported entries (2026-05-09) =====
    # Lessons distilled from KAIZEN's ruben_executor catalog. See
    # .clinerules/23-kaizen-mcp-failure-classifier.md for the policy layer.
    "safe-deploy: sha drift, re-read file before retry": [
        "**Root cause:** the file changed on disk between when you computed expected-sha256 and when safe-deploy ran. Retrying with the same hash will fail forever.",
        "**Fix:** before re-emitting safe_deploy, READ the current file via `read_file` or `cat`, compute its actual sha256 (`sha256sum <path>`), then call safe_deploy with `--expected-sha256` set to the LIVE value.",
        "Do NOT retry with the prior expected-sha256. Do NOT skip the read step.",
        "Valid safe-deploy flags: `--target` `--content` `--expected-sha256` `--check` `--force`. NOT `--src` `--source` `--srcfile` `--from`.",
    ],
    "safe-deploy: invalid flag (use --target/--content/--expected-sha256)": [
        "**Root cause:** you used a flag safe-deploy doesn't accept. Common offenders: `--src`, `--source`, `--srcfile`, `--from`, `--in`.",
        "**Valid flags only:** `--target FILE` `--content \"string\"` `--expected-sha256 HASH` `--check` (validate-only) `--force` (bypass).",
        "If unsure, run `safe-deploy --help` first as a read-only step. Don't guess.",
    ],
    "sql: unknown column (DESCRIBE target table first)": [
        "**Root cause:** you wrote columns that don't exist on the target table — usually borrowed from a sibling/rules table that has similar column names.",
        "**Fix:** before any INSERT/UPDATE/DELETE, run `DESCRIBE table_name` (or `SHOW CREATE TABLE`). Match column names character-for-character.",
        "Common pollution: writing `rule_key`/`rule_body`/`rule_source` to `ai_compiled_rules` — those live on `lazy_agent_rulesets`. The actual `ai_compiled_rules` columns are `category`, `trigger_pattern`, `rule_text`, `channel`, `avg_confidence`, `occurrence_count`, `source_correction_ids`, `status`.",
        "If a column name in your draft doesn't appear in DESCRIBE output, REMOVE IT before the write.",
    ],
    "php: syntax error (run php -l before deploy)": [
        "**Root cause:** PHP syntax error in code you were about to deploy or just deployed.",
        "**Fix:** before any safe_deploy of PHP, write the candidate to `/tmp/temp_check_<name>.php` and run `php -l` on it. Verify exit code 0.",
        "Common errors in this codebase: missing semicolon after `}` of class/function/use; mismatched curly braces in nested arrays; bad heredoc EOF tokens; `<?php` opening tag inside a require/include.",
        "Special case: `strict_types declaration must be the first statement` — move `declare(strict_types=1);` to immediately after the opening `<?php` tag.",
    ],
    "plan: no terminal action (must include safe_deploy/sql_execute/write/send)": [
        "**Root cause:** your plan only had read-only steps (check/show/select/describe/lookup/fetch/get) and shipped nothing. KAIZEN's #1 RUBEN failure (443 hits/7d).",
        "**Fix:** every plan MUST contain at least one TERMINAL ACTION step. Terminal actions: `safe_deploy`, `sql_execute`, `write_file`, `send_email`, `send_sms`, `post_imessage`, `deploy_route`, `install_cron`, `modify_table`, `insert_data`.",
        "If you genuinely cannot decide what to ship, emit `steps:[]` with a one-sentence `notes_to_reviewer` requesting a split. That IS the correct answer; investigation-only is not.",
        "Self-check: would a fresh agent looking at the steps array be able to tell what changed in the world? If no, the plan has no terminal action.",
    ],
    "step: placeholder content not resolved": [
        "**Root cause:** a step's `args.content` / `args.sql` / `args.command` contains a template marker like `<DERIVED_FROM_STEP_Y>` or `<FULL FILE CONTENT FROM STEP X>` that was never substituted.",
        "**Fix:** every step's content MUST be the LITERAL final value. If you need to derive content from a prior step, either compute it inline before emitting the plan, or split into multiple plan turns.",
        "Never emit a write_local_file or safe_deploy with a placeholder content value.",
    ],
    "worker: silent death / ext-host OOM (shorten plan, see rule 97)": [
        "**Root cause:** the agent process died mid-execution with no API error — true OOM/kill/ext-host crash. NOT a rate-limit, NOT a transport error (those are separate).",
        "**Fix:** retry with a SHORTER plan (≤ 4 steps).",
        "Avoid reading large files into context — use `plan_delegate_exploration` instead of multiple `plan_read_file` calls.",
        "For files > 100KB, prefer `shell_command` + sed/python over reading the whole file.",
        "If this is a high-token chain (>50K input tokens), break into two chains.",
        "See `.clinerules/97-extension-host-oom.md` and `.clinerules/98-edit-discipline.md` for the prevention layer.",
    ],
    "api: credit exhausted (escalate, no retry)": [
        "**Root cause:** Anthropic credit balance exhausted (HTTP 402). DIFFERENT from rate-limit — retrying will not succeed.",
        "**Fix:** STOP. Do NOT retry. Escalate to Ruben immediately.",
        "Surface a one-line status: \"Anthropic credit exhausted, paused\" and idle.",
    ],
    # ===== end KAIZEN-ported =====
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

    # KAIZEN-ported preventive lessons. Always render even if the category
    # hasn't fired in Cline yet — these are forward-looking lessons borrowed
    # from KAIZEN's ruben_executor catalog where the same failure mode has
    # already cost RUBEN executor cycles. See .clinerules/23.
    KAIZEN_PORTED = [
        "safe-deploy: sha drift, re-read file before retry",
        "safe-deploy: invalid flag (use --target/--content/--expected-sha256)",
        "sql: unknown column (DESCRIBE target table first)",
        "php: syntax error (run php -l before deploy)",
        "plan: no terminal action (must include safe_deploy/sql_execute/write/send)",
        "step: placeholder content not resolved",
        "worker: silent death / ext-host OOM (shorten plan, see rule 97)",
        "api: credit exhausted (escalate, no retry)",
    ]
    unrendered_kaizen = [k for k in KAIZEN_PORTED if k not in seen]
    if unrendered_kaizen:
        out.append("## Preventive lessons ported from KAIZEN (forward-looking)\n")
        out.append("These categories have not yet fired in Cline task history but have repeatedly bitten the RUBEN executor. KAIZEN's recipe table is the source. Listed here so Cline avoids them on first encounter rather than learning by tripping.\n")
        for cat in unrendered_kaizen:
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

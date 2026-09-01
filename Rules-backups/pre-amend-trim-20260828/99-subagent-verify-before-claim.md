# 99 — Subagent writes are unverified until parent re-reads

Permanent hardfloor rule. Workspace-scoped. Source: 2026-07-20 — a subagent claimed it fixed cron_ai_ticket_agent.php detectRepeatCaller but the permission error was swallowed. Parent reported success to Ruben while the bug remained live for 46+ minutes.

## The bright-line rule

**Any subagent dispatch that writes files, edits code, or deploys changes MUST NOT be trusted until the parent agent independently verifies the change took effect.** The subagent's claim of success is a hypothesis, not a fact.

## Mandatory verification step

After any subagent reports a write/deploy, the parent MUST:
1. Read the file back (read_file, ssh_command cat, or checksum)
2. Run a functional check (php -l, dry-run, or grep for the expected change)
3. Only then mark the step complete

## The subagent prompt clause (mandatory in every dispatch)

Every subagent prompt that involves writing files, editing code, or deploying changes MUST include:

> After writing any file, immediately read it back and confirm the content matches what you intended. If the read-back fails or the content differs, report FAILURE with the actual error message. Do NOT report success unless you have verified the write.

## Failure pattern to ban

Subagent hits permission denied / EACCES / timeout, swallows the error, reports 'done'. Parent ships a completion based on the lie. This is a systemic trust failure.

## Cross-refs

- Rule 29 — agents act on confidence tier (verification IS the confidence check)
- Rule 41 — post-deploy call the tool (verification IS the tool call)
- Rule 91 — every completion needs pickup prompt (false claims poison the pickup prompt)
- Bug library #1882 — subagent-false-success-20260720

## Source incident

2026-07-20 — subagent claimed cron_ai_ticket_agent.php line 402 fix deployed, but sed hit permission denied. Parent reported success. Bug found during manual verification 46 minutes later.

## Last updated

2026-07-20 — initial. Source: subagent false-success incident.
## Amendment (from reversal, 2026-08-20 03:10 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-improvements-2026-08-19
- RCA bucket: insufficient probe
- Trigger pattern: Patch tool per-block success treated as file validity without running the language linter before claiming applied
- Reversal note: 2026-08-19: multi-block SEARCH/REPLACE patch on argus_task_status.php reported OK for all 13 blocks, but the insertion split an if/elseif chain producing a PHP parse error at line 638, caught only by the subsequent php -l. Amended behavior: a patch tool's per-block OK is NOT evidence the file is valid; php -l (or equivalent lint) must run and pass BEFORE any 'patch applied' claim, and multi-block insertions near if/elseif/else chains must be re-read around the seams.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 03:12 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787190192283
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - 'UI patch 13/13 blocks applied OK' -> 'PHP parse error at line 638: insertion split an if/elseif chain; repaired, php -l clean' | RCA bucket: insufficient probe | causal rule upd

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 20:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579-julia-flicker
- RCA bucket: insufficient probe
- Trigger pattern: pgrep -fc pattern self-match: verification command's own remote command line contained the search pattern, so RUNNING=1 was the probe matching itself
- Reversal note: 2026-08-20 flicker-catcher deploy: 'RUNNING=1' was reported for a watcher that never started — the pgrep -fc julia_flicker inside the ssh verification command matched the ssh command line itself. Amended behavior: when verifying a background process by pgrep over ssh, the pattern must exclude the probe (pgrep -f 'bash /tmp/script.sh' exact-form, or bracket trick), AND liveness requires a second artifact (log file created/growing), never a bare count.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-24 21:29 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787620675000
- RCA bucket: stale assumption
- Trigger pattern: php -l pass treated as evidence a patch is correct, when the patch introduced an undefined variable reference
- Reversal note: 2026-08-24 phantom-purge build: a patch to proctoring/api/override_student.php introduced `$assignmentId` in an audit string on the assumption the variable was in scope. `php -l` PASSED because the syntax is valid, and the patch was nearly claimed as applied on that basis. A grep of the file showed the variable never exists anywhere (the codebase uses `$data["assignment_id"]`), so the audit line would have silently logged an empty value. Amended behavior: a lint pass proves SYNTAX ONLY, never that referenced variables/functions exist in scope. Before claiming any patch applied, grep every identifier the patch INTRODUCES against the target file to confirm it is defined there; an undefined-variable reference is a live defect that no linter will catch in PHP.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

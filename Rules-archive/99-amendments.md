Rule 99 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 99 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/99-subagent-verify-before-claim.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 4 amendment(s))

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

## Amendment (from reversal, 2026-08-29 08:40 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787984810000
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - "PIECEWISE flag patched" → corrected: sed had stripped the JSON escaping, all 6 ranks crash-looped Exit(2); rewrote via python + scp, verified with bash -n SYNTAX_OK + docker ins

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

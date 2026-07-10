# 266 — When an agent is found WRONG, fix the instrument that misled it (not just the answer)

Permanent rule. Archive-scoped, fetched via tree trigger: "I was wrong", "correction", "my first report was incorrect", stale/incomplete tool data.

## The bright-line rule

If you (or a prior agent) made a factual claim that turned out to be WRONG, correcting the answer is only HALF the job. You MUST also:

1. **RCA the instrument.** Identify the exact tool/query/data source that produced the incomplete or wrong picture. Name it (e.g. `check_student_comms` only read `communication_log`, missing `email_outbound_log` + `email_inbound_log`).
2. **Fix the instrument the same session** if you have the tools (patch the MCP tool, widen the query, add the missing table/column) — rule 29 Gate 0 applies. If the fix is genuinely out of reach, file an idea at autonomous tier with the exact patch described.
3. **Verify the fix** (rebuild, restart, re-run the failing case — rule 140/255 live evidence).
4. **Record it** so future agents inherit the correction: bug library row and/or HANDOFF note and/or source-code comment at the patch site explaining the incident.

## Why

Answers die with the session; instruments persist. An agent that says "I was wrong, here's the corrected picture" but leaves the misleading tool untouched guarantees the NEXT agent makes the identical error. The cost of the wrong answer repeats forever until the instrument is fixed.

## Self-check (fires on the phrase "I was wrong" or any correction of a prior claim)

1. *What tool/query produced the wrong claim?* Name it explicitly in the correction.
2. *Can I patch it right now?* If yes → patch + rebuild + verify (rule 144: server paths via ssh_command).
3. *Did I leave a breadcrumb at the patch site?* (comment citing the incident + date)
4. *Does the completion cite both the corrected answer AND the instrument fix?*

## Anti-patterns

- ❌ "Correction: there were actually 5 replies, not 1" with no change to the tool that showed 1
- ❌ Filing the instrument fix as a P3 idea when you have ssh_command + build access right now
- ❌ Blaming "the data" — data sources don't mislead; queries that read the wrong table do

## Source incident

2026-07-10 — Isaiah Brye Exam 1 investigation. `check_student_comms` MCP tool queried only `communication_log` (which captures a subset of outbound email), so the agent reported "only 1 email reply was ever sent" when `email_outbound_log` showed 5. Ruben caught the error in feedback. Fix: tool patched same-session to also query `email_outbound_log` + `email_inbound_log` (with ai_response_sent/ai_skip_reason), rebuilt, service restarted. Backup: `index.ts.bak-comms-rca-20260710`.

## Cross-refs

- Rule 29 — Gate 0: can I fix it now? → do it
- Rule 263 — verify-before-claim (prevents the wrong claim in the first place; this rule governs the aftermath)
- Rule 140/255 — live-evidence verification of the fix
- Rule 144 — server-path writes via ssh_command

## Last updated

2026-07-10 — initial.

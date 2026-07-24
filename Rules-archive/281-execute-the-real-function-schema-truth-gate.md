# 281 — Execute the real function + DESCRIBE the real schema + grep logs for SQLSTATE before theorizing about any routing/eligibility bug

Permanent rule (archive). Workspace-scoped.
Slug: `execute-the-real-function-schema-truth-gate`

## Source incident

2026-07-23 — TX zoom-routing "Virtual Class Required" bug. Multiple Cline agents cycled on this for ~25 days and never found the root cause. Root cause was trivial once the right method was used: a 2026-06-28 executor "correction" in `lib/zoom.php getConnecteamShiftsFromDB()` SELECTed non-existent columns (`instructor_id`/`class_methods` — real columns are `instructor_user_id`/`class_method`), the catch block did `error_log(...); return [];` (SILENT failure), so `sectionHasLocalInstructor()` returned false for every section in every state and every student got the MUST email. 7,446+ SQLSTATE error lines sat in cron logs unnoticed (cron_class_reminders.log alone had 7,030).

**Why prior agents failed:** they investigated the CONFIG layer (routing tables, overrides, coverage rules — all looked normal) and READ the code, where a comment asserted "CORRECTED field names" — so they trusted the comment as authoritative. Nobody (a) executed the actual decision function with real inputs, (b) DESCRIBE'd the real table to check the comment's claim, or (c) grepped the production logs for SQLSTATE. Any ONE of those three moves finds the bug in under 5 minutes.

## The bright-line rule (3 mandatory moves BEFORE theorizing)

When investigating any "system made the wrong decision" bug (routing, eligibility, gating, matching, suspension, grading — any boolean/branch outcome that came out wrong), you MUST do these three things BEFORE forming a theory from reading code or config:

1. **EXECUTE the real decision function.** Write a PHP harness (`chdir('/var/www/emtskills'); require 'lib/db.php';` then call the actual function with the actual failing inputs), scp to wopr:/tmp, run it, capture stderr. Template: `/tmp/tx_check4.php` pattern. Reading the code is a hypothesis; running it is evidence. Silent `catch { return []; }` patterns are INVISIBLE to code reading but scream on execution.

2. **DESCRIBE the real table.** Any column/table name claim — in a comment, in a query, in a prior agent's note, in an executor-generated patch — is UNVERIFIED until you run `DESCRIBE <table>` (or `SHOW COLUMNS`) against the live DB. Comments lie. The TX bug's comment said "CORRECTED field names" and was exactly backwards. Executor builds hallucinate schema constantly (documented: authnet_transactions, tickets.type/intent, email_inbound_queue, outbound_log, connecteam_shifts).

3. **Grep production logs for SQLSTATE.** `for f in /var/www/emtskills/logs/*.log; do c=$(grep -c 'SQLSTATE' "$f"); [ "$c" -gt 10 ] && echo "$c $f"; done | sort -rn` — a burst of identical SQLSTATE lines in a cron log IS the root cause announcement. The system was telling everyone for 25 days; nobody listened.

## The trust hierarchy (memorize)

```
live execution output  >  DESCRIBE / live DB  >  production logs  >  code  >  comments  >  prior agents' notes
```

A comment claiming "CORRECTED / FIXED / VERIFIED" carries ZERO evidentiary weight. It records what someone BELIEVED, possibly wrongly. The 2026-06-28 comment was written by the same executor build that introduced the bug — bad knowledge written INTO the codebase then trusted by every subsequent investigator.

## The silent-catch trap

`catch (Exception $e) { error_log(...); return []; }` (or `return null` / `return false`) converts a hard failure into a plausible-looking empty result. Downstream code treats "no shifts found" as valid data. When auditing any function that returns empty/false in a wrong-decision bug: temporarily echo/capture the exception, or run the query standalone. An empty result from a function with a catch block is NOT evidence the data doesn't exist.

## Extension check (this class recurs)

Executor-generated code + "correction" patches are the top source of schema hallucinations. When you fix ONE wrong-column bug, sweep for siblings:
- `grep -rn -E '(CORRECTED|REPOINTED|FIXED).*(field|column|table)' lib/ cron/ routes/` — audit each claim with DESCRIBE
- SQLSTATE burst scan (move 3 above) — every burst >10 lines is an open wound
- Ghost-table refs: a renamed/dropped table (e.g. `connecteam_shifts` → `emsu_shifts`) leaves crons crashing on 42S02 for weeks

## Cross-refs

- Rule 99 playbook "sql: unknown column (DESCRIBE target table first)" — that covers the agent's OWN queries; this rule extends it to auditing PRODUCTION code's queries
- Rule 266 — fix the instrument that misled the agent, same session (the misleading comment must be corrected, not just the code)
- Rule 262 — bug library before recycling approaches
- Rule 29 — act on evidence; a "working theory" from code-reading is not evidence

## Last updated

2026-07-23 — initial. Source: TX zoom-routing 25-day agent-cycling incident.

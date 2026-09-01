# 299 — A negative result proves your QUERY ran, not that the thing is absent. Confirm the instrument before concluding.

Source incident: 2026-07-31, task 1785012025445. Four separate wrong conclusions in ONE session, all the same shape: a lookup returned nothing (or returned a clean-looking value), and that emptiness was reported as a fact about the world instead of a fact about the query.

| What I looked up | What came back | What I concluded | What was actually true |
|---|---|---|---|
| SLS on `eshippconway@gmail.com` | `student_not_found` | "she has no student record" | **The email was wrong.** Real address `jones.elizabeth16@yahoo.com`, inherited from a prior handoff and never re-verified |
| `grep AVSCheckStatusEnum /var/log/php8.3-fpm.log` | `0` | "the AVS bug is not firing, keep #20130 on hold" | **19 occurrences across 4 sites.** The errors live in `/var/www/vhosts/<domain>/logs/error_log`. I grepped a log that never receives them |
| Payer identity for a declined charge | Students row within ±3 min | "payer unidentified" | A decline **never creates** a Students row. The query could not have succeeded for any decline, ever |
| Ticket body: student record + invoice | (never queried) | "no student record and no invoice" | Sabrina had **both**, plus a $1,595 balance |

Each looked like evidence. Each was an instrument failure.

## The gate: before reporting ANY negative or absence, prove the instrument works

You are about to write "there is no X", "X is not happening", "no rows matched", "not found", "0 occurrences", "never fired". **Do not, until you can answer YES to all four:**

1. **Positive control.** Has this exact query/grep/tool EVER returned a hit? Run it against a case you KNOW exists. If `grep PATTERN file` returns 0, first prove that `file` contains any related line at all. A grep against the wrong file returns 0 forever and looks identical to good news.
2. **Every input independently verified.** An email, ID, path, table, or date you copied from a handoff, a ticket, a prior session, or your own earlier turn is a HYPOTHESIS. One wrong character turns a real record into `not_found`. Verify each input against a primary source before trusting the miss.
3. **The query is structurally capable of a hit.** Ask: *"under what conditions would this return a row?"* If the answer is "never, for this population" the result is meaningless. Matching a Students row for a DECLINED payment is structurally impossible, because the row is only created after payment succeeds. A structurally-impossible predicate returns 0 forever and is indistinguishable from "clean".
4. **You searched where the data actually lives.** Named the file/table/schema from an authoritative source, not memory. Multi-tenant systems (per-vhost logs, per-site DB schemas, per-service log dirs) are where this fails hardest. `0` from the wrong location is the single most common false all-clear.

Any NO → you have an unproven instrument, not a finding.

## The corollary: never assert existence you did not query either

The mirror failure is asserting something is ABSENT without checking. My ticket body told a human "no student record and no invoice" while both existed and a $1,595 balance was outstanding. **If a claim can be checked with a query, either run the query or do not make the claim.** "Not captured" and "not checked" are honest. "There is none" is a factual assertion requiring evidence.

## When a NEGATIVE drives a HOLD decision, the bar is higher

"No AVS errors, so keep the fix on hold" is a negative result authorizing inaction. This is more dangerous than a false positive: a false positive gets challenged, a false all-clear is silently accepted and the hold persists. **Any negative that justifies deferring a fix, closing an investigation, or telling a human "nothing is wrong" requires an explicit positive control** (step 1) recorded alongside it.

## Suspicious-clean is a signal, not a comfort

`0` where you expected a small number deserves MORE scrutiny than a nonzero result, not less. Same for 100% success, "no errors", or an empty table. Empty tables in this codebase have repeatedly meant *the writer was never wired up* (`registration_failure_log`, `qb_refunds`, `payment_stalled_sla_timers`, `qb_decline_audit_cache` — all 0 rows, all dead code, none of them "healthy"). **Before reading an empty table as good news, prove something writes to it.**

## Also: a correlate present in BOTH failures and successes is not the cause

Same session: the AVS enum HTTP 400 appeared on every declined charge, which looked causal. Running the control — checking SUCCESSFUL charges — showed the identical error on those too (Andrew Hughes, Samuel Winkel, Braden Lopez all succeeded WITH the error). It is a constant, not a discriminator. **Before naming X as the cause of failure, check whether X is also present in the successes.** One control query killed a hypothesis I was one step from reporting.

## Self-check

Before writing "no / none / never / not found / 0 / clean":
1. Has this instrument ever returned a hit? Did I run a positive control?
2. Did I verify every input, especially ones inherited from a handoff or an earlier turn?
3. Could this query EVER match, structurally, for this population?
4. Did I search where the data actually lives, confirmed from an authoritative source, not memory?
5. Am I asserting an absence I never queried?
6. If this negative justifies a hold or an all-clear, is the positive control recorded?
7. If I am naming a cause, did I check whether it is also present in the successes?

## Cross-references

- Rule 297 — a COUNT of "impossible" rows is a hypothesis; classify before alarming (that rule governs a POSITIVE count; this one governs a NEGATIVE/zero result)
- Rule 281 — execute the real function, DESCRIBE the real table, before theorizing
- Rule 263 — verify before claim; no factual claims without tool evidence
- Rule 271 — verify before writing infra claims to durable surfaces
- Rule 294 — re-probe INHERITED facts rather than trusting them
- Rule 266 — when the instrument misled you, fix the instrument in the same session
- Rule 99 — subagent/prior claims are unverified until independently re-read

## Last updated

2026-07-31 — initial. Source: four false negatives in one session (wrong-email SLS miss, wrong-log AVS grep, structurally-impossible payer match, unqueried "no invoice" claim), each caught only because Ruben pushed back with contradicting evidence rather than by the agent's own checking.

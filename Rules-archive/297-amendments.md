Rule 297 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 297 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/297-population-anomaly-classify-before-alarming.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 9 amendment(s))

## Amendment (from reversal, 2026-08-22 00:16 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787121837052
- RCA bucket: wrong premise
- Trigger pattern: carried 'anomaly' label resolved by reading the trigger source and classifying by-design
- Reversal note: 'UPDATE anomaly' was carried as an open bug; reading the actual source (SHOW TRIGGERS FROM admin_portal) showed orchestrator_ideas_status_audit BEFORE UPDATE trigger force-reverts any move away from status='deployed' except to deployed/rejected/superseded — deployed is sticky BY DESIGN. Classification: by-design, not a bug. Reinforces: read the source that produced the symptom and classify before claiming a bug.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-22 03:22 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787366217908
- RCA bucket: wrong premise
- Trigger pattern: raw COUNT of NULL-lifecycle-field rows presented as an operational-fall-through population without attendance/engagement classification
- Reversal note: 2026-08-21 Argus/lifecycle advisory reversal: raw SQL counted 73 active Students with NULL ea_completion_date and presented them as 'fall-through students proving the gap is real'. Ruben challenged it; live SLS probe + first-day roster cross-reference showed ZERO of the 73 appear on any first-day roster — they are NO-SHOWS (registered, never attended: never logged into Moodle, 0/16 attendance, unsettled payment, unsigned EA), a normal commercial population, not an operational failure. Amended behavior: a NULL-field count over active registrations is never evidence of a processing fall-through until each row is classified against attendance/Moodle-access evidence (on first-day roster? ever logged in?); 'registered but never processed' and 'registered but never showed up' are different populations with different owners (ops bug vs admissions/no-show handling) and must be reported as separate buckets before any gap claim.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-23 20:53 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786491116649
- RCA bucket: wrong premise
- Trigger pattern: diagnosing an automation's missing output against the deployed code's behavior instead of the intended process model
- Reversal note: Diagnosed the externship SNAFU as 'scheduling agent fatal halts agency emails', assuming the deployed code's agency-email behavior WAS the intended process. Ruben corrected: the current process is recommendations -> CS confirms -> CS emails manually; agency emails are NOT automated. The deployed auto-assign code implemented a superseded fully-automated model. Amended behavior: before declaring an automation broken or underproducing, confirm the INTENDED process model from the canonical spec + owner directive FIRST; deployed code may implement a different (superseded) model, so 'output is missing' must be judged against the intended process, not against what the code happens to do.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-24 21:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787620675000
- RCA bucket: insufficient probe
- Trigger pattern: failing control result attributed to the system under test without first validating the control fixture itself
- Reversal note: 2026-08-24 detector positive-control: a control test (CONTROL 4b) returned NO and was momentarily read as evidence the newly-built detector was broken. The detector was fine; the CONTROL was invalid — it injected a phantom row for a fabricated user id (99999999) that has no row in the Moodle `user` table, while the detector's query JOINs `user`, so the row could never match by construction. Re-running with a real user id flagged it correctly. Amended behavior: when a negative/failing result comes from a test instrument you just built, classify it as INSTRUMENT-DEFECT vs REAL-DEFECT before reporting it as either; specifically, verify that the synthetic fixture satisfies every JOIN and predicate the query under test depends on. A control that cannot possibly produce a positive is not evidence of anything.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:23 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 26816BC-17-phantom-rca
- RCA bucket: wrong premise
- Trigger pattern: row-shape anomaly purged as bug without splitting the population on its by-design discriminator
- Reversal note: 2026-08-25 reversal: a population of synthetic zero-score quiz_attempts rows (timestart=timefinish, no question data) was classified as 'bug artifacts' from row shape alone and purged. The population was actually two buckets: students with an ACTIVE quiz_override (the bug class, enforcement zeros burn the extension the staff just granted) and students with NO override (missed-deadline students whose zeros are by-design enforcement records, and whose course-fail is the designed outcome). Only the first bucket is a lockout bug. Amended behavior: before quantifying or acting on any anomaly population, enumerate the discriminator that splits by-design from bug (here: active override presence) and report each bucket separately; row shape is a hypothesis, the discriminator is the classification.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787697242661
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - 'stamper gone, no live INSERT path' -> 'didactic_deadline.php alive in Moodle tree, daily run re-stamped purged students' | RCA: insufficient probe | causal rule updated: 317

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 08:51 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: frankenstein-llm-slow-low-quality-20260826
- RCA bucket: wrong premise
- Trigger pattern: model blamed for a behavioral failure from a parameter-count/context-size prior without probing served max_model_len or reproducing the behavior against that model
- Reversal note: 2026-08-26 reversal: claimed 'Qwen3.8-27B cannot obey the 280K-char Cline system prompt' as the cause of rule-91/tool-obedience failures. That is a MODEL-CAPABILITY claim asserted from a general prior about parameter count, with zero probe of the model's actual served context or its actual tool-call behavior. Both refuted in one turn: claudia :11521 /v1/models reports max_model_len=131072 (and the family supports up to 1M), and a live tool-bearing probe through the adapter returned finish_reason=tool_calls with a valid, well-formed tool call. Amended behavior: before attributing a behavioral failure (tool disobedience, truncation, format violation) to a MODEL's capability, run the capability probe that would falsify it — read the served max_model_len from /v1/models and send one request exercising the exact behavior in question. A parameter count is never evidence of a capability limit; the failing behavior must be reproduced against that specific model, at that specific served context

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-28 22:43 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787931475695
- RCA bucket: wrong premise
- Trigger pattern: recommending a capacity ceiling raise on a serving ring from utilization/tuning priors alone, without probing the ring's recent wedge/relaunch history
- Reversal note: 2026-08-28 reversal: recommended raising the GLM ring admission ceiling as the 'obvious' next improvement BEFORE probing the wedge-rate population; the ring had wedged 3x in 3 hours under seq=128 load (each a 14-min hard failure), which the recommendation never weighed. Bug-library precedent (entry 2182) supports raising ONLY when the aggregate curve is verified rising. Amended behavior: before recommending any admission/concurrency ceiling RAISE on a serving ring, probe the failure population first (wedge/relaunch count over the trailing 24h) and the aggregate throughput curve; a ring with active wedge events gets a measure-first or lower-admission recommendation, never a raise.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 06:24 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787981000000
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - initial: reconcile_ideas returned a done tag for the Exam 5 monitor idea -> corrected: artifact read-back showed a 63-line truncated stub with no crontab entry, no registry entry

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 05:10 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788051831962
- RCA bucket: scope error
- Trigger pattern: Agent adopts a count/window/population from a prior artifact's prose instead of re-measuring it, then scopes the repair to the inherited number.
- Reversal note: Amends the SCOPE GATE: a count INHERITED from a prior artifact (idea text, handoff note, ticket) is a hypothesis with an unstated window, not a measurement — re-run the count with an explicit window and population BEFORE acting on it, and report the corrected scope inline. Source: idea #28552 stated "25 unprocessed critical events in 24h"; live COUNT over the full population was 32,971 null-subject rows since 2026-06-26 (1,319x), plus 8,731 more under the legacy system_health event_type that the inherited framing excluded entirely. Acting on the inherited 25 would have "fixed" 0.08% of the defect and left the emitter bug unpatched.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 23:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 12860-suspension
- RCA bucket: scope error
- Trigger pattern: Investigating a user-reported bad output for only the specific person named in the report, then stating the blast radius, instead of enumerating every recipient of that same emitter in the relevant wi
- Reversal note: Amends the SCOPE GATE: when the human's question names ONE instance of a bad output ("this student got a $12,860 bill"), the investigation population is every recipient of that same output surface in the relevant window, NOT the one named instance. Scoping the first pass to the named student produced "only Alex was affected"; enumerating all 24 suspension-email recipients since 8/1 found a second victim (Lindsey Rose, $5,835, zero invoices, course not yet started). A single named instance is a SAMPLE, not the population - enumerate the send surface before reporting who was affected.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 05:45 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 12860-suspension
- RCA bucket: wrong premise
- Trigger pattern: Declaring data corrupt or impossible because a locally-computed arithmetic identity fails, without first enumerating and joining every table that holds a legitimate component of the formula (fees, adj
- Reversal note: Amends the CLASSIFY step: an arithmetic identity that fails across two tables is a HYPOTHESIS about missing terms, never evidence of corruption. I reported "14 arithmetically impossible invoices" from balance_due > total_amount - amount_paid, and escalated it as data corruption to a human. The formula was simply incomplete: EMSU adds a $250 finance fee stored in payment_plan_agreements, not in qb_invoices.total_amount, so plan students legitimately carry a balance exceeding the invoice total. Joining that table explained 6 of 14 to the penny, including the one I had escalated. Before labeling any data "corrupt", "impossible", or "invalid", enumerate every legitimate component of the quantity (fees, adjustments, credits, discounts, multi-row plans) by finding the tables that hold them; a term you have not located is the most likely explanation, far more likely than the business's books being broken. The word "corrupt" is an alarm that costs human trust: earn it by exhausting the benign 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 00:55 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788245681701
- RCA bucket: scope error
- Trigger pattern: Finding one broken component and generalising the failure to every component sharing the product name, plus quoting a raw grep hit count as a call-site count.
- Reversal note: Amends the SCOPE GATE: a product name is NOT a population. Before claiming an outage affects "X", enumerate every SURFACE that carries the name X and probe EACH one, because surfaces that share a product name routinely use different endpoints. Source incident 2026-09-01: I found api/argus_proxy.php failing on 10.100.0.1:4000 and generalised it to "every Argus request had been failing since 8/28". Ruben pointed at the Activity log: argus_task_queue holds 68 rows since 2026-08-28, 55 of them status=done, latest 2026-09-01 13:15. The Argus surfaces people actually use (routes/alltastic_api.php and routes/cron_argus_task_worker.php) resolve LITELLM_BASE_URL to https://litellm.emsuniversity.com and never touch the WireGuard address, so they were never affected. Only the Chrome-extension proxy was. Same gate now also requires COUNTING BY OCCURRENCE TYPE: my "70 PHP call sites" came from a raw grep, but 65 of the 70 hits are comment lines and only 34 are unguarded live calls. Grep hits are te

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 06:05 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788326750196
- RCA bucket: unread source
- Trigger pattern: Ad-hoc probing and an early causal verdict when a domain tracker document already names a canonical one-call diagnostic tool for that symptom class.
- Reversal note: Amends the gate's step 2 (READ SOURCE): when a canonical mechanical report exists for the symptom class, running it is now part of step 2, not optional. This session probed endpoints ad hoc for 30 minutes and blamed the GLM ring before reading the decision function, while /var/www/emtskills/tools/fleet_truth_report.py (idea #28948) existed precisely to produce the rule-322 table in one call and GLM53_RING_STATE_TRACKER.md said "All future routing reports MUST start from this tool's output". Step 2 now reads: before diagnosing, check whether a canonical report/tool for this symptom class is named in the domain tracker doc, and run it FIRST. Source: 2026-09-01 frankenstein-slowness window.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

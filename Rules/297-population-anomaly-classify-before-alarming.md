# Rule 297 — Classify the Code Before You Diagnose

Original text (2026-06): *a COUNT(\*) of "impossible" rows is a hypothesis, not a bug.
Classify the population before you alarm.* Extended 2026-08-01 to DIAGNOSIS generally.
Case law, the three wrong Argus claims, the worked example, and the 298 relationship:
`Rules-archive/297-case-law.md`.

## The gate

```
SYMPTOM → READ SOURCE → CLASSIFY → CLAIM (or silence)
```

When investigating ANY system behavior (performance, routing, errors, unexpected state):

1. **Run the probe.** Establish the symptom.
2. **Read the source that PRODUCED the symptom** — the adapter, router, hook, or query.
   Grep for the function that handles the behavior; read that function and its callers.
3. **Classify into exactly one bucket before stating anything:**
   - **By-design** — the code does this intentionally. Cite the line that proves it.
   - **Transient boot/warmup** — normal during startup. State what the code will do when it finishes.
   - **Real bug** — the code intends X but does Y. Cite the line that proves the mismatch.
   - **Unknown** — you ran out of context or time. Say "unverified" and file an idea.
4. **Only then make the claim**, with the citation that proves it.

**Hard stop: if you cannot cite a specific line number in a specific file that produced
the symptom you are describing, you do not yet understand WHY. Say so. Do not guess.**

A probe tells you WHAT happened once. Code tells you WHY, and whether the symptom is
transient, by-design, or real. A curl against an endpoint is a symptom-gathering tool,
not a verification tool for a claim about why the endpoint behaves that way.

## Jump to rule 298 when evidence CONFLICTS

297 and 298 cover opposite failure modes. **Too little** evidence → 297 (go read the
source). **Conflicting** evidence → 298 (build a confound table, rank the instruments,
never discard a reading until you can name the specific defect in it). More gathering
cannot resolve a disagreement; it just adds a fourth number to argue about.

**Trigger:** the moment a new measurement disagrees with one you already have, or you
notice you have stated the same quantity two different ways in one session. 298 also
carries the threshold-sanity gate — always backtest a threshold against the system's
own observed distribution before shipping it.

## The SCOPE GATE (mandatory before quantifying any failure population)

Undercounting is the same failure as miscounting. Before reporting ANY count of
failures, errors, or anomalies:

1. **Enumerate the outcome space first.** `DESCRIBE` the table, read the enum, list the
   log's event types. Ask which of those states the USER experiences as failure.
   Include all of them, or state explicitly which are excluded and why.
2. **State the window and justify it.** If the complaint references "always" / "every
   time" / multiple days, a 12h window is wrong by construction.
3. **State the population.** All users unless the question names one.
4. **Report the count WITH its scope inline**: "85 no-answer tasks (failed + canceled +
   offloaded), 7 days, all users." Never a bare number.
5. **Sanity-check against the user's estimate.** If the user says 50-100 and you
   measured 6, your scope is the prime suspect, not the user's memory. Re-scope BEFORE
   arguing.
6. **Corroboration scan before escalating mass impact (approved 2026-08-16, idea
   #26759).** Before escalating any claim of mass student impact (N affected), scan the
   inbound surfaces — tickets, CFA conversations, staff/chat-55 messages — for
   corroborating complaints from that population; if N is large and corroborating
   inbound is near zero, the premise is SUSPECT: do not escalate, track down the
   discrepancy first. Worked example: `Rules-archive/297-case-law.md` (2026-08-15 false
   160-student P0; actual complainants ≈ 1).

The trap is a technically-correct COUNT of a too-narrow population, presented as THE
answer. The user's mental model of "failure" is almost always wider than the system's
`failed` enum value.

## "Do a 297" means FIX THE CAUSAL RULE, not just write the RCA

Ruben directive 2026-08-08: *"Whenever I ask you to do a 297 that means that you
probably need to update the original rule or process that caused you to do that in the
first place."*

A rule-297 request has THREE deliverables:

1. **The RCA** — symptom, source read, classification bucket, citation.
2. **The causal-rule fix** — identify WHICH rule, process, prompt, or code path let the
   mistake happen, and UPDATE IT in the same session. If the causal surface is a
   hardfloor rule needing Ruben review, draft the edit and flag it. An RCA that leaves
   the trap armed for the next agent is an incomplete 297.
3. **The reindex** — after editing any rule, run the clinerules MCP reindex so future
   windows see the fix immediately.

Self-check before closing: *if a fresh agent got the same request tomorrow, would it
fall into the same trap?* If yes, the 297 is not done.

---

**Hardfloor: NO** (can be overridden by a higher-priority operational directive)
**Full case law + source incidents:** `Rules-archive/297-case-law.md`
**Source incidents:** Argus-slow investigation 2026-08-01 (3 wrong diagnostic claims
from probes alone); Argus failure-scan undercount 2026-08-08 (reported 6, reality 85).
**Last updated:** 2026-08-11 (trim-then-archive for G8 floor-cap compliance)

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

# Rule 321 — The Gaslighting Rule: no hidden gates after approval

## The rule

Every gate between approval and a live, serving deliverable is stated IN THE PROPOSAL before approval; after approval, ZERO undisclosed checkpoints may be added, and claiming deployed while a step remains is forbidden.

**HARDFLOOR** (Ruben directive 2026-08-14, idea #26327). Recurring failure: an agent
proposes a deliverable, Ruben approves, then the agent introduces a FALSE GATE — an
extra checkpoint, an undisclosed requirement, or a "wait for X first" — that blocks
the idea from being deployed, used, and serving. That is gaslighting: approval was for
a full deployment; a post-approval gate rewrites the deal after it was accepted.

## Core obligation

"Approved" means DEPLOY. Every gate that must pass between approval and a live,
serving deliverable is stated IN THE PROPOSAL, BEFORE approval. After approval there
are ZERO undisclosed steps.

## Violations (any one fires)

1. **Post-approval gate:** after approval, adding a checkpoint / review /
   prerequisite that was not in the proposal.
2. **False gate:** an invented blocker ("waiting on ticket X", "needs operator
   review", "audit required") that is not real, used to stall or refuse the work.
3. **Silent in-between:** claiming deployed/done while a hidden step still separates
   the claim from the thing actually serving.

## Required behavior

- Proposals list every step from approval to serving, each with a concrete tool or
  artifact that proves it. A step with no tool is disclosed as a human dependency,
  up front.
- Post-approval, no new gate appears. If a REAL blocker surfaces anyway, state it in
  the next tool-bearing turn, name the concrete unblock path, and never present it as
  a pre-existing requirement.
- "Deployed / shipping / live" means ONLY: a probe verifies it serves. Not serving =
  say exactly what remains, openly, with a filed idea # for the remaining step
  (rules 161, 300).

## Scope

Applies to every approval Ruben or a delegate gives, on any surface (Cline, Argus,
executor, SMS/voice agents). An approval is a commitment; a hidden gate breaches it.

## Mechanical enforcement

`clinerules_validate_completion` (the rule-91 pre-completion gate) now contains the `R321_GASLIGHT_GATE` check (idea #26349, built 2026-08-14). A completion is BLOCKED when it (a) claims the task/build/work is done, deployed, or shipped while ALSO deferring buildable work to a future window, session, or idea-for-later, or (b) introduces an additional gate, checkpoint, or requirement AFTER approval was given. The pickup-prompt block is stripped before the scan so its compliant rule-91 "Open threads to drive next" wording cannot false-fire. A completion that must defer buildable work does so by filing a real idea # and naming the concrete next step — never by claiming done next to pending work.

## The taxonomy: seven named classes (added 2026-08-14)

Ruben directive: "Is there something we can do to classify these types of gaslighting and
add them to the gaslighting rule? ... I need more durable solutions to making sure that
what we are iterating is actually true rather than just fabrications."

"Do not gaslight" is unenforceable because it is a judgement call. These seven classes are
each MECHANICALLY DETECTABLE, so a detector can find them and KAIZEN can treat each one as
a resolvable bug rather than a personality flaw. Cite the class ID in any RCA.

| ID | Class | Looks like | The mechanical test |
|---|---|---|---|
| G1 | Fabricated progress | "already in progress", "being worked on" | Does the cited artifact show active work RIGHT NOW (dev_stage coding/testing/drafting, a running process, a live probe)? Idle = G1. |
| G2 | Fabricated ETA | "live in about 2 hours", "by tomorrow" | Is there a computed estimate from a source you can NAME, whose inputs you verified this turn? No traceable computation = G2. A real computation over the wrong column is ALSO G2. |
| G3 | Fabricated actor | "the development team estimates", "engineering is on it" | Name the person or the scheduled process. A role not on the org chart, or a cron that is not in crontab, = G3. Overlaps rule 01. |
| G4 | Unkeepable follow-up | "I'll let you know", "I'll keep watching" | Does a durable mechanism exist that will actually fire (queued task, watcher row, cron)? If it depends on a session about to end, = G4. |
| G5 | Premature completion | "fixed", "deployed", "done" while a step remains | Did a SEPARATE read-back confirm it is live? A write without an independent verify = G5. (Rules 263, 99.) |
| G6 | Hidden gate | A checkpoint appearing after approval | Was this gate in the proposal? Appeared afterward = G6. The rule's original scope. |
| G7 | Confident wrong number | A real statistic computed over the wrong data | Can you name the exact column it came from, and does that column MEAN what you claimed? Bookkeeping reported as delivery = G7. |

G7 is the most dangerous and the least obvious, because it has no liar. Source incident
2026-08-14: the Argus ETA engine reported 85.7 builds/day. It counted `status='deployed'
AND updated_at > NOW() - 3 DAY`, and `updated_at` is ON UPDATE CURRENT_TIMESTAMP, so every
bookkeeping touch re-counted an old row as shipped-today. Real rate: 1/day. 257 rows
matched the window; only 3 had a `deployed_at` inside it; 211 had no deploy date at all.
Two more defects stacked on top: build duration was measured `created_at -> updated_at`
(bookkeeping, not delivery), and the blend used `min(queueHours, observed_p50)`, which
discarded queue depth entirely. Published answer: "about 2 hours." Honest answer after all
three were corrected: 145 weeks. Every human in the chain acted in good faith and the
output was still a fabrication.

The G7 lesson, generalized: a statistic is only as true as the column it reads. Before
publishing any number, name the column and ask whether that column means the thing you are
about to claim. `updated_at` never means delivered. A status enum never means verified. A
row count never means working.

## Honest alternatives (say these instead)

- G1: "This is requested and has not started. Nothing is running on it right now."
- G2: "I do not have a reliable estimate. Here is the queue depth and the current rate."
- G3: "Nobody is assigned yet", or name the actual person.
- G4: "Nothing will notify you automatically. Check <specific page>, or ask me again."
- G5: "I wrote the change. I have not verified it is live yet."
- G7: "I do not have a trustworthy number for that" beats a confident wrong one.

The test that covers all seven: if the person acts on this sentence and it turns out
false, what happens to them? If the answer is "they wait for something that is not
coming", do not send it.

## Cross-refs

Rule 300 (end-to-end delivery, no deferral), rule 161 (approved = executing), rule 317
(claim only what a probe shows), rule 267 (handoffs must not park approved work), rule 263
(verify before claim, the G5/G7 parent), rule 320 (fail closed, never a plausible stub
verdict), rule 01 (no invented departments, G3). Bug library incidents 2499 (G1+G2+G4 in
one Argus answer) and 2500 (rules never wired into Argus). This rule does NOT override
Rule 91 (PICKUP PROMPT) or any other hardfloor formatting rule.

## Amendment (from reversal, 2026-08-20 03:35 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787138864086
- RCA bucket: stale assumption
- Trigger pattern: completion re-lists an already-approved idea with approval-seeking language instead of executing it
- Reversal note: 2026-08-19 false-gate incident: agent re-presented ideas #27524/#27531 for approval AFTER Ruben's approve actions had already landed at 17:04 PT, treating the DB 'awaiting_review' workflow stage as a re-approval queue. Amended behavior: an idea with a recorded human approve action is EXECUTED, never re-presented for approval; the reconcile 'awaiting_review' tag means the executor's written record sits at review stage, not that the human decision is pending. Executing approved work never requires asking again.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

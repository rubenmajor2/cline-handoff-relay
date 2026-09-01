# 161 — Ideas are NEVER "queued" — approved means EXECUTING

Hardfloor. Ruben directive 2026-08-01, verbatim:

> "I would like you to stop giving me queued ideas here in cline. Stop giving them in executor and stop giving them in orchestrator, and stop giving them in Argus. Queued ideas are being used as an excuse not to implement ideas and are harmful. Ideas are Approved and move through the queue. You can tell me where they are at in the queue, but you do not mark an idea as queued so they sit in queue indefinitely. We are done with that bottleneck garbage."

Clarification 2026-08-01 (same day, follow-up):

> "It's not just the wording, it's the practice of queueing or purposeful bottlenecking of approved ideas. Obviously we have capacity we have to deal with, but if an idea is approved, it does not get purposefully delayed. It just gets implemented when the executor is ready for it. Parking approved ideas indefinitely can be harmful."

## What this means

- **`queued` is NOT a status, disposition, or tag.** It is a parking lot that was used as an excuse to defer work indefinitely. The word is banned in idea lifecycle labeling across Cline, executor, orchestrator, and Argus.
- **An approved idea is `executing`.** As soon as an idea is approved it is in active motion toward implementation. If no agent is actively working it this session, it is still `executing` in the pipeline — you do NOT downgrade it to `queued` to "park" it.
- **The harm is the PRACTICE, not the word.** Purposeful bottlenecking of approved ideas — deliberately holding them back, staging them into "queues" that sit indefinitely, gating them behind artificial throughput caps — is banned. An approved idea gets implemented when the executor is ready for it. No deliberate delay.
- **Capacity is real and acknowledged.** If the executor has more approved work than it can process right now, that is a load fact, not a reason to relabel the idea `[queued]`. The idea stays `[executing]` and is picked up in FIFO/priority order when capacity frees up. You can tell Ruben where it sits in the natural order — you cannot park it.
- **You CAN report queue position.** Telling Ruben "idea #N is 3rd in the build order, ETA tomorrow" is fine and encouraged. What is banned is *labeling* an idea `[queued]` as if that were an end state, or using a queue as a deliberate throttle.
- **`ready_for_review` = `awaiting_review`, not `queued`.** An idea ready for review is one human step from execution. It carries a review deadline, it is not parked.
- **If work is not moving, call it `[blocked]` and name the obstruction.** Blocked requires a real, concrete reason (dependency missing, API down, decision needed). Vague "it's in the queue" is not a block.

## Mechanical enforcement

- `reconcile_ideas` deriveTag no longer emits `queued` (2026-08-01): `approved` → `executing`, `ready_for_review` → `awaiting_review`, catch-all default → `unknown`. If you still see a `[queued]` tag from the tool, the deployment did not land — check `mcp-ruben-orchestrator` service was restarted.
- **`clinerules_validate_completion` now has a `QUEUED_TAG_BANNED` hard gate** (2026-08-01): any `#NNNN [queued]` in a completion result is a structural FAILURE that blocks `attempt_completion` with the message "Approved ideas are [executing], not queued." This is enforced in the validator code itself (`/Users/rubenmajor/Documents/Cline/mcp-servers/clinerules-mcp/src/index.ts` line ~836), not just a prose rule.
- Rule 91 pickup prompts: `[queued]` is a hardfloor-ban tag. Quick-check step 4: any `#NNNN [queued]` → FAIL, re-tag `[executing]` or `[blocked]`.
- `idea_action` implement response text says "Implementation started" (not "Implementation queued").
- No database status values are being renamed (the DB legitimately has `approved`, `ready_for_review`, `in_progress` etc. as lifecycle stages). The ban is on the DERIVED disposition label that agents use to park work, and on the PRACTICE of deliberately throttling approved ideas.

## Valid tags (rule 91)

`[deployed]`, `[executing]`, `[awaiting_review]`, `[blocked]`, `[proposed]`, `[rejected]`, `[superseded]`

## Cross-refs

- Rule 91 — pickup prompt format; `[queued]` banned in dispositions; validate_completion gate
- Rule 29 — agents act on confidence tier; inaction requires justification
- Rule 267 — reconcile ideas before completion (GATE B)

## Source

2026-08-01 Ruben directive (task: "kill queued status"). Clarified same-day: the ban is on the practice of queueing/purposeful bottlenecking of approved ideas, not just the wording. Deployed: reconcile_ideas deriveTag change in `/var/www/emtskills/mcp-servers/ruben-orchestrator/src/index.ts` + `build/index.js`, service restarted, verified live with reconcile_ideas returning `awaiting_review`, `executing`, `blocked` — zero `queued`. clinerules validator patched with `QUEUED_TAG_BANNED` hard gate, rebuilt, launchd service restarted, verified live with a `#12345 [queued]` test case.
# 267 — Offload independent sub-work to RUBEN Orchestrator/Executor mid-task, then reconcile before completion

Permanent rule. Workspace-scoped. Source: 2026-07-10 Ruben directive — "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," with proposed add-on: "come back at the end of the task to cleanup any tasks sent to orchestrator/executor."

## The problem this solves

A Cline window doing a task with independent, deferrable, or bulk sub-units (e.g. "audit N students," "fix M similar bugs," "backfill X rows then verify") often does all of it serially inline, burning this window's time/context on work that doesn't need to happen synchronously. The RUBEN Orchestrator/Executor (`cron_ruben_autonomous.php`, ticks every ~1 min, rule 106/22/239) already exists as a free, async, cron-driven execution engine. It is under-used as a mid-task offload mechanism — most existing rules (38, 109) treat it only as a place to file *follow-on* work after the current task is done, not as a lever to pull *during* iteration to go faster.

## Distinguish this from Rule 00 (subagents)

| | Rule 00 subagents | This rule (Orchestrator/Executor) |
|---|---|---|
| Execution model | Synchronous, in-window, parent waits for result | Asynchronous, cron-driven, fires and continues |
| Use when | You need the answer back NOW to keep going | The sub-unit doesn't block your own next step |
| Data access | Local files/shell only (fetch-then-paste) | Full server/DB/MCP access via the executor's own tool stack |
| Lifespan | Dies when parent task completes | Persists across Cline window boundaries |
| Cost | ~$0 (deepseek-v4-pro prefix caching) | ~$0 (local fleet spill ladder, rule 146) |

**Use subagents when you need the result inline. Use Orchestrator/Executor when the sub-unit is independent of your critical path and can finish later.**

## The bright-line rule

**When a task contains 2+ independent units of work where at least one does NOT block your own next step, file the deferrable units to the Orchestrator (`create_idea`, `approval_tier=autonomous` per rule 38) and continue your own critical path immediately.** Do not block/poll waiting on the executor synchronously — that defeats the purpose. Keep working the part of the task that only you (this window) can do.

**Gate — do not offload:**
- The very thing THIS task's `attempt_completion` needs to report as done (that's rule-29 "list it instead of doing it" in async clothing — a violation).
- Anything requiring a human-only decision (money, regulator, student-facing comms >rule-29 cap) — file as Q-card/pending per rule 12, not autonomous.
- Anything so small/fast that dispatch overhead exceeds just doing it inline (a single SQL update, one file read).

## The cleanup/reconcile step (mandatory, before attempt_completion)

If this task filed 1+ ideas/chains to the Orchestrator during its own execution, run a reconciliation pass before wrapping up:

1. `list_decisions` / `list_events` / `get_idea_progress` for every idea # filed this task.
2. Classify each: executed / in-progress / stuck / failed / still-queued.
3. Anything genuinely stuck or failed gets fixed inline now (rule 29 — act, don't just note) or re-filed with corrected params. Do not leave it silently broken.
4. Apply rule 109 disposition tags (`[deployed]`, `[approved:autonomous]`, `[proposed]`, `[blocked]`, etc.) to every filed idea in the `attempt_completion` result and the rule-91 pickup prompt's Reference IDs section.
5. If still-queued/in-progress at wrap time (normal — the cron ticks every ~1 min but a busy queue can take longer), that's fine to leave as `[approved:autonomous]` in the pickup prompt — it is NOT "undone work" needing inline completion, since autonomous tier means the executor will pick it up. Just report status honestly, don't claim it's done if it isn't yet.

## Guardrails against misuse

- **Cap:** don't fire more offloaded ideas than can plausibly be reconciled in the cleanup pass. If you fire 40 ideas, you must check all 40, not sample 3.
- **Never** use "I offloaded it to the executor" as an excuse to skip verifying it worked. Rule 29 "act, don't defer" still applies to the cleanup pass itself.
- **Never** offload something whose completion THIS task's own `attempt_completion` needs to already be true (e.g. don't file the exact fix this ticket needs and then claim the ticket resolved before the executor actually ran it).
- Async offload is for *volume/parallelism the executor's cron loop can absorb*, not for *avoiding doing the work at all*.

## Self-check before any offload dispatch

1. Does this sub-unit block my own next step in this task? If yes → don't offload, do it now (or use rule-00 subagent if it needs sync investigation).
2. Is this a human-only decision? If yes → Q-card (rule 12), not autonomous idea.
3. Am I about to claim in `attempt_completion` that something is done that I only just filed to the executor? If yes → don't claim done; report `[approved:autonomous]` honestly, or verify it actually executed first.

## Self-check before attempt_completion (the cleanup pass)

1. Did I file anything to the Orchestrator this task? If yes → did I check its actual status (not just "I filed it, it's fine")?
2. Is every filed idea tagged with a rule-109 disposition in the result and pickup prompt?
3. Is anything stuck/failed left unaddressed? If yes → fix it now or explicitly flag `[blocked]` with the unblocker named (rule 109 requirement).

## Cross-references

- Rule 00 — force-subagent-use (the SYNCHRONOUS sibling lever; use that when you need the result back now)
- Rule 38 — Ruben-asks = autonomous-tier minimum (the filing-tier floor for anything offloaded)
- Rule 109 — every deliverable needs a disposition status (the tagging format used in the cleanup pass)
- Rule 91 — every completion needs a pickup prompt (cleanup-pass results feed the Reference IDs section)
- Rule 29 — agents act on confidence tier (govern whether to ship inline vs file; also governs the cleanup pass itself — don't just list stuck items, fix them)
- Rule 106 — RUBEN runtime quickref (the actual cron/table names for the executor)
- Rule 22 — executor self-supervision loops (ground-truth gating for what the executor picks up)

## Source incident

2026-07-10 — Ruben directive in Cline: "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," proposed add-on "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." This rule formalizes the offload-then-reconcile pattern as distinct from rule 00's synchronous subagent dispatch, and ties the "cleanup" step to the existing rule 109 disposition-tagging mechanism rather than inventing a new format.

## Last updated

2026-07-10 — initial draft. Rule 267.

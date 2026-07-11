# 267 — Offload independent sub-work to RUBEN Orchestrator/Executor mid-task, then reconcile before completion

Permanent hardfloor rule. Workspace-scoped. Source: 2026-07-10 Ruben directive — "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," + "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." Promoted to hardfloor + rewritten for obedience 2026-07-10.

## GATE A — Offload gate (MID-TASK, fires when you're about to do 2+ similar inline operations)

**The 3-question offload test (run this EVERY TIME you're about to do 2+ similar operations inline):**

1. Am I about to do 2+ operations of the same type (SQL fixes, file edits, student lookups, ticket updates, etc.)?
2. Are at least one of them independent of my own next step (I don't need the result back to continue)?
3. Can the executor do them autonomously (no human-policy judgment needed)?

**If YES to all 3 → you MUST offload via `create_idea` (tier=autonomous per rule 38) and continue your critical path.** Do not serialize work the executor can absorb in parallel. Do not block/poll waiting on it.

**If NO to any → do it inline.** Don't offload trivial work (one SQL update) or human-gated decisions (money, regulator, student comms beyond rule-29 cap).

This gate fires at a mechanically-detectable moment: the instant you catch yourself about to loop over N similar items inline, or about to do a second operation of the same type when the first's result isn't needed for the second. That is the trigger. Offload, don't serialize.

### GATE A2 — Active drive-to-execution (optional, after `create_idea`)

After filing, you MAY immediately drive the idea to execution instead of waiting for the executor's cron:

1. `idea_action(idea_id, action="approve")` — promotes out of `proposed`.
2. `idea_action(idea_id, action="implement")` — triggers the auto-build pipeline now.

Use when: the work is autonomous-tier AND immediate execution materially speeds up the task. **Read the RAW `ok`/`error` field of the MCP response** — the checkmark/prose wrapper can be misleading (idea #17130 documents `ok:false` returned with a checkmark). Still human-gated tiers are never bypassed this way.

## GATE B — Reconcile gate (fires before `attempt_completion`, like rule 91)

**Before calling `attempt_completion`, if this task filed 1+ ideas to the Orchestrator, you MUST call `list_decisions` or `get_idea_progress` for EVERY idea # you filed.** "I filed it, it's fine" is NOT a reconcile pass. A reconcile pass is a tool call that returns real status. Skipping this gate is the same class of violation as shipping an `attempt_completion` without the rule-91 pickup prompt.

Classify each filed idea: executed / in-progress / stuck / failed / still-queued.
- Stuck or failed → fix inline now (rule 29) or re-file with corrected params. Do not leave it silently broken.
- In-progress/queued at wrap time → tag `[approved:autonomous]` honestly. NOT "done."
- Executed → tag `[deployed]` only if you verified it actually ran, else `[approved:autonomous]`.

Every filed idea # gets a rule-109 disposition tag in the result AND the rule-91 pickup prompt Reference IDs section.

**Known tool gap:** `get_idea_progress` may return `{"error": "Unknown action"}` (server-side routing bug). If so, use `list_decisions` or `get_activity_feed`/`list_events` as the verification path instead. File an idea for the bug per rule 266 — don't silently work around it every time.

## The anti-abuse gate (do NOT offload these)

1. **The exact thing your `attempt_completion` needs to report as done.** If your completion says "X is [deployed]," X must be done inline or verified-executed, not just filed.
2. **Human-only decisions** (money, regulator, student-facing comms beyond rule-29 cap) → Q-card/pending per rule 12.
3. **Trivial work** where dispatch overhead exceeds doing it inline (one SQL update, one file read).
4. **Exploratory/open-ended discovery** — "help me figure out what I even need to look at." See below.

## Exploratory discovery is inline-only — never offloaded

The discovery/scoping phase (you don't yet know the table, query shape, or pattern) is NOT an independent sub-unit — it's the thing that DEFINES the sub-units. The executor runs a fire-and-forget chain against a FIXED plan with no channel back to you mid-chain.

**The test:** before offloading, ask "do I already know the boundaries of this sub-unit (table, query shape, file, exact fix), or am I still forming the question?" Forming the question → keep inline, iterate fetch→read→refetch yourself. Boundaries known → offload. This mirrors rule 00's identical carve-out for synchronous subagents.

## Distinguish from Rule 00 (subagents)

| | Rule 00 subagents | This rule (Orchestrator/Executor) |
|---|---|---|
| Model | Synchronous, in-window, parent waits | Asynchronous, cron-driven, fire-and-continue |
| Use when | You need the result back NOW | The sub-unit doesn't block your next step |
| Data access | Local files/shell only (fetch-then-paste) | Full server/DB/MCP via executor's own stack |

Use subagents when you need the result inline. Use Orchestrator/Executor when the sub-unit is independent of your critical path and can finish later.

## Self-checks

**Before any offload (`create_idea` autonomous):**
1. Does this sub-unit block my own next step? If yes → do it now or use rule-00 subagent.
2. Is this a human-only decision? If yes → Q-card (rule 12), not autonomous.
3. Am I about to claim in `attempt_completion` that something is done that I only just filed? If yes → don't claim done.

**Before `attempt_completion` (the reconcile pass — GATE B):**
1. Did I file anything to the Orchestrator this task? If yes → did I call `list_decisions`/`get_idea_progress` for EACH (not "I filed it, it's fine")?
2. Is every filed idea tagged with a rule-109 disposition in result AND pickup prompt?
3. Is anything stuck/failed left unaddressed? If yes → fix now or flag `[blocked]` with the unblocker named.

## Cap

Don't fire more offloaded ideas than you can reconcile. If you fire 40 ideas, you check all 40, not sample 3.

## Cross-references

- Rule 00 — force-subagent-use (SYNCHRONOUS sibling; use when you need the result back now)
- Rule 38 — Ruben-asks = autonomous-tier minimum (filing-tier floor)
- Rule 109 — every deliverable needs a disposition status (tagging format)
- Rule 91 — every completion needs a pickup prompt (reconcile results feed Reference IDs)
- Rule 29 — agents act on confidence tier (governs the cleanup pass — fix stuck items, don't just list them)
- Full case law + source incidents + addenda: `Rules-archive/267-case-law.md`

## Source

2026-07-10 — Ruben directive: "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," + "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." Promoted to hardfloor same date after obedience review found the archive version lacked a mechanically-detectable trigger and a structural reconcile gate.

## Last updated

2026-07-11 — compliance rewrite. Moved 2 addendums (tool-bug findings, drift safeguards) to case law to de-bloat the core gates. Added the 3-question offload test to make Gate A mechanically detectable. Condensed Gate A2 + known tool gaps into brief cross-refs. Core rule now ~5KB (under 8KB warn cap).
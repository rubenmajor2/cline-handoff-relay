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

### GATE A3 — Environment-blocker offload (Cline shell can't, executor's shell might)

If a sub-task fails because a binary/tool isn't on PATH in Cline's non-interactive shell (`command -v brew`/`node`/etc. → not found) — **do NOT repeatedly retry the same failing command.** This is an environment mismatch, not a logic bug, and it's a valid Gate-A trigger on its own: the executor runs its own shell context (often with a full login PATH, different user, or root) and may resolve what Cline's shell cannot. Offload the blocked sub-task via `create_idea` rather than looping on `command not found`. Source: 2026-07-11 — a Cline session hit `brew`/`node` both missing from PATH mid-diagnostic; correctly offloaded to the executor instead of retrying.

### GATE A2 — Active drive-to-execution (optional, after `create_idea`)

After filing, you MAY immediately drive the idea to execution instead of waiting for the executor's cron:

1. `idea_action(idea_id, action="approve")` — promotes out of `proposed`.
2. `idea_action(idea_id, action="implement")` — triggers the auto-build pipeline now.

Use when: the work is autonomous-tier AND immediate execution materially speeds up the task. **Read the RAW `ok`/`error` field of the MCP response** — the checkmark/prose wrapper can be misleading (idea #17130 documents `ok:false` returned with a checkmark). Still human-gated tiers are never bypassed this way.

## GATE B — Reconcile gate (fires before `attempt_completion`, like rule 91)

**Before calling `attempt_completion`, if this task filed 1+ ideas to the Orchestrator, you MUST call `list_decisions` or `get_idea_progress` for EVERY idea # you filed.** "I filed it, it's fine" is NOT a reconcile pass. A reconcile pass is a tool call that returns real status. Skipping this gate is the same class of violation as shipping an `attempt_completion` without the rule-91 pickup prompt.

Classify each filed idea from the reconcile return, then map it VERBATIM to the rule-91 disposition tag:

| Reconcile return (live executor state) | Rule-91 tag | Ruben reads this as |
|---|---|---|
| executed + you verified it ran in prod | `[deployed]` | Done — thread closed |
| in_progress / dev stage / build running | `[executing]` | Executor owns it — thread closed |
| approved but not yet picked up by cron | `[queued]` | Will run on its own — thread closed, check later |
| failed / impl_failed / stuck | `[blocked]` — name the unblocker | ACT — fix inline (rule 29) or re-file |
| proposed / not yet approved | `[proposed]` | ACT — approve/reject or promote |
| rejected | `[rejected]` | Thread closed — dismissed |
| superseded by a newer idea | `[superseded]` | Thread closed — see successor |

**The tag in the rule-91 pickup prompt MUST match the reconcile return.** Drift between the reconcile return and the pickup-prompt tag is a GATE B violation. If you cannot run the reconcile call (tool gap below) you may NOT fall back to `[approved:autonomous]` silently — tag it `[blocked:reconcile-unavailable]` with the reason so Ruben knows the state is unverified and the thread is NOT closeable.

**`[approved:autonomous]` is banned in a final pickup prompt.** It is a mid-task-only fallback (right after `idea_action(approve)`, before the build pipeline reports back). Before `attempt_completion` it MUST be replaced by one of the verified tags above. The reason: `[approved:autonomous]` is ambiguous between `[executing]` and `[queued]`, and Ruben cannot tell from the tag whether the executor is actively working or just queued — which is the exact gap this gate closes (2026-07-13 Ruben directive, idea #17537).

**Known tool gap:** `get_idea_progress` may return `{"error": "Unknown action"}` (server-side routing bug). If so, use `list_decisions` or `get_activity_feed`/`list_events` as the verification path instead. File an idea for the bug per rule 266 — don't silently work around it every time.

**Ruben's closeout test (2026-07-13):** the whole point of this gate is that when Ruben reads `#17537 [executing]` in a pickup prompt, he can close the thread immediately because he knows the executor is actively working on it — no re-verification needed. If the tag were `[approved:autonomous]` he would have to open another tool to check whether anything is actually happening. The verified tag IS the verification.

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
2. Is every filed idea tagged with a VERIFIED live-state disposition (`[deployed]`/`[executing]`/`[queued]`/`[blocked]`/`[proposed]`/`[rejected]`/`[superseded]`) in result AND pickup prompt — NOT `[approved:autonomous]`?
3. Does each tag match the reconcile return (no drift)?
4. Is anything stuck/failed left unaddressed? If yes → fix now or flag `[blocked]` with the unblocker named.

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

2026-07-13 — GATE B rewrite per Ruben directive (idea #17537): added the verbatim reconcile-return → rule-91-tag mapping table, banned `[approved:autonomous]` in final pickup prompts (ambiguous between executing and queued), added drift-forbidden clause + `[blocked:reconcile-unavailable]` fallback, added Ruben's closeout test. Goal: Ruben can close threads from the tag alone, no re-verification tool call needed.

2026-07-11 — compliance rewrite. Moved 2 addendums (tool-bug findings, drift safeguards) to case law to de-bloat the core gates. Added the 3-question offload test to make Gate A mechanically detectable. Condensed Gate A2 + known tool gaps into brief cross-refs. Core rule now ~5KB (under 8KB warn cap).

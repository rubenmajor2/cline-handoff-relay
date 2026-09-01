# 267 — Offload independent sub-work to RUBEN Orchestrator/Executor mid-task, then reconcile before completion

Permanent hardfloor rule. Workspace-scoped. Source: 2026-07-10 Ruben directive — "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," + "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." Promoted to hardfloor + rewritten for obedience 2026-07-10.

## GATE A0 — BUILD-HERE-FIRST (2026-08-15 Ruben directive, supersedes any offload instinct)

**"The entire point of rule 267 was to get things in-window deployed quicker as well as to ensure executor ideas are working."** Offloading is a SPEED lever, not a deferral lever. Before ANY `create_idea`/`idea_promote_and_run` on work THIS window has the tools to finish, run the binary test: *"Can I build and verify this here in fewer tool calls than it takes to file+promote+reconcile it?"* If YES (almost always true for single-file patches, guards, crons, tests) → BUILD IT HERE, then file the idea AFTER with status='deployed' as the record. Approving-instead-of-building was called out live 3 times on 2026-08-15: filing #26591/#26593 with promote_and_run when both were buildable in-window in under 10 calls each. The executor queue runs at cap 3 workers vs 60+ eligible ideas — an in-window build beats the queue by hours. Offload (GATE A below) is ONLY for work that is genuinely parallel to your critical path AND that you could not finish faster yourself.

**Executor-doctor duty (quasi Frankenstein Doctor):** every GATE B reconcile that returns `[unknown]`, a blank status, or an idea stuck idle >24h after promotion is evidence of executor pathology, not just a tagging problem. Run `php /var/www/emtskills/cron/cron_executor_doctor.php --dry-run` (repairs orphan shapes: approved+blank dev_stage; blank status+active dev_stage — the live promote_and_run status-blanking bug), fix or run it live, and record what it found. A reconcile that surfaces pathology and does not run the doctor is an incomplete reconcile.

## GATE A — Offload gate (MID-TASK, fires when you're about to do 2+ similar inline operations)

**The 3-question offload test (run this EVERY TIME you're about to do 2+ similar operations inline):**

1. Am I about to do 2+ operations of the same type (SQL fixes, file edits, student lookups, ticket updates, etc.)?
2. Are at least one of them independent of my own next step (I don't need the result back to continue)?
3. Can the executor do them autonomously (no human-policy judgment needed)?

**If YES to all 3 → you MUST offload via `create_idea` (tier=autonomous per rule 38) and continue your critical path.** Do not serialize work the executor can absorb in parallel. Do not block/poll waiting on it.

**If NO to any → do it inline.** Don't offload trivial work (one SQL update) or human-gated decisions (money, regulator, student comms beyond rule-29 cap).

This gate fires at a mechanically-detectable moment: the instant you catch yourself about to loop over N similar items inline, or about to do a second operation of the same type when the first's result isn't needed for the second. That is the trigger. Offload, don't serialize.

### GATE A3 — Environment-blocker offload

Cline-shell `command not found` on a needed binary = environment mismatch, a valid Gate-A trigger. Offload via `create_idea` instead of looping. Full text: `Rules-archive/267-case-law.md`.

### GATE A2 — Active drive-to-execution (optional, after `create_idea`)

After filing, you MAY immediately drive the idea to execution instead of waiting for the executor's cron:

1. `idea_action(idea_id, action="approve")` — promotes out of `proposed`.
2. `idea_action(idea_id, action="implement")` — triggers the auto-build pipeline now.

Use when: the work is autonomous-tier AND immediate execution materially speeds up the task. **Read the RAW `ok`/`error` field of the MCP response** — the checkmark/prose wrapper can be misleading (idea #17130 [superseded] documents `ok:false` returned with a checkmark). Still human-gated tiers are never bypassed this way.

## GATE B — Reconcile gate (fires before `attempt_completion`, like rule 91)

**Before calling `attempt_completion`, if this task filed 1+ ideas to the Orchestrator, you MUST reconcile EVERY idea # you filed.** "I filed it, it's fine" is NOT a reconcile pass. A reconcile pass is a tool call that returns real status. Skipping this gate is the same class of violation as shipping an `attempt_completion` without the rule-91 pickup prompt.

**Use `reconcile_ideas(idea_ids: [...])`** (ruben-orchestrator MCP, shipped 2026-07-25 per #19173). ONE call over N ids, and it derives the rule-109 tag SERVER-SIDE from (status, dev_stage) so you never hand-derive a tag and get it wrong. Output is paste-ready for the pickup prompt. Do NOT loop `get_idea_progress` per idea: state goes stale between calls, and on 2026-07-25 that produced 6 wrong dispositions out of 39, including a P0 disk-migration idea reported live when it had already been rejected.

Map each reconcile return VERBATIM to the rule-91 tag: deployed→`[deployed]`, building→`[executing]`, failed/stuck→`[blocked]` (name the unblocker), proposed→`[proposed]`, rejected→`[rejected]`, superseded→`[superseded]`. (`[queued]` is banned per rule 161.)

**The tag in the rule-91 pickup prompt MUST match the reconcile return.** Drift between the reconcile return and the pickup-prompt tag is a GATE B violation. If you cannot run the reconcile call (tool gap below) you may NOT fall back to `[approved:autonomous]` silently — tag it `[blocked:reconcile-unavailable]` with the reason so Ruben knows the state is unverified and the thread is NOT closeable.

### Reconcile evidence quoting (prevents fake tags)

Every idea reconciled this session MUST carry a `(verified: ...)` parenthetical next to its tag quoting the reconcile return. Required for session-filed/reconciled ideas; optional for carried-forward tags. Rationale + format: `Rules-archive/267-case-law.md`.

### Bare idea numbers are a self-fail

If ANY field of the `result` (not just the pickup prompt block) mentions a `#NNNN` without a disposition bracket, GATE B is violated. This includes prose descriptions, "Where we left off" bullets, parentheticals, and cross-references. The rule-91 TAG-SCAN GATE is the mechanical enforcement for this. If the agent ships a bare idea number, it did not run the rule-29 pre-completion audit step 5, and the `attempt_completion` is invalid.

**`[approved:autonomous]` is banned in a final pickup prompt** — replace with a verified tag before `attempt_completion`. Tool-gap workarounds + rationale: `Rules-archive/267-case-law.md`.

## GATE C — Blocked-executor hand-ship

**If a GATE B reconcile finds a filed idea `impl_failed` / deploy-blocked AND the agent has the tools to do the work itself, the agent MUST ship it by hand in the same session — not re-file, not tag `[blocked]` and move on.** Re-queueing an impl_failed build is legal ONCE; a second failure or a structural blocker means the agent is the ship path. Tag `[deployed]` with `(verified: hand-shipped, <evidence>)`. Canonical case #18132 [deployed]: `Rules-archive/267-case-law.md`.

## The anti-abuse gate (do NOT offload these)

1. The exact thing your `attempt_completion` reports as done — must be done inline or verified-executed, not just filed.
2. Human-only decisions (money, regulator, student comms beyond rule-29 cap) → Q-card per rule 12.
3. Trivial work (one SQL update, one file read).
4. Exploratory discovery — still forming the question (table/query/file unknown)? Inline. Boundaries known? Offload. Full text: `Rules-archive/267-case-law.md`.

## Distinguish from Rule 00 (subagents)

Subagents = synchronous, in-window, local-files-only, use when you need the result NOW. Orchestrator/Executor = async, cron-driven, full server/DB/MCP stack, use when the sub-unit doesn't block your next step.

## Self-checks

**Before any offload (`create_idea` autonomous):**
1. Does this sub-unit block my own next step? If yes → do it now or use rule-00 subagent.
2. Is this a human-only decision? If yes → Q-card (rule 12), not autonomous.
3. Am I about to claim in `attempt_completion` that something is done that I only just filed? If yes → don't claim done.

**Before `attempt_completion` (the reconcile pass — GATE B):**
1. Did I file anything to the Orchestrator this task? If yes → did I run a reconcile call for EACH (not "I filed it, it's fine")?
2. Is every filed idea tagged with a VERIFIED live-state disposition in result AND pickup prompt — NOT `[approved:autonomous]`?
3. Does each tag match the reconcile return (no drift), with a `(verified: ...)` parenthetical?
4. Is anything stuck/failed left unaddressed? If yes → fix now or flag `[blocked]` with the unblocker named.
5. **TAG-SCAN check:** does `result` contain ANY bare `#NNNN` without a disposition bracket? If yes → the reconcile pass is INVALID. Tag every bare number before shipping.

## Cap

Don't fire more offloaded ideas than you can reconcile. If you fire 40 ideas, you check all 40, not sample 3.

## Cross-references

- Rule 00 — force-subagent-use (SYNCHRONOUS sibling; use when you need the result back now)
- Rule 38 — Ruben-asks = autonomous-tier minimum (filing-tier floor)
- Rule 109 — every deliverable needs a disposition status (tagging format)
- Rule 91 — every completion needs a pickup prompt (reconcile results feed Reference IDs, bare-number TAG-SCAN GATE is the mechanical enforcer)
- Rule 29 — agents act on confidence tier (governs the cleanup pass — fix stuck items, don't just list them)
- Full case law + source incidents + addenda: `Rules-archive/267-case-law.md`

## GATE D — Approved-idea auto-promotion (TO THE VERY TOP of Executor/Orchestrator)

**Permanent hardfloor (2026-08-12 Ruben steer: "promote TO THE VERY TOP of executor/orchestrator ... support Cline 1st and Argus 2nd").** When this window filed or approved ANY idea buildable in another window:

1. Promote EVERY approved/filed idea from THIS task to the very top: `UPDATE orchestrator_ideas SET efficiency_priority = 1 WHERE id = #NNNN` BEFORE attempt_completion.
2. Priority philosophy: ideas supporting THIS window's deliverable come FIRST (Cline 1st); fleet/infra/Argus monitoring ideas SECOND (Argus 2nd).
3. Do NOT file-then-forget: if the work is buildable in THIS window, still BUILD it here per rule 300.
4. Reconcile in GATE B: any promoted idea must be in an actionable status or marked `superseded`/`impl_failed` with a reason — never left `proposed` if you approved it.

## Last updated

2026-08-19 — duplicate "GATE C" heading renamed GATE D; self-checks + hand-ship sections tightened for G8 floor compliance. Prior: 2026-08-15 GATE A0 build-here-first + executor-doctor duty (Ruben directive); 2026-07-25 trim (idea #19125). Case law: `Rules-archive/267-case-law.md`.


# 267 — Offload independent sub-work to RUBEN Orchestrator/Executor mid-task, then reconcile before completion

Permanent hardfloor rule. Workspace-scoped. Source: 2026-07-10 Ruben directive — "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," + "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." Promoted to hardfloor + rewritten for obedience 2026-07-10.

## The two gates (both are binary, both fire at mechanically-detectable moments)

### GATE A — Offload gate (fires when you identify 2+ independent work units)

**When a task contains 2+ independent units of work and at least one does NOT block your own next step, you MUST offload the deferrable unit(s) to the Orchestrator via `create_idea` (tier=autonomous per rule 38) and continue your critical path.** Do not serialize work the executor can absorb in parallel. Do not block/poll waiting on it.

This gate fires the moment you catch yourself about to do inline work that is (a) independent of your next step and (b) bulk/repetitive/deferrable. The trigger is detectable: if you are about to loop over N similar items inline and the executor could do them, offload instead.

### GATE A2 — Active drive-to-execution (2026-07-11 addendum)

**The filing window is not limited to file-and-wait-for-cron.** After `create_idea`, the same window MAY immediately drive the idea to execution instead of waiting on the executor's cron cadence:

1. `idea_action(idea_id, action="approve")` — promotes the idea out of `proposed` immediately.
2. `idea_action(idea_id, action="implement")` — triggers the auto-build pipeline synchronously, right now, in this window.
3. For decisions (not ideas): `decision_action(decision_id, action="approve")` then `decision_action(decision_id, action="execute")` drives a pending/proposed decision straight to executed, instead of leaving it for the executor's own polling loop.

This is an ADDITIONAL option, not a replacement for Gate A's file-and-continue path. Use it when:
- The work is genuinely autonomous-tier (rule 29/38 — no human-policy judgment required), AND
- Immediate execution materially speeds up the task (the result is needed for this task's own completion, or queue pressure makes waiting for cron costly), AND
- The agent has verified (not assumed) the idea/decision is in a state that accepts `approve`/`implement`/`execute` (check `get_idea_progress`/`list_decisions` first if unsure).

**Still human-gated tiers are never bypassed this way.** Money, regulator, student-facing comms beyond the rule-29 cap stay Q-card/pending — driving to `implement`/`execute` does NOT override that gate; it only accelerates work already inside the autonomous lane.

**Gate B reconciliation still applies even after actively driving to execution.** Triggering `implement`/`execute` is not itself the reconcile pass — you still call `get_idea_progress`/`list_decisions` afterward to confirm the drive actually completed (success/stuck/failed), same as the cron-driven path. Don't claim `[deployed]` just because you called `implement` — confirm it landed.

### GATE B — Reconcile gate (fires before attempt_completion, like rule 91)


**Before calling `attempt_completion`, if this task filed 1+ ideas to the Orchestrator, you MUST call `list_decisions` or `get_idea_progress` for EVERY idea # you filed.** "I filed it, it's fine" is NOT a reconcile pass. A reconcile pass is a tool call that returns real status. Skipping this gate is the same class of violation as shipping an `attempt_completion` without the rule-91 pickup prompt.

Classify each filed idea: executed / in-progress / stuck / failed / still-queued.
- Stuck or failed → fix inline now (rule 29) or re-file with corrected params. Do not leave it silently broken.
- In-progress/queued at wrap time → tag `[approved:autonomous]` honestly. NOT "done."
- Executed → tag `[deployed]` only if you verified it actually ran, else `[approved:autonomous]`.

Every filed idea # gets a rule-109 disposition tag in the result AND the rule-91 pickup prompt Reference IDs section.

## The anti-abuse gate (do NOT offload these)

Offloading is for *volume the executor's cron loop can absorb in parallel*, NOT for *avoiding the work your own completion must report*.

**Never offload:**
1. **The exact thing your `attempt_completion` needs to report as done.** If your completion says "X is [deployed]," X must be done inline or verified-executed, not just filed. Filing the fix for the ticket you're closing, then claiming the ticket resolved before the executor ran it, is a rule-29 violation in async clothing.
2. **Human-only decisions** (money, regulator, student-facing comms beyond rule-29 cap) → Q-card/pending per rule 12, NOT autonomous.
3. **Trivial work** where dispatch overhead exceeds doing it inline (one SQL update, one file read).
4. **Exploratory/open-ended discovery** — "help me figure out what I even need to look at." See below.

## Exploratory discovery is inline-only — never offloaded

The discovery/scoping phase (you don't yet know the table, query shape, or pattern) is NOT an independent sub-unit — it's the thing that DEFINES the sub-units. The executor runs a fire-and-forget chain against a FIXED plan with no channel back to you mid-chain. Filing "go figure out X" either sits stuck (plan step can't resolve to a concrete tool call) or the executor guesses a scope and silently does the wrong thing.

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

## Addendum (2026-07-11) — 4 points from live investigation

1. **Offloaded work is not instant.** Gate A work filed via `create_idea` (autonomous tier) runs on the executor's own cron cadence, not synchronously. When you reach Gate B, do not assume a filed idea has completed just because time has passed in your own window — always call the verifying tool (below) rather than inferring completion from elapsed wall-clock time.

2. **Gate B verification must be a real tool call, not an assertion.** "I filed it, it's fine" — even if said confidently, even if the idea number is real — is NOT a reconcile pass unless `list_decisions` or `get_idea_progress` was actually called for that idea and returned status data. An agent that skips the tool call and asserts completion is committing the identical violation this gate exists to prevent, just with better prose.

3. **Open item needing independent verification:** idea #17119 (efficiency_priority auto-flag gap) has not yet been independently re-verified this cycle. Treat it as an open reconcile item, not a closed one, until a future session runs `get_idea_progress(17119)` and confirms real status.

4. **Staleness/drift safeguard for offloaded plans that touch files.** Before trusting a Gate A offloaded/queued plan, or before a Gate B reconcile auto-approves a decision that touches a file, verify the target file's content has not drifted since the plan was authored. This is not a new ask — a working precedent already exists and is live in production: `RubenExecutor::computeFileShasForPlan()` hashes every plan-referenced file at plan time into the `file_shas_at_plan_time` column, and `RubenExecutor::checkPlanFreshness()` re-hashes at approve/replay/reap time and diffs. It is wired into 3 call sites, all NON-DESTRUCTIVE by design (never hard-blocks, never silently overwrites):
   - `api/ruben_executor.php::handleApprove()` — refuses approval and reports drift in the API response if any referenced file changed since plan time.
   - `cron_ruben_autonomous.php::executeApprovedPlan()` — on detected drift, downgrades `outcome` to `rebase_required` (does not replay against stale state; next cycle re-plans against current file shas).
   - `cron_ruben_autonomous.php::sweepOrphanedApprovals()` (Orphan Approval Reaper) — aborts orphaned approvals with a descriptive message on drift or missing snapshot, rather than blindly re-executing a stale approved plan.
   Any NEW offload/reconcile pathway that touches files should follow this exact pattern: downgrade to `needs_verify`/`rebase_required`/supervised on drift — never hard-crash, never silently trust a stale queued plan.


## Cross-references

- Rule 00 — force-subagent-use (SYNCHRONOUS sibling; use when you need the result back now)
- Rule 38 — Ruben-asks = autonomous-tier minimum (filing-tier floor)
- Rule 109 — every deliverable needs a disposition status (tagging format)
- Rule 91 — every completion needs a pickup prompt (reconcile results feed Reference IDs)
- Rule 29 — agents act on confidence tier (governs the cleanup pass — fix stuck items, don't just list them)
- Full case law + source incidents: `Rules-archive/267-case-law.md`

## Source

2026-07-10 — Ruben directive: "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," + "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." Promoted to hardfloor same date after obedience review found the archive version lacked a mechanically-detectable trigger and a structural reconcile gate.

## Last updated

2026-07-10 — promoted to hardfloor + rewritten for obedience. Core gate trimmed from 9KB to <6KB; case law archived.
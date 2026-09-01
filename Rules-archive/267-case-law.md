# 267 — Case law & expanded source material (archive)

Companion to the hardfloor rule `Rules/267-orchestrator-executor-offload-and-reconcile.md`. The core gate + self-checks live in the hardfloor file (always-loaded). This file holds the longer rationale, examples, and source incidents — fetched on demand via `clinerules_lookup(rule_id=267-case-law)` when an agent needs the deeper context behind Gate A / Gate B.

## The problem this solves

A Cline window doing a task with independent, deferrable, or bulk sub-units (e.g. "audit N students," "fix M similar bugs," "backfill X rows then verify") often does all of it serially inline, burning this window's time/context on work that doesn't need to happen synchronously. The RUBEN Orchestrator/Executor (`cron_ruben_autonomous.php`, ticks every ~1 min, rule 106/22/239) already exists as a free, async, cron-driven execution engine. It is under-used as a mid-task offload mechanism — most existing rules (38, 109) treat it only as a place to file *follow-on* work after the current task is done, not as a lever to pull *during* iteration to go faster.

## Exploratory discovery — the worked example

There is a category of work that fails the "is this independent of my critical path" test even though it looks like it could be a sub-unit: **the discovery/scoping phase, where you don't yet know what you're looking for.**

- "Audit these 40 students" → offloadable (bounded, known unit, you already know the table and the query shape).
- "Figure out which students even have this problem" → NOT offloadable (you don't know the query, the table, or the pattern until you've iteratively poked at the data and read what came back).

**Why the Orchestrator/Executor can't do this (same failure shape as rule-00 subagents, different mechanism):** the executor runs a fire-and-forget chain against a FIXED plan (`create_idea` with a defined `approval_tier` and description). It has no channel back to you mid-chain to say "I looked, here's what I found, now tell me what to look at next." Filing an open-ended "go figure out X" idea to the executor either (a) sits stuck because the plan step can't resolve to a concrete tool call, or (b) the executor guesses a scope and silently does the wrong thing — worse than a stuck subagent, because nobody is watching it fail in real time.

This mirrors the identical gap added to rule 00 for synchronous subagents (open-ended research must stay inline there too) — same underlying principle, two different mechanisms (sync subagent vs async executor), same fix: exploratory/scoping work is inline-and-iterative by nature, only CONVERGED bounded units get offloaded (to either lever).

## Guardrails against misuse (expanded)

- **Cap:** don't fire more offloaded ideas than can plausibly be reconciled in the cleanup pass. If you fire 40 ideas, you must check all 40, not sample 3.
- **Never** use "I offloaded it to the executor" as an excuse to skip verifying it worked. Rule 29 "act, don't defer" still applies to the cleanup pass itself.
- **Never** offload something whose completion THIS task's own `attempt_completion` needs to already be true (e.g. don't file the exact fix this ticket needs and then claim the ticket resolved before the executor actually ran it).
- Async offload is for *volume/parallelism the executor's cron loop can absorb*, not for *avoiding doing the work at all*.

## Why this was promoted to hardfloor (obedience review, 2026-07-10)

The original archive version (9,082 bytes) was NOT reliably obeyable for three structural reasons:

1. **Location.** It lived in `Rules-archive/`, not the always-loaded system prompt. Agents only obey a rule they've been prompted with; an archive rule is obeyed only if the agent already knows to look it up.
2. **No mechanically-detectable trigger.** The trigger ("2+ independent units where one doesn't block your next step") was a judgment call an agent could rationalize past. Obeyed hardfloor rules fire at a binary moment ("first response," "before `attempt_completion`," "path starts with `/etc/`").
3. **Reconciliation was prose, not structural.** An agent could claim "I checked, all fine" without calling `list_decisions`/`get_idea_progress`. The fix: Gate B makes the reconcile pass a required tool call before `attempt_completion`, same enforcement shape as rule 91's pickup-prompt gate.

The promotion trimmed the core to <6KB (under the 8KB warn / 12KB block caps), added the slug to `HARDFLOOR_SLUGS`, and moved this expanded material here.

## Cross-references

- Rule 00 — force-subagent-use (SYNCHRONOUS sibling; use that when you need the result back now)
- Rule 38 — Ruben-asks = autonomous-tier minimum (the filing-tier floor for anything offloaded)
- Rule 109 — every deliverable needs a disposition status (the tagging format used in the cleanup pass)
- Rule 91 — every completion needs a pickup prompt (cleanup-pass results feed the Reference IDs section)
- Rule 29 — agents act on confidence tier (govern whether to ship inline vs file; also governs the cleanup pass itself — don't just list stuck items, fix them)
- Rule 106 — RUBEN runtime quickref (the actual cron/table names for the executor)
- Rule 22 — executor self-supervision loops (ground-truth gating for what the executor picks up)

## Source incident

2026-07-10 — Ruben directive in Cline: "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," proposed add-on "come back at the end of the task to cleanup any tasks sent to orchestrator/executor." This rule formalizes the offload-then-reconcile pattern as distinct from rule 00's synchronous subagent dispatch, and ties the "cleanup" step to the existing rule 109 disposition-tagging mechanism rather than inventing a new format.

## Addendum material moved from hardfloor rule (2026-07-11 compliance rewrite)

### 4 points from live investigation (2026-07-11)

1. **Offloaded work is not instant.** Gate A work filed via `create_idea` (autonomous tier) runs on the executor's own cron cadence, not synchronously. When you reach Gate B, do not assume a filed idea has completed just because time has passed in your own window — always call the verifying tool rather than inferring completion from elapsed wall-clock time.

2. **Gate B verification must be a real tool call, not an assertion.** "I filed it, it's fine" — even if said confidently, even if the idea number is real — is NOT a reconcile pass unless `list_decisions` or `get_idea_progress` was actually called for that idea and returned status data. An agent that skips the tool call and asserts completion is committing the identical violation this gate exists to prevent, just with better prose.

3. **Open item needing independent verification:** idea #17119 (efficiency_priority auto-flag gap) has not yet been independently re-verified this cycle. Treat it as an open reconcile item, not a closed one, until a future session runs `get_idea_progress(17119)` and confirms real status.

4. **Staleness/drift safeguard for offloaded plans that touch files.** Before trusting a Gate A offloaded/queued plan, or before a Gate B reconcile auto-approves a decision that touches a file, verify the target file's content has not drifted since the plan was authored. This is not a new ask — a working precedent already exists and is live in production: `RubenExecutor::computeFileShasForPlan()` hashes every plan-referenced file at plan time into the `file_shas_at_plan_time` column, and `RubenExecutor::checkPlanFreshness()` re-hashes at approve/replay/reap time and diffs. It is wired into 3 call sites, all NON-DESTRUCTIVE by design (never hard-blocks, never silently overwrites):
   - `api/ruben_executor.php::handleApprove()` — refuses approval and reports drift in the API response if any referenced file changed since plan time.
   - `cron_ruben_autonomous.php::executeApprovedPlan()` — on detected drift, downgrades `outcome` to `rebase_required` (does not replay against stale state; next cycle re-plans against current file shas).
   - `cron_ruben_autonomous.php::sweepOrphanedApprovals()` (Orphan Approval Reaper) — aborts orphaned approvals with a descriptive message on drift or missing snapshot, rather than blindly re-executing a stale approved plan.
   Any NEW offload/reconcile pathway that touches files should follow this exact pattern: downgrade to `needs_verify`/`rebase_required`/supervised on drift — never hard-crash, never silently trust a stale queued plan.

### Live obedience audit findings (2026-07-11b)

Ran a live test of Gate A2 this session: called `idea_action(idea_id=17122, action="approve")` — tool returned a checkmark AND a body of `{"ok": false, "error": "Invalid id or action"}` in the SAME response. The checkmark is misleading; `ok:false` is the real signal. **Never trust the checkmark/prose wrapper on an MCP tool response — always read the structured `ok`/`error` field.**

Also discovered `get_idea_progress` (the tool Gate B and the 4-point addendum both prescribe for verification) currently returns `{"error": "Unknown action", "valid": [...]}` — i.e. **the verification tool itself is not wired correctly on the server side right now.** This means an agent following Gate B in good faith (calling the documented verification tool) cannot currently get a real status back for ideas via that path. Until this is fixed server-side:
- Treat `get_idea_progress` failures with `"error":"Unknown action"` as a KNOWN TOOL GAP, not proof the idea is stuck/failed.
- Prefer `list_decisions` or `get_activity_feed`/`list_events` (which DO return real structured data, confirmed working this session) as the Gate B verification path until `get_idea_progress` is fixed.
- File an idea for the `get_idea_progress` action-routing bug rather than silently working around it every time (rule 29 — fix the instrument, don't just route around it, per rule 266).

**Obedience gap this reveals:** Gate A2 and Gate B assume the verification tools return clean, trustworthy status. They currently do not always. Any agent using Gate A2 must read the RAW body of the tool response (not the summary checkmark) before tagging anything `[deployed]` or `[approved:autonomous]`.

## Last updated

2026-07-11 — added addendum material (4-point investigation + obedience audit) moved from hardfloor rule during compliance rewrite. Core gates in the hardfloor rule were trimmed; this archive holds the edge-case detail.

## 2026-07-16 addendum — GATE A4: blocking poll-sleeps are a rule-267 violation

Source incident: 2026-07-16 10:12 — while waiting on a GLM ring relaunch, the agent issued repeated `execute_command` calls of the shape `sleep 120; tail log` / `sleep 240; ...`. Each blocked the window ~30s (terminal timeout), produced no work, and did what the already-running watchers (medic/supervisor/WOPR cron) were built to do. Ruben: "is that you sleeping or just a command? shouldn't you be leveraging rule 267?"

**The bright-line rule:** NEVER issue a blocking `sleep N` (N > 30) inside execute_command/ssh_command as a way to "wait for" an async process. That is inline serialization of watching — the exact anti-pattern Gate A kills.

Legal waiting shapes:
1. **A watcher already exists** (medic, supervisor, cron, systemd) → do OTHER work; check the log ONCE per natural break in that work. The watcher owns the waiting.
2. **No watcher exists** → CREATE one (nohup script, cron, launchd) that writes state to a file/DB, then do other work. Creating the watcher IS the rule-267 offload.
3. **Genuinely nothing else to do and the wait is short (<60s)** → end the turn with attempt_completion and let Ruben re-prompt, or check on the next natural tool call. Do not burn turns sleeping.

Self-check before any `sleep`: "is a machine already watching this?" If yes → work on something else. If no → build the watcher, then work on something else.


---

## Changelog moved out of the core rule 2026-07-25 (G7 12KB compliance, idea #19125)

## Last updated

2026-07-13 (2nd pass) — Added reconcile evidence quoting subsection (prevents fake tags by requiring `(verified: ...)` parenthetical next to the disposition tag). Added bare-number=self-fail clause (any bare `#NNNN` in `result` invalidates GATE B). Added TAG-SCAN self-check item 6. Added cross-ref to rule 91 TAG-SCAN GATE. Tagged all idea references in the rule body with disposition brackets per rule-91. Source incident: this session's own first attempt shipped "idea #17537" bare in prose, which is exactly what these new clauses prevent.

2026-07-13 — GATE B rewrite per Ruben directive (idea #17537 [rejected]): added the verbatim reconcile-return → rule-91-tag mapping table, banned `[approved:autonomous]` in final pickup prompts (ambiguous between executing and queued), added drift-forbidden clause + `[blocked:reconcile-unavailable]` fallback, added Ruben's closeout test. Goal: Ruben can close threads from the tag alone, no re-verification tool call needed.

2026-07-11 — compliance rewrite. Moved 2 addendums (tool-bug findings, drift safeguards) to case law to de-bloat the core gates. Added the 3-question offload test to make Gate A mechanically detectable. Condensed Gate A2 + known tool gaps into brief cross-refs. Core rule now ~5KB (under 8KB warn cap).

## 2026-08-15 — GATE A0 source incident + trimmed long-form sections

GATE A0 (build-here-first) added after Ruben called out approve-instead-of-build 3 times in one session ("lol, you are still approving rather than taking advantage of rule 267. The entire point of rule 267 was to get things in window deployed quicker as well as to ensure executor ideas are working (quasi frankenstein doctor of executor)"). Ideas #26591/#26593 were filed+promoted when both were buildable in-window in under 10 tool calls each; the window then built them by hand anyway. Executor queue that day: cap 3 workers vs 60 eligible ideas.

Executor doctor shipped same session: /var/www/emtskills/cron/cron_executor_doctor.php (crontab */15). Repairs orphan shape A (status=approved + dev_stage='' — 66 rows found) and shape B (status='' + active dev_stage — the promote_and_run status-blanking bug, 464 rows over 30d, scope-guarded to 7d/50-per-run). Flags impl_failed spikes (>5/24h) and stale mid-stage rows (>2h in drafting/coding/auditing/testing). Logs to orchestrator_event_log as system_health/cron_executor_doctor.

### Long-form text trimmed from the hardfloor rule for the G7 12KB cap, preserved here:

**GATE A3 environment-blocker (full text):** If a sub-task fails because a binary/tool isn't on PATH in Cline's non-interactive shell (`command -v brew`/`node`/etc. → not found), do NOT repeatedly retry the same failing command. This is an environment mismatch, not a logic bug, and it's a valid Gate-A trigger on its own: the executor runs its own shell context (often with a full login PATH, different user, or root) and may resolve what Cline's shell cannot. Offload the blocked sub-task via `create_idea` rather than looping on `command not found`.

**Reconcile evidence quoting rationale (2026-07-13):** the `(verified: ...)` parenthetical is the proof a reconcile call actually ran — prevents agents writing `[deployed]`/`[rejected]` as a guess. Required for ideas filed or reconciled this session; optional for carried-forward tags.

**`[approved:autonomous]` ban rationale:** ambiguous between executing and queued; forces Ruben to re-verify. Mid-task-only fallback right after idea_action(approve); must be replaced by a verified tag before attempt_completion (2026-07-13 Ruben directive, idea #17537 [rejected]).

**Known tool gap:** `get_idea_progress` may return `{"error": "Unknown action"}` — use reconcile_ideas / list_decisions / get_activity_feed instead.

**Ruben's closeout test:** verified tags let him close threads with zero re-verification. The verified tag IS the verification.

**Exploratory discovery carve-out (full text):** The discovery/scoping phase (you don't yet know the table, query shape, or pattern) is NOT an independent sub-unit — it's the thing that DEFINES the sub-units. The executor runs a fire-and-forget chain against a FIXED plan with no channel back mid-chain. Test: "do I already know the boundaries (table, query shape, file, exact fix), or am I still forming the question?" Forming → inline. Boundaries known → offload. Mirrors rule 00's carve-out.

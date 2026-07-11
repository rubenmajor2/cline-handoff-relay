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

## Last updated

2026-07-10 — initial case-law archive. Content moved from the archive version of 267 during hardfloor promotion.
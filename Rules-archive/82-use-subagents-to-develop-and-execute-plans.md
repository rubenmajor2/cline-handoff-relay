# 82 — Use subagents to develop AND execute multi-step plans

Permanent rule. Workspace-scoped. Source: 2026-05-15 task #1778525737952 — Ruben
directive verbatim: *"use subagents to develop the plans and develop them as
necessary for execution. Should this be a cline rule, the latter statement?"*

Yes. This rule formalizes it.

## Why this rule exists (the gap)

Rule 17 (default-on subagent dispatch) and rule 53 (subagent iteration +
narration) already mandate subagent use for research and multi-step builds.
But they leave a tactical gap: when Cline is about to execute a multi-step
plan (e.g. 5 phases of a system ship), the current pattern is to dispatch
subagents ONCE for the discovery phase and then run the rest serially.

That's wasteful. Subagents are also the right tool for **plan development**
(decomposing a build into phases, ranking integration paths, choosing
between competing implementations) AND for **plan execution prep** (drafting
the exact code/SQL/config for each phase so the main agent can ship without
re-deriving).

## The bright-line rule

**When Ruben approves a multi-phase ship (≥3 phases) OR a non-trivial
plan that requires synthesis across systems, the main agent MUST:**

1. **Dispatch parallel subagents BEFORE the first phase** to develop each
   phase's plan in detail (exact code, exact SQL, exact commands, reversal
   commands, smoke-test steps).
2. **Per rule 53**: narrate each dispatch inline with model selection
   (`Dispatching Haiku 4.5 for prompt 1 (phase 1 SQL + reversal), Sonnet
   4.6 for prompt 2 (phase 2 code patch), Opus 4.7 for prompt 3
   (cross-system integration audit)`).
3. **Take the subagent results and SHIP**. The main agent's job is
   execution — running the tools, deploying the files, watching for
   errors. The subagents already did the design work.
4. **Re-dispatch subagents mid-execution** if discovery turns up an
   unknown (rule 53 iteration mandate). Don't grind serially through
   unexpected branches.
5. **Re-dispatch subagents AFTER critical phases** to verify the ship
   landed correctly (smoke tests, log scans, cross-system sanity checks).

## When this fires (the trigger list)

This rule fires whenever the main agent finds itself about to:

- Execute ≥3 distinct phases (schema + MCP + portal + cron + rule, etc.)
- Synthesize across ≥2 systems (e.g. Mac yolo_learner + WOPR MySQL +
  emsu-operations MCP)
- Make a decision between 2+ competing implementation paths
- Re-evaluate something previously decided based on new evidence

When ALL of those are false (single-file edit, single SSH command,
read-only lookup) — skip per rule 17's exception list.

## Concrete example (the 2026-05-15 cline-learner integration)

Ruben said "ship both and the 3rd one unless detrimental, use subagents to
develop the plans."

What I did (correct per this rule):
- **3 parallel subagents** at task start:
  - Subagent 1: develop yolo_learner ↔ rule 81 wire-up plan (Haiku/Sonnet)
  - Subagent 2: develop the no-tool-use playbook content (Haiku)
  - Subagent 3: re-evaluate KAIZEN integration (Sonnet — needed
    cross-system synthesis)
- Subagent 3 found integration #3 was **detrimental** (Cline task_id vs
  orchestrator chain_id namespace mismatch — JOIN would be empty 95% of
  the time). Skipped per Ruben's "unless detrimental" caveat.
- Subagent 1's plan + subagent 2's playbook → main agent executed both
  directly without re-deriving.

What it would have looked like WITHOUT this rule: main agent serially
develops plan 1, ships it, serially develops plan 2, ships it, serially
re-evaluates plan 3, ships it. ~3x the wall-clock + 3x the chance of
running out of context.

## Anti-patterns that violate this rule

- Dispatching subagents ONCE at the start of a task and then going
  serial for execution (the most common mistake).
- Running 3+ separate `ssh` or `read_file` calls in serial when a single
  subagent could have done all three in parallel and returned synthesis.
- Re-deriving the exact code/SQL the subagent already returned (wastes
  context, drifts from the spec).
- Skipping the post-ship verification subagent dispatch (then finding
  out 3 turns later that something didn't land).

## What this rule does NOT do

- Does NOT override rule 17's "obviously trivial" exception list.
  Single-file edits don't need subagent plan development.
- Does NOT mandate 5 subagents per ship — match the count to the
  number of independent concerns. 2-3 is typical, 5 is the ceiling
  per Cline's parallelism limit.
- Does NOT change rule 54 (subagents can ACT under locking primitives).
  Some subagents return plans for main-agent execution; some execute
  directly. Pick by reversibility + locking, per rule 29 + 54.

## Self-check before any multi-phase ship

Ask: *"Am I about to execute ≥3 phases, OR synthesize across ≥2 systems,
OR pick between competing implementations?"*

If yes → my next tool call MUST be `use_subagents` with parallel plan
development. NOT inline tool calls. NOT serial discovery.

If I'm halfway through phase 1 and about to inline-derive phase 2's
specifics — STOP. Dispatch a subagent for phase 2's plan. Don't waste
main-agent context on work a Haiku can do.

## Cross-references

- Rule 17 — default-on subagent dispatch (broader policy; this rule is
  the multi-phase-ship specialization)
- Rule 53 — subagent iteration + narration + Opus binary signals
- Rule 54 — subagents can act under locking primitives
- Rule 22 — executor self-supervision loops (RUBEN-side analogue)
- Rule 29 — agents act on confidence tier
- Rule 65 — multi-failure incident → Opus root cause (related shape,
  different trigger)
- Rule 78 — idea mentions need Y/N + recommendation (subagents help
  surface the right recommendation)

## Source incident

Task #1778525737952 — Ruben asked for this rule directly after
observing the correct pattern in action: 3 parallel subagents
developed integration plans, 1 said "detrimental, skip", 2 returned
ready-to-execute specs, main agent shipped both in ~5 minutes.
Without subagents the same work would have taken ~30 minutes of
inline derivation and 2x context.

## Last updated

2026-05-15 — initial rule.

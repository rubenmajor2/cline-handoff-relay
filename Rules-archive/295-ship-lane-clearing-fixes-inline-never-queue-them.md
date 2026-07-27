# 295 — A fix that CLEARS A LANE or PREVENTS A REGRESSION ships INLINE. Never queue it behind the backlog it exists to unblock.

Proposed 2026-07-27. Source: Ruben directive — "These things addressing regressing or needing to clear lanes must be built and shipped here because otherwise they will sit in queue and not be built ahead of the others, thus compounding bottleneck and improper deployment. That probably should be a cline rule."

## The bright-line rule

**If a fix's PURPOSE is to unblock other work or to prevent regression of already-shipped work, the agent SHIPS IT INLINE in the current session. Filing it to the Orchestrator/Executor is a violation.**

Rule 267 GATE A says offload independent sub-work. This rule is the carve-out: **lane-clearing and regression-preventing work is NOT independent — it is the precondition for everything queued behind it.** Offloading it inverts the dependency order.

## The 3-question CLASS test (run BEFORE any `create_idea`)

Ask these about the fix you are about to file. **Any YES → ship inline, do not file:**

1. **Lane-clearing?** Does other queued work stay blocked, or keep failing the same way, until this lands? (test gates, schema validators, dispatcher unblocks, capacity guards)
2. **Regression-preventing?** Does this protect a fix already shipped from being silently deleted or reverted by later automated work? (marker guards, invariant alarms, denylists)
3. **Executor-self-referential?** Does the fix live inside the very pipeline that would build it? (`cron_ruben_implement.php`, `cron_ruben_autonomous.php`, `lib/safe_deploy.php`, the test gate, the dispatcher)

**Question 3 is the deadliest.** A fix to the build pipeline, filed as an idea, must be built BY the broken pipeline. That is circular and it will fail or land mangled.

## Why queueing these compounds the bottleneck

Measured 2026-07-26 → 27:
- A spec-quality gate (#19456) was filed rather than shipped. It landed `impl_failed` **on a PHP parse error in its own generated code** — killed by the exact defect class it was written to catch. Meanwhile 9 sibling ideas sat `impl_failed` on that same defect all night.
- A regression guard (#19458) was filed rather than shipped. The executor produced a patch whose only test inserted into an unrelated table, so **nothing landed** while the agent's completion described the risk as handled. 275 pre-July ideas targeting the just-fixed files remained live the whole time.
- Both were later hand-shipped in minutes and verified with a live test.

The pattern: **the fix that unblocks N items gets scheduled as item N+1.** Throughput never improves because the multiplier never lands.

## What "ship inline" requires (not a licence to skip verification)

Shipping inline means MORE rigor, not less:

1. **Read the target first.** Confirm the real function/helper names. Do not assume (`getImplDb()` vs `rubenDb()` cost a rewrite on 2026-07-27).
2. **Extend existing logic, never duplicate it.** Grep for a guard that already covers the concern. A parallel second guard drifts.
3. **`php -l` before and after.**
4. **Prove it with a live test that can FAIL.** Assert the bad case is rejected AND the good case still passes AND any escape hatch works. A test that only checks the happy path proves nothing. Structural grep is NOT proof (rule 99, rule 263).
5. **Back up, and state the one-command reversal.**
6. **Then file the idea for the audit trail, tagged as already-shipped, and close it** so the executor cannot re-build it and clobber the live fix (rule 267 GATE C).

## Anti-patterns

- ❌ Filing a test-gate fix and reporting the blocked ideas as "waiting on #NNNN"
- ❌ Describing a regression risk as handled when only an idea was filed
- ❌ "The executor will get to it" for a fix INSIDE the executor
- ❌ Bulk-retrying blocked items before the gate that unblocks them is live
- ❌ Shipping inline but verifying with grep instead of a failing-capable test

## Escape hatch

If the fix genuinely needs human policy judgment (money, regulator, student comms) it is not lane-clearing — it is a Q-card. Route per rule 12. If it is too large for one session, ship the smallest *verifiable* slice inline (the gate) and queue the elaboration (the tuning).

## Cross-references

- Rule 267 — GATE A offload / GATE B reconcile / GATE C hand-ship (this rule sharpens GATE C into a pre-filing class test)
- Rule 29 — agents default to action; "I filed it" is not acting when you hold the tools
- Rule 92 — fixing broken systems IS the work
- Rule 99 — subagent/self writes are unverified until independently re-read
- Rule 263 — verify before claiming
- Bug library #2035 (executor test gate), #2037 (marker guard + deploy audit schema)

## Source incidents

2026-07-26/27 — #19456 [rejected] and #19458 [queued] both filed instead of shipped; both failed to land; both hand-shipped later in minutes with passing live tests (markers `SPEC_QUALITY_GATE_20260727`, `MARKER_REGRESSION_GUARD_20260727`). Same session surfaced a P0 the queue could never have fixed: `cron_ruben_implement.php` line 96 `require_once`'d `lib/idea_cluster_consumer.php`, a file that never existed, so the ideas executor was fatally dead (ideas/hr 8 → 2 → 1 → 0). A fix for a fatally-dead build pipeline cannot be built by that pipeline.

## Last updated

2026-07-27 — initial proposal. Archive rule (per `_INDEX.md`, new rules default to `Rules-archive/`). Promote to hardfloor only on Ruben's explicit call, which also requires adding the slug to `HARDFLOOR_SLUGS` in `.pre-write-lint.sh` first.

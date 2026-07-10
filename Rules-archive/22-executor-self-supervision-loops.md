# 22 — Executor self-supervision loops (autonomous-agent ground-truth gating)

Permanent rule. Workspace-scoped. Source incident: ruben-emergency-cost-control,
2026-05-03 23:09 PT → 2026-05-04 02:25 PT. Five rounds of fixes, ~$8K Opus burn
in 24h, all stemming from the same architectural gap: an autonomous executor
whose self-reported "outcome=executed" signal had decoupled from its
ground-truth "did work actually ship" signal. Every cron tick the planner
re-emitted the same plan, the executor said "executed", no files moved, repeat
forever.

This rule is the policy layer for "executor self-supervision" — the practice
of closing that loop in code, not just docs, before turning autonomy back on.

## The bright-line rule

**Any autonomous agent with a "did it succeed" output MUST also expose a
ground-truth side-effect signal that's measurable independently of the
agent's own self-report. The two MUST be reconciled before the agent is
allowed to "retry" the same work.**

Examples of self-report vs ground truth on EMSU:

| Agent | Self-report | Ground truth |
|---|---|---|
| RubenExecutor | `orchestrator_execution_log.outcome` | `files_deployed_count`, `safe_deploy_audit` rows, `dispatch_snooze_until` |
| Personnel AI | `agent_action_log.action` | actual sent SMS / email row in `outbound_*` tables |
| Vapi voice agent | call transcript "completed successfully" | actual call duration ≥30s, no `voice_ai_outage` row |
| Bug Hunter detector | `learned_pattern.confidence` | actual repair_chain shipped + auto_enabled=1 |

If your executor's self-report can drift from ground truth without anyone
noticing, you have a "ghost loop" — and ghost loops on autonomy tier are
the single most expensive failure mode on this stack.

## The four required loops

When you ship a new autonomous executor (or modify one), all four loops
below MUST exist before the kill switch is allowed to flip true. If any
loop is missing, the executor stays in supervised tier or behind a kill
switch.

### Loop 1: classification of what failed

Every "outcome != success" path MUST write a structured failure category
into the log row, not just a freeform error string. EMSU's example:
`orchestrator_execution_log.failure_category` ENUM with categories like
`silent_ghost`, `gate_refused_safe_deploy`, `awaiting_qcard`,
`anthropic_credit_exhausted`. Categories are inferred from error_text +
context (e.g. `whats_pending`, `start_prompt`).

Without classification, every retry burns the same prompt and gets the
same failure. With classification, the next loop can short-circuit.

### Loop 2: a recipe table that says what to do

A small DB table (EMSU's `failure_repair_recipes`) maps each
`failure_category` → `retry_strategy` + `planner_input_modifier` +
`max_attempts`. The strategies fall into two families:

- **Soft-stop strategies** (`replan_compact`, `replan_with_describe_first`,
  `replan_with_file_reread`, `exponential_backoff_30_60_120`,
  `replan_with_schema_review`) — try again, but with a different prompt
  or after a delay. Bounded by `max_attempts`.
- **Hard-stop strategies** (`escalate_blocked`, `escalate_no_retry`,
  `snooze_until_upstream`) — do NOT retry. Demote the chain (or
  equivalent), notify the human, exit clean. `max_attempts=0`.

### Loop 3: an executor that READS the recipes on retry

This is the loop most often missing. The recipe table can exist, the
classifier can run, but if the executor doesn't actually consult the
recipe before its next retry, the loop is open. EMSU's wireup:

- `RubenExecutor::finalizeLog()` writes `failure_category` on every
  finalize, gated by `ruben_brain_expansion_enabled`.
- `RubenExecutor::tryModifyAndRetry()` looks up the recipe by
  `failure_category` from the prior log row, prepends
  `planner_input_modifier` to the v2 prompt for soft-stop strategies,
  and demotes the chain (no v2 attempt) for hard-stop strategies.

### Loop 4: a kill switch that's actually independent

The kill switch must short-circuit BOTH loops 1+3 simultaneously, in a
single config value, reversible by a single SQL statement. If it takes a
file deploy + FPM reload to disable the brain, the kill switch isn't a
kill switch — it's a fire drill. EMSU pattern:
`orchestrator_config.ruben_brain_expansion_enabled`. One JSON_SET, one
row affected, takes effect on the next cron tick (CLI re-reads config
fresh; no opcache).

## Rules of the road

1. **The executor PHP edit ships kill-switch-OFF, always.** No exceptions.
   Even if Ruben says "ship it live" — the kill switch is the rollback
   path. You can flip the switch on in the same handoff, but the file
   landing and the switch flipping MUST be two separate operations.

2. **Classification first, retry second.** If the classifier isn't
   shipped + tested, the recipe table is just decoration. If the recipe
   table isn't seeded, the executor wireup has no rows to read. Build
   in order: schema → seed → classifier → wireup → kill switch flip.

3. **Hard-stop categories MUST exist for self-flagging chains.** EMSU's
   trio: `self_demote_to_supervised`, `awaiting_qcard`, `locked_on_mac`.
   These catch chains whose own `whats_pending` text says "I am stuck"
   — the classifier reads the chain's own words and demotes the chain
   instead of replanning. This is the most operator-leveraged category
   because the chain literally tells you the answer.

4. **The recipe table needs a `detection_pattern` column.** Even if the
   classifier hardcodes patterns for speed, the column is the audit
   trail: "WHY was this row picked for that category." Without it,
   classifier drift over time becomes invisible.

5. **Babysit the live-fire for 4h minimum.** When the kill switch flips
   on, watch:
   ```
   SELECT failure_category, COUNT(*) FROM orchestrator_execution_log
     WHERE created_at > NOW() - INTERVAL 4 HOUR GROUP BY 1 ORDER BY 2 DESC;
   SELECT ROUND(SUM(...)/1e6,2) cost_4h FROM orchestrator_execution_log
     WHERE created_at > NOW() - INTERVAL 4 HOUR;
   ```
   Targets per agent: cost_4h is meaningfully below the pre-flip
   trajectory; classifier writes ≥80% of new rows with non-NULL
   `failure_category`. If either misses, flip the kill switch back off
   and figure out why before re-flipping.

6. **The first run after enable WILL surface bugs.** Plan for it.
   Tonight's example: enabling `ruben_back_repair_enabled` immediately
   exposed a `Column not found: 'note'` SQL error in
   `lib/RubenBackRepair.php` — a stale column reference from when
   `orchestrator_execution_log` was renamed `note → reviewer_note`.
   Caught and fixed in the same minute because the babysitting loop
   was active. Without active babysitting, the back-repair would have
   silently snoozed every chain to a fallback path and we'd never have
   noticed. Therefore: **the agent that flips the switch is the agent
   that watches the next ≥3 cron ticks live**. No "flip and walk away".

6.4. **CONSUMER PATH coverage — the sister-bug to 6.5**.
   On 2026-05-04 11:11 PT (round 6 of the same incident), discovered that
   the hard-stop recipe consumer at `tryModifyAndRetry()` only runs when
   outcome='failed'. Silent ghosts arrive with outcome='executed' — plan
   ran, no errors, just no work shipped. So the classifier correctly
   wrote `failure_category='silent_ghost'` (15 rows in 1h, perfect
   detection), but the DEMOTE action lived on a code path the ghost
   would never traverse. Result: chain stayed eligible, next cron tick
   produced another silent ghost, forever.

   **The architectural bug:** an asymmetric pipeline where classification
   fires on every finalize, but action consumption only fires on a
   subset of finalizes. The recipe table was decoration on outcome=
   'executed' rows because no code consulted it from that branch.

   **Fix:** add the recipe consumer in the SAME function that wrote
   the category (`finalizeLog`), not just in the retry branch. Then
   both paths — failed and executed — get the same hard-stop demotion.

   **Rule of thumb**: when you ship a classifier that writes a
   structured field, grep for every code path that READS that field
   and prove each path has the right consumer logic. If the read
   sites only fire on a subset of write sites, the feature is
   asymmetric and ghosts will exploit the gap. Fix: move the consumer
   up to the most-common write site, or duplicate it on every branch.

6.5. **READ vs WRITE pairing — the wiring bug**.

   Tonight (2026-05-04) discovered a wiring bug in `classifyFailure`:
   the silent_ghost rule needed `$extra['files_deployed_count']` and
   `$extra['distinct_states']` — but those keys were NEVER WRITTEN
   anywhere in the codebase. They defaulted to 0 and 99, so the rule
   `outcome=executed AND filesDeployed=0 AND distinctStates<=2` was
   `0===0 AND 99<=2` = always FALSE. **silent_ghost classifier was
   silently never firing for 8 hours**, masquerading as "the system is
   healthy: 0 silent_ghosts!" Even worse: the metric looked perfect.

   Fix: read from `$extra['files_deployed']` (the array WHICH IS
   populated by `executePlan` return at line 2061) and count it.
   Backfill the rule with a SECOND clause that uses fields actually
   populated by `finalizeLog` itself (chain.status fetched from DB,
   tick_count_24h fetched from DB).

   **Rule of thumb**: when you add a new column/field that a classifier
   reads, prove that the same field is WRITTEN somewhere — grep for
   the key/column in the same commit. If only the read site exists,
   the feature is dead on arrival. If grep returns ONE site, it's
   read-only and the rule is broken.

7. **Don't trust a "0 silent_ghosts!" metric** unless you've verified
   the classifier path actually fires. The post-hoc verification:
   `SELECT outcome, failure_category, COUNT(*) FROM
   orchestrator_execution_log WHERE created_at > NOW() - INTERVAL N
   HOUR GROUP BY outcome, failure_category` — if every row in
   outcome='executed' shows failure_category=NULL across 100+ ticks,
   the classifier isn't working. A real working classifier writes
   non-NULL on at least some executed rows (cascading_blocker,
   awaiting_qcard, etc fire on whats_pending text, independent of the
   silent_ghost path).

8. **Progress audit table — the canonical work-output metric**.
   Cost is an INPUT metric. Ticks/hr is a THROUGHPUT metric. Neither
   tells you "is real work happening?" The right metric: per-tick
   delta on (chain.status, what_was_done length, files_deployed_count).
   Tonight shipped `chain_progress_audit` table that records this on
   every finalizeLog. Dashboards/alerts should read THAT table for
   "are we making progress" questions. Pre-existing fixation on cost
   alone hid the fact that 209 ticks at $7.99/hr were producing 1
   actual completed chain (rate: 0.5%). The progress_score column
   (0=no progress, 1=files deployed, 2=what_was_done grew, 3=status
   advanced, 4=status=completed) is the right primitive.

9. **Subagent discipline catches main-context blindness**. Tonight's
   classifier wiring bug was IN VIEW of the main agent (a 35-line
   block I had personally written). I missed it because I had no
   pressure to verify the read/write pairing. A subagent that was
   asked specifically "does the codebase ever write
   files_deployed_count?" found the bug in 4 minutes via grep across
   the file tree. **The fresh-context perspective is a feature, not
   just a token-saver**: it forces explicit hypothesis-testing rather
   than implicit assumption-trusting. Use subagents on architecture
   audits even when token budget isn't tight.

7. **Force-chains lists are landmines, treat accordingly.**
   `orchestrator_config.ruben_autonomous_force_chains` bypasses cooldown
   and most safety gates by design — useful to push past forbidden
   patterns ONCE, evil to leave a chain there permanently. Rule of
   thumb: any slug added to a force list MUST be removed in the same
   handoff that completes its work. If the work didn't complete,
   either remove the slug anyway (and accept the slower retry) or
   demote to `approval_tier='blocked'` so the eligibility query at
   `cron_ruben_autonomous.php:589` (filters `tier IN
   ('approved','autonomous')`) excludes it regardless of the force
   list. Tonight's $1.5K bleed was force-chains slugs that never got
   removed.

8. **Snoozes alone are insufficient.** A `dispatch_snooze_until` is a
   timer. Demoting `approval_tier='blocked'` is a logic change. The
   eligibility query checks BOTH; snoozes alone re-enter the pool when
   the timer expires. Real "zap" = both: blocked + future-snooze. The
   block makes it permanent, the snooze gives back-repair a window
   before it's reconsidered.

9. **Don't write this kind of rule from one night's data.** This rule
   exists because four prior cline rounds (round 1 Ruben directive,
   round 2 ghost-detection PHP, round 3 force-chains gate bypass +
   recipes table, round 4 80% wireup, round 5 demote-to-blocked + 6h
   snooze + classifier backfill) plus tonight's wireup converged on
   the same architecture. Below ~3 nights of converging rounds, the
   rule is premature.

## Companion rules / infrastructure already in place

- `.clinerules/00-no-tool-use-tripwire.md` — top-priority defense; loops
  here exist on the autonomous side of the same boundary.
- `.clinerules/16-adaptive-thinking-high-xhigh.md` — the live-fire
  babysitting (rule of the road #5+#6) runs at `High` minimum.
- `.clinerules/17-chain-start-prompt-schema-verification.md` — chains
  that touch the schema-heavy stuff this rule references should run
  with verified DESCRIBE outputs at the top.
- `.clinerules/19-blocking-questions-plain-yn-with-recommendation.md` —
  the kill-switch flips MUST be Y/N-gated when humans are online; one
  Y/N per switch.
- `.clinerules/20-subagents-and-nohup-required.md` — exploring the
  3700+ line executor file is a subagent job. Live-firing is short
  SQL + log-tailing; not a long-shell, no nohup needed for that
  surface.

## Self-audit metric

For any autonomous executor on the stack, weekly:

```sql
SELECT
  COUNT(*) total_executions,
  SUM(CASE WHEN failure_category IS NOT NULL THEN 1 ELSE 0 END) classified,
  ROUND(100 * SUM(CASE WHEN failure_category IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0), 1) classified_pct,
  SUM(CASE WHEN outcome='executed' AND failure_category='silent_ghost'
           THEN 1 ELSE 0 END) silent_ghosts,
  ROUND(SUM(COALESCE(input_tokens,0)*15.0+COALESCE(output_tokens,0)*75.0)/1e6,2) cost_7d
FROM orchestrator_execution_log
WHERE created_at > NOW() - INTERVAL 7 DAY;
```

Targets:
- `classified_pct ≥ 80%` (anything less means the classifier has gaps)
- `silent_ghosts ≤ 1% of total_executions` (anything more means a
  recipe is missing or kill switch was off)
- `cost_7d` should be on the trajectory of a reasonable bound for the
  surface (currently ~$300/wk for RubenExecutor in steady state)

If any target misses, file an idea for the gap and re-run the rounds
needed to close it. Do not raise the targets to make them pass.

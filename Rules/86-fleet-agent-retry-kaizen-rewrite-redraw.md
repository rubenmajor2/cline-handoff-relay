# 86 — Fleet Agent error-recovery loop: retry → KAIZEN → rewrite → drawing board

Permanent rule. Workspace-scoped. Source: 2026-05-17 09:24 PT Ruben directive
verbatim during cline_fleet-agent-runaway: *"Idea similar to executor, fix
the errors / kaizon / then try again, if still errors, rewrite, if still
errors, go back to drawing board, ugh"*

Companion to .clinerules/22 (executor self-supervision loops) and 23
(KAIZEN MCP). Rule 22 is the framework for executor agents. This rule
specializes it for **Fleet Agent + LoRA training/replay/judge workstreams**
where the failure mode is "the pipeline drops data silently because nobody
asked the right downstream question."

## The bright-line rule

**When Fleet Agent (or any LoRA workstream — regrade, judge, backtest replay,
shadow wiring) hits an error, follow this exact escalation ladder. Do NOT
just log the error and walk away. Do NOT just retry indefinitely. Do NOT
wait for someone to manually inspect.**

```
Tier 1 — FIX-AND-RETRY (one shot)
  Inspect the actual error. If the cause is obvious (timeout too short,
  missing keep_alive, wrong column, stale opcache, etc), patch it inline
  and retry exactly once with the fix. Cap retry at 1.

Tier 2 — KAIZEN-CLASSIFY-AND-RETRY (one shot)
  If Tier 1 retry also fails, seed orchestrator_learned_patterns with the
  failure signature + dominant_action. Then run KAIZEN
  kaizen_propose_classifier_rule on the failure log. Apply the proposed
  recipe via failure_repair_recipes. Retry once with the recipe's
  planner_input_modifier applied. Cap retry at 1.

Tier 3 — REWRITE (one shot)
  If Tier 2 retry also fails, the original code shape is wrong. Throw it
  out. Write a new implementation from scratch following the canonical
  pattern in _scripts/llm_backtest/ or the closest sibling that works.
  Run once.

Tier 4 — DRAWING BOARD (escalate to Ruben)
  If Tier 3 rewrite also fails, the approach is wrong. Stop. Surface the
  full history (errors at each tier + what was tried) to Ruben as a Q-card.
  Do NOT spin up more pods, do NOT keep retrying, do NOT defer to a future
  agent without explicit handoff. The pattern is broken in a way that
  needs human design judgment.
```

## What "still errors" means at each tier

Concretely (not subjectively):

- **Tier 1 → Tier 2**: the first retry returned the same error class as the
  original failure, OR a different error class that's clearly downstream of
  the original (e.g. "504 timeout" → "504 timeout").
- **Tier 2 → Tier 3**: KAIZEN classifier returned a recipe, the recipe was
  applied, and the retry STILL hit one of:
  - same error class
  - "no rows returned" / "0 work product" / silent ghost
  - new error class that contradicts the recipe's assumed root cause
- **Tier 3 → Tier 4**: the rewritten code path produces no progress in 2
  consecutive runs, OR the rewrite itself fails to ship (e.g. lint errors
  that the agent can't resolve in 3 edits).

If the cause is genuinely intermittent infrastructure (Anthropic 529s,
Runpod region exhaustion, Spectrum WAN blip), exponential backoff is
acceptable BEFORE tier 1 — it's not part of the ladder.

## Examples (what triggered this rule, what NOT to do)

### What triggered the rule (2026-05-17 morning)

The 30B regrade had two distinct failure shapes:

1. **Phase 1 (regenerate response_text)** — Tier-1 worthy. The original
   replay script on 2026-05-14 hit 960 × HTTP 500 + 360 × connect refused
   + 3 × timeout on Artemis Ollama. The fix was obvious (router timeout
   bugs). Cline patched, ran once successfully, done. **Worked as designed.**

2. **Phase 2 (judge the response_text)** — the hourly grader cron was
   silently NOT touching the 1323 rows because it reads
   `orchestrator_llm_shadow_log`, NOT `llm_3way_backtest_runs`. The
   "wait for grader" path is **structurally dead** — different table,
   different schema, different baseline source. **Cline's first attempt
   was to suggest "wait for grader cron", which was the wrong answer.**

Per Ruben directly: *"If the path is dead then why are you asking me to
wait, that's really dumb."* Correct. When the grader cron path is
structurally incapable of processing these rows, Tier 1 must be "kill
the dead path and ship the right runner" — not "wait."

### What NOT to do at each tier

- **Tier 1**: do NOT silently keep the failing pipeline running while
  pretending it'll catch up later.
- **Tier 2**: do NOT skip KAIZEN seeding (so the pattern recurs).
- **Tier 3**: do NOT iterate on the broken code by patching new lines
  on top of patches — throw it out cleanly and start the rewrite from
  the canonical pattern.
- **Tier 4**: do NOT secretly spin up more pods to "try harder" —
  Ruben needs to see the failure ladder so he can pick a different
  direction.

## What goes in the Q-card at Tier 4

Plain language per .clinerules/05 question-card format:

```
**Q. [Workstream name] — Tier-4 drawing-board reset**

- **What yes does:** abandon current approach. Ruben + Cline pair-design
  the next try from scratch.
- **What no does:** approve more retries within the broken pattern (NOT
  recommended unless reason is clear).
- **What was tried:** Tier 1 (one-line fix attempt + error), Tier 2
  (KAIZEN classification + recipe + retry error), Tier 3 (full rewrite
  attempt + error).
- **Cost so far:** $N Anthropic + $M Runpod + W hours of wall-clock.
- **Recommendation:** ABANDON — the failure shape suggests
  [structural diagnosis, e.g. "we're judging against the wrong table",
  "the LoRA wasn't trained on this kind of prompt", "Artemis WG bandwidth
  saturates at this concurrency"].
```

## Specifically for LoRA workstreams

The data table → pipeline → judge fan-out has at least 3 different
target tables across EMSU:

| Table | Read-by | Write-by |
|---|---|---|
| `orchestrator_llm_shadow_log` | `cron_llm_ab_grader.php` (production grader) | `lib/llm_router.php` shadow path |
| `llm_3way_backtest_runs` | `_scripts/llm_backtest/replay_*.py` (one-shot replay grader) | `_scripts/llm_backtest/replay_*.py` |
| `orchestrator_llm_routes` | `cron_fleet_agent.php` auto-flip logic | manual / auto-flip cron |

**Common Tier-1 mistake**: assuming the production grader will judge
backtest table rows. It won't. They're different pipelines. Verify the
READ side of the table you wrote into before assuming downstream work
will pick up.

**Tier-1 verification SQL pattern** (run this before walking away from
ANY data-population workstream):

```sql
SELECT
  'wrote_to_table' AS step,
  COUNT(*) populated,
  SUM(target_field IS NOT NULL) gradeable
FROM <write_target_table>
WHERE <batch_id_or_match>;

-- THEN
SELECT 'will_grader_see_this?' AS step, COUNT(*) reachable
FROM <table_that_grader_reads_from>
WHERE <same_filter>;
```

If `reachable=0` and `populated>0`, you have a dead-path problem at
Tier 1. Ship the right runner inline.

## Self-check before any Fleet Agent / LoRA workstream wrap-up

Before any `attempt_completion` on a Fleet Agent / LoRA workstream:

1. Did I verify the downstream pipeline can actually see the data I
   wrote? (Run the SQL above.)
2. If not, did I write the right runner OR file a clear Q-card?
3. Did I avoid "wait for it" framing on structurally-dead paths?
4. If I retried more than 2x without changing approach, did I
   acknowledge that the failure category itself is wrong?

If any answer is no, finish the work or surface the dead-end before
shipping the wrap-up.

## Cross-references

- .clinerules/22 — executor self-supervision loops (the general framework
  this specializes)
- .clinerules/23 — KAIZEN MCP (Tier 2 mechanic)
- .clinerules/29 — agents act on confidence tier (Tier 1 reversibility gates)
- .clinerules/42 — proactive systemic solutions (Tier 4 idea filing)
- .clinerules/46 — every agent correction loops back to RUBEN + KAIZEN
  (Tier 2 KAIZEN seeding mandatory)
- .clinerules/55 — if you mention a bug, investigate and fix it
- .clinerules/84 — use Runpod to save time (Tier 3 rewrites can spin pods
  per the offer-to-spin protocol if the rewrite needs different hardware)
- .clinerules/85 — student issues: prefer systemic fix + class of others
  affected (Tier 2 KAIZEN classification mirrors this)

## Source incident

Cline task `#fleet-agent-runaway-2026-05-17`. 30B regrade Phase 1 worked
(Tier 1 was correct). Phase 2 was about to be wrongly handed off to "wait
for grader cron" — dead path. Ruben caught it: *"If the path is dead then
why are you asking me to wait, that's really dumb."* Cline then shipped
the proper judge runner (Phase 2-correct) as the Tier-1 fix, no Q-card
needed.

## Last updated

2026-05-17 09:27 PT — initial rule per Ruben directive in same task.

# 88 — LLM-as-judge must be cross-family (no Anthropic judging Anthropic)

Permanent rule. Workspace-scoped. Source: 2026-05-17 `~/Desktop/GRADER_BIAS_FINDINGS_2026-05-17.md` +
ideas #4807 (T1 cross-judge gate, P0), #4808 (T2 backfill, P1), #4809 (T3 policy, P1) + this session's
findings (1647 cross-judge calls across 4.5h corrected 800+ wrong-direction Haiku verdicts).

## Why this rule exists

EMSU's LLM A/B framework graded 65,629 shadow-log rows in 30 days using a single Haiku 4.5 grader.
Two distinct biases corrupted the win_rate stats Fleet Agent uses to autonomously flip production routes:

1. **Prompt instability**: same Haiku, same row, second pass = different verdict. Cross-judge experiment
   on 3 borderline rows flipped 2 of 3 results. ~5-15% of all `loss` verdicts are wrong-direction.
2. **Anthropic-family self-bias**: Haiku judging an Anthropic shadow gives ~10-25pp absolute lift per
   literature (Zheng MT-Bench 2023: +25pp Claude-judging-Claude; Panickssery et al. 2024: causal,
   correlates with self-recognition; verbosity bias compounds it).

Real production impact: 2 of 6 recent Fleet auto-flips are suspect (`plan_summary`→deepseek-v3 and
`file_extract`→claude-haiku-4.5). The `code_patch_small` route kept Sonnet as primary based on a
Haiku-judges-Anthropic stat (max bias condition). Without this rule, more biased flips would land.

## The bright-line rule

**Anthropic models MUST NOT be the sole judge of a route where ANY contestant (primary or shadow)
is also Anthropic.** Specifically:

1. **For any (primary, shadow) pair where both providers are `anthropic`**, the grader MUST use
   `crossJudge()` from `/var/www/emtskills/lib/llm_cross_judge.php` with the same-family swap (Haiku
   dropped, cross-family judge added).
2. **For any route where Fleet Agent is about to issue an UPDATE on `orchestrator_llm_routes`**
   (flip the primary or shadow_providers), Fleet MUST first call `crossJudge()` on a sample of 20-50
   recent graded rows and re-compute win_rate from the majority verdict. If cross-judge win+tie is
   ≥20pp below stored win+tie, BLOCK the flip and file a P1 `cline_grader_bias_block` idea.

## What "cross-family" means

Cross-family = judge model's provider/family is DIFFERENT from both primary AND shadow. Default
3-judge slate (verified live on OpenRouter 2026-05-17):
- `anthropic/claude-haiku-4-5` (Anthropic family)
- `openai/gpt-5.5` (OpenAI family)
- `google/gemini-3.1-flash-lite` (Google family)

Same-family swap-in when both contestants are Anthropic — drop Haiku, add:
- `x-ai/grok-4.3` (xAI family)

Majority vote across the 3 valid judges. 1-1-1 disagreement returns `tie` with `agreement=disagree`.

## When this rule fires

The runtime enforcement lives in two crons:

### Grader side (`cron_llm_ab_grader.php`)
Cross-judge is invoked when ALL of these are true:
- `orchestrator_config.config_json.ab_grader_cross_judge_enabled = true`
- Today's cross-judge call count < `ab_grader_cross_judge_daily_cap` (default 200)
- Row's (primary, shadow) is same-family Anthropic AND the route TODAY still has Anthropic primary
  AND the row's shadow is still in `shadow_providers` (skips legacy residue), OR
- Route is flip-eligible (`win_rate + tie_rate ≥ 0.40` AND `shadow_sample_count ≥ 30`) AND the row's
  shadow is in shadow_providers

### Fleet side (`cron_fleet_agent.php::fa_execute_flip()`)
Cross-judge is invoked BEFORE any UPDATE on `orchestrator_llm_routes` when:
- `orchestrator_config.config_json.fleet_cross_judge_gate_enabled = true`
- Cap on per-flip cost: $0.50 (default `fleet_cross_judge_max_cost_usd`)
- Sample size: 25 rows (default `fleet_cross_judge_sample_size`)
- Block threshold: 20pp drop vs stored stat (default `fleet_cross_judge_block_drop_pp`)

## What this rule does NOT do

- Does NOT replace single-Haiku grading for routes where neither contestant is Anthropic AND the
  route isn't flip-eligible. Cross-judge is ~5x more expensive than single Haiku; not every row needs it.
- Does NOT veto Fleet's other safety gates (cost-rank gate, criticality gate, rejection-freeze gate).
  All gates compose.
- Does NOT apply to W11 local reward model (TF-IDF+LR classifier at 0.80 confidence threshold).
  That's a different decision surface (cheap high-confidence pre-grade); cross-judge runs only on
  rows the local reward model didn't short-circuit.

## Self-supervision layer (rule 22 + rule 23 compliance)

A babysitter cron (`cron_cross_judge_babysitter.php`, runs every 5 min via
`/etc/cron.d/emsu-cross-judge-babysitter`) watches:

1. Any Fleet flip without a corresponding `fleet_cross_judge_check` event in the same window =
   bypass detected → severity=high event
2. Any `fleet_flip_blocked_cross_judge` fire in last hour = surface to Ruben
3. Any `cross_judge_daily_cap_hit` event today = review-required
4. Either gate disabled = warn

Plus 4 KAIZEN `orchestrator_learned_patterns` rows (`fleet_cross_judge_bypass`,
`cross_judge_cap_review`, `fleet_bias_blocks_summary`, `fleet_cross_judge_gate_disabled`) classify
the events on recurrence so RUBEN's triage path picks them up automatically.

## Kill switches

- Grader gate off: `UPDATE orchestrator_config SET config_json=JSON_SET(config_json,'$.ab_grader_cross_judge_enabled',false) WHERE id=1`
- Fleet gate off: `UPDATE orchestrator_config SET config_json=JSON_SET(config_json,'$.fleet_cross_judge_gate_enabled',false) WHERE id=1`
- Bump daily cap: `UPDATE orchestrator_config SET config_json=JSON_SET(config_json,'$.ab_grader_cross_judge_daily_cap',CAST(? AS UNSIGNED)) WHERE id=1`
- Disable babysitter: `sudo rm /etc/cron.d/emsu-cross-judge-babysitter && sudo service cron reload`

Each kill switch is reversible in <30 seconds, single SQL UPDATE or single shell command.

## Cost framing (per .clinerules/87 — opportunity cost)

Cross-judge costs ~$0.015 per call (Haiku $0.001 + GPT-5.5 ~$0.008 + Gemini-flash-lite ~$0.0005 +
overhead). At cap=200/day = ~$3/day = ~$90/mo upper bound. Realistic steady-state with tightened
eligibility: $30-40/mo.

This audits a $1,097/mo LLM-routing decision surface. 3-4% audit overhead is well-justified by the
opportunity cost of biased flips (estimated $200-500/mo in wrong route choices avoided). Per rule 87,
"if we will spend 10K in 30 days and a $30 audit prevents $500 in wrong-route spend, that's not
an expense — that's a return."

## Forbidden patterns (must not ship)

- Single-Anthropic-judge grader on any Anthropic-vs-Anthropic pair where the route still has both
  contestants in play (use `crossJudge()` instead).
- Fleet Agent UPDATE on `orchestrator_llm_routes` without an immediately-preceding cross-judge gate
  call (covered by `fa_execute_flip()` chokepoint).
- "Just use Haiku, it's fast" workarounds when introducing a new grader cron — point it at
  `crossJudge()` if the surface involves Anthropic contestants.
- Disabling either kill switch without filing a `cline_grader_bias_block_escape` idea explaining why.

## What to do when this rule's babysitter alerts

| Event | What to do |
|---|---|
| `fleet_cross_judge_bypass_detected` (severity=high) | Investigate: was lib missing? Kill switch flipped mid-flip? `fa_execute_flip` code path skipped the gate? Likely a regression in Fleet patch — re-verify the patch lines 246-340 of `cron_fleet_agent.php`. |
| `fleet_bias_blocks_summary` (warning) | Working as designed — bias-block fired and Fleet didn't flip. Surface to Ruben (or whoever owns route-flip review) so blocked candidates can be manually checked. Idea is auto-filed at P1 `cline_grader_bias_block`. |
| `cross_judge_cap_review_required` (high) | Either tighten `cj_row_eligible()` further, OR bump `ab_grader_cross_judge_daily_cap` if opportunity cost justifies it. Don't just keep bumping the cap without checking what's eligible. |
| `fleet_cross_judge_gate_disabled_warning` (high) | Someone (or some other cron) disabled the gate. Re-enable: `UPDATE orchestrator_config SET config_json=JSON_SET(config_json,'$.fleet_cross_judge_gate_enabled',true) WHERE id=1`. |

## Cross-references

- `.clinerules/22` — executor self-supervision loops (this rule's framework)
- `.clinerules/23` — KAIZEN MCP failure classifier (where the patterns get learned)
- `.clinerules/29` — agents act on confidence tier (Fleet's flip is the action gated here)
- `.clinerules/40` — Artemis Ollama is the analysis baseline (cross-judge is the audit layer above)
- `.clinerules/42` — proactive systemic solutions (this whole rule + babysitter + KAIZEN IS one)
- `.clinerules/87` — Fleet Agent opportunity cost (justifies the audit spend)
- `~/Desktop/GRADER_BIAS_FINDINGS_2026-05-17.md` — source incident
- `/var/www/emtskills/lib/llm_cross_judge.php` — the runtime
- `/var/www/emtskills/cron/cron_cross_judge_babysitter.php` — the watcher

## Last updated

2026-05-17 — initial rule. Source: cline_grader-bias-fix-2026-05-17. 1647 production rows already
graded with cross-judge confirming the bias-correction effect (e.g. row 71828: orig loss →
cross-judge win 2-of-3). Idea #4807/4808/4809 ship.

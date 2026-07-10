# 119 — Backtest first, training second, shadow last. Fleet Agent autoflips on clean backtest. Supervised-approval friction layer is bypass-eligible.

Permanent rule. Workspace-scoped.

## Source incident

2026-05-26 21:52 PT — Ruben directive verbatim during the cline_fleet_llm_coordinator session:

> *"Dammit, I gave fleet Agent guidelines so simple. Goal is to have 45% W/T (adaptive testing) or better to flip with same or better quality. Work your way up, goal is to get there through 1. backtesting, 2. training (including pods) 3. shadow (last resort), Fleet agent management, backtesting. Opportunity cost. Cline rules, fleet agent rules or whatever. Bypasses hard safety rails, not supervised autonomous approved promoted."*

Pulled because Cline (this thread) had been pushing **shadow_providers** as the primary path to accumulate quality data on new candidate models. Ruben pointed out: shadow is slow (waits for production traffic), backtesting is fast (n=50 controlled run on existing prompts), training closes the gap when a model is close-but-not-quite. The "supervised → human-approval → live-flip" friction layer was over-conservative; the actual safety rail is the gate function itself.

## The bright-line rule

**To bring a new candidate model to autoflip-ready state, follow this priority order:**

1. **Backtest first** — n=50 stratified controlled comparison against the current production primary on that surface. Existing Opus/Sonnet baselines + Haiku cross-family judge per .clinerules/88. Fastest path to a defensible W+T% number. Run via LiteLLM gateway (not raw Ollama queue, which saturates under production traffic).
2. **Training second** — if backtest shows W+T% below the 45% gate but the underlying base model is reasonably capable (we've trained models from sub-20% to 60%+ before — the EMSU corpus is dense signal), schedule a targeted LoRA training run on RunPod (Window J pipeline OR a one-shot 14B-LoRA run). No tight "35-45% only" band — if there's signal in the cell pattern (e.g. one segment is already winning, others losing), training can close the rest. Re-backtest the fine-tuned model.
3. **Shadow grading last resort** — passive vs-primary grading from production traffic. Slow (24-48h to accumulate n=50), depends on real production calls hitting the surface. Use only when:
   - Backtest can't be run offline (model needs live-shape prompts not available in shadow_log)
   - Cost of backtest API calls > expected savings
   - Surface traffic is high enough that 24-48h of grading is fast enough

**Fleet Agent v23 acts on the data the moment it clears the gate. No supervised-approval dwell.** The gate (cost-down × W+T ≥ current × n≥50 × blast ≤ $10/hr × surface allowlist × reversible) IS the safety rail. Adding "human review for 24h before flipping" on top of the gate is supervision-theater for things that are already gate-protected.

## What stays hard-rail (never bypassed)

These remain protected by `fleet_v23_excluded_surfaces_csv` AND must NEVER be auto-flipped under any conditions:

- `grievance_response` — legal-grade comms
- `refund_decision` — money decisions
- `regulator_outbound` — accreditor / state agency comms
- `payment_outreach` — billing language
- `affirm_dispute` — financial dispute language
- `student_email_compose` — outbound to a student in an active complaint thread (compliance)

Hard safety rails. Cannot be removed without explicit Ruben yes AND a Q-card AND a documented compliance review.

## What this rule changes

**Before this rule (the wrong shape):**
1. New candidate model considered.
2. Added as `shadow_provider` to a few routes.
3. Wait 24-48h for production traffic to accumulate grades.
4. Review shadow logs.
5. Manually flip to primary OR file Q-card for human approval.
6. Wait another 24h "shadow-of-live" review.
7. Maybe finally autoflip.

**After this rule (the correct shape):**
1. New candidate model considered.
2. **Backtest immediately** against current primary, n=50 stratified, Haiku judge per .clinerules/88.
3. If gates clear (cost-down × W+T ≥ current × n≥50 × blast ≤ $10/hr × surface allowlist) → **Fleet Agent v23 autoflips on next 5-min tick. No dwell.**
4. If close-but-not-quite → schedule LoRA training, re-backtest after.
5. If far below → reject candidate for that surface, file as `proposed` with reason.
6. Shadow grading reserved for surfaces where backtest is infeasible.

## Opportunity-cost framing

Every hour spent waiting on shadow data is dollars not saved. Every "24h supervised review" before flipping a candidate that already cleared the gate is a free $X/hr of avoidable cost. The gate function exists precisely so the human review layer can be skipped on the items that are already gate-protected.

Backtesting takes ~30-50 min wall-clock for n=50 (10s per LLM call × 2 models + 2s Haiku judge × 50 = ~25-50 min). Shadow grading takes 24-48h for the same sample size. **Choose backtest unless the surface can't be backtested.**

## Fleet Agent v23 config keys updated by this rule

```
fleet_v23_autoflip_enabled = 1                  (was 0 — flipped live)
fleet_v23_stale_reaper_enabled = 1              (was 0 — flipped live)
fleet_v23_backtest_priority_over_shadow = 1     (new)
fleet_v23_supervised_approval_required = 0      (new — supervised dwell removed)
```

## Self-check before any new candidate model evaluation

Before deciding how to evaluate a new candidate model, ask:

1. *"Can I backtest this offline against the current primary right now?"* If yes → backtest. Skip everything else.
2. *"If backtest is close-but-not-quite on some cells, can the LoRA training pipeline close the gap?"* If yes → train, re-backtest.
3. *"Is the surface backtestable at all (do we have stored prompts in shadow_log to replay against)?"* If no → that's the only case shadow grading is allowed.

If I find myself adding a candidate as `shadow_provider` first without trying backtest first, I'm violating this rule.

## Cross-references

- `.clinerules/29` — agents-act-on-confidence-tier (gate-protected actions can ship without Q-card)
- `.clinerules/38` — Ruben-asks = autonomous tier (this rule IS the Ruben-asked update)
- `.clinerules/86` — no silent-ghost flips (autoflip still logs every decision to fleet_decision_log)
- `.clinerules/88` — cross-family judge for backtests
- `.clinerules/89` — RunPod dormant gate (training still respects this gate)
- `.clinerules/116` — HTTP-probe before trust (backtest probes the LiteLLM gateway, not raw Ollama)
- `.clinerules/117` — fleet_inventory lookup before host probe
- `.clinerules/118` — parallel windows must run simultaneously (backtests across N candidates fire in parallel)

## Last updated

2026-05-26 21:52 PT — initial. Source: Ruben directive in cline_fleet_llm_coordinator session, after Cline had been over-engineering the shadow-grading path as the default. Backtest-first, training-second, shadow-last-resort. Fleet Agent autoflips on backtest data the moment gates clear — no supervised-approval dwell.
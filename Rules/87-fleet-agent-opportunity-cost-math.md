# 87 — Fleet Agent must include opportunity-cost-of-delay in spend decisions

Permanent rule. Workspace-scoped. Source: 2026-05-17 11:40 PT Ruben directive verbatim:

> *"Fleet agent does not seem to be taking into consideration money projected to be lost by waiting and doing it slowly. The on-going budget burn needs to be calculated, for example if we will spend 10K in 30days and it tries to spread out a solution that would save 5k over 14 days instead of doing it now to save more in that day vs waiting and paying tons later."*

Companion to .clinerules/29 (act-on-confidence), 51 (Runpod offer-protocol), 84 (default-on Runpod for >6h work), 86 (Fleet retry ladder).

## The bright-line rule

**When proposing a spend decision (mint pods, run training, do replacement work), the comparison MUST include the on-going burn rate of the status quo — not just the absolute cost of the action.**

Specifically: every "should we spend $X now?" framing must answer "what does NOT spending $X now cost us in T days?"

## The math (concrete formula)

For any proposed spend decision with cost $C and projected savings $S/month landing in T days:

```
Cost of doing it NOW          = $C
Cost of doing it in T days    = $C + (T/30) × (current monthly burn rate − target burn rate)
                              = $C + (T/30) × monthly_delta
```

If `monthly_delta > 0` (we're currently burning more than the post-fix rate), then **every day of delay costs `monthly_delta / 30`**.

**Decision rule**: spend now if `(T_days × monthly_delta / 30) ≥ break_even_factor × C`, where break_even_factor is typically 1.0 (spend now if delay cost matches action cost) to 0.5 (spend now even if delay only costs half the action cost — because optionality matters).

## Worked example (the EMSU LoRA replacement, 2026-05-17)

- Current Anthropic burn: **$1,236/30d = $41.20/day**
- Target post-replacement: **$750/30d = $25/day** (per the analysis)
- Daily delta if we don't act: **$16.20/day** = **$486/30d** = **$2,916/180d**
- Action: parallel-mint 8-10 Runpod B200 pods to compress RAG work from 60-90 days to ~1-2 days
- Action cost: **~$300-1,000** for the burst

```
Cost of doing it NOW              = $1,000 (worst case)
Cost of waiting 60 days (sequential RAG) = 60 × $16.20 = $972 IN DELAY + still need to do the work
```

**$1,000 now vs $972 in pure delay-cost + still-must-do-it later = ship now.**

Even more starkly: **if delay is 90 days** (the conservative "60-90 day RAG" estimate), delay cost alone is **$1,458**, exceeding the entire fleet burst cost. **Doing it slowly literally costs more than doing it fast.**

## What Fleet Agent currently misses (the bug)

Today's Fleet Agent code (`cron_fleet_agent.php`):
- Tracks `weekly_runpod_cap_usd`, `monthly_runpod_cap_usd`, `daily_runpod_cap_usd`
- Tracks `cost_overrun_hours`, `cost_overrun_usd` per pod
- Does NOT track `current_anthropic_burn_30d` or `projected_savings_per_30d` for any approved idea
- Does NOT compare `action_cost` vs `delay_cost_of_inaction`
- Result: Fleet Agent says "this pod is expensive at $5.49/hr, let me terminate" while the SURFACE that pod is meant to fix is burning $580/month every day it stays on Anthropic

## What needs to change (planned, not yet shipped — Phase 2 work)

Idea queued at #4815 (just filing): extend `cron_fleet_agent.php` decision math to consult:

```sql
-- For any approved idea touching an LLM surface, compute:
SELECT 
    (SELECT SUM(cost_usd) FROM llm_call_log 
     WHERE surface = idea.target_surface 
     AND ts >= NOW() - INTERVAL 30 DAY) AS monthly_burn,
    idea.estimated_savings_pct AS target_reduction_pct
INTO @burn, @savings_pct;

SET @daily_delay_cost = (@burn * @savings_pct / 100) / 30;
SET @action_cost = idea.estimated_action_cost_usd;
SET @break_even_days = @action_cost / @daily_delay_cost;
```

If `@break_even_days < 30`, fleet should escalate to "ship-now" tier instead of queueing.

## What Cline must do RIGHT NOW (until Phase 2 ships)

**Until cron_fleet_agent.php is patched with the opportunity-cost math, Cline manually computes it for every spend proposal.** Specifically:

1. Before proposing any "wait and do it slowly" timeline, compute:
   - Current monthly burn on the affected surface (from `llm_call_log`)
   - Projected post-fix monthly burn
   - Monthly delta
   - Days-to-completion × (delta / 30) = delay cost
2. Compare to action cost
3. If delay cost > 0.5 × action cost over the proposed timeline, **default to spending now**
4. Surface the math in the offer card per rule 51, with both numbers visible

## Forbidden phrases (that ignore opportunity cost)

- "Multi-session, sequential" — without showing what each session of delay costs
- "Over 30-60 days" — without showing the per-day burn during those 30-60 days
- "Cheap if we do it slowly" — slow is not cheap when the existing system burns money
- "Wait for shadow data to accumulate" — when shadow accumulation rate is slower than the burn rate

## Source incident

2026-05-17 11:35 PT. Ruben asked for the RAG savings + timeline picture. Cline returned a 60-90 day timeline as if that were just "the plan." Ruben correctly pointed out: 60-90 days of $41/day current burn = $2,460-$3,690 burned during the wait. That's more than the cost of just doing it all today on parallel pods. The implicit "spread it out" framing was wrong — opportunity cost is real money.

Ruben directive verbatim: *"if we will spend 10K in 30days and it tries to spread out a solution that would save 5k over 14 days instead of doing it now to save more in that day vs waiting and paying tons later."*

## Cross-references

- .clinerules/29 — act-on-confidence (this rule sharpens the "small blast + reversible + high confidence" → ACT logic by adding the delay-cost dimension)
- .clinerules/51 — Runpod offer-protocol (every offer card now includes opportunity-cost math)
- .clinerules/84 — default-on Runpod for >6h work (this rule says: also default-on when delay cost > action cost, regardless of work duration)
- .clinerules/86 — Fleet retry ladder (Tier 1 fix-and-retry should consider opportunity cost — sometimes "fix it cheaper" is more expensive than "ship the right tool now")

## Last updated

2026-05-17 11:40 PT — initial rule per Ruben directive in #fleet-agent-runaway-2026-05-17. Pair-shipped with idea #4815 for the executable code change.

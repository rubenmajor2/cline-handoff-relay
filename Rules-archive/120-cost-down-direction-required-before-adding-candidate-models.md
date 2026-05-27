# 120 — Cost-down + same-or-better quality is REQUIRED to even consider adding a candidate model, not just to flip it.

Permanent rule. Workspace-scoped.

## The 3 rules of EMSU model adoption (per Ruben, consolidated 2026-05-26 23:00 PT)

1. **45% W+T (adaptive) or better** vs whatever current production primary is on that surface
2. **Same or better quality** at the model level (not just "tied or close")
3. **Lower price** than the current primary (cost-down direction is hard-required, not optional)

**All three must be true together.** Not 2/3, not "we'll check the third in a backtest later." All three known-or-believed-true BEFORE the candidate even gets added to LiteLLM as a model_group.

If you can't make a defensible cost-down + quality-not-worse claim BEFORE adding the model_group, the model doesn't belong in the candidate pool. Adding it as a candidate "to see how it does" is supervision-theater: spending money + ops bandwidth backtesting things that mathematically can't clear the gate (because cost is going up, not down).

## Source incident

2026-05-26 22:55 PT — Ruben directive verbatim after Cline (this thread) staged 4 candidate model_groups (gpt-5.5-pro, grok-4.3, mistral-small-22b, gpt-5.4-nano) without verifying cost-direction for each:

> *"are they better quality but cheaper? as per my rules. In fact, can you tell me my rules agian and make a cline rule for it?"*

Specifically:
- **gpt-5.5-pro** — newer than gpt-5.5 but PRO tier is typically MORE expensive than the base SKU. Cost direction = UP, possibly. Added as candidate anyway. Wrong.
- **grok-4.3** — no known pricing relative to Sonnet baseline. Added blind. Wrong.
- **mistral-small-22b** — LOCAL Ollama, $0 cost. Cost direction = DOWN definitively. Right.
- **gpt-5.4-nano** — documented as ~40% cheaper than gpt-5.4-mini. Cost direction = DOWN definitively. Right.

So of the 4, only 2 (mistral-22b + gpt-5.4-nano) had defensible cost-down stories. The other 2 (gpt-5.5-pro, grok-4.3) were "let's see" adds — explicit drift from the rule.

## The bright-line rule

**Before adding a model_group to /etc/litellm/config.yaml as a candidate, verify ALL THREE:**

1. **W+T target:** is there reason to believe this model can clear 45% W+T vs the current production primary on at least ONE backtestable surface? Sources: existing shadow log data, vendor benchmark claims (with skepticism), same-model-family comparisons (e.g. "gpt-5.5-pro is at least as good as gpt-5.5"), public leaderboards (with skepticism).

2. **Quality direction:** is the candidate AT MINIMUM same quality as current primary? If it's clearly worse (e.g. a "mini" or "nano" or "lite" variant going against a flagship), the candidate doesn't belong unless point 3 is overwhelming.

3. **Cost-down:** is the per-token cost of this candidate STRICTLY LESS than the current primary on the target surface? Pull vendor pricing. If unknown, look it up before adding. If it's UP, don't add. Period.

If any one fails, the candidate doesn't enter the candidate pool. File as `rejected` with reason, or `proposed` if you want a placeholder to revisit.

## What this rule changes vs prior posture

**Before:**
- "Add interesting-looking models to LiteLLM, let Fleet Agent v24 Phase D backtest them, autoflip if they clear gates"
- Implicit assumption: "backtesting cheap, why not"
- Result: candidate pool fills with cost-UP candidates that mathematically can't ever clear the autoflip gate but consume backtest budget

**After:**
- Pre-screen at the moment of consideration: cost-down? quality ≥ current? plausible 45% W+T? If yes to all three → add. If no → reject upfront.
- Backtest budget only spent on candidates that COULD clear the gate
- Candidate pool stays small and focused

## Cost-down verification quick-reference (as of 2026-05-26)

| Vendor | Looking up cost | Pre-check sources |
|---|---|---|
| Anthropic | https://docs.anthropic.com/en/api/pricing | claude-haiku-4-5 ($0.80/$4 per Mtok) < Sonnet ($3/$15) < Opus ($15/$75) |
| OpenAI | https://platform.openai.com/docs/pricing | gpt-5.4-nano < gpt-5.4-mini < gpt-5.4 < gpt-5.5 < gpt-5.5-pro |
| OpenRouter | https://openrouter.ai/models (per-model card) | Most variants are ~10-30% markup vs vendor direct |
| DeepSeek | https://api.deepseek.com/pricing | V4-Flash ~1/3 of V3-0324 (verified) |
| xAI | https://docs.x.ai/docs/models | grok-4-fast-non-reasoning < grok-4.3 < grok-4-heavy |
| Local Ollama | $0 token cost. Cost line is electricity + Mac/GPU depreciation. Treat as $0 for routing decisions. | Free-tier; verify model fits the host's RAM |

## Self-check before adding ANY new model_group to /etc/litellm/config.yaml

Ask:

1. *"What's the current primary cost-per-1K-tokens on the surface I want to route this to?"*
2. *"What's the candidate's cost-per-1K-tokens?"*
3. *"Is candidate < primary?"* If no → STOP. Don't add. File as rejected with reason 'cost-up direction'.
4. *"What's the candidate's expected W+T% vs the primary?"* (rough estimate — shadow log, family comparison, or vendor benchmark)
5. *"Is the expected W+T% ≥ 45% AND ≥ current primary's effective performance?"* If no → STOP. File as proposed for future revisit.

Only after all 5 questions get green → safe_deploy to /etc/litellm/config.yaml.

## What the autoflip rules still do (unchanged from rule 119)

After a candidate is added (having passed the pre-screen), Fleet Agent v24 Phase D backtests it. Phase B autoflip then promotes it IF AND ONLY IF the live backtest data still clears the gate:

- W+T% ≥ 45% absolute on n≥50 backtest samples
- W+T% ≥ current primary's effective baseline
- Cost-down vs current primary
- Blast radius ≤ $10/hr
- Surface on `fleet_v23_surface_allowlist_csv`
- Surface NOT in `fleet_v23_excluded_surfaces_csv`
- Reversible by single SQL UPDATE

Rule 120 is the PRE-screen. Rule 119 (autoflip) is the LIVE-data verification. Together they keep the candidate pool clean AND the live routes safe.

## Anti-patterns this rule kills

- ❌ "Let's add gpt-5.5-pro since it's newer than gpt-5.5" — no cost check
- ❌ "We have an unused vendor key for xAI, add grok-4.3 as a candidate" — no quality or cost check
- ❌ "Vendor X released a new model, default-add to LiteLLM" — Window P's freshness audit FILES the IDEA, but the idea must pass rule 120 before it ships
- ❌ "Backtest is cheap, just throw it in the candidate pool" — backtest budget IS spent ($5/cand × $50/day); cost-up candidates waste that budget for zero promotion potential
- ❌ "Pro / Heavy / Plus tier might be better quality" — even if true, cost is almost always UP, so it can't autoflip in. File as proposal for human-grade UX comparison instead.

## Cross-references

- `.clinerules/29` — agents-act-on-confidence-tier (gate-protected actions ship; rule 120 is the pre-screen layer above the gate)
- `.clinerules/38` — Ruben-asks = autonomous tier (autonomy doesn't mean bypass the rules — autonomy means apply them right)
- `.clinerules/86` — no silent-ghost flips (rejection of a candidate per rule 120 must be logged as such)
- `.clinerules/89` — RunPod dormant gate (training is gated separately)
- `.clinerules/118` — parallel windows simultaneously (rule 120 checks happen per candidate, in parallel)
- `.clinerules/119` — backtest first, training second, shadow last resort (rule 119 is downstream of rule 120; rule 120 controls what enters the candidate pool, rule 119 controls how candidates are evaluated)

## Last updated

2026-05-26 23:00 PT — initial. Source: Ruben directive after Cline drift-added gpt-5.5-pro and grok-4.3 as candidates without cost-direction checks. Rule consolidates the 3 EMSU model-adoption rules: (1) 45% W+T or better, (2) same or better quality, (3) lower price. ALL THREE must be true before adding a candidate. Cost-up candidates don't enter the pool, period.
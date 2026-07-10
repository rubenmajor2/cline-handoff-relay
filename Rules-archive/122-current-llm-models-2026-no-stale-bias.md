# 122 — Current LLM model landscape (2026). Do NOT judge cheap/free models on 2024 knowledge.

Source incident: 2026-05-31 LLM-cost session. Cline repeatedly concluded "our free LLMs suck / a 7B can't beat Sonnet / you need a 70B to replace Sonnet" — all anchored to 2024-era model capability (Qwen2.5, Llama3.3). Ruben caught it: *"this makes me think you're looking up old LLM info and saying our Free LLMs suck — sure if they're based off 3 years ago."* He was right. The prior "free LLMs lose" verdict came ENTIRELY from a 2026-05-14 backtest that tested ONLY Qwen2.5-7B/14B (17-25% W+T) plus an errored Qwen3-30B (0/0/0). No current model had ever been tested.

## The bright-line rule

**Before concluding any cheap/free/open model is inadequate, query the LIVE `/models` endpoint and current benchmarks. Your training-data intuition about model quality is STALE and will be wrong by multiple generations.**

- Live OpenRouter models: `curl -s https://openrouter.ai/api/v1/models -H "Authorization: Bearer $OPENROUTER_KEY" | jq` (filter by name)
- Our config: `/etc/litellm/config.yaml` (what's already wired)
- Our backtest harness: `/var/www/emtskills/_scripts/llm_backtest/run_4way.py` (real calls + judge → `llm_3way_backtest_summary`), auto-flip via `analyze_and_flip.py --apply` at 45% W+T gate (70% critical) per rule 121.

## CURRENT cheap/free models (verified live 2026-05-31, $/M in→out)

| Model | in | out | ctx | note |
|---|---|---|---|---|
| deepseek/deepseek-v4-pro | $0.435 | $0.87 | 1M | Sonnet-class, reasoning+tools |
| deepseek/deepseek-v4-flash | $0.098 | $0.197 | 1M | cheapest strong |
| deepseek/deepseek-v3.2 | $0.252 | $0.378 | 164k | |
| qwen/qwen3.7-max | $1.25 | $3.75 | 1M | |
| qwen/qwen3.6-plus | $0.325 | $1.95 | 1M | |
| qwen/qwen3-coder-next | $0.11 | $0.80 | 262k | agentic/coding |
| moonshotai/kimi-k2.6 | $0.684 | $3.42 | 262k | |
| moonshotai/kimi-k2.6:free | $0 | $0 | 262k | **FREE** |
| z-ai/glm-5 | $0.6 | $1.92 | 203k | |
| z-ai/glm-5.1 | $0.98 | $3.08 | 203k | |

Compare paid: claude-sonnet-4-6 $3→$15, claude-opus-4-8 $15→$75. The cheap models are 1/10 to 1/100 the price and many are genuinely Sonnet-class on narrow + mid tasks in 2026.

**This table itself goes stale.** It is a snapshot, not gospel. The RULE is "query live before judging," not "these exact prices forever." Re-pull when reasoning about model choice.

## Self-host vs hosted (2026 economics)

Self-hosting a 70B is NOT worth it below ~10-100x our volume (RunPod H200 $4.39/hr = ~$3,160/mo before training). Hosted cheap-frontier (DeepSeek-V4, Qwen3.x, Kimi, GLM-5) wins on cost at our scale. Owning a model only makes sense for data-sovereignty or very high volume. If ever self-hosting: Qwen3-32B/Coder-30B base, Unsloth QLoRA+DPO, serve via vLLM/SGLang (not Ollama) for agentic tool-calling.

## Fine-tuning (only narrow tasks, only with DPO)

We have 63K win/tie/loss pairs = native DPO format. Plain SFT (what the nightly does) throws away the 42K loss signal and trains on losses. rank-64/1-epoch LoRA is the textbook failure config. Only fine-tune small models (8-14B) for NARROW tasks (classify/extract/triage) where they can actually win; route everything else to current hosted-cheap.

## Eval gate

50-pair holdout + 0.5pp bar = unmeasurable noise (SE ±7pp). Need 200-300+ holdout + binomial significance test + multi-model judge panel before trusting a flip.

## Last updated

2026-05-31 — initial. Full research doc on server: `/var/www/emtskills/docs/llm-research/CURRENT-MODELS-AND-BACKTEST-2026-05-31.md`.

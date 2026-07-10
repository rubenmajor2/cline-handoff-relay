# 139 — Report Judge/LLM-eval cost in every task completion that ran a gate/judge

Source: 2026-06-06 Ruben directive verbatim during the Frankenstein 70B retrain watch:

> "We need to figure out a way to track this cost and put Judge task in task completion per cline rule. Something like 'Judge Cost for this Task Completion/Window: $XX.XX of $XX.XX'"

## The bright-line rule

**Any task/window that ran an LLM-as-judge / gate-eval step (Frankenstein gate, A/B grader, reward model, distill eval, or any Anthropic/OpenAI call used to SCORE another model's output) MUST include a Judge Cost line in its `attempt_completion` result, in this exact shape:**

```
Judge Cost for this Task Completion/Window: $XX.XX of $XX.XX
```

- First number = **actual** judge spend incurred this task/window (USD).
- Second number = the **budget/cap** for judge spend on this run (USD).

If no budget is defined, use the run's `JUDGE_BUDGET` default ($5.00 for Frankenstein gate) and say so. If the task ran NO judge/eval step, omit the line entirely (do not print "$0.00 of $0.00" noise).

## Why this rule exists

The Frankenstein gate (`pod_gate_eval_hf.py`) calls Claude Sonnet + Opus **directly against `api.anthropic.com`** from the RunPod, bypassing LiteLLM. So judge spend is **invisible** in `llm_call_log`, `/tmp/emsu_router_spend.jsonl`, and every EMSU dashboard — it only surfaces, untagged, in the raw Anthropic Console. Ruben had no way to see what the judging cost per training run. This rule forces the number into the one place he always reads: the task completion.

## Where the number comes from (Frankenstein gate)

The gate eval was patched 2026-06-06 to capture its own usage:
- `pod_gate_eval_hf.py` accumulates `usage.input_tokens` / `usage.output_tokens` from every judge response, prices them per a per-model table, and writes `/tmp/gate_cost_<TK>.json` + prints a `JUDGE_COST ...` line.
- `frank_retrain_code_parallel.sh` pulls `gate_cost_sonnet_<RUN_TAG>.json` + `gate_cost_opus_<RUN_TAG>.json` to `/var/www/frank_adapters/logs/`, computes the combined total, and writes `/var/www/frank_adapters/logs/JUDGE_COST_<RUN_TAG>.txt` containing:
  ```
  JUDGE_COST_TOTAL=$X.XXXX of $Y.YY :: claude-sonnet-4-...=$A.AAAA claude-opus-4-...=$B.BBBB
  ```

So to fill the completion line, `cat /var/www/frank_adapters/logs/JUDGE_COST_<RUN_TAG>.txt` (or read the per-judge JSON files) and reformat to the bright-line shape.

## How to find judge spend for OTHER eval surfaces

- If the judge routes through LiteLLM: `SELECT ROUND(SUM(cost_usd),4) FROM llm_call_log WHERE surface LIKE '%gate%' OR surface LIKE '%judge%' OR surface LIKE '%eval%' AND ts > <run_start>`.
- If it calls Anthropic/OpenAI direct (like the Frankenstein gate): the script must self-report usage to a file; read that file. Direct-to-vendor calls are NOT in `llm_call_log`.

## The durable fix (filed as proposal, not yet shipped everywhere)

Point all judge/eval scripts at the LiteLLM endpoint (`base_url=http://<wopr>:4000`) instead of `api.anthropic.com`, so judge spend lands in `llm_call_log` under a `frank_gate` surface automatically. Until that ships, the self-report-to-file mechanism above is the source of truth.

## Self-check before attempt_completion

1. Did this task/window run any LLM-as-judge / gate / eval / grader step? If no → no Judge Cost line needed.
2. If yes → did I read the actual judge spend (from `JUDGE_COST_<RUN_TAG>.txt`, the per-judge JSON, or `llm_call_log`)?
3. Did I include `Judge Cost for this Task Completion/Window: $XX.XX of $XX.XX` in the result with REAL numbers (not placeholders)?

## Cross-references

- `.clinerules/138` / `fast_train_runbook` — Frankenstein fast-train stack
- `.clinerules/91` — every completion needs a pickup prompt (this Judge Cost line sits alongside it)
- `.clinerules/29` — act on confidence (this rule shipped under a Ruben directive = rule 38 autonomous)

## Last updated

2026-06-06 — initial. Source: Ruben directive during the cline_code_turn 70B retrain. Gate eval + parallel retrain script patched same session to emit the cost; this rule makes reporting it mandatory.

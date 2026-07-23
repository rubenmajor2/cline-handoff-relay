# 171 — [DEPRECATED 2026-07-23] Honest W/T eval method (cross-family judge + position-swap + rubric + max_tokens room)

> **DEPRECATED 2026-07-23 per Ruben directive: "No W/T anymore... I do not like shadow testing. Dumb and waste of time and creates unnecessary gates."**
> W/T (win/tie) shadow-eval gates are NO LONGER required before adapter flips, model flips, or routing decisions. Do not cite this rule as a blocking gate. Flips are governed by rule 29 (act, reversible-first) + rule 140 (live-verify routing after the flip) + rule 146 (free-local-first). If a W/T-style comparison is ever run anyway, the six mitigations below remain the only honest way to do it — but running one is not a gate.


Source incident: 2026-06-29 #120b-merge-fix. The Cato merged 120B W/T gate was triple-bogus: original 5% → honest 60%. A bogus number would have triggered an unnecessary multi-hour FSDP retrain. Standardize the honest method across ALL future W/T gates (adapter flips, fleet routing, model selection).

## The bright-line rule

**Before citing a W/T number to justify a model flip, retrain, or routing decision, the eval MUST apply ALL SIX of these mitigations.** A W/T number from an eval that skips any of them is not evidence.

## The six mitigations (all required)

1. **Cross-family judge** — the judge model MUST be from a different family than the candidate AND all references. Never let a model judge its own family. (Self-preference bias, Wataoka et al. 2024, arxiv 2410.21819: LLM judges systematically over-score their own family's outputs.) Example: deepseek-v4-pro judge for a claude-refs-vs-gpt-oss-candidate comparison.
2. **Position-swap pairwise** — run each pairwise comparison TWICE with the A/B order swapped, average the verdict. Eliminates position bias (Zheng et al. 2024).
3. **Rubric judge with numeric scoring** — score explicit criteria (completeness/tone/accuracy/actionability) 1-5, parse `A_SCORE`/`B_SCORE` numerically. Do NOT use a one-word WIN/TIE/LOSE (ambiguous across judge models). Numeric parsing is robust.
4. **Strip reasoning from BOTH sides** — if the candidate gets `strip_reasoning()` (to remove chain-of-thought preamble), the reference MUST get it too. Stripping only the candidate biases the judge toward the reference's preamble.
5. **max_tokens room for reasoning models** — candidate AND reference `max_tokens` >= 2048. Reasoning models (gpt-oss, Opus-4-8, deepseek) reason for 500-2000 tokens BEFORE the answer; a 512 cap truncates them to a fragment (Opus at 512 emitted just "Ruben\nEMS University" — a 20-char signature, not an email). ALWAYS verify references produce full outputs before judging.
6. **Judge max_tokens >= 2000** for reasoning judges (deepseek reasons before scoring; 80 max_tokens returns empty).

## Also fix: enable_reasoning=False trap

For gpt-oss served on vLLM: `chat_template_kwargs={"enable_reasoning": False}` does NOT suppress reasoning — it forces the model to reason IN the content channel (since the reasoning channel is disabled), then truncate before the answer. Do NOT pass `enable_reasoning=False` for eval candidates. Let the model reason in its proper channel, then `strip_reasoning()` to extract the answer.

## Canonical template

`/var/www/frank_adapters/baseline_eval_cato_adapter_v4.py` + `run_gate_v4.sh`. Copy this as the starting point for any new W/T gate. Set `JUDGE_MODEL` to a cross-family model, `CAND_MAXTOK=4096`, `REF_MAXTOK=2048`, run via the position-swap `judge()`.

## Why "beats Opus more than Sonnet" can be a red flag

If a candidate beats a stronger reference (Opus) more than a weaker one (Sonnet), suspect a reference-truncation artifact: the stronger reasoning model reasons longer, hits the max_tokens cap, and emits a fragment — so the candidate "wins" against a degenerate reference, not a real one. Always check reference output lengths before trusting a W/T inversion. (In the Cato case, Opus at REF_MAXTOK=512 produced 20-char fragments; at 2048 it produced real 1376-char emails.)

## Cross-references

- Bug library #1381 (self-preference bias, resolved)
- Idea #15897 (standardize this method across all flips)
- Rule 140 (live-verify routing), Rule 146 (free-local-first), Rule 121 (W/T gate)

## Last updated

2026-06-29 — initial. Source: Cato merged 120B gate, 5% → 60% after applying all six mitigations.
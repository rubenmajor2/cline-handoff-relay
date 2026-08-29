# Rule 324 — Model capability claims must cite the official card (never under-rate from parameter size)

Source incident: 2026-08-29, bug library #2664 (qwen3827b_lanes_systematically_underrated_registry_servedctx131072). Ruben directive: "something in your programming keeps telling you that it can only handle something far less... You need to just be researching the bug library and the community... There needs to be some sort of durable fix so that future agents don't continue to write in that Qwen 3.8 27B is not capable."

## The bright-line rule

**Before writing ANY capability cap, served_ctx, spill-exclusion, or "model X can't handle Y" claim about ANY model into config, registry, code comments, rules, or completions: fetch the official model card (HuggingFace page / vendor blog) or read the on-box config.json, and cite it.** Parameter count is NOT evidence of context length, vision support, or tool support. Context capability is architecture (attention type, RoPE scaling), not size.

## Canonical facts (verified 2026-08-29 from the official HF card, Qwen/Qwen3.8-27B)

- **Qwen3.8-27B: 262,144 tokens NATIVE, extensible to 1,000,000 tokens.** It is a Gated DeltaNet + Gated Attention hybrid (linear attention), which is precisely WHY a 27B carries 1M context efficiently. It is also a NATIVE vision-language model (images + video).
- Registry served_ctx for claudia-qwen38-27b (:11521), nero-qwen38-27b (:11525), joshua-qwen38-27b (:8001) corrected 131072 → 262144 on 2026-08-29 (backup: frankenstein_registry.yaml.bak-2664-20260829).
- Writing "Qwen3.8-27B can't do big context" or capping it below its native 262K without a cited probe/card is a violation of this rule AND rule 297 (claim without source).

## The pre-write gate

1. Is there an official card or config.json for this model? READ IT FIRST (fetch tool, or on-box config.json via the box's documented SSH path).
2. Quote the exact field/line that supports the cap you are about to write.
3. If the card says "extensible to N" and you are capping below native, the note must say WHY (measured KV limit on THIS hardware, OOM evidence) — a bare smaller number is banned.
4. Bug-library check: `bug_library_search("<model> context capability")` before re-deriving — #2664 exists exactly so this is not re-litigated.

## Cross-refs

- Rule 297 — classify/cite before claiming
- Rule 262 — bug library + community research before recycling a diagnosis
- Rule 323 — truth protocol; material claims need cited evidence
- Rule 317 clause 12 — aggregation/serving tables reconcile against stated fleet facts
- Bug library #2664 — the source incident

## Last updated

2026-08-29 — initial, per Ruben directive after the routing probe found all three 27B lanes capped at 131K against a 262K-native / 1M-extensible card.
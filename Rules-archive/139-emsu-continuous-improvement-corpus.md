# 139 — EMSU continuous-improvement corpus (the self-improving LoRA loop): how it works + don't reinvent it

Permanent rule. Workspace-scoped. Source: 2026-06-04 Ruben directive during Project Frankenstein — after Cline wrongly claimed "the corpus is not continuous," Ruben corrected that EMSU services corpus changes by the minute with flock. He then asked to make the mechanism a durable Cline rule so future windows recognize it instead of re-discovering (or re-building) it.

## The one-line truth

**EMSU already has a continuous, flock-guarded, quality-gated, auto-reverting self-improvement loop for the 7B-LoRA, built on the `emsu_preference_corpus` table. Before building ANY "make the model continuously better" mechanism, reuse THIS loop. Do not stand up a parallel one.**

## The loop (verified components, 2026-06-04)

| Stage | Concrete thing | Cadence |
|---|---|---|
| Source of truth | `emsu_preference_corpus` table (admin_portal) — ~37k rows, grows continuously | live |
| Realtime ingest | `cron/cron_emsu_corpus_realtime_ingest.php` → `CorpusRealtimeIngester::runAll()` (harvests handoffs, clinerules, ideas, qcards, corrections; watermark-gated; INSERT-IGNORE `(source_table, source_pk)` dedup; cap 50 rows/kind/tick) | every 5 min |
| Embedding | `cron/cron_fleet_corpus_embed_watchdog.php` + `scripts/embed_emsu_preference_corpus_v2.php`, BOTH flock on `/tmp/emsu_corpus_embed.lock` (OpenAI text-embedding-3-small). "Behaves continuous without daemon fragility." | every 1 min |
| Prune | `cron/cron_fleet_corpus_prune_watchdog.php`, flock `/tmp/emsu_corpus_prune.lock` (dedup newest-per-content, age-prune low-value kinds) | hourly |
| Train + promote | `scripts/cron_lora_nightly_refresh.php` — corpus-delta gate (skip if <500 new pairs), RunPod SFT, 50-pair never-seen holdout eval, promote ONLY if W+T ≥ `LORA_PROMOTE_MARGIN_PP` (0.5pp), `ollama create` on Joshua/Artemis | nightly 02:00 PT |
| Safety watchdog | same script `--watchdog` — re-evals 60 min after a swap; AUTO-REVERTS to prior adapter if W+T drops > `LORA_WATCHDOG_DROP_PP` (2.0pp) within `LORA_WATCHDOG_WINDOW_MIN` (60) | 14:00 + every 30 min |

Kill switches live in `orchestrator_config` (`fleet_corpus_prune_watchdog_enabled`, etc.).

## The flock pattern (why "by the minute" is safe without a daemon)

Every-minute crons wrap the worker in `flock -n /tmp/<name>.lock`. If the prior tick is still running, the new tick exits 0 immediately (no stacking, no daemon to crash/restart). This is the canonical EMSU pattern for "continuous-feeling" work. When you need continuous behavior, reach for an every-minute flock-guarded cron, NOT a long-lived daemon. (Cross-ref the KAIZEN recipe `cron_no_flock_stacking`.)

## The non-negotiable safety shape for ANY self-improvement loop

If you build or extend a continuous-improvement loop (e.g. extending it to the 70B Frankenstein experts, idea #9728), it MUST have all four or it is unsafe:

1. **A held-out eval** the candidate never trained on (group-split, zero leakage).
2. **A promote gate** — only swap in the new model if it beats the incumbent by a margin (≥0.5pp W+T), never "newer = better."
3. **A post-swap watchdog with auto-revert** — re-eval shortly after promotion; roll back automatically on regression (>2pp/60min).
4. **A training-data quality filter** — the corpus imitates whatever was shipped. If past shipped outputs contained a failure mode (e.g. the Frankenstein head-fabrication: "payment confirmed / balance zero" with no lookup), continuous training AMPLIFIES it. Filter those outputs BEFORE they enter the training set. An inference-time prompt clause does NOT clean training data; the filter must run at corpus-build time.

Point 4 is the one most likely to be skipped and the most dangerous: a loop without it gets continuously *worse* in a way that looks like "it's learning."

## Two corpora, do not confuse them

- `emsu_preference_corpus` → feeds the **7B-LoRA** (the continuous loop above). Live.
- `_scripts/frankenstein/distill_corpus.jsonl` (via `build_distill_corpus.py`) → feeds the **70B Frankenstein** experts. As of 2026-06-04 this is ONE-SHOT, not continuous — that gap is idea #9728 (give the 70B the same loop, ideally by drawing from `emsu_preference_corpus` too).

## Self-check

Before writing any "continuously retrain / auto-improve the model" code, ask:
1. *Does the `emsu_preference_corpus` loop already do this?* If yes, extend it, don't fork it (rule 92).
2. *Does my loop have all four safety components (held-out eval, promote gate, auto-revert watchdog, training-data filter)?* If any is missing, it is unsafe — add it before enabling.
3. *Am I about to build a daemon for "continuous" work?* Use an every-minute flock-guarded cron instead.

## Cross-references

- `.clinerules/23` — KAIZEN (the failure-classifier self-improvement loop; complementary, classifier-layer not model-layer)
- `.clinerules/92` — work at the core / reuse, don't reinvent
- `.clinerules/40` + `.clinerules/50` — Artemis/Ollama-first + RAG-augmented prompts (consumers of the trained model + corpus)
- `.clinerules/87` — fleet-agent opportunity-cost math
- idea #9728 — extend this loop to the 70B Frankenstein experts
- `scripts/cron_lora_nightly_refresh.php` — the reference implementation to copy

## Last updated

2026-06-04 — initial. Source: Ruben directive in the Project Frankenstein thread. Cline under-researched and claimed the corpus was not continuous; it is (7B loop, flock, by the minute). This rule makes the mechanism durable so future windows reuse it instead of re-discovering or duplicating it, and codifies the four-part safety shape any self-improvement loop must have.

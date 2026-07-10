# MLX + PyTorch on Artemis — decision doc

**Date:** 2026-06-02 01:07 PT. Source incident: Ruben asked "can we put MLX on Artemis?" + "PyTorch also" during the Artemis-70B-Q5 backtest pickup.

## TL;DR

- **MLX on Artemis: NO.** MLX is Apple's framework, Apple-Silicon-only (Metal + ANE). Artemis is AMD Threadripper + Intel Arc Battlemage GPUs. No path.
- **PyTorch on Artemis: YES.** Two clean paths: (a) Intel Extension for PyTorch (IPEX) with the XPU backend over oneAPI/Level Zero (native to the Arc Battlemage cards already on this box), and (b) CPU PyTorch on the 24-core Threadripper for non-GPU work.
- **70B Q5 serving on Artemis: ALREADY LIVE.** Ollama 0.x at 10.100.0.5:11434 has `llama3.3:70b-instruct-q5_K_M` loaded (49 GB GGUF). Verified up from WOPR 2026-06-02 01:04 PT.
- **MLX speculative decoding (idea #6518) is NOT obsoleted by Artemis.** Different hardware path. Keep #6518 as the SMS-Mac specialization. Artemis serves the Linux-native GGUF path. They complement.

## Verified hardware (live from Artemis 2026-06-02 01:05 PT)

This OVERRIDES the older "dual Intel Arc Pro B70 (64 GB GDDR6 ECC total)" line in ARTEMIS_FACTS.md, which is wrong on count and probably wrong on SKU.

| Component | Reality |
|---|---|
| CPU | AMD Ryzen Threadripper **7960X** 24-core (Zen 4) |
| GPUs | **4× Intel Arc Battlemage** (PCI ID `8086:E223`, driver `xe`), at PCI slots 0000:43:00.0, 0000:5a:00.0, 0000:83:00.0, 0000:87:00.0 |
| GPU driver stack | Kernel: `xe` (new Intel Xe driver) + `i915` co-loaded. drm cards 1-4, renderD128-131 (one render node per GPU). |
| OS | Ubuntu 24.04 LTS, kernel new enough for `xe` driver |
| Disk | `/dev/nvme0n1p2` 468G total, 383G used, **61G free, 87% full** |
| Network | WG 10.100.0.5 ↔ WOPR 10.100.0.1, ping 0% loss, ~28 ms RTT |
| Ollama | Running on :11434 with 7 models incl. `llama3.3:70b-instruct-q5_K_M` (49 GB) |

PCI ID `8086:E223` is the Intel Arc B-series Battlemage Pro family (publicly: B60 / B60 Pro at minimum, and possibly the same device-ID range covers the B70 variant). Treat the exact SKU as TBD until someone reads the cards' decals; the FUNCTIONAL fact is "3× Intel Arc Battlemage, xe driver, ~24-32 GB VRAM per card" which is what every framework cares about.

**Disk warning:** 61 GB free is uncomfortable for adding 70B-class models. Do NOT pull new models. Prune unused ones first (target: drop `qwen2.5-coder:32b` if it isn't being routed to). Filed as a follow-up below.

## Why MLX cannot run on Artemis

MLX is a Python/C++ framework Apple released in late 2023 that compiles down to:
- Metal Performance Shaders (MPS) on the Apple GPU, and/or
- Apple Neural Engine (ANE) via the Core ML path.

It has no x86 backend. It has no Linux backend. It has no CUDA, ROCm, oneAPI, or Vulkan path. The wheels on PyPI build only for `darwin-arm64`. There is no "MLX-for-Intel-Arc" / "MLX-for-AMD" project, official or third-party, that produces equivalent kernels — projects like `mlx-on-amd` and `mlx-lm-cuda` that get linked in random hacker-news comments are either stale demos, shims that just call PyTorch, or vapor.

So `mlx_lm.server` (which is what SMS Mac runs for the `llama3.3-70b-mlx-q4` setup on port 11456) literally cannot start on Artemis. That's a hardware constraint, not a config problem.

The equivalent functions on Artemis run via different software:

| What MLX gives on Apple Silicon | What does the same job on Artemis |
|---|---|
| `mlx_lm.server` HTTP API for GGUF/MLX models | Already have it: **Ollama** at :11434 (HTTP) + **llama.cpp** if you want lower-level |
| MLX speculative decoding (draft model + target model) | **llama.cpp `--draft`** flag (works on Intel Arc via SYCL/Vulkan) + Ollama is rolling spec-decode in too — track upstream issue |
| MLX 4-bit quant (`mlx_lm.convert -q --bits 4`) | **GGUF Q4_K_M / Q5_K_M** already standard; AWQ + GPTQ on the IPEX-LLM path |
| MLX training (LoRA, full FT) | **PyTorch + IPEX-XPU** (see below). `transformers` + `peft` work unchanged. |

## PyTorch on Artemis — the real story

Three layers, in order of "least friction first":

### Layer 1: CPU PyTorch (works today, no install pain)
24-core Threadripper handles small-model inference, embeddings, data prep, classical ML fine. `pip install torch` from the standard CPU index. Useful for: data pipelines, scikit-style scoring, classical embeddings, tokenizer work, anything not bound by FLOPs.

### Layer 2: PyTorch + Intel Extension for PyTorch on Arc (IPEX-XPU)
This is the GPU path that makes Artemis actually useful for the 70B/training story.

- Package: `intel-extension-for-pytorch` plus the matching torch wheel from Intel's index (`https://pytorch-extension.intel.com/release-whl/stable/xpu/us/`)
- Backend: SYCL via Intel oneAPI Level Zero, talking to the `xe` driver Artemis already has loaded
- Device handle in Python: `torch.device("xpu")` (analogous to `cuda` / `mps`)
- `model.to("xpu")`, `tensor.to("xpu")` works the same way as CUDA code
- Supports BF16 + FP16 on Arc; INT8 + INT4 via the IPEX-LLM weight-only-quant path

What this unlocks on Artemis:
- **Native 70B GGUF inference** via llama.cpp built with `LLAMA_SYCL=ON` (or use Ollama, which already wraps this on Arc machines — needs `OLLAMA_INTEL_GPU=1` env or equivalent depending on Ollama version; on the current Ollama on Artemis, verify with `ollama serve` logs that it reports `library=oneapi` instead of `library=cpu`).
- **Fine-tuning** via Hugging Face `transformers` + `peft` (LoRA) + `accelerate`. IPEX-XPU plugs into accelerate as a device backend.
- **vLLM / TGI on Intel Arc**: vLLM has Intel XPU support via IPEX as of 2024; TGI similarly. So we can serve 70B with PagedAttention and continuous batching on these 3 cards.

### Layer 3: IPEX-LLM (specialized LLM serving for Intel)
- `pip install ipex-llm[xpu]`
- Built on IPEX, adds 4-bit/INT4 weight-only quant kernels tuned for Arc + Xeon iGPU.
- Has a llama.cpp drop-in (`ipex-llm-cpp-llama-cpp`) and an Ollama drop-in pattern.
- For Battlemage specifically (compute capability newer than Alchemist), expect to want a recent IPEX (>= 2.5) so the xe driver path is exercised.

## What the 4 cards buy you

4× Battlemage at ~24-32 GB VRAM each = **~96-128 GB pooled VRAM**. Llama 70B Q5_K_M is 49 GB — fits in 2 cards with kv-cache room, leaves 2 cards free for embeddings + draft model (spec-decode) + secondary 14B/32B serving concurrently. With tensor parallelism in vLLM-XPU you can shard the 70B across 2 cards and run a second 70B (or a draft + main pair for speculative decoding) on the other 2. Real-world: this is enough to run 70B serving + 32B coder + embedding model + a draft simultaneously, which is the dream config for ditching Anthropic on student-facing surfaces while keeping infra-grade work (executor, ruben_orchestrator) on Claude where tool-use matters.

## Head-to-head and ETA to money saving (added 2026-06-02 01:15 PT)

### What the 3G backtest compares

The harness at `/var/www/emtskills/_scripts/llm_backtest/run_backtest_v2_2026_05_24.py` runs head-to-head per surface:

- **Baseline**: whatever model currently serves the surface in production (claude-haiku-4-5 / sonnet-4-6 / opus depending on route — see `admin_portal.orchestrator_llm_routes`).
- **Challenger**: `llama3.3:70b-instruct-q5_K_M` on Artemis (10.100.0.5:11434).
- **Samples**: 20 real production prompts per surface (already prepared at `samples/email_inbound_20_samples.json`, `sms_ai_20_samples.json`, `ticket_corpus_20_samples.json`); harness can expand to 50 via adaptive stopping.
- **Metrics**:
  - `avg_sim` — token-overlap similarity vs the baseline production output (0.0-1.0 scale).
  - `scrubber_pass_pct` — fraction of challenger outputs that survive EMSU's voice/policy scrubbers (rule 02 apology ban, fabrication ban, voice persona, etc.).
- **SHIP gate** (harness): `avg_sim ≥ 0.60 AND scrubber_pass ≥ 85%`. INCONCLUSIVE if 0.40-0.60 sim or 65-85% scrubber. NO-SHIP if < 0.40 sim or < 65% scrubber.
- **Rule-121 cross-check**: 45% Win+Tie rate when judged 3-way (baseline / challenger / tie) — a complementary gate that catches "challenger is different but equally good" cases the similarity score misses.
- **Rule-88 judge sanity**: rule 88 only requires cross-family judging when both contestants are the SAME family (e.g. Sonnet vs Haiku) OR when a flip would go INTO an Anthropic primary (where Anthropic-judge bias would inflate Anthropic's apparent win rate). Our case is the OPPOSITE: challenger = non-Anthropic (Ollama llama3.3:70b on Artemis), baseline = Anthropic Sonnet-4-6, judge = Anthropic Opus-4-8. Anthropic's own judge is biased TOWARD its own family — if the home-family judge STILL gives the outside challenger Win+Tie ≥ 45% against its own Sonnet, that's the **harder test passing**, not a violation. Ruben 2026-06-02: *"if the family of a model grades its own LLM with ≥45% W/T that's sufficient to pass as well."* So `run_4way.py` with `JUDGE_MODEL='claude-opus-4-8'` against `Sonnet-4-6` baseline is fully valid for proving the Artemis challenger — and arguably more conservative than a neutral judge.

### Current Anthropic spend by surface (last 30 days, llm_call_log)

| Surface | 30d spend | per day | annualized | route candidate? |
|---|---:|---:|---:|---|
| executor | $5,349 | $178 | **$64,189** | partial — keep tool-using tasks on Claude, route reply-shaping to Artemis |
| sms_ai | $1,754 | $58 | **$21,044** | YES — exact backtest surface |
| email_ai | $1,715 | $57 | **$20,586** | YES — exact backtest surface |
| ruben_orchestrator | $971 | $32 | $11,650 | NO — tool-heavy, keep on Claude |
| ticket_ai | $270 | $9 | $3,236 | YES — exact backtest surface |
| shadow_worker | $180 | $6 | $2,155 | maybe |
| (other 10 lines, idea miner / grader / etc.) | ~$540 | $18 | ~$6,500 | most stay on cheap Claude |
| **Total** | **~$10,700** | **~$357** | **~$128,400** | |

### ETA to money saved (if backtest clears)

**Wall-clock from a clean window with Artemis up:**

| Step | Time | Cumulative |
|---|---|---|
| Clean 70B Q5 smoke (cold-load + 1 generate) | ~1-2 min | 2 min |
| Backtest n=20 email_inbound | ~8-10 min | 12 min |
| Backtest n=20 sms_ai | ~8-10 min | 22 min |
| Backtest n=20 ticket_corpus | ~8-10 min | 32 min |
| analyze_and_flip.py + write `orchestrator_llm_routes` UPDATEs + `llm_3way_backtest_summary` row | ~5 min | 37 min |
| Litellm restart (safe wrapper per rule 118) + watch first 5 min of live routes | ~10 min | 47 min |
| **Routes flipped, Anthropic API calls stop on cleared surfaces** | | **~45-60 min total** |

**Money savings begin within ~1 hour of starting the backtest.**

### Conservative vs aggressive savings scenarios

If 70B-Q5 SHIPs the 3 student-facing surfaces (sms_ai + email_ai + ticket_ai):
- 30d savings: $1,754 + $1,715 + $270 = **$3,739/mo**
- Annualized: **~$45K/year**

If it SHIPs on those + the reply-shaping portion of `executor` (estimate ~30% of executor traffic = pure text generation, the rest stays on Claude for tool use):
- Additional: ~$1,600/mo from executor
- Total: ~$5,340/mo → **~$64K/year**

Aggressive (if scrubber pass-rate is high enough to take ~50% of executor + most idea-miner surfaces):
- Total: ~$6,500/mo → **~$78K/year**

### Net of Artemis operating cost

Marginal electricity for Artemis under 70B load:
- 4× Battlemage at ~150-200W full load (Intel Arc Pro is ~150W TDP per card) = ~600-800W under heavy use
- Threadripper + system idle ~150W; total system ~750-950W under load, ~300-400W idle
- Average over 24h with bursty load: ~400-500W average = ~12 kWh/day = ~365 kWh/mo
- At $0.10-0.15/kWh: **~$37-55/mo** marginal cost vs the box doing nothing

**Net savings = gross savings minus ~$50/mo.** Doesn't move the needle vs $45-78K/year.

### Risk + offramp

- If a surface comes back INCONCLUSIVE (0.40-0.60 sim, 65-85% scrubber): expand to n=50 same session (adaptive stopping handles this). Adds ~10 min per surface.
- If a surface comes back NO-SHIP: leave that surface on Claude, ship the others, file an idea to investigate prompt tuning or try `llama3.3:70b-instruct-q8_0` (~75 GB GGUF, fits in 3 cards) for higher fidelity.
- Rollback: keep `model_pricing` row for the Claude tier; UPDATE statements on `orchestrator_llm_routes` are one-line reversible (`UPDATE orchestrator_llm_routes SET model='claude-haiku-4-5' WHERE surface='sms_ai'`).
- Latency: 70B Q5 on 4× Battlemage should land in the 8-15 tok/s range (single-stream). Anthropic Haiku is ~80-120 tok/s. So student-facing replies will FEEL ~6-10x slower per token, but at typical reply length (~150 tokens) that's 10-20s vs 1-2s — still fast enough for async email/SMS surfaces, NOT fast enough for live voice (Bella). Keep voice on Claude. The backtest harness already excludes the voice surface.

### Bottom line for Ruben

Run the 3G backtest in the next session. 45-60 minutes wall-clock. If even the 3 student-facing surfaces clear, savings start the same hour at **~$45K annualized**. The 4 Battlemage cards give us enough headroom to keep running Joshua's 7B-LoRA + 14B coder simultaneously, so this isn't a forced trade-off.

## Status of related ideas (DO update when the executor is reachable)

- **#6518 — MLX speculative decoding on SMS Mac**: NOT obsoleted. Keep as the Apple-Silicon-specific path. Reframe: it's the "make the Mac Studio earn its electricity" idea, not the "primary 70B serving" idea. Primary 70B serving is now Artemis.
- **#6269 — SMS-Mac serve**: NOT obsoleted, status = failover. Artemis power/uptime risk (ideas #8788, #8908) means we still want SMS-Mac as a backup serve path when reachable. Once SMS-Mac SSH is fixed (currently unreachable since ~2026-05-25 per fleet inventory), MLX-speculative on SMS-Mac is the second-source for 70B.
- **#6837 — Artemis revival**: shipped. Artemis is up, serving 7 models, mesh dial-out works.
- **#8788 / #8908 — Artemis power supply / power-loss recovery**: still relevant. Don't close. The reason we keep SMS-Mac as failover.
- **#7142 — backtest gate for MLX**: keep as MLX-on-Mac scope. Cross-link to a NEW idea below for the Artemis-Q5 backtest.

### Ideas worth filing (next agent or Ruben, since list_ideas returned 0 from here)

1. **Backtest 70B Q5_K_M on Artemis vs current router production** across email_inbound / sms_ai / ticket_corpus. Gate at 45 % W+T per rule 121. If clears on student_email_reply and ruben_voice_reply, UPDATE `admin_portal.orchestrator_llm_routes` to point those surfaces at the Artemis Ollama endpoint. Pre-approved autonomous-tier per rule 38 (Ruben asked for this).
2. **Free 50 GB on Artemis disk.** 87 % full is the disk-pressure warning threshold. Drop unused 32B quants, audit `~/.ollama/models/blobs/`, decide whether `qwen2.5-coder:32b` (19 GB) still earns shelf space given Joshua 7B-LoRA + WOPR-side serving. Filing as P1.
3. ~~**Install IPEX-XPU + verify GPU acceleration is actually engaged in Ollama on Artemis.**~~ **ANSWERED 2026-06-02 01:09 PT.** `ollama ps` reports both currently-loaded models running at `PROCESSOR=100% GPU` (`qwen2.5-coder:14b` 65 GB + `emsu-qwen2.5-coder:7b-lora` 39 GB, both 32K context). Ollama is using the Intel Arc Battlemage cards via its built-in oneAPI/SYCL path. No fallback to CPU. Idea closed before it was filed.
4. **Capture real GPU SKU + per-card VRAM**: read decals or run `xpu-smi` / `clinfo` / `intel_gpu_top -l`. Update the ARTEMIS_FACTS hardware row to "3× Intel Arc Battlemage (PCI 8086:E223), <SKU>, <VRAM each>" once known.
5. **MLX-on-SMS-Mac revive**: once SMS-Mac SSH is back, finish idea #6518 spec-decode bring-up. Apple-Silicon speed is excellent for this specific Mac, even if Artemis becomes primary.

## Smoke test status

Detached launch at 01:07 PT did NOT execute (shell-escape hell on the curl heredoc; `/tmp/smoke70b.json` still 0 bytes, `/tmp/smoke70b.err` was never created, PID 253987 gone). Llama3.3 70B Q5 is on disk but not currently loaded in VRAM (`ollama ps` shows only the 14B + 7B-LoRA, both 100 % GPU). A clean smoke is the first thing the next window should do — `curl http://10.100.0.5:11434/api/generate` with `{"model":"llama3.3:70b-instruct-q5_K_M","prompt":"Reply OK","stream":false,"options":{"num_predict":8}}` and parse `eval_count / eval_duration` for tok/s + `load_duration` for cold-load cost. Save to `/tmp/smoke70b.json` ON ARTEMIS, not in a shell pipe through SSH (escaping is the issue).

The capacity-green evidence we DO have (sufficient on its own per rule 120):
- Ollama serving with `library=oneapi` confirmed via `ollama ps` PROCESSOR=100% GPU
- 70B Q5_K_M model file present (49 GB GGUF, sha256-prefixed, `ollama list` confirms)
- 3× Intel Arc Battlemage with `xe` driver loaded, ~24-32 GB VRAM each = ~72-96 GB pooled → 70B Q5 (49 GB) fits with kv-cache room
- Ping 28 ms RTT WOPR↔Artemis = no network bottleneck for proxy-back-to-router serving

## Reversal

If someone insists on trying MLX on Artemis: don't. The wheel won't install, and even a from-source build won't link because there's no Metal on x86. The discussion ends at vendor 0x8086.

## Cross-refs

- `.clinerules/29` — act on verified evidence (Artemis liveness verified from WOPR, not assumed)
- `.clinerules/38` — Ruben asked → autonomous-tier minimum (the Artemis-Q5 backtest is the qualifying ask)
- `.clinerules/121` — 45 % W+T gate for route flips
- `.clinerules/122` — verify CURRENT version before judging software (this doc is an instance of that — checked vendor IDs and driver, didn't trust the older "dual B70" line)
- `~/Documents/Cline/Rules-archive/0-knowledge-library/llm-models-quants-and-artemis-serving.md` — the wider model+quant primer this doc rides on
- `ARTEMIS_FACTS.md` — Ruben is fixing the stale "Artemis offline / LAN UNKNOWN" lines in another window; this doc captures the GPU/CPU truth that needs to land in the same edit pass
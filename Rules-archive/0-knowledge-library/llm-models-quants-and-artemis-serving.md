# LLM Models, GGUF Quants, and Serving on Artemis (EMSU reference)

Knowledge library entry. Workspace scope: EMSU LLM stack — Artemis Ollama host (10.100.0.5:11434), the LiteLLM router, and the 3G model-adoption pipeline.
Author audience: Cline main, Fleet Agent, future subagents deciding which model/quant to pull, serve, or route.
Last researched: 2026-06-01 (live web + subagent research + live Artemis inspection). Sources linked inline.

This is the thing you reach for before pulling a new model, choosing a quant, or
deciding whether Artemis can serve something. Do not re-do the research. Read this,
then act. Pairs with `ollama-fleet-troubleshooting.md` (operational/503 issues) and
`lora-scale-up-strategies.md` (training). Governed by .clinerules/120 (3G all-greens)
and .clinerules/121 (45% W+T flip gate).

---

## 1. Artemis hardware reality (verified 2026-06-01)

| Property | Value |
|---|---|
| GPUs | **4× Intel Arc Battlemage (BMG G31)** — NOT NVIDIA, NOT AMD |
| Backend | **Vulkan** via the Intel open-source **Mesa (ANV)** driver. No CUDA, no ROCm. `nvidia-smi` / `rocm-smi` do not exist on this box. |
| System RAM | 125 GB |
| Disk | 468 GB NVMe (`/dev/nvme0n1p2`). Keep an eye on it — a single 70B Q5 is ~49 GB. |
| OS | Ubuntu 24.04.4 LTS, kernel 6.17 |
| Ollama | 0.22.1 (binary `/usr/local/bin/ollama`), systemd unit `ollama.service`, `OLLAMA_HOST=0.0.0.0:11434` |
| Service tuning | `OLLAMA_KEEP_ALIVE=24h`, `OLLAMA_MAX_LOADED_MODELS=4`, `OLLAMA_NUM_PARALLEL=1`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`, `OLLAMA_LOAD_TIMEOUT=15m` |

**It already runs a 32B Q4 (19 GB) + a 14B simultaneously at "100% GPU."** That means it
has the VRAM/RAM headroom to also host a 70B (Q4 ~42 GB / Q5 ~49 GB). This is the key fact:
Artemis can be a **local, always-on, $0 70B endpoint** — which is what the entire
RunPod/SMS-Mac-tunnel/MLX-speculative-decoding saga (ideas #6269, #6485, #6518) was
trying to achieve elsewhere.

### Intel Arc backend choice (Vulkan vs SYCL/ipex-llm) — settled mid-2026

- **ipex-llm is effectively dead.** Intel's `ipex-llm[cpp]` Ollama fork stalled (last build ~Ollama 0.9.3, July 2025). Do not build new infra on it. (r/IntelArc, 2026)
- **Mainline Ollama now has Vulkan support** (merged late 2025/early 2026). That is what Artemis uses, and it is the correct, maintained path for Battlemage. (r/IntelArc "Ollama now has Vulkan support", 2026)
- **SYCL (via llama.cpp) is faster but higher-friction** — requires compiling inside an Intel XPU/oneAPI container. Worth it only if Vulkan tok/s proves inadequate for the 70B. (r/LocalLLaMA, 2026)
- **Caveat:** on some specific Intel parts Vulkan has underperformed ipex-llm/CPU. Battlemage discrete (B70/B60/B50, G31) is the well-supported case; Lunar Lake iGPUs are the problem children. Artemis is discrete G31 → the good case.
- **Multi-GPU:** Ollama/llama.cpp can split one model across multiple Arc GPUs OR run one-model-per-GPU. Multi-GPU Arc has documented "uses all system RAM" pitfalls on llama.cpp SYCL — verify VRAM actually engages (not RAM fallback) when serving the 70B. Real Battlemage G31 benchmark (Arc Pro B70, 32GB, Vulkan/Mesa, `--n-gpu-layers 99 --flash-attn 1`) confirms flash-attn works on this backend.
- **vs H100:** a single NVIDIA H100 still beats a 4× Arc box on raw 70B throughput and on software maturity. Arc's win is **acquisition cost + $0 ongoing** vs RunPod/cloud. For EMSU's batch/async surfaces (email, SMS, ticket triage) latency tolerance is high, so the tradeoff favors Arc.

**Action note:** when serving the 70B Q5 on Artemis, confirm tok/s on a real prompt and log it as the **capacity-green** evidence per rule 120. If Vulkan tok/s is too slow, the escalation path is a SYCL llama.cpp build, NOT ipex-llm.

---

## 2. GGUF quant reference (70B-class model)

Eff. bits, file size, quality loss vs FP16, and VRAM to serve a 70B. Sources: llama.cpp
k-quants/IQ-quant PRs (#1684, #4861), bartowski/mradermacher HF GGUF cards, PPL benchmark threads.

| Format | eff. bits/wt | 70B file size | PPL increase vs FP16 | VRAM to serve 70B |
|---|---|---|---|---|
| Q8_0 | ~8.5 | ~70–75 GB | negligible (~0.001–0.005) | ~80 GB |
| Q6_K | ~6.56 | ~54–58 GB | very small (~0.005–0.01) | ~64 GB |
| **Q5_K_M** | **~5.6** | **~48–50 GB** | **small (~0.01–0.03)** | **~56–64 GB** |
| Q5_K_S | ~5.5 | ~47–48 GB | slightly worse than K_M | ~56 GB |
| **Q4_K_M** | **~4.8** | **~40–43 GB** | **moderate (~0.03–0.08)** | **~48 GB** |
| IQ4_XS | ~4.25 | ~37–38 GB | ≈ Q4_K_S at smaller size | ~44 GB |
| IQ3_M | ~3.5 | ~30–34 GB | noticeable (~0.1–0.3) | ~38–40 GB |

### Q4_K_M vs Q5_K_M — the EMSU-relevant tradeoff

- **Q5_K_M recovers most of the Q4→FP16 quality gap** for ~7 GB more on a 70B (~49 GB vs ~42 GB) and a small (~10–15%) throughput cost.
- **For a quality-REPLACEMENT play** (the 70B is trying to stand in for paid Claude on customer-facing email/voice), Q5_K_M is the right default: Q4_K_M's larger PPL bump shows up exactly as subtle wording/factual slips on the surfaces where we need it to clear the rule-121 quality gate. Q4 is the "fits anywhere cheap" quant; Q5 is the "actually trying to match a frontier model" quant.
- **Ruben directive 2026-06-01: use Q5_K_M for the Artemis 70B.** Matches idea #6518's named Q5_K_M target. Artemis has the headroom, so there's no fit penalty for the better quant.
- Only drop to Q4_K_M / IQ4_XS if VRAM or disk forces it. Don't go below Q4 for a quality-replacement model.

---

## 3. Open-weight model landscape (mid-2026, live-verified 2026-06-01)

Sources: HuggingFace open-source-LLM blogs (daya-shankar), ComputingForGeeks 2026 comparison, codersera "Best Open-Source LLM May 2026", MindStudio agentic-coding 2026, onyx self-hosted leaderboard.

| Model | ~Params | License | On Ollama | Notable |
|---|---|---|---|---|
| **Llama 4** (Scout / Maverick) | MoE | Llama 4 Community | Yes | Long context; Scout for long-ctx if you have serious hardware |
| **Llama 3.3 70B Instruct** | 70B | Llama 3.3 Community (commercial OK) | Yes (`llama3.3`) | Strong, safe default for email replies. EMSU's current 70B target. |
| **Qwen3 / Qwen3.6 / Qwen3-Coder** | 27B–72B+ | **Apache 2.0** (commercial-safe) | Yes | Recommended default local family 2026. Coder variant strong for ops. |
| **DeepSeek V4** (Flash / Pro) | MoE (large) | DeepSeek (commercial OK) | Partial | Top agentic-coding tier; Flash = cheap, Pro = high-end. Needs serious infra for full weights. |
| **GLM-5 / GLM-5.1** | large | open | Partial | Strong coding/agents, permissive |
| **Kimi K2.6** | large MoE | open | Partial | Top agentic-coding, heavy |
| **Gemma 4** (e.g. 31B) | up to ~31B | Gemma (commercial OK) | Yes | Strong single-GPU multimodal; speculative decoding support |
| **Mistral Small 4 / Medium 3.5** | 24B / mid | Apache 2.0 (Small) | Yes (Small) | Permissive, efficient |
| **Phi-4 / Phi-4-mini** | small | MIT | Yes | Weak-hardware fallback |
| **gpt-oss** | — | Apache 2.0 | Yes | OpenAI open reasoning models |

### Recommendation for EMSU's "self-host ~70B to replace paid Claude on email/voice" goal

1. **Llama 3.3 70B Q5_K_M** — the current pick. Safe license, strong instruction-following, fits Artemis, well-understood. This is what's being pulled now. Backtest it first.
2. **Qwen3 ~72B (or Qwen3.6)** — strongest Apache-2.0 alternative if Llama 3.3 underperforms on the 3G gate. No license ambiguity. Worth a parallel backtest.
3. **Gemma 4 31B Q5_K_M** — if the 70B is too slow on Vulkan, a 31B is far faster and Gemma 4 punches above its size; viable fallback for the high-volume cheap surfaces.

**Note on the EMSU cloud-cheap routes already live (2026-05-31 3G backtest):** the cloud
challengers `qwen3.6-plus` and `glm-5` already clear the 45% gate and are flipped in for
`ticket_triage` (92.7% W+T), `plan_summary`, `classify`. A local 70B does NOT need to beat
those — it needs to clear 45% on `student_email_reply` / `ruben_voice_reply` at $0 to keep
that traffic off paid APIs. That's the bar.

---

## 4. EMSU LLM stack wiring (where models actually plug in)

- **Router config:** `~/Documents/Cline/cline-router/config.yaml` (LiteLLM). Artemis 7b-lora is PRIMARY at `http://10.100.0.5:11434` (`stream:false` so the quality-gate hook runs). SMS-Mac (`192.168.1.55:11434`) is FALLBACK.
- **Route table (DB):** `admin_portal.orchestrator_llm_routes` — `task_kind` → primary/shadow. Flip via single UPDATE (reversible). Backups exist (`orchestrator_llm_routes_backup_*`).
- **Usage log:** `admin_portal.llm_call_log` (cols: `ts, provider, model, surface, duration_ms, input_tokens, output_tokens, cost_usd`). Local provider rows = `$0`.
- **3G backtest harness:** `/var/www/emtskills/_scripts/llm_backtest/` — `run_4way.py` (current-models real-prod-replay), `run_backtest_v2_2026_05_24.py` (single-model vs opus, ollama-based), `analyze_and_flip.py` (auto-flips routes at the rule-121 gate), `samples/` (staged real prod rows w/ opus replies embedded), `results/`.
- **Pricing:** `admin_portal.model_pricing` (Opus $15/$75, Sonnet $3/$15, Haiku $1/$5 per Mtok). Local = $0 (electricity only).
- **Dashboards:** `routes/lora_fleet.php` (MasterAdmin), `cron_lora_fleet_collector.php` (collector).

### How to backtest a local model on Artemis (the $0, no-RunPod path)
```bash
cd /var/www/emtskills/_scripts/llm_backtest
OLLAMA_URL=http://10.100.0.5:11434/api/generate \
LLAMA_MODEL=llama3.3:70b-instruct-q5_K_M \
python3 run_backtest_v2_2026_05_24.py \
  --input-json samples/email_inbound_20_samples.json \
  --surface email_inbound \
  --out results/backtest_70b_q5_email_$(date +%F).md
# repeat for sms_ai / ticket_corpus surfaces, then read results/, then flip per rule 120/121 if it clears 45% W+T.
```

---

## 5. The 70B program context (why this model matters)

- **#6485** — backtest llama3.3:70b vs Opus on real prod samples (prep done; was blocked on RunPod orchestration).
- **#6269** — retrofit SMS-Mac to serve the 70B. **May be obsoleted by Artemis serving it locally.**
- **#6518** — MLX-LM + Q5_K_M + speculative decoding to make 70B fast/cheap. Named the Q5_K_M target. **May be obsoleted by Artemis Vulkan serving.**
- **#6522 / #7734** — 70B LoRA *training* (separate from inference). **PAUSED** after ~$2K burned on multi-GPU FSDP failures (unsloth single-process can't do 4×H100 PCIe; needs FSDP/DeepSpeed rewrite). See `docs/70B_LORA_GPU_FLOOR.md`.
- **"70B failed on Artemis" is a stale myth:** the 2026-05-26 pilot scorecard shows the 70B was meant to run via the SMS-Mac tunnel (WOPR:11455); that tunnel broke 2026-05-25, the run fell back to a 32B proxy and scored 0% **SKIPPED** (not a real eval). Do not cite that as "the 70B is bad."

### Hard lesson logged 2026-06-01
A model with 0 rows in `llm_call_log` is **not necessarily dead weight** — it may be a
*candidate/target* not yet wired as a live route. Cline wrongly deleted `llama3.3:70b` Q4
reading "0 calls = prune," then had to re-pull. **Before removing any model from Artemis,
check whether it's a 3G candidate / part of an active idea (#64xx/#65xx/#77xx) — not just
its live-call count.** (Cross-ref rule 29: act on *verified* evidence; usage count alone is
not sufficient evidence that a model is retired.)

## Source dates
- Live Artemis inspection: 2026-06-01 23:00–23:26 PT
- Web research (model landscape, Intel Arc Vulkan): 2026-06-01 via Brave search
- Quant table: llama.cpp k-quant/IQ-quant PRs + HF GGUF cards
- Program docs: `docs/70B_LORA_GPU_FLOOR.md`, `docs/ollama70b_pilot_scorecard_2026-05-26.md`, `docs/RUBEN-EXECUTIONS/idea-6485-*`, `idea-6518-*`

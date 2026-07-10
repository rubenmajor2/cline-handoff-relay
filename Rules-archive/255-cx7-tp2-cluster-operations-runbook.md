# 255 — CX7 TP=2 cluster operations runbook (Cesar+Cato, Julia+Claudia)

Source: 2026-07-04 — Ruben directive: "bug library? runbooks? I just want to make sure no agent gets stale garbage and jacks up our running LLMs." Pairs with rule 254 (verify-before-kill), rule 157 (never destroy TP=2 without permission), rule 156 (bug library check first), bug library row 1458 (agent-killed-vllm), bug library row 1474 (lora-adapter-missing-while-base-serving), and bug library row 1475 (lora-adapter-auto-restart-recovery). Updated 2026-07-05 with LoRA section (#16525).

## What this runbook covers

The two CX7 TP=2 gpt-oss-120b clusters:
- **Cesar+Cato**: Cesar = head (192.168.100.1), Cato = worker (192.168.100.2). Serves on WOPR:11506.
- **Julia+Claudia**: Julia = head (192.168.100.2), Claudia = worker (192.168.100.1). Serves on WOPR:11513.

Both use the same winning config: mxfp4 quantization, NF4 layers, fp8 kv cache, TORCHINDUCTOR_MAX_AUTOTUNE=0, RoCE (NCCL_IB_DISABLE=0), --load-format fastsafetensors.

## SSH access (canonical paths)

| Box | SSH command | WireGuard IP |
|---|---|---|
| Cesar | `ssh -p 2203 rubenmajor@127.0.0.1` (via WOPR) | 10.100.0.13 |
| Cato | `ssh -p 2204 rubenmajor@127.0.0.1` (via WOPR) | 10.100.0.14 |
| Julia | `ssh -p 2205 rubenmajor@127.0.0.1` (via WOPR) | 10.100.0.15 |
| Claudia | `ssh -p 2206 rubenmajor@127.0.0.1` (via WOPR) | 10.100.0.16 |

## Scripts on each head box

| Script | Purpose |
|---|---|
| `cesar_serve_custom.sh` / `julia_serve_custom.sh` | vLLM serve with winning config (NF4+MXFP4+fp8+autotune=0+RoCE) |
| `cesar_head_custom.sh` / `julia_head_custom.sh` | Ray head start |
| `full_custom_relaunch.sh` / `julia_full_relaunch.sh` | Orchestrator: kill stale -> Ray head -> worker -> wait >=2 nodes -> serve |
| `vllm_watchdog.sh` | Auto-restart watchdog (every 2 min via cron) |
| `scripts/lora_lint_gate.py` | LoRA adapter lint gate (#16525) — probes /v1/chat/completions for model="emsu" |
| `wait_roce_ready.sh` / `wait_claudia_ready.sh` | Block until CX7 link + worker reachable (boot ordering) |

## Normal operations

### Check if cluster is serving
```bash
# From WOPR (end-to-end check):
curl -s -m 5 http://localhost:11506/v1/models  # Cesar
curl -s -m 5 http://localhost:11513/v1/models  # Julia

# From the head box (box-local check):
ssh -p 2203 rubenmajor@127.0.0.1 'curl -s -m 5 http://localhost:8000/v1/models'
```

### Check LoRA adapter status (lint gate #16525)
```bash
# From the head box (box-local probe):
ssh -p 2203 rubenmajor@127.0.0.1 'python3 ~/scripts/lora_lint_gate.py --port 8000 --timeout 10'

# From WOPR (via tunnel):
python3 /usr/local/bin/lora_lint_gate.py --host localhost --port 11506  # Cesar
python3 /usr/local/bin/lora_lint_gate.py --host localhost --port 11513  # Julia

# Check fleet inventory status:
mysql admin_portal -e "SELECT host_key, lora_loaded, lora_last_probed, lora_probe_error FROM fleet_inventory WHERE host_key IN ('julia', 'cesar')"

# Check lint gate audit log:
mysql admin_portal -e "SELECT * FROM lora_lint_log ORDER BY probed_at DESC LIMIT 10"
```

### Check Ray cluster health
```bash
ssh -p 2203 rubenmajor@127.0.0.1 'source ~/.python-vllm-custom/bin/activate; RAY_ADDRESS=192.168.100.1:6379 ray status'
# Should show 2 nodes Active, 2.0/2.0 GPU
```

### Check serve log
```bash
ssh -p 2203 rubenmajor@127.0.0.1 'tail -20 /tmp/vllm_custom_serve.log'
```

### Check watchdog log
```bash
ssh -p 2203 rubenmajor@127.0.0.1 'tail -10 ~/vllm_watchdog.log'
```

## Recovery operations

### If vLLM is down but Ray head is up (SIGTERM/crash)
The watchdog should auto-restart within 6 min. To manually restart:
```bash
ssh -p 2205 rubenmajor@127.0.0.1 'setsid bash ~/julia_serve_custom.sh > /tmp/julia_serve_relaunch.log 2>&1 < /dev/null &'
```
This is recovery restart #1 (rule 157 allows up to 3 without permission).

### If both vLLM AND Ray are down (full cluster restart)
```bash
ssh -p 2205 rubenmajor@127.0.0.1 'bash ~/julia_full_relaunch.sh'
```
This kills stale processes, starts Ray head, starts Claudia worker, waits for >=2 nodes, then launches vLLM serve. Takes ~10 min cold.

### If the box rebooted
The @reboot cron should auto-relaunch the cluster (sleep 45 then full_relaunch.sh). Check:
```bash
ssh -p 2205 rubenmajor@127.0.0.1 'cat /tmp/julia_relaunch_boot.log'
```

## LoRA Adapter Lint Gate (#16525, deployed 2026-07-05)

### Problem
vLLM's `/v1/models` endpoint returns HTTP 200 even when the LoRA adapter is NOT loaded — the base model (gpt-oss-120b) serves normally, but model="emsu" requests fail with 404. The fleet watchdog's `/v1/completions` probe tests the *base* model only, missing the adapter gap. On Julia, the adapter was trained and on disk (47MB, `~/models/emsu_distill_lora/`) but the running vLLM process predates the patched launch script that adds `--enable-lora`. On Cesar, the launch script IS correct (includes `--enable-lora --max-loras 4 --max-lora-rank 16 --lora-modules emsu=...`).

### Solution
A Python lint gate script (`scripts/lora_lint_gate.py`) that probes `POST /v1/chat/completions` with `model="emsu"`:
- HTTP 200 with valid response → adapter IS loaded (exit 0)
- HTTP 404 → adapter NOT loaded (exit 1)
- Connection refused → vLLM down entirely (exit 2)
- Timeout → vLLM hung (exit 3)

### Integration
The lint gate runs INSIDE the vllm_watchdog.sh health check (section 2.5), AFTER the base generation probe passes. If the base model is serving but the adapter is missing, the watchdog logs it and touches `/tmp/lora_lint_needs_restart_${INSTANCE}` as a signal flag.

### Fleet inventory tracking
Three new columns in `admin_portal.fleet_inventory`:
- `lora_loaded TINYINT(1)` — 1 if adapter confirmed loaded by lint gate
- `lora_last_probed DATETIME` — last probe timestamp
- `lora_probe_error VARCHAR(500)` — error details if lora_loaded=0

Plus `lora_lint_log` audit table for probe history.

### When adapter is missing (Julia scenario)
1. Watchdog detects adapter NOT loaded → logs and touches signal file
2. The launch script needs to be updated to include `--enable-lora --max-loras 1 --max-lora-rank 16 --lora-modules emsu=~/models/emsu_distill_lora`
3. After update, restart vLLM with the patched script
4. Lint gate verifies adapter loads on next probe cycle

### Adapter config
- Path: `~/models/emsu_distill_lora/adapter_model.safetensors` (47MB)
- Rank: r=16, lora_alpha=32
- Target modules: v_proj, o_proj, k_proj, q_proj
- Trained: 2026-06-24 on the 120B base

## Hardening checklist (MANDATORY for CX7 TP=2, verified 2026-07-05)

These 10 items are REQUIRED on both CX7 TP=2 clusters. If any is missing, the cluster WILL crash-loop:

1. **`--enforce-eager` in serve script** — MANDATORY. Prevents `RayChannelTimeoutError` in compiled DAG (CUDA graph). Community confirmed: vllm#36237, vllm#40969, vllm#40899. Without it, vLLM hangs after ~10 min and EngineCore dies.
2. **`RAY_memory_monitor_refresh_ms=0` in BOTH head + serve scripts** — MANDATORY. Prevents Ray's OOM killer from killing workers when system RAM hits 95%. Julia's head script was missing this (idea #16464).
3. **Watchdog tests `/v1/completions` not `/v1/models`** — MANDATORY. The API server returns 200 on `/v1/models` EVEN WHEN EngineCore is dead (zombie process). Generation probe is the only reliable health check.
4. **systemd unit for boot persistence** — REQUIRED (not just @reboot cron). Julia: `frankenstein-julia-tp2-boot.service` (installed 2026-07-05). Cesar: @reboot cron (broken systemd unit disabled).
5. **`NCCL_P2P_DISABLE=1`** — GB10 needs `=1` (not 0). Confirmed in winning config.
6. **`VLLM_DISABLE_COMPILE=1`** — Prevents inductor compile deadlocks on SM121.
7. **`TORCHINDUCTOR_MAX_AUTOTUNE=0`** — Prevents cold compile cache deadlocks (idea #16448).
8. **KV cache monitoring** — If `Maximum concurrency < 1.0x`, the config is broken. Julia showed 0.06x before fix (4096 tokens), 26x after fix (1.76M tokens). Check serve log for this line during startup.
9. **`RAY_CGRAPH_get_timeout`** — Default 300s. Can be increased, but `--enforce-eager` bypasses the DAG entirely (better fix). See vllm#36237.
10. **Bug library rows 1458+1459** — Row 1459 "stale Ray actors" was a SYMPTOM, not cause. Actual cause is compiled DAG timeout (#16463). Actors accumulate as a side-effect of DAG hangs.

### Community references (upstream bugs to monitor)

- **vllm#36237** — EXACT same bug (RayChannelTimeoutError at `refs[0].get()`). Open since 2026-03-06. H100 x8, vLLM 0.16.1rc1.
- **vllm#40969** — SAME hardware (DGX Spark GB10 SM12.x, 2x via 100Gb RoCE). Hangs with `FULL_AND_PIECEWISE` cudagraph_mode. Workaround: `--enforce-eager` or PIECEWISE only.
- **vllm#29373** — Ray compiled DAG crash, Raylet death. Regression from v0.7.3.
- **vllm#27116** — RayChannelTimeoutError since v0.10.2 with TP=8.
- **vllm#40899** — DeepSeek V4 SM12x PR. Documents PIECEWISE works, FULL_AND_PIECEWISE hangs.

When vllm#36237 or vllm#40969 ship a fix, test removing `--enforce-eager` for a potential speed boost (eager mode is ~10% slower than compiled DAG).

## What NEVER to do (rule 254 + rule 157)

1. **NEVER `kill -9` a process on a GPU box without verifying it via `ps -p <PID> -o pid,cmd`.** The 43GB GPU process is vLLM serving the 120B model, NOT a "wedged ollama." See rule 254 and bug library row 1458.

2. **NEVER `pkill vllm` or `pkill python` on a serving box.** This kills the production LLM. The watchdog uses `pkill -9 -f "vllm serve"` only AFTER confirming 3 consecutive probe failures, and only as part of the auto-restart sequence.

3. **NEVER tear down a TP=2 cluster (ray stop + kill) without Ruben's explicit permission.** Rule 157. The watchdog's auto-restart is the ONLY exception (it's recovery, not teardown).

4. **NEVER probe the worker box's serving port.** Cato :11507 and Claudia :11514 return conn-reset BY DESIGN (rule 157, rule 253). They are Ray workers, not serving endpoints. The cluster serves ONLY via the head box's :8000 (Cesar) or :8000 (Julia), tunneled to WOPR :11506 / :11513.

5. **NEVER declare a GPU box "down" based on heartbeat age alone.** Live-probe the serving endpoint first (rule 252). The heartbeat write path has been broken before (idea #16032).

## Bug library (rule 156)

Before diagnosing ANY LLM serving issue, check the bug library:
```sql
SELECT id, problem_key, LEFT(symptom_observed,200), LEFT(resolution,300), status
FROM frankenstein_router_incidents
WHERE LOWER(symptom_observed) LIKE '%<keyword>%'
ORDER BY occurred_at DESC LIMIT 5;
```

Known entries:
- **Row 1458**: `agent-killed-vllm-thinking-wedged-ollama` — Agent kills vLLM EngineCore thinking it's a stuck ollama. Resolution: verify process identity via `ps` + `nvidia-smi --query-compute-apps` before ANY kill. See rule 254.

## Winning config (the canonical template)

Both clusters use identical env vars + vllm serve flags:
```
VLLM_NF4_LAYERS=all VLLM_NF4_GROUP_SIZE=128 VLLM_MARLIN_USE_ATOMIC_ADD=1
VLLM_MXFP4_BACKEND=marlin VLLM_STREAM_LOADING=1 VLLM_FASTSAFETENSORS_NOGDS=1
NCCL_IB_DISABLE=0 NCCL_IB_HCA=rocep1s0f1 NCCL_IB_GID_INDEX=3 NCCL_NET_GDR_LEVEL=5
NCCL_P2P_DISABLE=1 NCCL_SOCKET_IFNAME=enp1s0f1np1 GLOO_SOCKET_IFNAME=enp1s0f1np1
TORCHINDUCTOR_MAX_AUTOTUNE=0 RAY_memory_monitor_refresh_ms=0 VLLM_KV_CACHE_MEM_MARGIN=10240
CUDA_DEVICE_MAX_CONNECTIONS=1 PYTORCH_ALLOC_CONF=expandable_segments:True

vllm serve openai/gpt-oss-120b --served-model-name gpt-oss-120b \
  --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-num-batched-tokens 4096 \
  --max-cudagraph-capture-size 32 --enforce-eager --max-model-len 131072 \
  --enable-prefix-caching --enable-chunked-prefill --enable-auto-tool-choice --tool-call-parser openai \
  --reasoning-parser openai_gptoss --kv-cache-dtype fp8 --quantization mxfp4 \
  --load-format fastsafetensors --tensor-parallel-size 2 \
  --distributed-executor-backend ray --swap-space 0
```

For LoRA adapter (EMS distill), add to serve flags:
```
  --enable-lora --max-loras 4 --max-lora-rank 16 \
  --lora-modules emsu=~/models/emsu_distill_lora
```

If a script is missing any of these, it's broken. The winning config was proven on Cesar (idea #16448) and mirrored to Julia (idea #16461).

## Source incidents

- 2026-07-04 ~18:00 PT: Agent killed Cesar vLLM (PID 647224) thinking it was "wedged ollama." 30min outage. Bug library row 1458 + rule 254.
- 2026-07-04 19:06 PT: Sibling window SIGTERM'd Julia vLLM. Watchdog (#16449) would have caught it but wasn't deployed yet. Recovery #2 manual restart.
- 2026-06-28: Cesar `frankenstein-tp2-boot.service` failed on `ray_nodes=3 ABORT not 2 nodes`. Fixed in #16449: gate changed to `>=2` with retry.
- 2026-07-05 ~14:30 PT: LoRA adapter lint gate investigation (#16525): confirmed Julia vLLM running but adapter NOT loaded (404 on model="emsu"). Cesar correctly configured with --enable-lora. Lint gate deployed to watchdog on both boxes. Adapter: ~/models/emsu_distill_lora/adapter_model.safetensors (47MB, r=16, lora_alpha=32).

## Last updated

2026-07-05 — added LoRA adapter lint gate (#16525): deployment of lora_lint_gate.py, vllm_watchdog.sh integration, fleet_inventory lora_loaded columns, lora_lint_log audit table. Updated winning config with --enable-lora flags. Source: 2026-07-05 — Ruben directive: "the fleet watchdog tests /v1/models which returns 200 even when adapter is missing."
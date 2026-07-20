# 277 — GLM-5.2 Hexarchy PP=6 launch: UMA memory + JIT timeout fix (MANDATORY before any launch)

Slug: `glm52-hexarchy-launch-uma-jit-fix`

## The bright-line rule

**Before launching GLM-5.2 PP=6 on ANY Hexarchy node, ALL of the following MUST be true. Violating ANY of these causes SSH lockout requiring physical reboot.**

1. `VLLM_ENGINE_READY_TIMEOUT_S=1800` MUST be set as a Docker env var (`-e`). Default is 600s (10 min). Cold-start FlashInfer JIT compilation of ~85 sm_121a CUTLASS kernels for 379GB MoE EXCEEDS 600s. Container exits silently. (GitHub vllm#48031)
2. `gpu_memory_utilization=0.82` — PROVEN value from v9-fallback (102 tok/s). Do NOT lower it. The UMA OOM theory (#1754) was WRONG — Docker `--memory` limits added in v16-v20 were the actual cause of the freezes.
3. NO Docker `--memory` limit, NO `--oom-kill-disable`, NO `--memory-swappiness`. These "safety" features (v16-v20) CAUSED the freezes. The v9-fallback script had NONE of these and worked perfectly.
4. NO `--enforce-eager` — not needed with proven NCCL settings.
5. NCCL_SOCKET_IFNAME must be 3-interface: `enp1s0f0np0,enp1s0f1np1,enP7s7` (NOT just `enP7s7`).
6. NCCL_NET_CHANNEL_COUNT=4 (NOT 2), NCCL_MIN_NCHANNELS=4, NCCL_TIMEOUT=1200 (NOT 3600).
7. Use `nohup` + `sleep infinity` pattern to keep container alive.
8. Use `bash -lc` (login shell, NOT `bash -c`).
9. ALL old containers MUST be killed before launch (`docker rm -f vllm_slot`).

## The canonical launch script

`~/Desktop/glm52_v20_community_fixed.sh` — the ONLY script that has all fixes. Do NOT use v1-v19 (all missing `VLLM_ENGINE_READY_TIMEOUT_S`).

`~/Desktop/glm52_v20_launcher.sh` — deploys v20 to all 6 nodes + launches simultaneously with correct ranks per rule 273.

## Node mapping (rule 273)

| Rank | Name | IP | Notes |
|---|---|---|---|
| 0 (master) | Cato | 192.168.1.115 | Serving endpoint :8210 |
| 1 | Augustus | 192.168.1.244 | |
| 2 | Pompey | 192.168.1.21 | |
| 3 | Marcus | 192.168.1.171 | spark-63ce; verified live 2026-07-20 |
| 4 | Tiberius | 192.168.1.32 | |
| 5 | Cesar | 192.168.1.56 | |

## What to do if nodes are frozen

If SSH times out on any Hexarchy node after a launch attempt:
1. The node is OOM-frozen. SSH will NOT come back.
2. Physical reboot is the ONLY option.
3. After reboot, deploy `glm52_safety_gate.sh` to prevent future bad launches.
4. Record the incident in the bug library via `bug_library_record`.

## Bug library entries

- #1754 — UMA OOM SSH lockout (resolved)
- #1755 — JIT compilation timeout + UMA memory starvation (resolved)

## Cross-references

- Rule 273 — Hexarchy GLM-5.2 ring membership (node/rank mapping)
- Rule 146 — Frankenstein LLM routing (never suggest paid models)
- Rule 140 — verify routing from live headers
- Rule 156 — consult bug library before diagnosing

## Source

2026-07-15 — 5 of 6 Hexarchy nodes frozen, requiring physical reboots. Community research found GitHub vllm#48031 (JIT timeout) and vllm#48140 (UMA memory). All 19 prior script versions (v1-v19) were missing `VLLM_ENGINE_READY_TIMEOUT_S`. v20 fixes both issues.

## Last updated

2026-07-15 — initial. Root cause: 2 community-documented vLLM bugs on GB10 UMA architecture.
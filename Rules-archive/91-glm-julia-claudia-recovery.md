# Rule 91-GLM — GLM Ring + Julia/Claudia 235B Recovery to Serving Speed

**Severity: OPERATIONAL RUNBOOK (not hardfloor formatting)**
**Created: 2026-08-19 (Ruben directive: "comprehensive rule 91 that covers how we get the GLM and Julia/Claudia back to serving at proper speeds and addresses questions regarding decode")**
**Cross-refs: Rule 315 (verify before declaring down), Rule 277 (GLM launch UMA+JIT fix), Rule 273 (hex ring PP=6), Rule 322 (what was serving table), Rules 145/157 (don't destroy TP=2)**

## Core principle

GLM-5.2 ring and Julia/Claudia 235B are the fleet's capacity backbone. When they stall,
everything spills to paid cloud or crawls. This rule is the RECOVERY RUNBOOK: how to
diagnose, relaunch, and verify serving speed — with decode tok/s as the ground truth.

## PART 1: The decode question (why "fast" prefill ≠ serving)

**PREFILL tok/s is NOT serving speed.** A ring can show 3500+ tok/s prefill while decode
is 0.55 tok/s/stream. The user experiences DECODE (token generation), not prefill
(prompt ingestion).

**The 3 numbers that matter:**

| Metric | Where | Healthy | Sick |
|---|---|---|---|
| DECODE tok/s (aggregate) | `:8210/metrics` `vllm:generation_tokens_total` delta | >30 at 8+ streams | <10 |
| DECODE per-stream | aggregate / num_running | >2 tok/s | <1 tok/s |
| PREFILL:DECODE ratio | counter deltas | <10:1 | >100:1 (prefill starving decode) |

**How to measure (the ringrate.sh method):**
```bash
# On WOPR, 30-second counter delta
T1=$(curl -s http://127.0.0.1:8210/metrics | awk '/^vllm:generation_tokens_total/{printf "%.0f",$2}')
P1=$(curl -s http://127.0.0.1:8210/metrics | awk '/^vllm:prompt_tokens_total/{printf "%.0f",$2}')
sleep 30
T2=$(curl -s http://127.0.0.1:8210/metrics | awk '/^vllm:generation_tokens_total/{printf "%.0f",$2}')
P2=$(curl -s http://127.0.0.1:8210/metrics | awk '/^vllm:prompt_tokens_total/{printf "%.0f",$2}')
echo "DECODE = $(echo "scale=2; ($T2-$T1)/30" | bc) tok/s"
echo "PREFILL = $(echo "scale=2; ($P2-$P1)/30" | bc) tok/s"
RUNNING=$(curl -s http://127.0.0.1:8210/metrics | awk '/num_requests_running/{print $2}')
echo "PER-STREAM = $(echo "scale=2; (($T2-$T1)/30)/$RUNNING" | bc) tok/s"
```

## PART 2: GLM-5.2 ring recovery (PP=6 hex ring)

### Ring topology (GLM52_RING_TOPOLOGY.md)
- Pompey (50c0), Marcus (63ce), Tiberius (e9e0), Cesar (3b41), Cato (2aa8), Augustus (e3b2)
- PP=6 pipeline parallel — ALL 6 nodes required, one missing = ring won't init
- Cato is rank 0 (head), serves :8210

### Pre-flight (MANDATORY before any relaunch)
1. **Watchdog un-paused FIRST:** `ls /tmp/glm52_ring_paused` must return "No such file"
2. **Launch artifact exists:** `/usr/local/bin/glm52_ring_relaunch_v20_maxseqs32.sh` (or current version)
3. **All 6 nodes have vllm_slot container:** SSH to each node, `docker ps | grep vllm_slot`
4. **NCCL fabric healthy:** RoCE IPv4 present on all nodes (rule 315 amendment)

### The decode lever: max_num_seqs
- **Default was 15, now 32** (2026-08-19)
- With chunked prefill + max-num-batched-tokens=16384, a single 83K prompt can eat the
  whole step budget, starving decode. Higher max_num_seqs = more decode slots per step.
- **Safety:** watch `num_preemptions_total` in metrics. Preemption = latency, not crash.
- KV headroom: 37+ GiB available vs 29.83 in historical 128-lane build.

### Relaunch sequence (human-gated per rules 145/157/277)
1. Verify watchdog un-paused
2. Verify launch artifact written with correct flags
3. **Ruben approves the relaunch** (bad params have physically frozen 5/6 nodes before)
4. Execute: `glm52_ring_relaunch_v20_maxseqs32.sh`
5. Wait for NCCL init (can take 5-10 min for 6-node PP)
6. Verify: `curl :8210/v1/models` returns glm-5.2-local
7. Measure decode with ringrate.sh — target >30 tok/s aggregate at 8+ streams

### Common failure modes
| Symptom | Cause | Fix |
|---|---|---|
| NCCL init stuck >10 min | Missing node, RoCE IPv4 absent | Check all 6 vllm_slot containers, verify fabric |
| :8210 empty response | Ring not started, or head node wrong | Check Cato is rank 0, docker logs |
| Decode <1 tok/s/stream | Chunked prefill starvation | max_num_seqs 32, reduce max-num-batched-tokens |
| 671 tok/s "fast" but crawl | That's prefill, not decode | Measure generation_tokens_total, not prompt |

## PART 3: Julia/Claudia 235B recovery

### Architecture
- Julia (spark-6ae6) + Claudia = Qwen3-235B-A22B, TP=2 over CX7 direct cable
- Julia SSH port 2205, serves :11513 via reverse tunnel to WOPR
- 3 seats reserved for Cline interactive

### Pre-flight
1. **Host reachable:** SSH to Julia (port 2205), `hostname` returns spark-6ae6
2. **CX7 fabric:** `ip -4 addr` on RoCE netdev, GID table populated (rule 315 amendment)
3. **vLLM process:** `ps aux | grep [v]llm` shows served-model-name julia-235b
4. **Tunnel vs model:** :11513 connection-refused = TUNNEL down, not model dead. Check router audit for `picked: julia-235b`.

### Relaunch (human-gated)
1. Verify CX7 link admin-UP on both nodes, carrier=1
2. Run Julia's relaunch script (or vLLM serve command with correct TP=2 flags)
3. Wait for engine ready (can take 5+ min for 235B)
4. Verify: `curl :11513/v1/models` OR router probe `litellm:julia-235b`
5. Canary auto-rejoin: frankenstein_tier_health shows julia healthy

### Common failure modes
| Symptom | Cause | Fix |
|---|---|---|
| :11513 refused | Tunnel down, not model | Check autossh/WG unit, re-probe over 10 min |
| NCCL unhandled system error | RoCE IPv4 missing, GID mismatch | ip -4 addr on CX7 netdev, fix GID index |
| Engine wedged mid-init | Ray placement-group hang | Restart vLLM, check startup-complete count |
| Kernel wedge (hot chassis, no SSH) | Hung kernel, not power loss | Hardware watchdog arm, not just WOL |

## PART 4: Verification before declaring "serving"

**Rule 322 discipline:** A "serving" claim requires:
1. `curl :PORT/v1/models` returns HTTP 200 with the model name
2. Decode probe produces tokens (not just HTTP 200)
3. Router audit shows `picked: <model>` for recent requests
4. For ring: ringrate.sh shows >2 tok/s/stream at realistic concurrency

**One probe is never a verdict.** Re-probe over >10 minutes for intermittent issues.

## PART 5: The "why not just use X" questions

**Why spill to DeepSeek instead of waiting for GLM?**
- GLM decode 0.55 tok/s/stream = 10+ min for a normal response
- DeepSeek cloud = seconds. User experience wins.
- The ladder is latency-ordered: fastest-serving first.

**Why not go straight to 235Bs?**
- Limited seats (Julia 3, Claudia limited)
- 235Bs are premium tier for complex reasoning
- Flooding them with bulk ops saturates the fleet's best capacity

**Why is paid DeepSeek faster than free?**
- Paid tier = priority queue, no rate limiting
- Free tier = best-effort, can be queued/throttled

## Source incidents
- 2026-08-19: GLM decode 0.55 tok/s/stream, ring wedged at NCCL init with 4/6 nodes
- 2026-08-18: Julia tunnel flapping misdiagnosed as model down
- 2026-08-17: RoCE IPv4 loss caused NCCL EINVAL across reboot

## Last updated
2026-08-19 — initial, per Ruben directive for comprehensive GLM/Julia/Claudia recovery rule.
## Amendment (from reversal, 2026-08-19 20:54 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787138864086
- RCA bucket: insufficient probe
- Trigger pattern: Applying a higher max_num_seqs decode lever to a live GLM ring without a controlled CONC ladder or a same-day revert config
- Reversal note: max_num_seqs 16 to 32 applied naively (idea #27524) HUNG the GLM hex engine at 3 concurrent requests: KV cache ~0%, engine stats silent 7 min, zero tokens in a 90s probe. Amendment: max_num_seqs changes MUST follow the controlled CONC ladder in docs/GLM52_MEASUREMENT_METHOD_AND_RESTORE_RISK.md; never apply a higher seqs value to a live ring without a same-day backup config and a 90s token-production probe; revert to last known-good value (16) on any stall.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

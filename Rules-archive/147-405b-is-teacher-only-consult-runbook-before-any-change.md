# 147 — The 405B is a TEACHER. Consult the runbook BEFORE any change to how it operates. Never route interactive/executor load to it.

Source: 2026-06-13 Ruben directive. A Cline window (#12060) tried to route executor planner load to `frankenstein-405b` to escape a saturated 120B pool. Ruben interrupted mid-task: *"if there are going to be any changes to how the 405 operates, first there needs to be a comprehensive investigation into how the 405 works because it is very precise and relies on precise documentation which is already in our runbook... I need to make sure that is actually consulted if anything is to change."*

## The bright-line rule

**The 405B (`frankenstein-405b` = Augustus 192.168.1.244 + Tiberius 192.168.1.32, TP=2 Ray, :11512) is a DISTILLATION TEACHER / quality-ceiling tier. It is NOT an interactive server, NOT a daily-driver, and NOT a spill-ladder target for Cline / Executor / Orchestrator traffic.**

Two non-negotiables:
1. **Never route interactive/executor/orchestrator request load to the 405B.** It would wedge it AND fail technically.
2. **ANY change to how the 405B operates — traffic it receives, serve flags, quant, role — REQUIRES reading the canonical runbook FIRST.** It is precision infrastructure that relies on exact documented config. Never change it from a config-read or an assumption.

## Why it is teacher-only (the technical facts)

- Served `--max-num-seqs 1` — handles exactly ONE request at a time. 240 concurrent executor workers wedge it instantly.
- Served `--max-model-len 1024` (ladder falls to 256 under memory pressure). It physically cannot accept a 24k-max_tokens planner request — the request errors / returns an empty body (confirmed live 2026-06-13).
- AWQ-INT4 (~102GB/box) on 128GB Sparks, util 0.90, enforce-eager, swap-space 1-4 — memory-fragile by design. The NVFP4 110GB artifact was PROVEN unservable; do not retry it.
- Doc verbatim (405B_WINDOW_4_teacher_explained.md): *"The 405B's job is NOT to answer your day-to-day prompts (too slow). Its job is to be the quality ceiling that pulls your fast models UP. You run it occasionally, in batch."* / *"The 405B is your TEACHER, not your daily driver. 120Bs = fast interactive workers. 405B = slow teacher."*

## Intended uses ONLY

1. DISTILLATION TEACHER (main use): batch-generate high-quality training data to fine-tune the fast 7B/14B/32B/70B/120B models UP.
2. HARD OFFLINE BATCH: occasional one-off hard problems where 30+ seconds latency is fine.
3. QUALITY ARBITER / JUDGE: score/rank smaller models' outputs offline.

## Canonical runbook (read BEFORE any 405B change)

- `405B_WINDOW_4_teacher_explained.md` — the role (teacher, not daily driver).
- `405B_CHECKPOINT.md` — FINAL VERIFIED CONFIG (AWQ-INT4, proven serve args).
- `auto405.sh` — the authoritative serve command.
- `405B_RECOVERY_RESEARCH_2026-06-13.md` — idea #11735 FINAL VERIFIED CONFIG + the NVFP4-is-unservable post-mortem.

The proven serve args (verbatim): `vllm serve /models/llama405b-awq --tensor-parallel-size 2 --max-model-len 1024 --gpu-memory-utilization 0.90 --enforce-eager --max-num-batched-tokens 1024 --max-num-seqs 1 --swap-space 1 --served-model-name llama405b --enable-auto-tool-choice --tool-call-parser llama3_json --host 0.0.0.0 --port 8000 --distributed-executor-backend ray` (image nvcr.io/nvidia/vllm:25.09-py3, vLLM 0.10.1.1, BOTH containers --memory=100g, RAY_memory_monitor_refresh_ms=0).

## If a 120B pool is saturated, the fix is NOT the teacher

The fix for a saturated interactive/executor 120B pool is the **per-box admission cap + saturation-aware routing** (idea #12059), NOT borrowing the teacher. The army marches by spilling across the FREE INTERACTIVE fleet (7B → 14B → 32B → 70B → other 120Bs → RunPod) → DeepSeek → Claude-last. The 405B is never a spill target. A machine should never be able to wedge: that is what the admission cap guarantees.

## Self-check before touching anything 405B-related

1. *Am I about to send Cline/Executor/Orchestrator traffic to frankenstein-405b?* → STOP. It is the teacher. Use the interactive spill ladder.
2. *Am I about to change a 405B serve flag / quant / api_base / role?* → Read the canonical runbook (above) FIRST. Never from a config-read or assumption.
3. *Am I "fixing" a saturated 120B by borrowing the 405B?* → Wrong fix. The fix is the admission cap (#12059).

## Cross-references

- project-frankenstein MCP `frankenstein_architecture` → `FOUR_OH_FIVE_B_TEACHER_GUARD` block (read-at-runtime guard)
- PROJECT_FRANKENSTEIN.md §405B teacher guard
- .clinerules/146 — Frankenstein routes every LLM (the 405B is in the fleet but teacher-tier, off the interactive ladder)
- .clinerules/141 — call the project-frankenstein MCP first for architecture truth
- .clinerules/92 — fix at the core (admission cap, not borrowing the teacher)

## Last updated

2026-06-13 — initial. Source: Ruben interrupted #12060 to enforce that the 405B is precision teacher infrastructure and its runbook must be consulted before any change.

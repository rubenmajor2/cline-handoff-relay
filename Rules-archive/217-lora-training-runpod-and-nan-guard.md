# 138 — PREFER RunPod for LoRA/QLoRA training (speed + economics, not "never touch my computer"); and ALWAYS NaN-guard the first 2 iters


Source: 2026-06-04 — Ruben's M5 (Rubens-MacBook-Pro-2, 128GB) was bogging for hours. Cause: a 70B CODE-LoRA train (adapter emsu70b_code, #9715/#9741) running locally via mlx_lm, **NaN loss on EVERY iteration since Iter 1**, crawling at ~0.3 tok/s (healthy run = 35-41 tok/s), pinning ~45GB for 3h49m, producing a poisoned adapter. Ruben: "just do it on a runpod? ... That was what was jacking up my CPU. Did you learn from this and put this recipe in KAIZEN or Fleet Agent?"

## Bright-line rule 1 — PREFER RunPod for training (speed + economics), don't default to a Mac

**Default training host = RunPod, because it is faster and cheaper-by-outcome, not merely "to avoid touching Ruben's computer."** The framing matters: Ruben may later turn a Mac into a dedicated LLM/training station, so the rule is NOT "never run an op on my machine." The rule is: pick the host that finishes the job fastest for the least total cost, and on an 8×B200/H200 RunPod box that is almost always RunPod.

Concrete economics (measured 2026-06-04): a 70B LoRA that takes **~6-8h on the M5** (MLX 4-bit, ~35-41 tok/s, ~45GB pinned, machine unusable) finishes in **~20-60 min on 8×B200/H200** for a few dollars to ~$35/hr. So even at $35/hr the RunPod run is cheaper-by-outcome AND frees the workstation.

When a Mac IS the right host:
- **Short one-time jobs** (GGUF convert ~10-40 min, quantize, a quick smoke) — fine on any Mac per .clinerules/137.
- **A DEDICATED LLM-station Mac** (not Ruben's daily-driver) that Ruben has explicitly stood up for training/serving — then a multi-hour train there is acceptable.
- **RunPod genuinely unavailable** (no GPU capacity across the whole rule-114 fallback chain) AND the only Mac available is non-daily-driver.

The one hard line: **never run a multi-hour, machine-saturating train on Ruben's ACTIVE daily-driver workstation while he's using it.** That's a productivity/economics problem, not a "don't touch the computer" rule.

RunPod launch surface (proven path): `mint_idea_<N>_lora_pod.php` (B200-first, rule 114 GPU fallback chain) + a `training_run_*.sh` bringup that scp's corpus + script to the pod and runs QLoRA bf16 detached. See the #9715 code-LoRA run for a worked example.


## Bright-line rule 2 — NaN-guard the first 2 iterations, always

**Never walk away from a training launch until you've confirmed Iter-1 val loss is a real (finite) number.** NaN at Iter 1 = zero gradient signal = every downstream checkpoint is poisoned garbage. A run that NaNs at step 1 will NaN forever — it never recovers — so leaving it "running overnight" just burns the host for nothing.

The launcher MUST tail the log and abort within the first 2 reports if loss is `nan`/`inf`. Pseudo-guard:
```
# after launch, within ~first eval:
if grep -qE "loss (nan|inf)" "$LOG"; then
  echo "NaN at step 1 — aborting, config is broken"; pkill -f "adapter-path.*$ADAPTER"; exit 1
fi
```

## NaN root causes (in priority order) + fixes

1. **Empty target span after truncation** (the #1 cause here). The corpus had many >2048-tok rows; under `--mask-prompt` a `--max-seq-length 2048` truncation can cut the assistant span to empty → an all-masked row → NaN. **Fix:** sanitize the corpus — drop or pre-split rows whose assistant/answer span would be empty after truncation; or raise `--max-seq-length`; or pre-split long docs.
2. **Learning rate too high for the corpus/quant.** 4-bit base + 1e-5 can diverge. **Fix:** lower to 5e-6 or 2e-6, optionally add grad clipping.
3. **Bad/over-aggressive quant of the base for training.** Prefer training on a higher-precision base on RunPod (bf16/8-bit) rather than 4-bit MLX when feasible.

Note: the CS run (adapter emsu70b) used the SAME harness and trained fine (loss 1.4-1.9). So the harness is OK — when a sibling run NaNs, suspect the **corpus + lr**, not the script.

## How long is a 70B LoRA supposed to take?

Healthy reference (the CS run): 1200 iters, 16 layers, batch 1, seq 2048, ~35-41 tok/s → ~6-8h on the M5. On a RunPod A100/H100 with a higher-precision base it's faster and far less NaN-prone. **If you see <1 tok/s, that is NOT "slow," it is broken** — stop and diagnose, don't wait it out.

## Durable learning — where this recipe lives

- **This rule (138)** = the Cline-facing SOP (train on RunPod + NaN-guard).
- **KAIZEN** is failure-LOG driven (mysql error tables per target); there is no training-job failure table today, so a KAIZEN recipe has nowhere to attach UNTIL a `lora_training` target + log table exists. Filed an orchestrator idea to add a training watchdog that writes NaN/stall events to a log KAIZEN can learn from, and to auto-kill NaN runs.
- **Fleet Agent** owns host placement; the idea also asks Fleet to refuse 70B-train placement on the M5 and route it to RunPod.

## Self-check before launching ANY training job

1. Is this a multi-hour 70B train on the M5? → STOP, use RunPod.
2. Did I add a first-2-iter NaN guard to the launcher? → if no, add it before launching.
3. Did I confirm Iter-1 val loss is finite before walking away? → if no, don't walk away.
4. Is throughput in the expected tok/s band (tens, not <1)? → if <1 tok/s, it's broken; diagnose.

## Source incident

2026-06-04 — emsu70b_code CODE-LoRA NaN-diverged from Iter 1, ran 3h49m on the M5 at 0.3 tok/s pinning 45GB, jacking Ruben's CPU. Killed mid-session. Adapter emsu70b_code/*.safetensors discarded as poisoned. Evidence: ~/frankenstein/logs/train_code.log.

## Last updated

2026-06-04 — initial. Source: Ruben directive after the NaN-train bog. Train on RunPod; NaN-guard the first 2 iters; <1 tok/s = broken, not slow.

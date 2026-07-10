# 140 — LoRA training as warm-start + hard-negative + parallel adaptive sweep (standard method)

Permanent rule. Workspace-scoped. Source: 2026-06-05 — the Frankenstein CODE-70B v1 adapter gated 40.0% W/T vs Opus (below the 45% ship floor). Forensics proved it was NOT a data ceiling: it trained only 150 steps = 0.18 effective epochs of the 6623-row corpus (a smoke-test max_steps cap survived a babysitter-incident re-mint). Ruben's directive: *"a failed/undertrained snapshot is gold, not a do-over — use what we found to train faster and train the right things. Run as many B200 pods simultaneously as possible. Use adaptive testing. Make this a standard."*

## The standard (apply to every LoRA/QLoRA retrain after a gate miss)

When an adapter gates BELOW its ship floor, do NOT default to "collect more data" or "redo from scratch." Run this 5-step loop:

### 1. Prove the cause before re-spending (rule 92 — fix the core)
Compute **effective_epochs = (steps_run × batch × grad_accum) / corpus_rows**. If < 1.0 the adapter is undertrained, not data-starved — the fix is simply *run to full epochs*, nothing exotic. Always check this first; an 11×-too-short run looks identical to a "bad model" at the gate. (KAIZEN target `lora_training`, recipe `undertrain_step_cap`.)

### 2. Warm-start, don't redo (faster)
The failed adapter's last checkpoint (with optimizer + scheduler state) is an asset. Load it `is_trainable=True` (`PeftModel.from_pretrained(model, prev_adapter, is_trainable=True)`) and continue training. You keep the 24/60 it already wins and don't pay for the steps already taken.

### 3. Hard-negative mine the losses (train the right things)
Join the gate scorecard verdicts back to the eval rows. Regex-cluster the GOLD answers of the LOSS rows to find which patterns the model misses. (CODE-70B example: losses concentrated 100% on `safe-deploy`, sha/CAS checks, backup-then-swap, `php -l`, sudo upload-then-mv — deterministic EMSU deploy idioms, highly learnable.) Build a v2 corpus = original + N extra copies of training rows matching those patterns (e.g. 3× weight). This spends capacity where the model is weak, not uniformly.

### 4. Parallel B200 sweep, not one serial run (as fast as possible)
Mint multiple B200 pods at once (rule 114 GPU chain, each self-contained pulling base from the unsloth non-gated mirror so there is no shared-volume single-attach conflict). One arm per hypothesis, e.g.:
- A: full corpus, target epochs, baseline r/lr (the "correct v1" control)
- B: hard-neg-weighted corpus, same r/lr
- C: weighted + higher rank (r32) + more epochs + lower lr
- D: warm-start from the prior checkpoint + weighted corpus

### 5. Adaptive testing (cheap, early-kill)
Gate at checkpoints (`save_steps`), not only at the end. Run a SEQUENTIAL eval: start with a small row count (~15); if an arm's W/T is clearly below floor with margin, KILL that pod immediately (stop paying); if clearly above, promote to the full confirm set; if ambiguous, add rows. This saves both GPU-hours and judge calls. (Mirrors the `adaptive_repair` SPRT pattern.)

### 6. 45% is a SHIP GATE, not a training target — keep climbing after deploy
The 45% W/T floor (rule 121) only answers "is it safe to put in the routing path." It is NOT where training stops. Because the router early-exits to the frontier model (Opus) on low confidence, a 45% local model in production CANNOT regress quality — it only converts paid calls to free ones and hands hard cases up. So:

- **Ship at 45% immediately** to start capturing free-inference savings (a local 70B is ~$0/call; every W/T point converts more traffic off paid Opus, and that saving compounds on every future call).
- **Then keep improving in the background, even after deployment.** No reason to stop at 45%, 85%, or any fixed number short of the data's ceiling. Higher W/T = strictly more value (3G capacity principle: free capacity should be pushed as high as it goes).
- **Production IS the next training set (the flywheel).** The cases where the deployed model early-exits to Opus are, by definition, its hard negatives. Log them, mine them (step 3), warm-start retrain (step 2), re-gate, redeploy. Ship → log early-exits → mine → warm-start → ship. The model climbs toward frontier parity using its own production failures as curriculum. Stop only when W/T plateaus (diminishing returns) or hits ~95%+ where it owns nearly everything.

The mental model: 45% unlocks the routing slot; everything above 45% is pure compounding upside pursued continuously, not a box checked once.

## Mandatory guardrails (carried from prior incidents)

- **Epoch-guard in the trainer:** assert effective_epochs ≥ target before `tr.train()`; abort loudly (exit 7) if a `max_steps` cap or a truncated corpus (`<2000` rows when ~6623 expected) would cut it short. Shipped in `cloud_train_code.sh` / `frank_code_train_v2.sh` 2026-06-05.
- **SAFE babysitter only (HANDOFF 2026-06-04 23:46):** terminate a pod ONLY on adapter-saved (DONE marker) OR (train-proc-dead AND no-adapter). NEVER kill on a log error string without confirming the producing process is dead AND it is the current run — a stale error line from a prior attempt false-killed 3 healthy pods once.
- **Hard teardown + spend close:** every pod minted gets terminated the moment its arm is decided; close its `runpod_spend_log` row. Rule 84 burn surface applies at >3 pods.

## Self-check before any "the adapter failed, collect more data" conclusion
1. Did I compute effective_epochs? If < 1.0 → it's undertrained, retrain full first.
2. Am I redoing steps I already paid for? → warm-start from the last checkpoint.
3. Do I know WHERE it loses? → mine the loss golds, upweight those patterns.
4. Am I running one serial arm? → parallelize the hypotheses across B200s.
5. Am I waiting for full runs to gate? → adaptive checkpoint eval, kill losers early.

## Cross-references
- .clinerules/114 (B200-first GPU chain), /137 (gate = acceptance check; delete intermediates), /92 (fix the core), /84 (>3-pod burn), /29 + /38 (act/autonomous)
- KAIZEN `lora_training` target, recipe `undertrain_step_cap`
- idea #9926 (CODE-70B full retrain), fleet_agent_config `lora_retrain_method`

## Last updated
2026-06-05 — initial. Source: CODE-70B v1 undertrain (0.18 epochs) reframed by Ruben as a faster-training opportunity. Codifies warm-start + hard-neg mining + parallel B200 sweep + adaptive early-kill as the standard retrain method.

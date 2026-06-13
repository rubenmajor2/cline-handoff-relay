# 145 — Frankenstein RunPod fleet: continuous training, size the disk, never show stale, never skip

Permanent rule. Workspace-scoped. Source: 2026-06-08 Ruben directive session building the parallel RunPod adapter fleet alongside the live 120B. "Max as many RunPods as possible, ignore budgets, keep them running continuously."

## The doctrine

EMSU trains Frankenstein LoRA adapters (7B/14B/32B/70B Qwen/Llama) on RunPod H100s, in parallel with the 120B on the GB10 boxes. The operating posture Ruben set:

1. **Continuous, not one-shot.** Pods should ALWAYS be training. A finished or dead pod is immediately replaced by the next work-queue item. The orchestrator is `scripts/frank_fleet_keeper.php` (cron `emsu-frank-fleet-keeper`, every 3 min, `FLEET_TARGET` pods kept alive). It is a CRON, not a Cline window (rule 92).
2. **Budget is not a gate here.** Ruben explicitly said ignore budget on training pods — maximize throughput. The old $20/$35 nightly caps do NOT apply to the fleet keeper. (Still log spend to `runpod_spend_log` for visibility.)
3. **Fast Frankenstein method (rule 138) on every pod.** 1 epoch (not 5), `packing=True`, raw-LoRA serve, 30-min checkpoint cadence (time-based `TrainerCallback`, not `save_strategy="epoch"`). Each adapter trains on ONE H100 — that IS correct Fast Frankenstein for 7-70B because they fit on a single GPU. Multi-box DDP/FSDP is ONLY for the 120B (CX7 tandem). A single-box adapter pod is NOT a bug.

## Hard lessons baked into the launcher (don't relearn these)

- **Size the disk by model or it dies disk-full.** The RunPod default container/volume of 60GB is too small for big bases. The 32B base (~64GB) and 70B base (~140GB) fill it and the run crashes with `OSError: No space left on device` mid-download. `frank_train_launch.php` sizes disk: 70b=320GB, 32b=220GB, 14b=140GB, 7b=90GB. Any new size needs its own entry.
- **The launcher must actually START training, not just create the pod.** An early bug created pods that sat idle ($/hr for nothing) because the launcher only called the RunPod create API. The launcher MUST: create → wait for SSH → scp corpus + train script → `nohup` the training detached → verify it advanced. `frank_train_launch.php` does all of this.
- **No Python f-strings with backslashes in the embedded train script.** `f"...\n..."` is a SyntaxError before Python 3.12 and crashes the pod instantly. Use string concatenation. The canonical train script is `scripts/frank_train_adapter.py` (loaded by the launcher, not inlined).
- **The cron user is `emsuserver`, not `www-data`.** The status-snapshot cron runs as emsuserver, which (a) can't read www-data's SSH key and (b) isn't authorized on the pods (pods get www's pubkey at launch). The launcher injects emsuserver's pubkey into each pod's authorized_keys, and the collector probes pods with emsuserver's key. If progress shows blank, this is why.

## Dashboard truth rules (llm_router_live.php + cron_train_status_snapshot.php)

- **Never show stale progress.** The collector probes each pod's health (`frank_pod_probe.sh`: PROC alive/dead, log age, last error). If the training python is dead while step<total → status `CRASHED (<error>)`. If the log hasn't advanced >180s → `STALLED`. A frozen tqdm bar must NEVER render as `TRAINING`.
- **Show the Method.** Every training row shows how it trains (`Fast Frankenstein ...`) so "why isn't this Fast Frankenstein" is answered on the page.
- **Show W/T opponent + skips.** Grading rows show `vs Sonnet` / `vs Opus` (Opus on plan/grievance/refund/regulator surfaces, Sonnet on the rest per rule 121) and a `(N skip)` annotation. A `0/0/0` tally is only honest when the skip count explains it.
- **Show Deployed/LIVE.** Grading rows show LIVE (green) from `lora_production_promotions` (graduated/re-graduated = live, demoted = not).
- **Pull-before-gate (rule 138).** A finished adapter is rescued to `/var/www/frank_adapters/ARCHIVE_<tag>/` BEFORE any gate/terminate, via `frank_adapter_rescue_cron.php`. Pods lack `rsync` — use `scp -r`.

## Never skip prompts in grading (wasted training signal)

Ruben directive: a graded eval that SKIPS prompts is wasted compute. The eval must get an answer for every prompt (retry/timeout-extend/force a completion) so the W/T tally reflects all N, never `skip:50`. A run with skips is a bug in the eval harness, not an acceptable result.

## Self-check before any RunPod training work

1. Is the fleet keeper cron alive and is `FLEET_TARGET` being met? If pods are idle, the keeper is the fix, not a manual one-off.
2. Did I size the disk for this model, or will it die disk-full?
3. Does the launcher actually start training (not just create the pod)?
4. Will the dashboard show CRASHED/STALLED if this pod dies, or will it show stale progress?
5. Is the adapter rescued to WOPR ARCHIVE before any gate?

## Cross-references

- Rule 138 — Fast Frankenstein levers + pull-before-gate hardfloor
- Rule 92 — orchestrator is a cron, fix the core
- Rule 121 — W/T ≥ 45% gate vs Sonnet/Opus
- Rule 29 — act + verify end-to-end
- Rule 137 — Definition-of-Done + change→verify
- `scripts/frank_fleet_keeper.php`, `frank_train_launch.php`, `frank_train_adapter.py`, `frank_pod_probe.sh`, `frank_adapter_rescue_cron.php`
- `cron/cron_train_status_snapshot.php`, `routes/llm_router_live.php`, `routes/frank_retrain_action.php`
- Tables: `runpod_spend_log`, `lora_eval_scores`, `lora_production_promotions`, `frank_retrain_strategy`

## Last updated

2026-06-08 — initial. Source: Ruben session — "max RunPods, ignore budget, continuous; show the method; never stale; never skip; deployed column."

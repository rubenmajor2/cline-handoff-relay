# 149 — Every RunPod training pod launch MUST follow the full checklist (keep-alive + dashboard + checkpoint-rescue), never an ad-hoc pod

Permanent rule. Workspace-scoped. Source: 2026-06-09 — the 120B distill was launched 8 times by an ad-hoc script and all 8 died (orphan-killed, $15, 0 steps) because they skipped the proven launch path: wrong purpose tag (reaper killed them), no SSH-wait, no corpus upload, not registered for the dashboard or checkpoint-rescue. Ruben: "anytime that you mint a pod in runpod, do all these things and follow the proper process so that the pod continues running and so that you enter the proper information on the page. That way we can track what's going on."

## The bright-line rule

**Never `POST /pods` ad-hoc to start a training run. Always launch through the proven path (`scripts/frank_train_launch.php`) OR, if you must hand-roll, you MUST replicate ALL of the following or the pod will be killed and/or invisible.** A RunPod training pod is not "launched" until every box below is checked.

## The 6-point launch checklist (all mandatory)

### 1. Protected purpose tag (or the reaper kills it in 15 min)
The `runpod_spend_log.purpose` MUST match a reaper-protected pattern: `lora`, `train`, `nightly`, `adapter`, `distill`, OR the `pod_name` contains `distill`/`120b`. The reaper (`cron_runpod_orphan_reaper.php`, every 15 min) kills any pod whose purpose matches NOTHING as an orphan at the 15-min grace — before SSH even comes up. Canonical purpose: `emsu-lora-keeper-<size>` / `emsu-lora-keeper-<size>-distill`.

### 2. `triggered_by='frank_train_launch'` (or checkpoint-rescue skips it)
The checkpoint-rescue cron (`frank_adapter_rescue_cron.php`, every 5 min) selects `WHERE terminated_at IS NULL AND triggered_by='frank_train_launch'`. If your spend_log row doesn't have that exact `triggered_by`, **your checkpoints are NEVER pulled to WOPR and are LOST when the pod terminates.** Launching via `frank_train_launch.php` sets this automatically.

### 3. SSH-wait + corpus upload + detached train (the actual "keep it running")
- Wait for SSH with a real loop (frank_train_launch.php waits 90×10s = 15 min). A bare image needs time to come up; a short wait = false "SSH never came up" abort.
- scp the corpus + train.py to `/workspace/`.
- Launch training **detached** (`nohup ... & disown`) so it survives the launching process exiting.
- Add the dashboard's probe pubkey (`/var/www/.ssh/id_ed25519.pub`) to the pod's `authorized_keys` so the page can read progress (frank_train_launch.php does this).

### 4. Register the pod for the dashboard + rescue
Add a line to `/etc/emsu_runpod_train_pods.env`:
```
PODID|PUBLIC_IP|SSH_PORT|/workspace/train_outer.log|HUMAN LABEL|TOTAL_STEPS
```
This is what makes the row on `routes/llm_router_live.php` show a live **progress bar + ETA + checkpoints** (the registered-pod probe path in `cron_train_status_snapshot.php`). Without it the row is metadata-only. Also remove terminated pods from this file so the page doesn't probe dead hosts.

### 5. Checkpoints to durable storage (so you CAN take it offline mid-run)
The train script MUST write checkpoints to `/workspace/output` on a cadence (`save_strategy="steps"`, `save_steps=25`, `save_total_limit=6`, + a 30-min `TimedCkpt` callback). The rescue cron rsyncs `/workspace/output → WOPR ARCHIVE_<run>/` every 5 min. **This is what lets you terminate a pod 30 min in and resume from the last checkpoint** — but only if #2 (`triggered_by`) and #5 (checkpoints actually being written) are both true. Verify the rescue is pulling (`/var/log/emsu_frank_rescue.log` is fresh) before trusting that a mid-run terminate is safe.

### 6. Dependency stack correct for the base model (or 0 steps)
gpt-oss/120b bases need `transformers==4.56.2` + `kernels==0.4.4` (older raises `model type gpt_oss not recognized`; unpinned `>=4.55` pulls 5.x which breaks on `kernels`). The 7B/14B/32B/70B keepers use the pinned `<4.50` stack. `frank_train_adapter.py` selects by base model — keep it that way. See PROJECT_FRANKENSTEIN.md §6.1.1.

## The canonical launch (use this, it does 1-3 + 6 for you)

```
sudo -u www-data php /var/www/emtskills/scripts/frank_train_launch.php \
  "<BASE_HF>" "emsu-lora-keeper-<size>[-distill]" "<size>" "<CORPUS_PATH.jsonl>"
```
Then do #4 (register in `/etc/emsu_runpod_train_pods.env`) and verify #5 (rescue log fresh). Example (120B distill, verified 2026-06-09):
```
sudo -u www-data php /var/www/emtskills/scripts/frank_train_launch.php \
  "unsloth/gpt-oss-120b-unsloth-bnb-4bit" "emsu-lora-keeper-120b-distill" "120b" \
  "/var/www/emtskills/_scripts/frankenstein/distill_train.jsonl"
```

## The verify-before-you-walk-away check (all must be true)

1. `runpod_spend_log` row exists with a protected `purpose` AND `triggered_by='frank_train_launch'`.
2. Pod is in `/etc/emsu_runpod_train_pods.env` (so the page shows the bar).
3. `routes/llm_router_live.php` row shows a real status (LOADING WEIGHTS / TRAINING N/total), not "probe blind" or a stale "DONE".
4. `/var/log/emsu_frank_rescue.log` is fresh AND lists your pod (so checkpoints reach WOPR).
5. The train script writes checkpoints to `/workspace/output` on a 30-min cadence.

If any is false, the pod is at risk of being killed, invisible, or losing its work. Fix it before moving on.

## What "probe blind" means (and the fix)

The dashboard runs as `www-data`. If the pod-probe SSH key isn't www-data-readable (e.g. `/home/emsuserver/.ssh/id_ed25519`), every RunPod row shows "probe blind / SSH not answering" forever. Use `/var/www/.ssh/id_ed25519` (www-data-readable + authorized on pods by the launcher). Fixed in `cron_train_status_snapshot.php` 2026-06-09.

## Cross-references

- `.clinerules/92` — fix at the core (the launch path IS the fix, not babysitting each pod)
- `.clinerules/138` — fast-train levers + weight-rescue hardfloor (pull weights BEFORE any gate)
- `.clinerules/145` — every LLM training run must surface on the dashboard
- `.clinerules/29` — act on the money-burn (an unprotected/unregistered pod is silent waste)
- `PROJECT_FRANKENSTEIN.md` §6.1.1 — the gpt-oss dependency pin + launch path (project-frankenstein MCP)

## Source incident

2026-06-09 — 8 ad-hoc 120B distill pods, all orphan-killed, $15, 0 steps, because they skipped the proven path: `purpose=auto-detected` (reaper killed them), no SSH-wait, no registration (invisible on the page), no `triggered_by` (no checkpoint-rescue). The proven `frank_train_launch.php` path booted clean on the first try (SSH up in 11s, corpus uploaded, training launched). The dashboard separately showed false "DONE" (shard-bar misparse) and "probe blind" (unreadable SSH key) — both fixed same session.

## Last updated

2026-06-09 — initial. Source: Ruben directive to codify the RunPod launch process so pods keep running and the dashboard tracks them.

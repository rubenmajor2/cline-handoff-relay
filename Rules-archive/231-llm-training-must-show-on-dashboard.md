# 145 — Every LLM training run (local OR RunPod) must be tracked live on llm_router_live.php

Permanent rule. Workspace-scoped. Source: 2026-06-09 Ruben directive — "needs to be updated each time there's a change in runpod status so i can see what's actually training. Whenever there is training of an LLM it needs to be tracked here: https://emsuniversity.com/emtskills/routes/llm_router_live.php"

## The bright-line rule

**Any time you launch an LLM training run — on a local box (cato/cesar GB10), on a RunPod pod, or anywhere else — it MUST appear as a live phase on the training dashboard (`routes/llm_router_live.php`), updating automatically.** Ruben watches that page to see what is actually training. A training run that does not show up there is invisible to him and violates this rule.

The dashboard reads `/tmp/emsu_train_status.json`, written every 60s by `cron/cron_train_status_snapshot.php` (emsuserver crontab). The page is light; the cron does the polling (rule 92: heavy work in cron). So "make it show on the dashboard" = "make the snapshot cron detect your run."

## How to register a run so it shows up

### Local box training (cato/cesar)

The cron already detects specific local trainers by process name + log path. If you launch a NEW local trainer script (different filename / log / output dir than the ones already wired), you MUST patch `cron_train_status_snapshot.php` to also pgrep your script + parse its tqdm log, exactly like the existing `train_120b_unsloth.py` / `train_120b_distill.py` blocks. Verify by running the cron AS emsuserver (`php cron/cron_train_status_snapshot.php`) and confirming your phase appears in `/tmp/emsu_train_status.json`.

### RunPod training (the 2026-06-09 mechanism)

The cron reads a registry file: **`/etc/emsu_runpod_train_pods.env`**, one line per active training pod:

```
PODID|IP|SSHPORT|LOGPATH|LABEL|TOTALSTEPS
```

Example:
```
q3oq63qe5xom5w|38.80.152.146|32009|/workspace/distill_train.log|120B distill retrain (paired corpus)|907
```

The cron SSHes each registered pod (via `sudo -n ssh -i /var/www/.ssh/id_ed25519`, emsuserver has NOPASSWD sudo), greps the tqdm step line + `ADAPTER_COMPLETE` from the log, and emits a `RunPod training — <LABEL>` phase with TRAINING / STARTING-DOWNLOADING / COMPLETE / UNREACHABLE status.

**So: when you mint a RunPod training pod, immediately append its line to `/etc/emsu_runpod_train_pods.env`.** When the run completes (adapter pulled back + pod terminated), REMOVE its line so the dashboard doesn't show a stale/UNREACHABLE phase.

## The lifecycle obligations (do all of these)

1. **On launch:** append the pod line to `/etc/emsu_runpod_train_pods.env` (RunPod) OR patch the cron for a new local trainer. Verify the phase shows by running the cron once as emsuserver.
2. **During:** nothing — the cron auto-updates every 60s. Status flips STARTING/DOWNLOADING → TRAINING (with step/total/ETA) → COMPLETE on its own.
3. **On completion:** after `ADAPTER_COMPLETE`, pull the adapter back (rsync to WOPR + the box), **TERMINATE the RunPod pod** (it bills until deleted: `curl -X DELETE https://rest.runpod.io/v1/pods/<id>` with RUNPOD_API_KEY), and **REMOVE the pod's line from `/etc/emsu_runpod_train_pods.env`** so the dashboard goes clean.

## Self-check before walking away from any training launch

1. *Did I launch an LLM training run this session?* If yes →
2. *Does it show on llm_router_live.php?* Verify by running `php cron/cron_train_status_snapshot.php` as emsuserver and checking `/tmp/emsu_train_status.json` has a phase for it. If not → register it (RunPod env line OR cron patch).
3. *Is it a RunPod pod?* → its line is in `/etc/emsu_runpod_train_pods.env`, AND my pickup prompt says to terminate the pod + remove the line on completion.

## Cross-references

- Rule 92 — fix at the core (the cron polls; the page stays light)
- Rule 114 — RunPod B200-first GPU chain
- Rule 138 — Fast Frankenstein fast-train levers
- Rule 29 — act on confidence (register the run yourself, don't defer)

## Files

- Dashboard: `routes/llm_router_live.php` (masteradmin-gated)
- Snapshot cron: `cron/cron_train_status_snapshot.php` (emsuserver crontab, every 60s)
- Snapshot output: `/tmp/emsu_train_status.json`
- RunPod registry: `/etc/emsu_runpod_train_pods.env`
- SSH key for pod polling: `/var/www/.ssh/id_ed25519` (root, via emsuserver NOPASSWD sudo)

## Source incident / last updated

2026-06-09 — Ruben moved the 120B retrain from cato (~20hr) to a RunPod B200 (~1-1.5hr). The dashboard only knew about local trainers, so the RunPod run was invisible. Ruben: "needs to be updated each time there's a change in runpod status so i can see what's actually training... whenever there is training of an LLM needs to be tracked here." Patched the cron to poll `/etc/emsu_runpod_train_pods.env` pods; verified "RunPod training — 120B distill retrain" shows TRAINING with live step/total. This rule makes dashboard-visibility mandatory for every future training run.

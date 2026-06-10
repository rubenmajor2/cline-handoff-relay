# 146 — Consult the training runbook BEFORE any model train. Never re-derive the env from scratch.

Permanent rule. Workspace-scoped. Source: 2026-06-09 Ruben directive verbatim:

> *"You need to be documenting and learning this and then whenever you do training consulting the documentation / could be in the MCP or could be Kaizen or wherever, whatever, but as a cline rule, I want you to do that so you don't have to keep reinventing the wheel."*

## The bright-line rule

**Before launching ANY LoRA/distill/fine-tune run (RunPod, cato/cesar, or any box), the FIRST move is to read the canonical training runbook — do NOT improvise the pip install, the model load, or the launch shape from memory.** Re-deriving the environment is the #1 time sink and the #1 cause of failed runs. The pinned, known-good recipe already exists. Use it.

## Where the canonical recipe lives (in priority order)

1. **`project-frankenstein` MCP `fast_train` action** (or `frankenstein_fast_train`) — the 4 levers + durable-storage hardfloor. Call this FIRST.
2. **`fleet_mint_train` / `fast_train_runbook` MCP tools** (fleet-state MCP) — the mint chain + on-pod bringup.
3. **`/var/www/emtskills/_scripts/frankenstein/frank_lora_train.sh`** — the LIVE, working on-pod trainer with the EXACT pinned dependency versions that are proven to import and train. This is the source of truth for the dependency block.
4. **`FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md`** on WOPR + `.clinerules/138`.

## The pinned dependency block (the thing I keep re-deriving wrong)

The working 70B/distill trainer pins EXACT versions. Unpinned `pip install unsloth trl datasets bitsandbytes` installs a BROKEN unsloth (e.g. `UnslothGKDTrainer.py: SyntaxError: non-default argument follows default argument`) and a bitsandbytes that fails on `libnvJitLink.so.13`. The proven block (from frank_lora_train.sh, 2026-06-06):

```
pip install "transformers==4.46.3" "peft==0.13.2" "trl==0.12.1" "accelerate==1.1.1" \
    "tokenizers==0.20.3" "bitsandbytes>=0.49.2" "datasets==3.1.0" sentencepiece
pip install --force-reinstall regex safetensors "huggingface_hub==0.26.2"
pip install rich
pip install "torch==2.9.1+cu128" torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
python3 -c "import transformers,peft,trl,bitsandbytes; print('versions ok')" || exit 3   # GATE before train
```

Note: the 70B path uses **plain transformers + BitsAndBytesConfig(nf4)**, NOT unsloth — it's more robust on RunPod images. Prefer that path unless the model specifically needs unsloth (gpt-oss MXFP4). Always run the `import` GATE line and abort if it fails, BEFORE downloading 60GB of base weights.

## The other hard-won lessons (cross-ref the rules that already encode them)

- **Durable-storage hardfloor (rule 138):** pull the adapter to WOPR/`/var/www/frank_adapters/` BEFORE any gate/eval/terminate. RunPod spot B200s get reclaimed mid-run (happened 3× on 2026-06-09: q3oq63qe5xom5w @ step 11, pt3lw673xzd0vh, plus the relaunch). Always deploy a WOPR-side auto-pull watcher right after launch so a reclaim never destroys the run.
- **Use SECURE (on-demand) not spot for short critical runs** — spot reclaim wastes more time than on-demand costs.
- **xet always off on RunPod:** `HF_HUB_DISABLE_XET=1` (xet → "Disk quota exceeded"). Cache to container disk (`/root/hfcache` or `/tmp/hf_cache`), not a network volume.
- **No nested heredocs through the emsu-operations MCP ssh_command** — the single-quote wrapper mangles them. Write the run script to a WOPR `/tmp` file, `scp` it to the pod, then `nohup bash` it. (rule 41/99 spiral risk otherwise.)
- **GPU mint chain (rule 114):** B200 → H200 → H100 80GB → H100 NVL → H100 SXM → A100. Inject `PUBLIC_KEY` from `sudo -n cat /var/www/.ssh/id_ed25519.pub` (needs sudo; an empty pubkey = a pod you can't SSH into).
- **Registry lifecycle (rule 145):** write the pod to `/etc/emsu_runpod_train_pods.env` on launch, delete the line on terminate.
- **The cron method is the proven monitoring + bringup path (Ruben, 2026-06-09):** register the pod in `/etc/emsu_runpod_train_pods.env` (PODID|IP|SSHPORT|LOGPATH|LABEL|TOTALSTEPS) — `cron_train_status_snapshot.php` reads it every 60s and the run auto-appears on `llm_router_live.php` (rule 145). For bringup, write the run script to a WOPR `/tmp` file, `scp` it to the pod, launch with `setsid bash /workspace/run_train.sh > log 2>&1 < /dev/null & disown` (NOT `nohup ... &` through the MCP, which the ssh wrapper mangles). Arm the durable pull watcher as a standalone WOPR `/tmp` script launched the same setsid way.
- **B200 spot capacity is unstable (2026-06-09):** three B200s reclaimed in a row, even SECURE/on-demand, none finished the base download. When B200 keeps reclaiming, jump to H200/H100 in the rule-114 chain — they were stable. Don't burn three cycles on B200.
- **MCP ssh_command gotchas:** a remote `pkill`/`grep` that matches nothing returns non-zero and the wrapper reports "Command failed" (not fatal). A bare `=` in a remote grep arg and `&` backgrounding both trip the wrapper. Prefer files + setsid.

## Self-check before any training launch

1. *Did I read the runbook / frank_lora_train.sh for the pinned deps?* If no → do it now, don't guess the pip line.
2. *Is there a durable auto-pull watcher armed on WOPR?* If no → arm it before walking away.
3. *Did I gate `import transformers,peft,trl,bitsandbytes` BEFORE the base download?* If no → add the gate.
4. *Spot or on-demand?* Short critical run → SECURE.

## Maintenance — keep this rule learning

When a training run teaches a NEW lesson (a version that broke, a flag that fixed a reclaim, a faster path), append it here AND to `FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md` so the next window inherits it. This rule is the durable memory Ruben asked for — it only works if every run updates it.

## Cross-references

- `.clinerules/138` — fast-train levers + durable-storage hardfloor
- `.clinerules/145` — RunPod train-pod registry lifecycle
- `.clinerules/114` — B200-first GPU mint chain
- `.clinerules/140` / `.clinerules/141` — verify routing/architecture from live, not files
- `.clinerules/92` — fix at the core (the runbook IS the core; re-deriving is the bandaid)
- `frank_lora_train.sh` — the live pinned dependency block (source of truth)

## Source incident

2026-06-09 — during the 120B distill retrain, after two B200 reclaims, I re-derived the pip install from memory with unpinned `unsloth trl datasets bitsandbytes`. It installed a broken unsloth (`UnslothGKDTrainer SyntaxError`) + a bitsandbytes that couldn't load `libnvJitLink.so.13`, wasting two launch cycles. The working pinned block existed the whole time in frank_lora_train.sh. Ruben: "stop reinventing the wheel — consult the documentation, as a cline rule."

## Last updated

2026-06-09 — initial.

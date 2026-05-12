# 51 — Runpod cloud-GPU workflow + offer-to-spin protocol

Permanent rule. Workspace-scoped. Source: 2026-05-11 cloud-GPU fleet session
(10 parallel pods, ~$45/hr). Ruben directive verbatim: *"Put this runpod
stuff in MCP and/or cline rules as well as API access and offer to spin it up
whenever you think it might serve to be beneficial."*

This rule codifies (a) the Runpod API access pattern, (b) the proven mint +
bootstrap + nohup-launch flow, (c) when to OFFER to spin up cloud GPU as a
yes/no question, and (d) where the canonical scripts live.

## API access — keychain-stored, never inline

The Runpod API key lives in **macOS keychain** under service name
`RUNPOD_API_KEY`. Read it with:

```bash
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w)
```

Never paste the key inline in a script committed to the repo. Never log
its value. Use `-H "Authorization: Bearer $KEY"` only.

The API base is `https://rest.runpod.io/v1/`. Useful endpoints:

| Method | Path | Use |
|---|---|---|
| GET | `/pods` | List all running pods |
| GET | `/pods/{id}` | Single pod detail (publicIp, portMappings, status) |
| POST | `/pods` | Mint a new pod (body: `{name, imageName, gpuTypeIds, gpuCount, cloudType, volumeInGb, containerDiskInGb, volumeMountPath, ports, env}`) |
| DELETE | `/pods/{id}` | Terminate a pod (204 on success) |

`gpuTypeIds` is an array of strings. Proven working strings (rank-ordered
by raw compute, highest first):
- `"NVIDIA B200"` — 191 GB VRAM, sm_100, ~$5.49/hr SECURE
- `"NVIDIA H200"` — 141 GB VRAM, ~$3.99/hr SECURE
- `"NVIDIA H100 80GB HBM3"` — 80 GB VRAM, ~$2.99/hr SECURE
- `"NVIDIA H100 NVL"` — 94 GB VRAM, ~$3.07/hr
- `"NVIDIA H100 SXM 80GB"` — 80 GB VRAM
- `"NVIDIA A100 80GB PCIe"` — 80 GB VRAM, ~$1.39/hr

If your first choice 500s with "no resources to deploy", iterate down the
list (mint_one in `/tmp/fleet_mint.sh` does this automatically).

Default image: `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04`.
B200 (sm_100) needs **cu128** torch — the base image's cu124 wheels will
crash with `no kernel image is available for execution on the device`.
Fix is `pip install --index-url https://download.pytorch.org/whl/cu128
torch torchvision torchaudio` early in bootstrap. Verified working.

## The proven mint + bootstrap + launch flow (per rule 95)

The flow has three short Cline tool calls, each well under the 30s wall:

1. **Mint detached.** `nohup /opt/homebrew/bin/bash /tmp/fleet_mint.sh > /tmp/fleet_mint.outerr 2>&1 & disown`
   - Logs to `/tmp/fleet_mint.log`
   - State file at `/tmp/fleet_pods.env` (lines: `POD_<name>=<id>`, `GPU_<name>=<gpu>`)
2. **Orchestrate detached.** `nohup /opt/homebrew/bin/bash /tmp/fleet_orchestrate.sh > /tmp/fleet_orchestrate.outerr 2>&1 & disown`
   - For each pod: poll API for `publicIp` + `portMappings.22`, SSH-probe,
     scp `/tmp/pod_<name>.sh` → `/workspace/work.sh`, nohup-launch detached
   - State file at `/tmp/fleet_ssh.env` (lines: `IP_<name>=...`, `PORT_<name>=...`)
   - Log at `/tmp/fleet_orchestrate.log`
3. **Status check.** `/opt/homebrew/bin/bash /tmp/fleet_status.sh`
   - Reads `/tmp/fleet_ssh.env` and tails `/workspace/STATUS.txt` +
     `/workspace/work.log` on each pod
   - Shows running procs (training, inference, etc.)

**`/opt/homebrew/bin/bash` (bash 5)** is required because macOS default
`/bin/bash` is 3.2 and doesn't support `declare -A` or modern features.
Always use the homebrew path for orchestration scripts.

## Per-pod work.sh pattern

Each pod gets a `work.sh` that:

```bash
#!/bin/bash
set -uo pipefail
exec > /workspace/work.log 2>&1
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# Step 1: deps. ALWAYS pin transformers compatible with the torch version.
#   If B200 (cu128 torch), do NOT use transformers >=4.55 because the MoE
#   custom_op in modeling utils crashes torch.library on torch 2.11.
#   Safe combo:
#     torch (cu128) + transformers==4.54.1 + sentence-transformers==3.4.1
pip install --quiet --upgrade pip
pip install --quiet --index-url https://download.pytorch.org/whl/cu128 \
  torch torchvision torchaudio 2>&1 | tail -3
pip install --quiet "transformers==4.54.1" "peft>=0.13" "accelerate>=1.0" \
  "datasets>=3.0" "bitsandbytes>=0.49" "trl>=0.11" sentencepiece protobuf \
  huggingface_hub

# Step 2: prefetch base model
python3 -c "from huggingface_hub import snapshot_download; \
  snapshot_download(repo_id='Qwen/Qwen2.5-Coder-7B-Instruct', \
                    local_dir='/workspace/base/7b', max_workers=8)"

# Step 3: do the work (LoRA train, embed, eval, whatever)
# Write progress to /workspace/work.log; final state to /workspace/STATUS.txt
# Final line MUST be: echo "=== ALL DONE $(date -Iseconds) ==="
```

For LoRA training, the canonical hyperparams (from v17 30B run, verified):
- `lora_r=16 lora_alpha=32 lora_dropout=0.05`
- `target_modules=['q_proj','k_proj','v_proj','o_proj','gate_proj','up_proj','down_proj']`
- `learning_rate=2e-4 micro_batch=1 grad_accum=8 cutoff_len=1024`
- `num_epochs=1 save_steps=200 eval_steps=100 warmup_steps=20`
- `bf16=True`

## Idle-pod trap (READ THIS)

Spinning up a pod and immediately exiting via `=== ALL DONE ===` while
the data is still being prepped on Mac means the pod sits idle burning
$3-6/hr. Options:

1. **Don't mint until the data is ready.** Stage data on Mac first, scp up
   AT mint, then launch training in the same orchestrate phase.
2. **Have the work.sh script BLOCK on a sentinel.** E.g. `while [ ! -f
   /workspace/data/voice_train.jsonl ]; do sleep 10; done`. Then push the
   data via scp from Mac in a second phase.
3. **Kill the pod immediately** if its work is genuinely awaiting external
   prerequisites that won't be ready for 4h+. Re-mint later.

Approach #1 is best. Approach #2 used in this session for W6/W7/W11 because
data prep was async.

## When to OFFER to spin up cloud GPU

**Offer when ANY of these is true:**

1. **Local Artemis Ollama GPU is saturated or VRAM-pressured.** Symptoms:
   `ollama ps` shows multiple models loading/evicting; the pinned 7B-LoRA
   is splitting CPU/GPU >20%; user reports slow inference.
   → Offer to spin a B200 to run a heavier model variant or batch job.
2. **Inference batch size genuinely > 100 prompts.** A 100-row replay or
   eval is fine on Artemis; a 10K-row backtest is faster on cloud.
   → Offer 1×B200 + parallel inference.
3. **Training/fine-tuning request.** Anything that's `transformers.Trainer`
   over more than 100 rows for >5 min. B200 finishes most LoRA jobs in
   under an hour.
   → Offer the right size: 7B → H100, 14B → H100, 30B → B200.
4. **Embedding a large corpus.** If >5K chunks or any GPU embed model,
   cloud is faster. Under 5K chunks on a CPU model (BGE-small): run
   LOCAL on Mac (faster than spinning a pod, free).
5. **Replay grading at scale.** ab_grader through Haiku for 5K+ pairs
   benefits from cloud-side parallelism.
6. **The user says "as fast as possible" / "no budget".** Take that as
   permission to fan out 5-10 B200s in parallel.

**Do NOT offer when:**

- The task is one-off inference of <10 prompts. Use the live Artemis 7B.
- The job is fully I/O bound (scp, rsync). GPU adds nothing.
- The data is PII and the scrubbing pipeline isn't ready. Scrub first.
- The user is in the middle of an active debug session and the answer
  is in front of them.

## The offer format (yes/no card per rule 05)

```
**Q. Spin up a Runpod B200 for <task name>?**

- **What yes does:** mint 1× B200 (~$5.49/hr), bootstrap with cu128 torch,
  run <task> in nohup detached. ETA <duration>, total cost ~$<amount>.
- **What no does:** keep <task> on the live Artemis 7B-LoRA. ETA <duration
  on local hardware>, GPU contention on Artemis device 1.
- **Scope:** affects this one job; doesn't touch existing pods, doesn't
  change ruben_executor_provider.
- **Risk if wrong:** can terminate pod within 30s via API DELETE; charges
  prorated by-second.
- **Rollback:** `curl -X DELETE -H "Authorization: Bearer $KEY"
  https://rest.runpod.io/v1/pods/<id>` — instant.
```

If Ruben says yes, proceed immediately. If no, route to Artemis.

## Cost guardrails

- **One-pod jobs**: ~$5-15 typical (B200 1-3h). No guardrails needed.
- **Multi-pod fleets (>3 pods)**: surface the burn rate in the offer card.
  E.g. "10 pods × ~$4-5/hr each = ~$45/hr total. ETA 3-4h. Total ~$135-180."
- **Always include the kill command** in the resume kit so future-Cline
  can drain the fleet cleanly without re-reading this whole session.
- **Watch for orphan pods**. The probe-pod failure mode from 2026-05-11:
  a probe API call that returned 201 minted a real pod called
  `cline-probe-b200`. Always list all pods after any mint operation.

## Canonical scripts to copy/adapt

Already on Mac in `/tmp/`:

| Script | Purpose |
|---|---|
| `/tmp/fleet_mint.sh` | Mint N pods in parallel with GPU candidate fallback |
| `/tmp/fleet_orchestrate.sh` | Poll SSH ready, scp work.sh, nohup-launch |
| `/tmp/fleet_status.sh` | One-shot status of every pod (work.log + STATUS) |
| `/tmp/fleet_phase2.sh` | Push data + trigger training on bootstrapped pods |
| `/tmp/pod_*.sh` | Per-workstream work scripts |

These are transient by definition (in /tmp). For durable templates, the
canonical path is `~/Documents/Cline/Rules/templates/runpod/` — copy
clean versions there when a script proves itself.

## Termination + result pull pattern

Always rsync results BACK to Mac/Artemis before terminating:

```bash
# Pull LoRA adapter
rsync -avz -e "ssh -p $PORT" \
  root@$IP:/workspace/checkpoints/<adapter>/ \
  /tmp/<adapter-local>/

# Then terminate
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w)
curl -X DELETE -H "Authorization: Bearer $KEY" \
  https://rest.runpod.io/v1/pods/<id>
```

For Ollama-bound adapters, after rsync to Mac, push to Artemis:
```bash
rsync -avz <adapter-local>/ artemis:/opt/lora-checkpoints/<adapter>/
ssh artemis 'ollama create emsu-<adapter> -f /opt/lora-checkpoints/<adapter>/Modelfile'
```

## Failure modes catalogued (so we don't relearn)

1. **B200 cu124 torch crash**: error `no kernel image is available for
   execution on the device`. Fix: force `pip install --index-url
   https://download.pytorch.org/whl/cu128 torch ...`. Do NOT just
   `pip install torch` — that pulls cu124.
2. **transformers >=4.55 MoE custom_op crash on torch 2.11**: error
   `infer_schema(func): Parameter input has unsupported type torch.Tensor`.
   Fix: pin `transformers==4.54.1` AND keep torch cu128. If you can't,
   fall back to CPU torch (small jobs only).
3. **Mac bash 3.2 `declare -A`**: shebang `#!/bin/bash` won't accept
   associative arrays. Fix: `#!/opt/homebrew/bin/bash` for all
   orchestration scripts.
4. **30s tool wall on sleep+ssh loops**: a 75s sleep blows the tool wall
   even though the background scripts continue. Fix: small sleeps + repeat
   poll, or background the whole orchestrator and tail its log.
5. **scp of 38 MB hits 30s wall**: bigger files take 30-60s. Always
   background scp inside nohup-detached scripts.
6. **probe-pod orphan**: a curl POST that times out on the Mac side may
   still have minted a pod on Runpod. Always `GET /pods` after any
   mint failure.

## Cross-references

- Rule 95 — 30s tool wall + scp-script + nohup pattern (this rule's foundation)
- Rule 17 — default-on subagents (consider for unfamiliar pod recipes)
- Rule 22 — executor self-supervision (cloud jobs are autonomous executors too)
- Rule 29 — act on confidence tier (cloud spin-up is reversible in 30s = green if budget OK)
- Rule 32 — prefer dedicated MCP wrappers (a future `runpod-mcp` would replace these scripts)
- Rule 37 — sink-or-swim, no dry-run (don't propose 24h shadow on cloud; just ship + monitor)
- Rule 40 — Artemis Ollama is the analysis baseline (cloud is the EXTENSION, not the default)
- Rule 44 — Anthropic outage failover (when Anthropic is down, cloud Ollama can pick up some load)

## MCP wrapper (future build)

Currently the Runpod API is hit via curl from shell. The natural next step
is a `runpod-mcp` server with tools:
- `list_pods`
- `mint_pod(name, gpu, disk, image)`
- `bootstrap_pod(pod_id, script)`
- `pod_status(pod_id)`
- `pull_artifacts(pod_id, remote_path, local_path)`
- `terminate_pod(pod_id)`

When that ships, this rule's canonical script paths become MCP tool calls
and the offer-to-spin protocol routes through `mint_pod` directly.

Filed as orchestrator idea slug `runpod-mcp-wrapper-2026-05-11`.

## Last updated

2026-05-11 21:25 PT — initial rule. Source incident: 10-pod parallel fleet
mint (30B v17 retrain + 7B+14B B200 LoRA training + W3 H100 replay + W4-W11
+ W19 measurement workstreams). Total fleet burn ~$45/hr. Ruben directive
in same session: "offer to spin it up whenever you think it might serve
to be beneficial."

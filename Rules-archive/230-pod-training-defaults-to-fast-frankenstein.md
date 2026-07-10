# 144 — Pod training defaults to the Fast Frankenstein method

Source: 2026-06-06 Ruben directive verbatim: *"cline rule, when possible, training on pods should be done using the fast frankenstein method."*

Companion to .clinerules/138 (fast-lora-training-stack — the WHAT/HOW) + .clinerules/140 (frank-lora-serving-architecture) + .clinerules/29 (act on confidence) + .clinerules/92 (work at the core).

## The bright-line rule

**Any time you launch a LoRA/QLoRA training run on a RunPod (or any GPU) pod, the DEFAULT is the Fast Frankenstein method. Slow-method runs require a stated justification.**

The Fast Frankenstein levers (full detail in rule 138 / `fast_train_runbook` MCP tool / `FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md`):

1. **NUM_EPOCHS=1 first** (not 5). Add epochs only if the gate fails for a real reason. ~3-5x.
2. **packing=True** (TRL SFTTrainer concatenates short samples to fill max_seq_length). ~2-3x.
3. **DDP one full replica per GPU** via `accelerate launch --multi_gpu` / `torchrun --nproc_per_node=N`. REMOVE `device_map=auto` from training (it pipeline-shards ONE model = ~1-GPU throughput). Near-linear in #GPUs.
4. **Serve raw LoRA on vLLM** (`--enable-lora` + runtime hot-load) instead of the 60-90min merge→GGUF→ship tail.

The shared on-pod trainer `frank_lora_train.sh` already bakes in packing + BATCH/GRAD_ACCUM. To get the epoch lever you MUST pass `NUM_EPOCHS=1` explicitly (the script + frank_retrain_v2.sh default to higher). Remember the sudo env-var gotcha: `sudo -n -u www-data NUM_EPOCHS=1 bash ...` (assignment AFTER the user spec), or sed the on-pod run.sh — `EPOCHS=1 sudo ...` is STRIPPED.

## When the slow method is allowed (state the reason)

- The gate genuinely failed on a fast run for a real (scored) reason and more epochs is the diagnosed fix — not a harness `<none>` crash (re-gate first per #10212 pattern).
- A research run explicitly comparing epoch counts / sweep.
- Ruben asked for a specific slow config.

Otherwise: fast by default. A slow launch with no stated reason is a rule violation — you're burning $5.89/hr pods for no reason.

## Pull-before-gate still applies (138 hardfloor)

Fast does NOT mean skip the gate-independent safety pull. Per rule 138, pull the adapter to `ARCHIVE_<run>/` BEFORE any gate decision, every time. A crashed gate eval must never destroy the only copy. Fast + safe, not fast + reckless.

## Corpus problems are not speed problems

If an expert fails the gate at 17-25% repeatedly, faster pods will NOT fix it — that's a distill-corpus / eval-set problem (re-gate the ARCHIVE adapter, audit row count + label balance + eval-vs-corpus distribution). Don't reflexively relaunch a fast pod against a bad corpus. See #10212.

## Self-check before any pod training launch

1. *Am I passing `NUM_EPOCHS=1` (or a stated higher count with a reason)?* If running default high epochs unintentionally → stop, add the flag.
2. *Is packing=True inherited (shared trainer) or set?* Yes via frank_lora_train.sh — confirm if using a different launcher.
3. *Did I keep the pre-gate safety pull?* Must be yes.
4. *Is this a corpus problem masquerading as a training problem?* If the expert failed before at low %, re-gate / audit corpus first.

## Which MCP owns this (decided 2026-06-06)

**The Frankenstein lifecycle (corpus → fast train → rescue-pull → gate → vLLM serve) belongs in the dedicated Frankenstein MCP, NOT Fleet MCP.** Ruben asked which one owns it; the answer is Frankenstein MCP because: (1) he explicitly wants a surface named "Frankenstein MCP"; (2) Fleet MCP (fleet-state) is infrastructure STATE — inventory, routing map, failover, spend — and read-only; (3) the Frankenstein lifecycle has its own ACTIVE verbs (launch_fast_train, rescue_pull, run_gate, serve_lora_shm, route_ready) that form one cohesive domain. The read-only `fast_train_runbook` doc-tool MAY stay mirrored in fleet-state as a cross-pointer (rule 138 references it there), but the active train/gate/serve tools (#10198/#10195/#10200) live in Frankenstein MCP.

## Cross-references

- .clinerules/138 — fast-lora-training-stack (the runbook this rule enforces as default)
- .clinerules/140 — frank-lora-serving-architecture
- .clinerules/29 — act on confidence (q5: verify the fix actually worked end-to-end)
- .clinerules/92 — work at the core
- `fast_train_runbook` MCP tool (currently fleet-state; doc-mirror only) — read at runtime before launching
- Frankenstein MCP (#10200) — canonical home for train/gate/serve tools
- Ideas #10185 (packing fix), #10212 (corpus-not-speed), #10198/#10195/#10200 (serve side)


## Last updated

2026-06-06 — initial. Source: Ruben directive after a code70b babysit where plan_summary + ticket_triage were (correctly) retried with the fast method, confirming it should be the default for all pod training, not a special case.

# 138 — Fast LoRA training stack (applies to ALL EMSU model training) + never let a gate delete weights

Permanent rule. Workspace-scoped. Source: 2026-06-06 — an 8-hour single-GPU 70B
LoRA run was watched live by a babysitter window; two prior runs (code70b_2ep,
code70b_3ep) had already been DESTROYED by a crashed gate eval. Ruben: "this is
complete garbage... we need to speed up this training significantly... 30-60
minutes... do whatever it takes to make it work reliably" and then "Can this be
used for all LLM training... if so we've made a fundamental breakthrough and
needs to be captured so it's not forgotten or lost."

Full runbook: `/Users/rubenmajor/Desktop/FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md` and
WOPR `/var/www/frank_adapters/FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md`.

## Honest scope (do not oversell)

These are STANDARD industry techniques, not novel ML. They feel like a
breakthrough only because the EMSU pipeline used NONE of them. The win is real
for us (~10-70x) but it is catching up to best practice, not advancing the
field. Apply broadly; describe accurately.

## The stack — applies to every task_kind through frank_lora_train.sh

All EMSU adapters (classify, student_email_reply, plan_summary, ticket_triage,
cline_code_turn, code70b) share ONE trainer. Fix the trainer once → all benefit.

Four compounding levers:
1. **1 epoch first** (was 5) — ~3-5x. Add epochs only if the gate fails.
2. **packing=True** (was False) — ~2-3x. TRL SFTTrainer concatenates short
   samples to fill max_seq_length.
3. **DDP, one full replica per GPU** via `accelerate launch --multi_gpu` /
   `torchrun --nproc_per_node=N` — near-linear in #GPUs. **REMOVE
   `device_map="auto"` from training** — it pipeline-shards ONE model and runs
   at ~1-GPU throughput while looking like it uses all GPUs. A 4-bit 70B QLoRA
   replica fits in ~40-45 GB, so one per 80GB H100/B200.
4. **Serve the raw LoRA on vLLM** (`--enable-lora` + runtime hot-load of
   adapter_model.safetensors, `VLLM_ALLOW_RUNTIME_LORA_UPDATING=true`) — skips
   the 60-90 min merge→GGUF→ship delivery entirely. Pass the adapter name as the
   `model` field in the OpenAI-compatible request.

device_map="auto" = model parallel (slow for training). DDP = data parallel
(fast). For TRAINING always use DDP. device_map is fine for single-GPU inference
only.

## Lever sizing depends on corpus shape (2026-06-06 measured nuance)

Packing's speedup is NOT fixed — it depends on how long your examples already
are. Measure before assuming:
- **Short examples** (style/format tasks like classify, email): packing gives
  the full ~2-3x because there's lots of padding to reclaim.
- **Long examples** (code corpus: 6863 rows, ~18.9M tokens, median ~2600 tok,
  p90 ~3400): examples already nearly fill max_seq_length=4096, so packing only
  cut steps 2571→1746 (~1.5x). NOT 8x.

For a big/long corpus the dominant lever is **epochs**, not packing. The code70b
run only became fast (582 steps, ~3.5h) when set to NUM_EPOCHS=1; at 3 epochs it
was still ~11h even WITH packing. Lesson: packing is a free win to always keep
on, but on a large corpus you MUST also drop to 1 epoch to get the real speedup.
Measure token-length distribution first (`chars/3.5 ≈ tokens`) to predict which
lever matters.

## The sudo-env-strip gotcha (cost a wasted 11h relaunch)

`EPOCHS=1 sudo -n -u www-data bash script.sh` does NOT pass EPOCHS through —
sudo strips the environment, so the script uses its own default (was 5/3).
The env assignment must come AFTER the user spec:
`sudo -n -u www-data EPOCHS=1 bash script.sh`. Verify it landed by grepping the
on-pod run.sh for NUM_EPOCHS before walking away. If a run is already going with
the wrong epochs, you can sed the on-pod /workspace/run.sh + kill the python PID
+ relaunch run.sh ON THE SAME WARM POD (model still cached in /tmp/hf_cache → 4s
reload vs 2.5min re-download) instead of re-minting.

## The `tar cf - | tar xf -` streaming principle (Ruben 2026-06-06)

Streaming beats materialize-an-intermediate. Maps to training in TWO places, but
NOT the third:
- ✅ **Delivery**: vLLM live-LoRA (lever #4) IS the streaming path — raw 1.6GB
  adapter hot-loaded onto a resident base, vs merge→GGUF→quant (3 disk
  materializations, 60-90 min). This is exactly `tar | tar` vs `tar cf; tar xf`.
- ✅ **Staging**: stream the base model pod→pod with
  `ssh src 'tar cf - -C /workspace/base_model .' | ssh dst 'tar xf - -C /workspace/base_model'`
  instead of each pod re-downloading from HF. Keeping a pod warm is the strongest
  form (don't re-materialize what's in memory).
- ❌ **Training compute itself** is FLOPs-bound, not I/O-bound. tar|tar saves
  I/O only, so it CANNOT speed up the gradient steps. Don't conflate "skip the
  intermediate artifact" with "do less compute" — different bottlenecks.


## Hardfloor: a gate result must NEVER be able to destroy the only copy of weights

The same incident destroyed two good adapters because:
- adapter pulled to WOPR **only on gate PASS**
- `term_pod` hard-DELETEs the pod **unconditionally** after the gate
- pods are ephemeral `containerDiskInGb`, **no network volume**
- the gate eval crashed → wrote no result → read as "none" → FAIL → DELETE

So a *broken eval* (not a bad model) deleted hours of compute. "none" on BOTH
Sonnet and Opus judges = systematic eval crash, never a real quality signal.

**Rule: pull first, judge second, terminate last.** Always SCP the adapter to
`ARCHIVE_<run>/` BEFORE the gate decision. Run an independent rescue watcher
(`frank_adapter_rescue.sh`) that pulls weights the instant
adapter_model.safetensors exists, decoupled from the success path. Never gate
before the artifact is safe on durable storage.

## Self-check before launching ANY LoRA training run

1. Is this 1 epoch with packing=True? If 5 epochs / packing=False, fix it first.
2. Is it DDP (multi-replica) or accidentally device_map="auto" single-proc? Use DDP.
3. Is there a pull-before-gate archive + rescue watcher so a crash can't delete weights?
4. Can the result be served as a raw vLLM LoRA instead of a 90-min GGUF? Prefer that.

## Cross-references

- .clinerules/29 (act on confidence), .clinerules/92 (fix the core not bandaids)
- Runbook: Desktop + WOPR FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md
- Fleet MCP: add fast-train + rescue as a documented capability

## Open verification (not yet proven on our fleet as of 2026-06-06)

- 8-GPU DDP 70B QLoRA end-to-end run + gate PASS — projection until a real run lands.
- vLLM runtime LoRA hot-load on vllm-70b-tools-v4 — confirm --enable-lora +
  VLLM_ALLOW_RUNTIME_LORA_UPDATING before relying on it.

Mark DONE only after a measured run.

## Last updated

2026-06-06 — initial. Source: the 8-hour-train incident + Ruben's "capture this
breakthrough" directive.

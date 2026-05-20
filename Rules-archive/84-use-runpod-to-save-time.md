# 84 — Use RunPod cloud GPU to save time (default-on for long sequential work)

Permanent rule. Workspace-scoped. Source: 2026-05-15 20:30 PT cline task
`#fleet-agent-status-2026-05-15`. Ruben directive verbatim: *"Please use the
runpods to save time, especially for the 30b if possible. cline rule and rule
for Fleet Agent to consider run pods to save time for iniital machine setup."*

This rule extends .clinerules/51 (Runpod workflow exists; offer-to-spin
protocol) with a stronger default. Rule 51 said *"offer to spin up when
relevant."* Rule 84 says *"if the work is long, sequential, and
parallelizable, **default to RunPod** — don't ask, ship."*

## Why this rule exists (the gap)

Rule 51 codified the API access, the mint/bootstrap/launch flow, and a
yes/no offer card. But the card is friction. On 2026-05-15, a 30B backtest
was about to be queued 5-day-sequential on local Artemis when the right
move was obviously a single H100 pod for ~$30 over 4-8 hours. Ruben had
to manually tell Cline *"use the runpods to save time."*

That manual nudge should never have been necessary. If wall-clock matters
and the work is parallelizable, RunPod is the answer. Rule 84 makes the
default explicit so future-Cline ships cloud GPU without prompting.

## The bright-line rule

**Any work that would take >6 hours sequentially on local hardware AND is
parallelizable defaults to RunPod.** No offer card needed under cost
guardrails (see below). Just ship.

"Parallelizable" means the work can be sliced into independent units
(rows, prompts, training steps, conversion blocks) without losing
correctness. If it can't be parallelized AND it's >6h, surface the
sequential cost to Ruben as a Q-card — but that's a rare case.

## Where local Artemis IS the right move (exception list)

RunPod is the default for long parallel work. Local Artemis stays the
right call when:

1. **Inference on already-loaded models** — <10s per call, low volume
   (<100 prompts). Artemis's pinned 7B-LoRA + 14B already-warm wins on
   latency. Don't spin a pod for 20 chat turns.
2. **Quick smoke tests** — verifying a script runs end-to-end on tiny
   input (10-50 rows). Cloud spin-up overhead alone is 2-5 minutes;
   the smoke is done in 30s locally.
3. **WireGuard-local network access required** — anything that needs to
   reach `admin_portal` DB, the EMSU Rails app, internal MCP tools that
   only resolve on WG. RunPod pods are on public internet; they can't see
   the WG mesh. Run from Artemis.
4. **Student PII touches** — per .clinerules/02 (no apologies in student
   emails, but also no PII surfaces) and .clinerules/15 (no internal
   reasoning narration). Any pipeline that handles SSN/DOB/address/
   transcript data stays inside the WG perimeter. Scrub on Artemis, push
   scrubbed-only to cloud if needed.
5. **Active debug session where the answer is in front of you** — per
   rule 51's "don't offer" list. Same applies here. Don't spin a pod for
   a one-line config fix.

## Where RunPod is default-on (trigger list — ship without asking)

If the task hits ANY of these, mint the pod immediately:

1. **LoRA training of any base model >7B.** 14B/30B/70B all default to
   cloud. Even 7B if the dataset is >5K rows. Canonical: 30B → 1×H100 or
   1×B200, training completes in 2-6h vs 3-7 days locally.
2. **Backtests >500 rows.** Replay grading, ab_grader sweeps, agent
   evals over historical traces. Cloud parallelism with 5-10 pods
   collapses days into hours.
3. **Embedding batches >5K rows.** Per rule 51's threshold. BGE-small on
   CPU loses to a single B200 once you cross 5K chunks. Mint, embed,
   rsync embeddings back, terminate.
4. **Quantization/conversion of any 7B+ model.** GGUF conversion, AWQ,
   GPTQ, EXL2 — these saturate CPU+RAM on Artemis for hours per model.
   A B200 with 191 GB VRAM does it in minutes. Use the canonical
   conversion template.
5. **Initial machine setup / model warmup / artifact ingestion >2h.**
   Specifically named in Ruben's directive: *"rule for Fleet Agent to
   consider run pods to save time for iniital machine setup."* If a new
   Fleet Agent or new Artemis instance needs to pull 5-10 base models,
   warm caches, and ingest a large artifact tree, doing it on cloud with
   parallel downloads and then rsync-ing the warmed artifacts down is
   often faster than sequential local pulls.
6. **Any task where wall-clock matters and the cost is <$100.** If Ruben
   has signaled "as fast as possible" or "by EOD" or "before the staff
   call" — and the cloud spend is under $100 — ship. Don't ask. The cost
   is dwarfed by the value of finishing the day with the result.

## Cost guardrails

The default-on posture only holds inside these cost lanes:

- **Single-pod jobs <$50 estimated total**: ship without asking. Mint,
  run, rsync back, terminate. Note it in the resume kit.
- **Single-pod jobs $50-$100**: ship, but note the spend in the next
  Ruben-facing message (one line: *"Spent ~$72 on H100 for the 30B
  backtest — finished in 4.2h vs ~5d local."*).
- **Multi-pod fleets (>3 pods)**: surface the burn rate in an offer
  card per rule 51. *"6 pods × ~$4/hr = ~$24/hr, ETA 3h, total ~$72.
  Ship?"* — even though the total may be under $100, parallel-pod
  failure modes (orphan pods, region exhaustion) deserve a moment of
  Ruben confirmation.
- **Always include the kill command in the handoff/resume kit.** Per
  rule 51 cost guardrails section. Format:
  `KEY=$(security find-generic-password -s RUNPOD_API_KEY -w); \
   curl -X DELETE -H "Authorization: Bearer $KEY" \
   https://rest.runpod.io/v1/pods/<id>`
- **Daily total cap: $200** across all jobs unless Ruben explicitly
  approves a larger burn. If a single day's cumulative cloud spend
  approaches $200, pause and surface the running total before minting
  the next pod.

## The mechanic (per rules 51 + 95)

Use the canonical templates at `~/Documents/Cline/Rules/templates/runpod/`:

- `fleet_mint.sh` — mint N pods with GPU fallback chain
- `fleet_orchestrate.sh` — poll SSH, scp work.sh, nohup-launch
- `fleet_status.sh` — one-shot status across all pods
- `fleet_phase2.sh` — push data + trigger training on bootstrapped pods

The 3-step flow stays:

1. `nohup /opt/homebrew/bin/bash /tmp/fleet_mint.sh ... & disown`
2. `nohup /opt/homebrew/bin/bash /tmp/fleet_orchestrate.sh ... & disown`
3. `/opt/homebrew/bin/bash /tmp/fleet_status.sh`

Each step is well under the 30s tool wall per rule 95. State files at
`/tmp/fleet_pods.env` and `/tmp/fleet_ssh.env`.

## The 30B canonical example (the trigger for this rule)

The 30B backtest in handoff 6087 is the canonical case study:

- **Local Artemis path**: 30B Q4 quantized model running sequentially
  through ~10K replay pairs at ~30s/pair = ~83 hours = ~3.5 days
  wall-clock, with GPU contention against the live 7B-LoRA serving
  production. Realistic ETA including babysitting: 5 days.
- **RunPod H100 path**: 1× H100 80GB at $2.99/hr, full-precision 30B in
  VRAM, batched inference at ~5s/pair = ~14 hours wall-clock. With
  bf16 + flash-attn and proper batching, often 4-8 hours. Total cost
  $12-$24.

**5 days of waiting → 4-8 hours of $30 GPU spend.** This is the shape
of decision that rule 84 makes automatic. Don't ask. Mint the H100.

For >30B (70B, 120B) the same logic with a B200 ($5.49/hr) instead.

## What this means for Fleet Agent specifically

Per Ruben's directive ("rule for Fleet Agent to consider run pods to save
time for iniital machine setup"), Fleet Agent gets the same default-on
posture for setup-class work:

- New Artemis bootstrap (10+ base models to pull): mint a B200,
  parallel-download all models there, rsync the warmed `~/.ollama/models/`
  tree back over WG. Faster than sequential `ollama pull` on Artemis.
- New LoRA adapter ingestion across multiple base models: convert/quantize
  on cloud, push final artifacts back.
- Backfilling embeddings for a new RAG corpus: cloud-side embed, rsync
  index back.

Fleet Agent's offer card from rule 51 still applies for ambiguous cases.
But the trigger list above is default-on for Fleet Agent too.

## Anti-patterns (don't do these)

1. **Queueing a 3-day sequential job on Artemis without mentioning the
   cloud alternative.** This is the failure mode that prompted the rule.
   If you're about to `nohup python train.py` for >6h, stop and re-route
   to RunPod first.
2. **Spinning a pod for a 5-minute job.** Bootstrap alone is 2-5 minutes.
   The pod-mint-bootstrap-rsync overhead has to be amortized over real
   work. Don't use cloud for trivial tasks.
3. **Forgetting to terminate.** Idle B200s cost $5.49/hr = ~$132/day.
   Always include the kill command in the resume kit AND set a mental
   timer to verify termination after rsync completes.
4. **Letting the pod sit idle waiting on Mac-side data.** Per rule 51's
   idle-pod trap section. Stage data on Mac first, scp at mint, then
   launch training in the same orchestrate phase.
5. **Pushing PII to a public-internet pod.** Scrub first on Artemis.
   Always.
6. **Multi-pod fleet without surfacing burn rate.** Even if total spend
   is under $100, >3 pods is enough complexity to deserve an offer card.

## Cross-references

- Rule 02 — no apologies / no PII in student emails (informs PII scrub
  requirement before cloud push)
- Rule 15 — no internal reasoning narration in student emails (same
  PII-perimeter logic)
- Rule 29 — agents act on confidence tier (cloud spend under $50 with
  reversible API DELETE = green tier, ship)
- Rule 37 — sink-or-swim, no dry-run (don't propose 24h shadow on cloud;
  just ship + monitor work.log)
- Rule 38 — Ruben asks = autonomous-or-shipped (if Ruben names a
  long-running task, default to cloud + ship the result)
- Rule 40 — Artemis Ollama is the baseline (cloud is the EXTENSION for
  long parallel work; inference baseline stays Artemis)
- Rule 51 — Runpod workflow + API access + offer-to-spin protocol (this
  rule's foundation; rule 84 strengthens the default)
- Rule 82 — subagents to develop AND execute plans (dispatch subagents
  to draft work.sh / training configs in parallel with pod minting)
- Rule 95 — 30s tool wall + scp-script + nohup pattern (the execution
  mechanic for all cloud orchestration)

## Source incident

Cline task `#fleet-agent-status-2026-05-15`, 2026-05-15 20:30 PT. Ruben
was reviewing the 30B backtest plan that had it queued sequentially on
Artemis for ~5 days. He named the gap directly: *"Please use the runpods
to save time, especially for the 30b if possible. cline rule and rule for
Fleet Agent to consider run pods to save time for iniital machine
setup."* Rule 84 filed same session.

## Last updated

2026-05-15 20:30 PT — initial rule. Source: cline task
`#fleet-agent-status-2026-05-15`. Extends rule 51 with default-on
posture for >6h parallelizable work.

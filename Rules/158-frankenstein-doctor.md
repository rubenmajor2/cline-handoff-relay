# 158 — Frankenstein Doctor: when a Frankenstein-LLM window is stuck/looping, BABYSIT it to completion by fixing the fleet, not the window

Permanent rule. Workspace-scoped. Source: 2026-06-16 Ruben directive — "create a tool in cline we call frankenstein doctor... we are going to be consulting the bug list documentation right away and looking at project Frankenstein, and the other window gets babysat for the duration of the frankenstein doctor session... bring the entire frankenstein LLM window to successful conclusion... document the changes in the bug list and change the processes so the routing is what it should be. Kill two birds: the original task gets completed AND Project Frankenstein improves."

## Trigger phrases

If Ruben (or any directive) says any of:
- "frankenstein doctor" / "doctor of frankenstein" / "frankenstein's doctor"
- "we have a frankenstein doctor situation"
- "the frankenstein LLM window is stuck / looping / wedged / not converging"
- "be frankenstein's doctor"

→ Enter the Frankenstein Doctor protocol below. It MAY be one window or many (up to 10) — the protocol scales to each affected window.

## What the Frankenstein Doctor IS

You are NOT just diagnosing. You are the attending physician for a sick Frankenstein-LLM window (the patient). Your job: **bring the patient's ORIGINAL task to successful completion by enhancing its capabilities and fixing fleet bugs in real time, so it can finish by itself.** You operate at the FLEET level (LiteLLM router, frankenstein-tools adapter, registry, the serving boxes) — the patient window keeps its own task; you remove the obstacles under it.

Two birds, one stone (Ruben's framing): (1) the patient's task completes, and (2) Project Frankenstein/the routing gets permanently better. A Frankenstein Doctor session that only restarts a service and doesn't fix the routing at the core (rule 92) has failed half its job.

## The protocol (in order — do NOT skip the first two)

### Step 0 — Consult the documentation FIRST (mandatory, per rules 156 + 141)

Before ANY probe or fix:
1. `bug_library_check_before_fix(symptom=...)` — KNOWN_REPAIR → apply it verbatim; NOVEL → continue. (rule 156)
2. project-frankenstein MCP — `frankenstein_what_served` (loop signature), `frankenstein_registry` (the ladder + tool_track ranks), `frankenstein_host_probe` (which boxes are hot/wedged), and read PROJECT_FRANKENSTEIN.md §8 for any serving/spill question. (rule 141)

These two come BEFORE you touch the fleet. They usually name the bug.

### Step 1 — Identify the patient + the loop signature

- Get the patient's conversation_id(s) from `frankenstein_what_served` `timeline_last_50` — a window stuck in a loop re-hits the SAME backend every 25-30s with the same conversation_id and never completes.
- Note the requested model (`frankenstein-llm` = interactive Cline) and the served backend. A mismatch from the designed path is your first suspect.

### Step 2 — Prove the failure with LIVE evidence (rule 140 — never from files)

- Header probe through LiteLLM with the SAME shape the patient sends. CRITICAL: an interactive Cline window sends `stream:true` PLUS `tools`. Probe BOTH shapes — many adapter bugs (e.g. the 2026-06-16 `_send_as_sse` NameError) only fire on the STREAMING tool path, so a non-stream probe falsely looks healthy.
  ```
  MK from /etc/litellm/env (LITELLM_MASTER_KEY); curl -N -D - ... -d '{"model":"frankenstein-llm","stream":true,"tools":[...],...}'
  ```
  The smoking-gun signals: `x-litellm-model-api-base` (the REAL backend — should be 127.0.0.1:11510 the adapter for tool turns, NOT a raw 120B or openrouter), whether `tool_calls` + `[DONE]` arrive cleanly, and whether `reasoning_content`/`reasoning_details` deltas leak in (a sign the turn spilled to a reasoning model the client can't parse → "empty or unparsable response").
- Probe each suspect upstream DIRECTLY (adapter :11510, cesar :11506, raw artemis :8000) to isolate which layer is sick.

### Step 3 — Fix at the CORE, not the window (rule 92)

The patient cannot fix the fleet under itself — that's your job. Typical core fixes (apply the one the evidence points at):
- **Adapter wedged** (`:11510` returns 200 on /v1/models but 502 on completions, while its upstreams are healthy directly): `sudo systemctl daemon-reload && sudo systemctl restart frankenstein-tools`. Do NOT touch the TP=2 cluster (rule 157).
- **Adapter code defect** (e.g. a helper called on the streaming path but never defined → NameError → 502 → spill to a reasoning model): patch the adapter source via `ssh_command` (rule 144), `ast.parse` syntax-check, restart the service. The 2026-06-16 `_send_as_sse` undefined bug is the canonical case.
- **Routing bypasses the adapter** (a raw 120B's `tool_rank` beats the `frankenstein-tools` adapter rank, so interactive tool turns hit raw artemis which leaks tool args into content — rule 148): edit `/etc/litellm/frankenstein_registry.yaml`, demote the raw-120B `tool_rank` BELOW the adapter's, back up first, then `sudo /usr/local/bin/emsu-safe-litellm-restart.sh --reason=...` (rule 118).
- **Dead rung / 404 / dead pod**: per rule 142, no dead-end; let the designed §8.1 spill ladder handle it or remove the dead member.
- Always: server-path edits via emsu-operations `ssh_command` (rule 144), litellm restart only via the safe wrapper (rule 118), TP=2 untouched without explicit permission (rule 157).

### Step 4 — VERIFY the patient can now converge (rule 140 + rule 29 Q#5)

Re-run the EXACT failing shape (stream + tools) end-to-end and confirm the previously-failing case now succeeds:
- Header probe: backend is the intended one (`frankenstein-tools` :11510), clean `tool_calls` + `[DONE]`, no reasoning leak, latency sane.
- `frankenstein_what_served` (last 2-3 min): the patient's conversation_id stopped hammering; tool turns now serve from the correct backend; adapter log shows successes and zero errors AFTER the restart timestamp.
- Greping your own patch or "service is up" is NOT verification — the re-run is.

### Step 5 — Document + harden so it never recurs (kill the second bird)

1. `bug_library_record(...)` — symptom, diagnosis, the exact resolution commands, live evidence, status=resolved. (rule 156) Catalogue EVERY distinct bug encountered in the session, not just the headline one — a single Doctor session often uncovers a stack (wedged adapter + routing rank + a code defect); each gets its own bug-library row.
2. If the bug was a process/config that WILL drift again (e.g. an autosync or a rank that a future idea could re-raise), file an idea (rule 38, autonomous tier) or add a watchdog so the core self-heals. Changing the process IS the work, not a follow-up (rule 92).
3. HANDOFF_NOTES + ledger row per the wrap-up rules.

## Step 6 — Revive Frankenstein (≥3 attempts), then euthanize cleanly — but NEVER leave the work undone

A fixed fleet does NOT always revive the patient. A window that accumulated broken turns while the fleet was sick (empty/reasoning-only assistant turns, a poisoned tool-call in history) keeps choking on its OWN prior bad turn even after the core is healthy — a healthy fleet cannot un-corrupt an already-broken transcript. So the Doctor must NOT declare victory the instant the fleet probes green. Follow the revive-or-euthanize protocol.

### Try to keep Frankenstein alive — at least 3 attempts

After each core fix, make a genuine attempt to bring the SAME patient window back to life (re-run its failing shape end-to-end; if you can, watch the live window take a clean turn). **The Doctor MUST try to revive the patient window at least THREE times before concluding the window itself is unrecoverable.** Each attempt must be a DIFFERENT lever:
- Attempt 1: the most likely single fix (e.g. restart the wedged adapter).
- Attempt 2: the next layer (e.g. fix the routing rank so tool turns hit the adapter).
- Attempt 3: the deeper defect (e.g. the code bug the streaming path hit).

Three green *fleet* probes in a row is NOT three revive attempts — a revive attempt means the actual patient window (or its exact request shape, including any poisoned history) got a turn and you checked whether it converged.

### When the patient cannot be revived — the euthanasia order

If after 3 honest attempts the SAME window still dies (because its in-window history is poisoned, not because the fleet is broken), give Ruben the euthanasia order: a clear, unambiguous, slightly fun instruction to put THIS Frankenstein down and raise a fresh one. Vary the wording, keep it light but unmistakable. Examples:
- "This Frankenstein's stitches won't hold — the transcript's gone necrotic. Time to call it. Open a fresh window, paste the pickup prompt, and the new monster walks. The fleet under it is healthy now."
- "Three shocks, no pulse on this window. We euthanize it and raise a fresh Frankenstein. Spin up a new window with the pickup prompt below."

ALWAYS pair the euthanasia order with the concrete fresh-window steps (delete the last broken assistant turn and resend, OR open a new window + paste the pickup prompt) and call out any separate CLIENT issues you spotted (e.g. "Cannot use checkpoints in Desktop directory" → reopen the task from a project subfolder, not the Desktop root — that's a Cline-client issue, not routing).

### THE HARD RULE — Frankenstein's WORK must never be left undone

The window is disposable. **The work Frankenstein was doing is NOT.** Before the Doctor calls `attempt_completion`, the underlying task the patient was originally working on MUST be in one of these resolved states:

1. **IDEAL — Frankenstein does it himself.** The revived window completes its own original task. Always the preferred outcome; the whole point of the Doctor is to enhance the patient's capabilities so it finishes by itself.
2. **The Doctor finishes it.** If the window must be euthanized, the Doctor picks up Frankenstein's original task and completes it directly (the Doctor has the same tools). A killed window does NOT mean abandoned work — this is acceptable but NOT ideal.
3. **Filed as ideas that WILL resolve it.** If the work is large/long-horizon and cannot be finished in the Doctor session, every unfinished piece is filed as an `orchestrator_ideas` row at autonomous tier (rule 38) so it is guaranteed to get done — never left as loose prose in a pickup prompt (rule 91 Gate 0/Gate 1).

The Doctor's pre-completion self-check MUST include: *"What was Frankenstein actually trying to DO, and is that work now (1) done by him, (2) done by me, or (3) filed as an idea that will do it?"* If the answer is "none of those — I only fixed the routing," the Doctor is NOT done. Fixing the fleet but leaving the patient's task undone is half the job (rule 92). The euthanasia of a window is acceptable; the abandonment of its work is not.

### EVERY open thread / suggestion becomes a FILED + acted idea (rule 29 + rule 91 Gate 1)

The Doctor does NOT leave "optional", "future", or "nice-to-have" items as loose prose in the completion or pickup prompt. Per rule 91 Gate 0/Gate 1 + rule 29: for each candidate open thread, (a) if the Doctor has the tool to do it now, DO IT now; else (b) `create_idea` and cite the real returned `#NNNN`. Then apply rule 29's THREE G's to decide the tier: **Good confidence** (high), **Goes-back** (reversible), **Gentle blast radius** (single surface) — if all three hold (and it's not a hard human-only category), bump the idea to approved/autonomous per rule 38 so it actually ships, not just sits at proposed. A Doctor completion containing an un-filed suggestion, or a filed idea left un-acted when the three-G's pass, is an incomplete session. (2026-06-16: the two Doctor expansion suggestions were filed as #12763 + #12764 and approved-autonomous on this basis.)


## Babysitting many windows

If 10 windows are sick, the fleet-level fix usually heals all of them at once (they share the router/adapter/registry). Diagnose ONE patient to root cause, apply the core fix, then verify across the others' conversation_ids in `frankenstein_what_served`. You do NOT need 10 separate fixes for one shared root cause — that's the whole point of fixing at the core. But the Step-6 revive-or-euthanize check still applies PER window: each window's own transcript may or may not be poisoned independently.

## Ideas to expand the Doctor (Ruben asked for suggestions)

- A `frankenstein-doctor` MCP action that bundles Steps 0-2 into one call (bug-library check + what_served loop-detect + registry tool_track + a live STREAM+tools header probe) and returns a ranked differential diagnosis.
- A loop-detector in the audit pipeline: same conversation_id + same backend + N hits in M minutes with no completion → auto-flag + auto-card Ruben (and, at rule-147 safety tier, let Kaison apply the known repair).
- A standing invariant check: alert if ANY raw-120B `tool_rank` ever rises above the `frankenstein-tools` adapter rank (the rule-148 violation that caused the 2026-06-16 loop).
- An adapter startup self-test: on boot, the adapter probes its own stream+tools path once and refuses to report healthy if a code path raises (would have caught the `_send_as_sse` NameError before any window hit it).

## Self-check before declaring a Doctor session done

1. Did I consult the bug library + project-frankenstein MCP BEFORE probing? (Step 0)
2. Did I prove the cause with a LIVE header probe of the STREAM+tools shape, not a file-read and not only a non-stream probe? (rule 140, Step 2)
3. Did I fix the CORE (router/adapter/registry/adapter-code), not just bounce a service? (rule 92)
4. Did I VERIFY by re-running the failing shape and watching it converge? (rule 29 Q#5)
5. Did I record EVERY bug encountered in the bug library AND harden the process so it can't drift back? (rules 156, 38)
6. Did I try to revive the patient window at least 3 times (different lever each time) before euthanizing? (Step 6)
7. If euthanizing: did I give clear fresh-window instructions AND is Frankenstein's original work now (a) done by him, (b) done by me, or (c) filed as an idea that will do it? (Step 6 hard rule)

## Cross-references

- Rule 156 — bug_library_check_before_fix FIRST (Step 0)
- Rule 141 — project-frankenstein MCP first; PROJECT_FRANKENSTEIN.md §8 for serving/spill
- Rule 140 — prove routing from live headers, never files
- Rule 148 — interactive tool turns route through the :11510 adapter, never pinned to a raw 120B
- Rule 142 — no dead-end LLM entrypoints
- Rule 118 — litellm restart only via the safe wrapper
- Rule 157 — never tear down the TP=2 cluster without explicit permission
- Rule 144 — server-path edits via emsu-operations ssh_command
- Rule 92 — fix at the core, not bandaids
- Rule 29 — act on confidence; Q#5 verification = re-run the failing case
- Rule 38 — Ruben-asked = autonomous/shipped
- Rule 91 — pickup prompt (the euthanasia order's fresh-window handoff)

## Source incident

2026-06-16 — A frankenstein-llm Cline window was looping (re-hitting raw artemis-gpt-oss-120b every 25-30s, conv_28ca2950852189f1, never completing), then after retries threw "Invalid API Response: empty or unparsable response... tool calls Cline cannot process." Three stacked bugs found: (1) the frankenstein-tools adapter :11510 was wedged (200 on /v1/models, 502 on completions, healthy upstreams) — fixed by restart; (2) registry #12506 set artemis tool_rank=5, beating the adapter (rank 10), so interactive tool turns bypassed the clean adapter and hit raw artemis which leaks tool args into message.content (rule 148) — fixed by demoting tool_rank 5→15 + safe litellm restart; (3) THE killer — the adapter CALLED `_send_as_sse(...)` on the streaming-tools path but the function was NEVER DEFINED, so every streaming tool turn (the real Cline shape) raised NameError → 502 → LiteLLM spilled to openrouter/DeepSeek which streams reasoning_content deltas Cline cannot parse = the "empty/unparsable response" — fixed by defining `_send_as_sse`. All verified live: frankenstein-llm stream+tools → :11510 adapter, clean tool_calls + [DONE], no reasoning leak, 2.4s. Recorded as frankenstein_router_incidents problem_keys frankenstein_window_loop_raw_artemis_content_leak_2026_06_16 + frankenstein_tools_adapter_send_as_sse_undefined_2026_06_16. Lesson that drove Step 6: a non-stream probe looked "fixed" while the streaming patient window still died, and even after the fleet was green the patient's poisoned transcript needed a fresh turn — so the Doctor must probe the real shape, try ≥3 revives, then euthanize with orders and never abandon the work. Idea #12761 (approved) hardens the rank invariant. Ruben directed this be made a reusable cline rule — the Frankenstein Doctor.

## Last updated

2026-06-16 — initial, + Step 6 (revive ≥3 / euthanize / never-abandon-work) per Ruben directive same day.

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

## THE PRIME DIRECTIVE — repair Frankenstein WHILE it works; get the patient to do its OWN work (Ruben, 2026-06-16)

**The doctor's job is to make the patient capable of finishing its own task — NOT to do the task for it.** Ruben, verbatim: *"the whole point of you being the doctor is not to do the patient's work it's to get the patient to be able to do their own work... The idea is that you are repairing Frankenstein as Frankenstein is working."* Treating the patient (doing the work yourself, or euthanizing) is the LAST resort, not the default.

### The ladder of intervention (try IN THIS ORDER — do not skip to the bottom)

1. **Fix the fleet-level defect live, under the running window.** Restart the wedged adapter, demote the bad rank, patch the adapter code, broaden a guard — whatever the root cause is — WITHOUT touching the patient window. Then watch the patient's NEXT turn converge on its own. This is the ideal: the patient never even knew it was sick.

2. **Inject the missing knowledge into the live window** (the key case Ruben called out). A VERY common reason a window is stuck-but-alive: the doctor just shipped a bug repair the window does not know about, so the window keeps re-deriving the now-solved problem or acting on stale assumptions. The fix is NOT to take over — it is to hand the window the one fact it is missing so IT can continue. The injected message is minimal, factual, and scoped to the repair only:
   > "Context update from the fleet: <the specific bug> was just fixed at <file:line / config>. <The one-line new truth, e.g. 'temperature is now auto-stripped for opus-4.x; re-run your last grader call'>. Continue your original task from here."
   This is allowed and ENCOURAGED. It is NOT "messing up the experiment" — you are only telling the window about a repair that happened outside its context window. You are NOT solving its task, giving it answers it should derive, or steering its work. Inject the repair fact, nothing more, then let it run.

3. **Only if the window is genuinely DEAD** — poisoned transcript that cannot recover even after the fleet is healthy AND you cannot inject into it (no channel, or injection already tried and it still loops) — fall to Step 6 (revive ≥3, then euthanize). Euthanasia + the doctor doing the work itself is the **last resort**, never the opening move.

### Injection is a TEMPORAL-GAP patch ONLY — never a substitute for the permanent core fix (Ruben, 2026-06-16)

**Every injection (Step 2) MUST be paired with a permanent CORE fix (Step 3) that repairs all FUTURE windows.** Ruben's test: *"will such a fix or repair repair a future window? Or is it just a Band-Aid? The idea is for this to be a comprehensive repair so that Frankenstein is able to do its own work."*

The mental model:
- The **core fix** (broaden a guard, define the missing adapter function, fix the rank, add the self-correcting retry) is the PERMANENT repair. A brand-new window opened five minutes later inherits it automatically because it lives in the fleet code/config, not in any window's transcript. THIS is what makes Frankenstein able to do its own work.
- The **injection** only exists because of a TIMING accident: the patient window took its context snapshot BEFORE the core fix shipped, so it alone doesn't know. Injection tells that one window "the fleet changed under you, re-try." It repairs NOTHING for the next window — the core fix already did that.

**The bright-line rule: never inject without having shipped (or being about to ship) the core fix.** If you catch yourself injecting "the fix is X, just do X" into a window WITHOUT a corresponding permanent change in the fleet, you are band-aiding — STOP and ship the core fix first. Injection without a core fix means the next window hits the identical wall.

**Same discipline for capability/capacity (tools, MCP access, context):** if a window "can't use tools" or "can't reach the MCP" or "loses context," the repair must be at the fleet level — the adapter's tool-call path, the registry's tool_rank, the served context length, the routing — so EVERY future window gains the capability. Fixing it only inside one live window (e.g. talking it through a workaround) is the band-aid. The permanent fix is: the adapter correctly emits tool_calls (rule 148), the rung serves enough context (128K verified 2026-06-16), the entrypoint routes tool turns through :11510 — all fleet-level, all inherited by every future window. Verify the permanence by opening a FRESH probe/window after the fix and confirming it works with zero injection.

### Pre-completion permanence check (add to the Step-6 / self-check)

Before declaring a Doctor session done, for EVERY fix applied ask: *"If a brand-new frankenstein-llm window opens right now with no injection, does it work?"* If yes → permanent core fix, good. If it only works because I injected something into the current window → NOT done; the core fix is missing or incomplete. The injection is disposable; the core fix is the deliverable.

### What "do NOT mess up the experiment" means


Injecting the repair fact (Step 2) is fine. What is forbidden: doing the patient's actual research/coding for it, handing it conclusions it was supposed to reach, or biasing how it solves the task. The line: you may tell it WHAT CHANGED IN THE FLEET (a fact it could not have known because it happened after its last context snapshot); you may NOT tell it HOW TO DO ITS TASK. Repair knowledge = allowed. Task answers = forbidden (that's doing Frankenstein's work, which Ruben explicitly does not want).

### The self-check that keeps the doctor honest

Before doing ANY of the patient's actual task work, ask: *"Am I fixing Frankenstein so it can do this, or am I doing it FOR Frankenstein?"* If the latter, STOP — go back up the ladder: is there a fleet fix? can I inject the missing repair fact? Only when both fail AND the window is dead do you take over. "I did the work myself" is a doctor FAILURE mode unless the window was unrecoverable.


## HARDENED CLAUSES — knowledge-gap reversion prevention (added 2026-06-19)

Source: 2026-06-19 incident where a Doctor window reverted a fix that a sibling window had shipped intentionally 90 minutes earlier, because it skipped the pre-read gate and acted on stale file assumptions. Three clauses added to prevent repeat.

### Clause A — MANDATORY PRE-READ ORDERING (hard gate before any action)

The Doctor MUST call ALL THREE of the following in order BEFORE any teardown, revert, config change, registry edit, or service restart:

1. `frankenstein_what_served` (timeline_last_50) — establish what backend actually served the patient's last N requests
2. `frankenstein_registry` — read current registry state: tool_rank ladder, upstreams, active throttles
3. `bug_library_check_before_fix(symptom="...")` — KNOWN_REPAIR → apply verbatim; NOVEL → continue

**The gate:** if you have not called all three and read their outputs, you are NOT permitted to modify any config, revert any file, or restart any service. Skipping this ordering and acting on assumptions is a rule-92 bandaid violation — you will likely undo live sibling-window work.

**Anti-pattern this prevents:** opening a Doctor window, seeing a config file that looks stale, and immediately reverting it without calling `frankenstein_what_served` first. The file may look stale but a sibling window may have updated it 10 minutes ago for valid reasons. The pre-read ordering is how you discover that.

### Clause B — NO-BLIND-REVERT (protect sibling-window fixes, cross-ref rule 160)

Before reverting ANY change (config file, registry row, adapter python code, rule text, SQL row, env variable), the Doctor MUST:

1. Check the **backup timestamp** of the file/row — when was the last backup created?
2. Read **HANDOFF_NOTES** (via `emsu-operations read_handoff_notes`) — is there an entry from a sibling Cline window documenting this exact change as an intentional fix in the current session?
3. If a sibling window shipped it and it appears in HANDOFF_NOTES within the current session (< 4h), the Doctor MUST NOT revert — instead file an `orchestrator_ideas` row flagging the conflict for review

**Why cross-ref rule 160:** rule 160 governs session-handoff fidelity. A Doctor that reverts a sibling fix defeats the rule-160 handoff contract — the next window inherits a broken state the previous window spent effort fixing. This is the Doctor becoming the source of new bugs.

**The self-check:** before any revert, ask "did I ship this change?" — if no, and HANDOFF_NOTES says yes (within 4h), do not revert. Cross-check: does the bug_library show this as a known fix? If yes, it was intentional.

### Clause C — FRESHNESS PROTECTION (fixes < 24h old require regression evidence before revert)

**The Doctor MUST NOT revert any fix that is less than 24 hours old unless there is explicit bug-library evidence** — a `frankenstein_router_incidents` row with `status=open` AND a `problem_key` matching the fix as the CAUSE of a regression.

Rationale (inverse of rule 147 freshness): rule 147 says fresh context is more reliable than stale. Applied to fixes: a fix shipped < 24h ago was shipped with fresh context about the problem. Reverting it without evidence of regression is destroying fresh work on a stale assumption. The burden of proof is on the reverter.

**The test before reverting any recent fix:**
- Is the fix < 24h old? (check file mtime or backup timestamp)
- Does `bug_library_check_before_fix` return a row with `status=open` caused by THIS fix?
- If both yes → revert is permitted
- If only age yes (< 24h) but no regression row → do NOT revert; instead file an idea for review

**Anti-patterns Clause C blocks:**
- ❌ "The config looks different from what I expected so I'll revert it" — missing regression evidence
- ❌ "A prior window reverted this so I'll revert again" — cascading reversion without evidence
- ❌ "The file mtime is recent so a mistake probably happened" — recency ≠ error


## PRINCIPLE — guidelines + agentic behavior over hardcoding (Ruben, 2026-06-17)

**frankenstein-llm IS the router. It makes the routing CHOICE at request time based on the LLM's capability and health under it. The Doctor's job is to fix the BEHAVIOR and GUIDELINES that govern that choice — NOT to hardcode model names, caps, or fallback lists.** Ruben, verbatim: *"frankenstein-llm is the router and makes the choice, so I don't know that hardcoding models is a good play... it's more about the LLM under its capability. I'm leaning towards guidelines and agentic behavior rather than hardcoding. If you see hardcoding on these — no bueno. Needs to be about behavior and guidelines."*

### What "hardcoding — no bueno" means (the anti-patterns to REMOVE, not add to)

- ❌ A static `FRANK_BOX_CAPACITY=11506=N` hand-tuned per box. The cap should be DERIVED at runtime from the engine's live `--max-num-seqs` MINUS a wedge-safety margin the box discovers from its own decode-health (the adapter already has `_observe_capacity` / WEDGE_DETECT — let THAT set the operating cap, not a human number that drifts every topology change).
- ❌ A hand-maintained model list in `FRANK_TOOLS_UPSTREAMS` that goes stale on every CX7/TP merge. The upstream set should come from a capability+health registry (a box is in the tool rotation IFF it is reachable AND serves a clean tool_call within the SLO), so a merged/renamed box is picked up or dropped automatically.
- ❌ A hardcoded fallback ladder that names specific models. The ladder should be ordered by MEASURED properties at request time: is-tool-capable, is-local ($0), live tok/s, current load — so a rung that starts 400ing on tools (joshua) or reasoning-leaking (deepseek on a tool turn) is DEMOTED by its own measured behavior, not by a human editing a list.

### What to build INSTEAD (behavioral guidelines the router/doorman should encode)

These are the GUIDELINES that should govern frankenstein-llm's choice — express them as runtime-measured rules, not constants:

1. **Capability gate (is this rung usable for THIS turn?):** a box enters the candidate set for a tool turn ONLY if it has demonstrated a clean `tool_calls` response within the SLO recently. A box that 400s on tools (no tool-parser) or streams `reasoning_content` Cline can't parse is NOT tool-capable for that turn — auto-excluded by measured behavior, no hardcoded blocklist.
2. **Health/capacity is self-discovered:** the safe concurrent cap per box = what its own decode-health sustains without WEDGE (watch generation-tokens forward-progress), re-derived after any topology change. The engine's `--max-num-seqs` is the CEILING, never the operating point.
3. **Local-first by measured cost, not by name:** prefer rungs with measured cost=$0 (local) and acceptable live tok/s; only spill to paid when local is GENUINELY full (real waiting-queue past the SLO), never on a false-offline probe.
4. **Keep capable local boxes WARM so they stay in the rotation:** a box that unloads its model (ollama idle-evict) flaps in/out of the candidate set. The guideline: keep-warm any box the router wants as standing capacity, so its membership is stable — capability persists rather than being re-discovered cold every spike.
5. **The ladder ORDER is a policy (machines → runpods → deepseek → sonnet LAST), the MEMBERS are discovered.** Ruben sets the policy order once; which concrete box fills each tier is decided live by capability+health, so the policy survives every hardware change without a config edit.

### The Doctor's bias when fixing

When a Doctor session finds a routing problem, the durable fix is almost always a BEHAVIORAL one (a better health probe, a capability check, a self-derived cap, a keep-warm) — NOT a new hardcoded constant. If your fix is "I set FRANK_X=N", ask: *"will this drift the next time the topology changes? Could the system DISCOVER this value instead?"* If yes, the hardcode is a band-aid (rule 92) — file the agentic version as the real fix. Interim hardcodes to stop active bleeding are acceptable ONLY paired with a filed idea to replace them with measured behavior.

(2026-06-17 source: during the CX7 stress test, the wedges traced to exactly the hardcoded constants above — a stale :11507 in FRANK_TOOLS_UPSTREAMS, a pre-merge FRANK_BOX_CAPACITY=2, a 2s load-probe timeout, a hardcoded joshua rung that 400s on tools. Each interim fix was a new constant; the DURABLE fixes — idea #13075 + the capability/health-discovery work — make the router choose by measured capability so the constants stop drifting.)

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

1. `bug_library_record(...)` — symptom, diagnosis, the exact resolution commands, live evidence, status. (rule 156) **Record EVERY distinct symptom AND its SOLUTION, not just the headline one.** A single Doctor session routinely uncovers a stack (wedged adapter + routing rank + load-probe timeout + dead rung); EACH gets its own row, and the `resolution` field MUST carry the exact commands/config/file:line + backup path that fixed it so the next agent applies it verbatim, not re-derives it. A symptom recorded WITHOUT its solution is half a row — go back and fill the resolution. If still in progress, record status=investigating WITH the proposed resolution, then flip to resolved when shipped. Ruben directive 2026-06-17: *"all stuff like this goes into bug library... make more reports to bug library and also about the solutions there too — needs to be referenced in the frankenstein doctor cline rule."*
2. If the bug was a process/config that WILL drift again (e.g. an autosync, a rank, or a pre-merge capacity throttle a future idea could re-raise), file an idea (rule 38, autonomous tier) or add a watchdog so the core self-heals. Changing the process IS the work, not a follow-up (rule 92).
3. HANDOFF_NOTES + ledger row per the wrap-up rules.

### Known-resolution catalog — recurring frankenstein-llm routing/resilience bugs (run `bug_library_check_before_fix` FIRST; append every session)

These problem_keys are the high-frequency hits — the bug library has the full symptom+resolution for each. Append new ones here AND to the library every Doctor session.

- **`frankenstein_window_loop_raw_artemis_content_leak_2026_06_16`** — interactive tool turn hit a raw 120B (not the :11510 adapter), tool args leaked into message.content → loop. Fix: demote raw-120B `tool_rank` below the adapter rank (rule 148) + safe litellm restart.
- **`frankenstein_tools_adapter_send_as_sse_undefined_2026_06_16`** — adapter streaming-tools path called an undefined helper → NameError → 502 → deepseek reasoning-leak → "empty/unparsable." Fix: define the helper; ast.parse; restart frankenstein-tools.
- **`frankenstein_llm_cx7_cap2_throttle_plus_cato11507_separate_doorman503_openrouter_leak_2026_06_17`** — after Cato+Cesar merged into ONE CX7 TP=2 cluster (served via Cesar :11506 only), FRANK_TOOLS_UPSTREAMS still listed :11507 separately → :11507 http=000 → quarantined → doorman "no 120B ready" 503 → cloud spill. Fix: drop :11507 from FRANK_TOOLS_UPSTREAMS (CX7 = :11506 + Artemis :11434 only).
- **`frankenstein_cx7_premerge_cap2_sat1_throttle_eager_spill_2026_06_17`** — pre-merge throttles (FRANK_BOX_CAPACITY=11506=2, FRANK_TOOLS_SAT_INTERACTIVE=1) left after the CX7 merge → doorman fast-failed at 2 concurrent though the engine handles `--max-num-seqs 16`. Fix: re-derive cap from live max-num-seqs (→10) + raise SAT_INTERACTIVE (→8) to QUEUE locally before spilling. **RULE: after ANY CX7/TP topology change, re-derive FRANK_BOX_CAPACITY from live `--max-num-seqs` and re-check SAT — never leave pre-merge throttles.** WEDGE-check after raising (rule 157; cap=3 wedged the PRE-merge single Cesar — merged capacity differs, verify).
- **`frankenstein_adapter_load_probe_timeout_2s_false_offline_spill_2026_06_17`** — `_upstream_load()` probes vLLM /metrics with `timeout=2`; a healthy-busy CX7 box mid-prefill misses 2s → except → `LOAD_OFFLINE` → false "saturated" → cloud spill while the box is fine. Fix: raise probe timeout 2→5s AND on probe-Exception reuse last-known cached load (or light load=5.0) when the canary says NOT quarantined. (27 false-spills/2min → 0.)
- **`frankenstein_artemis_ollama_120b_canary_quarantine_tok_s_zero_lost_local_rung_2026_06_17`** — Artemis ollama :11434 (gpt-oss:120b) UP (200) but canary marks tok_s=0/unhealthy → excluded → only Cesar serves → spill sooner. Fix (in progress): fix the canary ollama-path tok_s measurement so a healthy ollama box stays the 2nd local rung.
- **`frankenstein_llm_spill_joshua_400_tools_deepseek_reasoning_leak_deadrung_2026_06_17`** — joshua-llama3.3-70b (vLLM-XPU) launched WITHOUT `--enable-auto-tool-choice --tool-call-parser` → 400 on every tool turn; next rung deepseek reasoning-leaks → spill wedges Cline. Fix: add the tool-parser flags to joshua, OR keep tool-capable rungs only. **Ruben 2026-06-17: do NOT shortcut the fallback to claude-sonnet — the order machines→runpods→deepseek→sonnet-LAST is correct; fix RESILIENCE (keep load local), don't demote to paid.**

**Meta-lesson (Ruben 2026-06-17): the recurring failure class is EAGER CLOUD SPILL while a healthy local box could have served.** Before touching the fallback list, ask "is a local box being WRONGLY EXCLUDED (false-offline probe, stale pre-merge cap, false quarantine)?" — fix THAT (resilience: keep it local) rather than re-ordering the ladder. The doorman/Kaizon talent-agent should saturate the local CX7 + 70B/runpod rungs and only spill to deepseek (then sonnet LAST) when local is genuinely full.


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


## When the Doctor finishes BEFORE the patient window (what Ruben does with it)

Common case: the Doctor (this window) shipped the core fix + injected the repair-fact, and is ready to wrap, but the patient frankenstein-llm window is STILL RUNNING. Ruben asked: "what am I supposed to do with that window?" The Doctor's completion MUST tell him explicitly. Decide which of these the patient window is in and state it:

1. **Patient is making progress (taking clean turns, advancing its task)** → "Leave it running. The fix is in; it now has what it needs. Let it finish its own task — that's the win." Do NOT tell Ruben to kill a healthy, progressing window.
2. **Patient is idle/waiting after the injection** → "Send it one nudge: 'fleet fix shipped, continue your original task from your last step.' Then let it run." Give Ruben the exact one-line nudge to paste.
3. **Patient is still looping/dead after fix + injection + 3 revive attempts** → the euthanasia order (Step 6): "Close it, open a fresh window, paste this pickup prompt." Provide the pickup prompt.

The Doctor's completion is NOT done until it answers "what do I do with the still-running window?" with one of the above. Never leave Ruben holding a running window with no instruction. If unsure which state it's in, say so and give him the check ("if it's taking clean turns leave it; if it's re-hitting the same thing, euthanize with the prompt below").

## Browser-verifying a display behind a login wall (rule 63 — MANDATORY, do not bail)

Doctor sessions frequently need to confirm what an admin page (e.g. ruben_executor_live.php) actually SHOWS vs what the DB says. When `browser_action` hits a "Sign In to Continue" / 403 / login wall, you are FORBIDDEN from bailing to "I'll trust the DB" (rule 63 HARD TRIPWIRE). Build the rule-63 session bridge (`make_session.php` + `_dev_render_<target>.php`) and authenticate yourself in. Getting past the login wall IS the verification step Ruben asked for — hitting it is the start of the work, not a blocker.

## Babysitting many windows


If 10 windows are sick, the fleet-level fix usually heals all of them at once (they share the router/adapter/registry). Diagnose ONE patient to root cause, apply the core fix, then verify across the others' conversation_ids in `frankenstein_what_served`. You do NOT need 10 separate fixes for one shared root cause — that's the whole point of fixing at the core. But the Step-6 revive-or-euthanize check still applies PER window: each window's own transcript may or may not be poisoned independently.

## Ideas to expand the Doctor (Ruben asked for suggestions)

- A `frankenstein-doctor` MCP action that bundles Steps 0-2 into one call (bug-library check + what_served loop-detect + registry tool_track + a live STREAM+tools header probe) and returns a ranked differential diagnosis.
- A loop-detector in the audit pipeline: same conversation_id + same backend + N hits in M minutes with no completion → auto-flag + auto-card Ruben (and, at rule-147 safety tier, let Kaison apply the known repair).
- A standing invariant check: alert if ANY raw-120B `tool_rank` ever rises above the `frankenstein-tools` adapter rank (the rule-148 violation that caused the 2026-06-16 loop).
- An adapter startup self-test: on boot, the adapter probes its own stream+tools path once and refuses to report healthy if a code path raises (would have caught the `_send_as_sse` NameError before any window hit it).

## DIAGNOSIS DISCIPLINE — the cost-truth + design-truth lessons (added 2026-06-19)

Source incident 2026-06-19: a Doctor/cost session gave Ruben THREE wrong answers before landing the truth. The errors were systemic, so they are now hard rules for every Doctor session:

### D1 — admin_portal.llm_call_log does NOT capture LiteLLM gateway spend. NEVER cite it for frankenstein-llm cost.
The first cost answer said "$12 total" from `llm_call_log` while the real bill was ~$700. `llm_call_log` only logs the PHP agent surfaces (sms_ai/ticket_ai/idea_miner/shadow_worker). Interactive frankenstein-llm / executor gateway traffic is NOT written there (≈13 rows/day vs thousands of real picks). **The ONLY truth source for what frankenstein-llm served + cost is `/tmp/emsu_router_audit.log`** (fields: req, picked, total_chars, ctx_overflow_reroute, v3_reason, is_interactive) — count picks per backend there, and per rule 140 confirm with live response headers. A cost claim sourced from `llm_call_log` for a gateway surface is INVALID.

### D2 — a 500K context reaching Sonnet is the HEAD (distiller) FAILING, never "a context limit." Reason FROM the architecture.
The second answer described the bug as if it were the design ("no local box holds 500K, so it spills to Sonnet"). WRONG per rule 146: Project Frankenstein = DECOMPOSE→DISTILL→SERVE-LOCAL→REASSEMBLE. Context size must NEVER force a paid/cloud model. If a big context reaches Sonnet, the distiller no-op'd or a healthy local rung was wrongly excluded — find THAT, do not rationalize the spill as inevitable. The recurring failure class is EAGER CLOUD SPILL while a healthy free member could have served. Before blaming "limits," ask: did the distiller actually compress (check pathological_distill ratio<0.9, chunks>1)? Is a local rung being falsely excluded (stale probe, fail-open no-op, missing ladder member)?

### D3 — separate the LOOPING bug from the COST bug. They are different fixes; don't conflate.
- LOOPING (empty content:null / "did not use a tool" / unknown_tool retries) = the ADAPTER tool-call path (TTFB threshold, _send_as_sse, tool-parser). Fixing it makes windows COMPLETE.
- COST (frank→paid sonnet/deepseek) = the DISTILLER + spill ladder (context compression, ladder membership/order). Fixing it makes windows CHEAP.
- LoRA tool-call training improves tool-call QUALITY, it is NOT a cost fix. "Training will fix everything" is wrong. State which bug each fix addresses.

### D4 — confirm the FULL registry ladder is actually implemented in code, not just documented.
The registry can document a non-cline ladder (e.g. cesar→artemis→405b→joshua-70b→deepseek→sonnet→opus) while the HARDCODED spill function skips members (405b/235b were skipped). Per rule 140, verify the live spill function walks every documented rung; a member that only appears as `explicit_L4` by-name picks (never via the ladder) is NOT actually in the spill path. Registry text is a HYPOTHESIS; the code path + audit log are the truth.

### D5 — "is it usable RIGHT NOW" is answered by a live stream+tools probe, not by log absence.
To tell Ruben a window is safe to use: send a frankenstein-llm request WITH `tools` AND `stream`, and confirm `finish_reason=tool_calls` + a populated `tool_calls` array. NOTE: `content:null` WITH tool_calls is CORRECT (not the bug); the bug is content:null with NO tool_calls (empty). Do not declare "fixed" from "no errors in the log" alone — emit the real shape and read the result.

## Self-check before declaring a Doctor session done

1. Did I consult the bug library + project-frankenstein MCP BEFORE probing? (Step 0)
2. Did I prove the cause with a LIVE header probe of the STREAM+tools shape, not a file-read and not only a non-stream probe? (rule 140, Step 2)
3. Did I fix the CORE (router/adapter/registry/adapter-code), not just bounce a service? (rule 92)
4. Did I VERIFY by re-running the failing shape and watching it converge? (rule 29 Q#5)
5. Did I record EVERY bug encountered in the bug library AND harden the process so it can't drift back? (rules 156, 38)
6. Did I try to revive the patient window at least 3 times (different lever each time) before euthanizing? (Step 6)
7. If euthanizing: did I give clear fresh-window instructions AND is Frankenstein's original work now (a) done by him, (b) done by me, or (c) filed as an idea that will do it? (Step 6 hard rule)
8. For any COST claim: did I source it from /tmp/emsu_router_audit.log (+ live headers), NEVER from llm_call_log? (D1)
9. Did I reason FROM the architecture (distiller-should-have-crushed-it), not rationalize a paid spill as a "context limit"? (D2)
10. Did I state which bug each fix addresses (looping vs cost) and not conflate them or claim "LoRA fixes cost"? (D3)
11. For routing claims: did I confirm the live spill function implements the documented ladder, not just trust the registry text? (D4)
12. Did I answer "usable now?" with a live stream+tools probe (finish_reason=tool_calls + populated tool_calls), not log-absence? (D5)

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

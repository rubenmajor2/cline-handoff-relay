# 254 — Verify-before-kill on GPU boxes: ps identity + fleet_inventory + live-probe before ANY kill

Source: 2026-07-04 18:49 PT — Cline agent killed vLLM EngineCore (PID 647224) on Cesar, misidentified as "wedged ollama llama-server." Cesar runs vLLM/Ray TP=2 (NOT ollama). The 43GB "wedge" was normal GPU VRAM for the 120B model. 30min production outage of primary 120B endpoint (WOPR:11506). RCA idea #16459.

## The bright-line rule (run BEFORE every `kill`/`kill -9`/`kill -TERM`/`pkill` on a GPU box)

**Before issuing ANY process kill command on a GPU box, you MUST complete all three verification steps. No exceptions. A kill without verification = production outage risk.**

GPU boxes: cesar, cato, julia, claudia, augustus, tiberius, cicero, artemis, joshua, sms_mac (any host with a GPU serving an LLM).

### Step 1: Verify process identity (`ps -p <PID> -o pid,ppid,user,cmd`)

**Never trust a label, comment, or assumption about what a PID is.** Run `ps` and read the actual command. The Cesar incident happened because the agent labeled PID 647224 "ollama" in a bash comment without ever running `ps -p 647224`. The process was `vllm serve openai/gpt-oss-120b` (VLLM::EngineCore).

```bash
# REQUIRED before any kill
ps -p <PID> -o pid,ppid,user,%mem,%cpu,cmd
```

Read the `cmd` column. If it contains `vllm`, `ray`, `llama-server`, `ollama`, `python.*serve`, `EngineCore`, or any model-serving binary → STOP. This is almost certainly a production LLM process. Do not kill it without:
- Confirming it is actually wedged (Step 3), AND
- Ruben's explicit permission if it's a TP=2 head (rule 157).

### Step 2: Check fleet_inventory for the host's role

**Never assume which box runs what.** Consult `fleet_inventory` (via `fleet_inventory` MCP or `fleet_now`) for the host's `role` field. The box-role map is:
- **Cesar / Cato / Julia / Claudia** = vLLM/Ray TP=2 (gpt-oss-120b) — NOT ollama
- **Augustus / Tiberius** = vLLM TP=2 (405B) — NOT ollama
- **Cicero** = MLX (235B) — NOT ollama
- **SMS Mac** = ollama host (7B/14B/32B/70B) — this IS the ollama box
- **Artemis** = vLLM (120B) + ollama (secondary)
- **Joshua** = vLLM (70B) — NOT ollama

If the host's role is `llm_120b_*`, `llm_405b_*`, or `llm_compute` → any vLLM/Ray/MLX process is production. Killing it tears down a serving cluster (rule 157 for TP=2).

### Step 3: Live-probe the serving endpoint before declaring "wedged"

**High memory usage by a model-serving process is NORMAL, not a wedge.** A 120B model holds 40-80GB GPU VRAM. A 405B model holds 200GB+. This is the model being loaded, not a leak or a hang.

Before declaring a process "wedged" and killing it:
```bash
# Probe the box's serving endpoint (use the box-local port, not WOPR tunnel)
curl -s -m 5 http://localhost:8000/v1/models   # vLLM boxes (cesar/julia/artemis)
curl -s -m 5 http://localhost:11434/api/tags   # ollama boxes (sms_mac)
```

If the endpoint returns HTTP 200 with a model list → the process is SERVING, not wedged. Do not kill it. "High memory" alone is never grounds for a kill on a GPU box.

If the endpoint times out or returns an error → THEN investigate further (check logs, `ray status`, `nvidia-smi`). A kill is the LAST resort, not the first.

## What "wedged" actually means (and doesn't)

**Wedged = the process is not making progress AND the endpoint is unresponsive.** Both conditions must be true. High memory alone is not wedged. High CPU alone is not wedged. A process that is serving HTTP 200 is not wedged, regardless of its resource usage.

The Cesar incident: VLLM::EngineCore held 43GB VRAM and was serving HTTP 200. The agent saw "43GB" + "llama" (wrong — it was vLLM) and concluded "wedged." Neither condition for wedged was true. The process was healthy and serving.

## Rule 157 composition (TP=2 clusters)

Killing the vLLM head process on a TP=2 cluster (cesar, julia, augustus) IS tearing down the cluster. Rule 157 requires Ruben's explicit permission for TP=2 teardown. This rule's Step 1 (ps identity) surfaces whether the process is a TP=2 head BEFORE the kill, giving the agent the information needed to stop and ask.

If `ps` shows the process is a vLLM/Ray head on cesar/julia/augustus → STOP. Do not kill. File an idea or ask Ruben. The only exception is a confirmed runaway process that Ruben has already authorized killing.

## The box-local-port note (rule 253 composition)

When probing a GPU box's endpoint to check if it's wedged, use the **box-local** port (e.g. `localhost:8000` on Cesar), NOT the WOPR tunnel port (e.g. `WOPR:11506`). The WOPR tunnel port lives on WOPR, not on the GPU box. Probing `WOPR:11506` from Cesar's shell will fail (no listener) and give a false "down" signal. See rule 253 §2.

## Self-check before ANY `kill` on a GPU box

1. Did I run `ps -p <PID> -o pid,ppid,user,cmd` and read the actual command? If no → run it now.
2. Does the command contain `vllm`/`ray`/`ollama`/`llama`/`EngineCore`/`serve`? If yes → this is likely production. Do not kill without steps 3-4.
3. Did I check `fleet_inventory` for this host's role? If no → check now.
4. Did I live-probe the box's serving endpoint (box-local port)? If no → probe now. If HTTP 200 → NOT wedged, do not kill.
5. Is this a TP=2 head (cesar/julia/augustus)? If yes → rule 157, need Ruben's permission.
6. Is the ONLY evidence "high memory"? If yes → that's normal for a model-serving process. Not grounds for a kill.

## Banned phrases (self-check before typing the kill command)

- `kill -9 <PID>  # kill the wedged ollama` (you didn't verify it's ollama)
- `kill -9 <PID>  # holding 43GB, must be a leak` (43GB is normal for a 120B model)
- `sudo kill -9 <PID>` on a GPU box without steps 1-3 above
- `pkill vllm` or `pkill python` on a GPU box (too broad, will kill production)

## Cross-references

- Rule 157 — never tear down TP=2 cluster without Ruben's permission (killing the vLLM head IS teardown)
- Rule 252 — stale-info live-probe gate (probe serving ports before declaring any host down)
- Rule 253 — LLM location citation discipline (cite WOPR endpoint, not box port; respect Ray workers)
- Rule 250 — no hardcoded LLM statuses in router config (doorman + reactive quarantine handle liveness)
- Rule 146 — Frankenstein-LLM is the one router; free-local-first
- Rule 29 — agents act on evidence; "wedged" without a probe is not evidence
- Idea #16459 — this rule's source RCA (Cesar vLLM killed, misidentified as ollama)
- Idea #16460 — spill ladder gap (explicit cesar-120b should try Artemis before cloud)

## Source incident

2026-07-04 ~18:00 PT — Cline agent on Cesar executed `sudo kill -9 647224` with bash comment `kill the wedged ollama llama-server holding 43GB`. PID 647224 was `vllm serve openai/gpt-oss-120b` (VLLM::EngineCore), the TP=2 head serving the primary 120B endpoint (WOPR:11506). Cesar runs vLLM/Ray TP=2 (cesar_serve_custom.sh), NOT ollama — SMS Mac is the ollama host. The 43GB was GPU VRAM holding the 120B model (normal). Agent never ran `ps -p 647224`, never consulted fleet_inventory, never live-probed localhost:8000. Result: 30min outage, router spilled to cloud (glm-5.2), no user-facing 502s but avoidable. RCA idea #16459. Router audit log evidence: `req:cesar-120b, picked:glm-5.2` throughout outage.

## Last updated

2026-07-04 — initial. Source: Cesar outage RCA (idea #16459). Composes rules 157, 252, 253, 250 into a pre-kill verification gate specifically for process termination on GPU boxes.
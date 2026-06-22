# 157 — NEVER destroy working serving infra (destructive teardown) without Ruben's EXPLICIT permission. Recovery restarts auto-allowed up to 3 attempts.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-16 — during the Cesar↔Cato CX7 TP=2 bring-up, Cline twice started tearing down the working TP=2 cluster (stopping vLLM + Ray + removing the gptoss-tp2 containers) based on its OWN benchmark interpretation, WITHOUT asking Ruben first. Refined 2026-06-22 — added the destructive-teardown vs recovery-restart distinction (idea #13849) after a Frankenstein Doctor session correctly asked permission for an artemis restart, revealing that non-destructive recovery restarts need a lighter gate.

## The two categories (READ FIRST — which category your command falls into determines the gate)

### DESTRUCTIVE TEARDOWN — ALWAYS requires Ruben's explicit, in-the-moment permission

**Definition:** any command that destroys configured state, removes containers, reverts config, kills engine processes, or alters the topology of a working LLM-serving deployment. These commands are NEVER auto-allowed, regardless of how many times you've tried, what you measured, or how convinced you are.

Destructive teardown includes:
- `docker rm -f <container>` — removing containers (not the same as restart)
- `pkill vllm` / `killall vllm` — killing the engine process
- `ray stop` — tearing down the Ray cluster
- Reverting the adapter config (`kaison-upstreams.conf`) away from a working endpoint
- Reverting the LiteLLM registry to remove or demote a working rung
- Re-enabling watchdog crons that would respawn standalone containers (fighting the current topology)
- Any "revert to the previous setup" action on serving infra
- Any config change that removes or replaces a currently-serving backend

**Gate:** Ruben must say YES, explicitly, for this specific teardown action, in the current conversation. A benchmark number, a measured tok/s, a perf concern, or Cline's own analysis is NOT permission. Cline MUST present the finding and ASK before touching anything.

### RECOVERY RESTART — auto-allowed up to 3 attempts, then requires permission

**Definition:** a non-destructive restart of a running service that preserves ALL configuration, topology, and state. The service comes back up with the same config, on the same port, serving the same model. Nothing about the system's topology changes — this is purely a bounce to recover from a transient wedge/stall/hang.

Recovery restart includes:
- `docker restart <container>` — restarts the SAME container in-place
- `sudo systemctl restart <service>` — restarts a systemd service
- `sudo systemctl daemon-reload && sudo systemctl restart <service>` — reload unit file + restart (only when the unit file change is not a topology/config revert)
- `sudo kill -USR2 $(cat /var/run/<service>.pid)` — graceful reload signal (PHP-FPM style)
- The emsu-operations `reload_php_fpm` MCP tool
- Bouncing a single upstream in the adapter WITHOUT removing it from the upstream list

**Gate (3-attempt protocol, matching rule 158 Step 6 revive):**

1. **Attempt 1:** Run the restart command. Log it to HANDOFF_NOTES: `[RECOVERY RESTART #1] <service> — <reason>`. Wait for the service to come back up (probe health).

2. **Attempt 2:** If the service is still wedged after 1, run the restart again. Log: `[RECOVERY RESTART #2] <service> — still wedged after #1, retrying`. Probe health.

3. **Attempt 3:** If still wedged after 2, run ONE more restart. Log: `[RECOVERY RESTART #3] <service> — final recovery attempt before escalating`. Probe health.

4. **After 3 failed recovery restarts:** STOP. Do NOT attempt a 4th restart or escalate to a destructive teardown. Present the situation to Ruben: "`<service>` has been restarted 3 times and is still not healthy. Here's what I've observed. Do you want me to escalate to a destructive action (docker rm / pkill / config revert)?"
   - Do NOT self-authorize a destructive teardown after the 3rd failed recovery restart. The 3-attempt limit applies to RECOVERY RESTARTS ONLY — it is NOT a countdown that unlocks destructive teardown.

### The boundary cases — when in doubt, treat as DESTRUCTIVE

If you're unsure whether a command is a recovery restart or a destructive teardown, treat it as DESTRUCTIVE and ask Ruben. The default is always "ask first." Specifically:
- `docker stop` + `docker start` = recovery restart (same container, same config)
- `docker rm` + `docker run` = DESTRUCTIVE (removes and recreates — container state/config may differ)
- Restarting a service via the adapter's own endpoint = OK (recovery restart)
- Removing the service from the adapter's upstream list = DESTRUCTIVE (changes topology)
- A watchdog cron that respawns a dead container = OK (it's already dead)
- Re-enabling a watchdog cron that was DISABLED to prevent it from fighting a new topology = DESTRUCTIVE (you're undoing a deliberate topology decision)

## Why this rule exists (the specific failure)

TP=2 was hard to build — it took many hours, a reboot, and root-causing 5+ GB10-specific blockers (per-container VLLM_HOST_IP, Ray OOM-monitor, gpu-util, NCCL-over-TCP vs RoCE, cron port-theft, unified-mem leak). It is expensive and fragile to rebuild. Cline tearing it down on a whim — twice — based on a single-stream microbenchmark that didn't even measure the workload TP=2 is FOR (concurrent + big-context Cline turns) destroyed hard-won work and forced rebuilds. The cost asymmetry is enormous: teardown is one command, rebuild is an hour. So the default MUST be "never destroy working serving infra without an explicit human yes."

The 2026-06-22 refinement adds the recovery-restart allowance because the original rule blocked ALL touch-actions — including simple `docker restart` and `systemctl restart` — which meant even a known-safe recovery bounce required Ruben's permission. During a Frankenstein Doctor session, this worked correctly (artemis restart was gated through Ruben), but the overhead of asking for every single restart is unnecessary when the restart is non-destructive and the Doctor already has a 3-attempt revive protocol (rule 158). The 3-attempt cap prevents infinite restart-looping while allowing legitimate recovery bounces.

## What Cline SHOULD do when it thinks serving infra is wrong/slow

1. **Keep it running.** Do not touch it.
2. **Measure the RIGHT thing.** For TP=2 that means concurrency (multiple simultaneous requests) and big-context prefill latency — NOT a single-stream 100-token generation. A single-stream number understates TP=2 by design.
3. **If it's a transient wedge (service is running but not responding):** Recovery restart, up to 3 attempts. Log each one. If still wedged after 3, present to Ruben — do NOT self-escalate to destructive teardown.
4. **If you think the config/topology needs to change (destructive):** Present the finding + ask. "Here's what I measured, here's what I think it means, here are the options — do you want me to change anything?" Then WAIT for an explicit answer.
5. **Only act on the specific destructive action Ruben authorizes.** "Revert to single-node" from Ruben = permission for that. "Restart it" from Ruben = permission for a recovery restart (don't count it against the 3-attempt cap if Ruben directed it). Cline's own conclusion = NOT permission for destructive actions.

## The self-check before ANY serving-infra action

Before running ANY command on a working LLM-serving deployment, classify it:

1. *Is this a DESTRUCTIVE TEARDOWN?* (`docker rm`, `pkill vllm`, `ray stop`, config revert, adapter revert, watchdog cron re-enable) → STOP. Did Ruben explicitly authorize THIS specific action in THIS conversation? If no → present the finding and ask. Never self-authorize.
2. *Is this a RECOVERY RESTART?* (`docker restart`, `systemctl restart`, `kill -USR2`, `reload_php_fpm`) → How many recovery restarts have I already done on this service in this session? If 0-2 → proceed, log it. If 3 already failed → STOP, present to Ruben.
3. *Am I unsure which category this falls into?* → Treat as DESTRUCTIVE. Ask first.
4. *Is this infra currently serving or successfully built?* → Protected by this rule. A service that is genuinely DOWN (crashed, not "slow") can be restarted as recovery attempt #1.

## Scope

- Primary target: the Cesar+Cato CX7 TP=2 gpt-oss-120b cluster.
- Generalizes to: any LLM-serving deployment that is currently running or that Ruben has signed off on (RunPod pods, Artemis vLLM, Joshua/SMS Mac serving, frankenstein-tools adapter, future clusters).
- Does NOT block: building NEW infra, recovery restarts (up to 3), fixing a genuinely-CRASHED service (recovery attempt #1), or destructive teardowns Ruben explicitly authorizes.

## Audit requirement (recovery restarts)

Every recovery restart MUST be logged to HANDOFF_NOTES with:
- Attempt number (#1/#2/#3)
- Service name
- Reason for restart
- Result of health probe after restart

Format: `[RECOVERY RESTART #N] <service> — <reason>. Post-restart health: <result>.`

This creates an audit trail so a future window (or Ruben) can see the restart history and know whether the 3-attempt cap has been reached.

## Cross-references

- Rule 158 — Frankenstein Doctor (Step 6: 3-attempt revive protocol that this rule's recovery-restart cap mirrors)
- Rule 29 — act on confidence: this rule is the EXCEPTION boundary. Recovery restarts are a green-tier reversible action (auto-allowed up to 3). Destructive teardowns are human-gated — they need explicit sign-off.
- Rule 92 — work at the core: keep the working core running; don't thrash it. Recovery restarts keep it running. Destructive teardowns risk un-building it.
- Rule 137 — Definition-of-Done: "verified working" is the done-state; don't un-do it without authorization.
- Idea #12710 (TP=2 shipped), #12723 (4-blocker root-cause), #13849 (destructive vs recovery refinement), TP2_LAUNCH_README.txt on Cesar.

## Source incidents

2026-06-16 — Cline twice initiated teardown of the live TP=2 cluster (adapter revert + container removal) based on its own 22-tok/s single-stream benchmark, without asking Ruben. Ruben stopped it both times and directed this rule. The benchmark was also methodologically wrong (single-stream doesn't measure TP=2's concurrency/big-ctx advantage).

2026-06-22 — During a Frankenstein Doctor session, the rule correctly gated an artemis restart through Ruben (he gave permission). But the reflection revealed that non-destructive recovery restarts (docker restart, systemctl restart) should be auto-allowed up to 3 attempts — matching rule 158's revive protocol — while destructive teardowns always require explicit permission. Idea #13849 filed. This refinement adds the two-category framework.

## Last updated

2026-06-22 — refined to add destructive-teardown vs recovery-restart distinction per idea #13849. Recovery restarts auto-allowed up to 3 attempts with audit logging; destructive teardowns always require Ruben's explicit permission.
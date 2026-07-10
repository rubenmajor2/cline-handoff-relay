# 139 — Frankenstein / LoRA training windows stall when the ollama endpoint does not actually serve the target model

Source incident: 2026-06-07 — Ruben reported Frankenstein LLM training windows "stuck / spinning for hours, not making progress." Root cause was NOT the training itself. It was a fleet endpoint mismatch that cascaded into a global autonomous-executor throttle.

## The bright-line rule

**Before concluding a Frankenstein/LoRA training window is "stuck," verify the configured ollama endpoint actually serves the model being requested.** A 404 "model not found" on the cheap local draft does NOT stop the work cleanly — it silently falls back to PAID Sonnet, which burns the autonomous hourly rate cap, which snoozes EVERY autonomous chain (not just the training ones) for 65 minutes in a loop. That loop is what "spinning for hours" looks like.

## The exact failure chain (memorize this shape)

1. `orchestrator_config.ollama_endpoint` points at a host/port that does NOT have the model (e.g. `:11434` qwen pool, which has `qwen2.5-coder:7b/14b/32b` but NOT `emsu-qwen2.5-coder:7b-lora`).
2. `LlmRouter::fireOllamaChat()` hits that endpoint → `404 not_found model=emsu-qwen2.5-coder:7b-lora` → auto-pull also fails (`http=500`, can't pull a LoRA tag).
3. predispatch-revival logs `7B saturated, falling back to Sonnet for draft`.
4. Each Sonnet draft counts against `mode=autonomous` hourly cap (cap=100). With every chain falling back, `used` blew past cap to 384.
5. `runOne` gates `rate_limit_exceeded` → `snoozed <slug> 65min (rate-limit gate)`.
6. Repeat next tick. Net effect: 1700+ chains parked in `session_handoffs.dispatch_snooze_until` with reason `rate_limit_gate_snooze`. Training windows look frozen; they are actually waiting out a snooze caused by a dead draft endpoint.

## How to diagnose (fast, read-only)

```
# which port actually serves the LoRA?
for p in 11434 11455 11505; do echo "=== :$p ==="; curl -s -m4 http://127.0.0.1:$p/api/tags | tr ',' '\n' | grep '"name"'; done
# what does cfg point at?
mysql -u adminportal -p... admin_portal -N -e "SELECT JSON_EXTRACT(config_json,'\$.ollama_endpoint') FROM orchestrator_config WHERE id=1"
# how jammed is the queue?
SELECT dispatch_snooze_reason, COUNT(*) FROM session_handoffs WHERE dispatch_snooze_until IS NOT NULL AND status IN ('in_progress','resting') GROUP BY dispatch_snooze_reason ORDER BY 2 DESC;
```

If the cfg endpoint's `/api/tags` does NOT list the requested model, that is the bug.

## The core fix (not a band-aid)

Repoint `ollama_endpoint` to the host that actually serves the model, then clear the snoozes that the dead endpoint caused:

```sql
UPDATE orchestrator_config SET config_json = JSON_SET(config_json,'$.ollama_endpoint','http://127.0.0.1:11505') WHERE id=1;
-- clear ONLY the snoozes the outage caused, leave policy gates alone:
UPDATE session_handoffs SET dispatch_snooze_until=NULL, dispatch_snooze_reason=NULL
  WHERE status IN ('in_progress','resting') AND dispatch_snooze_until IS NOT NULL
    AND dispatch_snooze_reason LIKE 'rate_limit_gate_snooze%';
UPDATE session_handoffs SET dispatch_snooze_until=NULL, dispatch_snooze_reason=NULL
  WHERE status IN ('in_progress','resting') AND dispatch_snooze_until IS NOT NULL
    AND dispatch_snooze_reason LIKE 'predispatch_revival_failed: 7B returned INSUFFICIENT_CONTEXT%';
```

Verify the LoRA answers at the new endpoint before walking away:
```
curl -s -X POST http://127.0.0.1:11505/api/generate -d '{"model":"emsu-qwen2.5-coder:7b-lora","prompt":"say OK","stream":false,"options":{"num_predict":5}}'
```

## Do NOT clear these snoozes (they are correct, per rule 29)

Leave parked: `predispatch_revival_failed: judge rejected: Spec touches refund/AuthNet/Moodle/student/Affirm/outbound`. Those are policy gates doing their job. Clearing them would shove human-required money/grade/comms work through the autonomous path. Only clear snoozes whose reason is an INFRASTRUCTURE failure (dead endpoint, rate-cap blown by that dead endpoint), never a POLICY rejection.

## Why subagents/windows "spin" in general (the answer to Ruben's standing question)

Two distinct causes, both look identical from outside ("spinning, no progress"):
1. **Snooze jam (this rule):** an upstream infra fault (dead draft endpoint, blown rate cap) parks the chain in `dispatch_snooze_until`. The window is alive but gated. Fix the infra, clear the infra-caused snoozes.
2. **Fleet latency (separate):** the 70B host (SMS Mac, `:11455`) is genuinely slow or down — `/api/tags` returns empty. Cold 70B loads are 90-180s; a dead 70B host means the route hangs until timeout. Per Ruben 2026-06-07: fleet is "notoriously slow, needs overhaul" — prefer READING fleet state over firing tools at it. Use `fleet_now` / `fleet_inventory` snapshots, do not re-discover via ssh/grep.

A genuinely-progressing training window writes to its `/tmp/ruben-parallel-idea-*.log` and the nightly log every few minutes. If those timestamps are advancing, it is working (free GPU = good, let it run). If they are frozen AND the chain is snoozed, it is this rule.

## Why subagents stall for hours (Ruben's "stuck spinning" question — 2026-06-07)

"Some subagents spin for hours making no progress, others are fine." Two DIFFERENT things that look identical from outside:

1. **Genuinely working (leave alone):** high tool counts (100-335) at **$0.00** cost = the free local fleet doing real research/build work. Free + busy = good. A working window's `cline_passthrough` rows in `llm_call_log` keep advancing (new `id`s, fresh `ts`). Let these run.

2. **Wedged (must intervene):** the window holds idle ESTABLISHED connections to the litellm tunnel (`127.0.0.1:11505 -> WOPR:4000`) with **0/0 send/recv queues** and makes ZERO new LLM calls — `cline_passthrough` surface frozen at the same `id` for 30+ min while every OTHER surface advances. Cause: a litellm restart (there were 8 in one day from Frankenstein/CATO/Spark deploys) drops `:4000` for ~10s, severing in-flight HTTP streams; the Cline extension host sits on the dead half-open sockets forever because ssh `ServerAliveInterval` only checks the transport, not the HTTP channel inside it.

### How to tell which (fast)
```
# is the subagent surface advancing or frozen?
mysql ... -e "SELECT MAX(id), MAX(FROM_UNIXTIME(ts)), TIMESTAMPDIFF(MINUTE,FROM_UNIXTIME(MAX(ts)),NOW()) min_ago FROM llm_call_log WHERE surface IN ('cline_passthrough','gateway_unattributed')"
# held-idle conns (wedged) on the Mac:
lsof -nP -iTCP:11505 -sTCP:ESTABLISHED | grep -c Code   # high + 0/0 queues + frozen surface = wedged
```
If frozen + held conns: the server is fine (test it — a fresh request returns in <1s). The wedge is client-side.

### Recovery for a wedged window
- **Bounce the launchd tunnel:** `launchctl kickstart -k gui/$(id -u)/com.ruben.cline-router-tunnel` (clears the dead channels; KeepAlive respawns it clean).
- **Then RELOAD the VS Code window** (Cmd+Shift+P -> "Developer: Reload Window"). Cancel+continue does NOT un-wedge an already-poisoned extension host — it just spawns new stalled subagents. Only a window reload clears the poisoned socket state.
- **Durable prevention (shipped):** `~/bin/emsu-cline-tunnel-watchdog.sh` + launchd `com.emsu.cline-tunnel-watchdog` (60s) auto-detects the "connect failed: Connection refused" storm in `/tmp/cline-router-tunnel.log` and auto-kickstarts the tunnel. Idea #10535. Part 2 (a client-side stream-read timeout in Cline so a severed stream aborts the turn instead of hanging) is #10529.

### Do NOT restart litellm carelessly
Each litellm restart wedges every Cline window mid-request. Batch deploys; restart once via `/usr/local/bin/emsu-safe-litellm-restart.sh` (rule 118), and expect the watchdog to heal the tunnel within 60s afterward.

## Cross-references


- `.clinerules/92` — work at the core: fix the endpoint, do not hand-restart each window
- `.clinerules/29` — only clear infra snoozes, never policy gates
- `.clinerules/138` — fast-train runbook (the training method itself — do NOT change it)
- `.clinerules/135` — fleet/routing lives in lib + cfg, single source of truth
- `fleet_now` / `fleet_routing_map` MCP tools — read fleet state, don't grep for it

## Last updated

2026-06-07 — initial. Source: Frankenstein training windows stuck for hours. Real cause: `ollama_endpoint` cfg pointed at `:11434` (no LoRA) instead of `:11505` (has `emsu-qwen2.5-coder:7b-lora`). 404 → paid Sonnet fallback → autonomous rate cap blown (used=384/cap=100) → 1705 chains snoozed in a 65-min loop. Fix: repoint endpoint + clear the 1943 infra-caused snoozes. Frankenstein method itself was untouched.

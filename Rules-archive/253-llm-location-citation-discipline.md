# 253 — LLM location citation discipline (live-probe, cite endpoints, respect workers)

Source: 2026-07-03 Ruben directive — "any agent that calls up information about an LLM has accurate and dynamic information... this issue keeps recurring and causing damage." Filed after a multi-hour detour where an agent declared the healthy Julia+Claudia 120B cluster "down" because it probed the wrong port on the wrong box.

## The bright-line rules (3 of them — all mandatory before citing an LLM location)

### 1. Live-probe, don't trust the cache

**Before declaring where a model is served OR declaring any LLM endpoint down, call `llm_locate(model)` (fleet-state MCP, idea #16346).** It live-probes every known endpoint and returns `live_status: serving|down` with an HTTP code + latency. The `fleet_inventory` table is a stale cache — never cite it as the source of truth for whether a model is up RIGHT NOW. `llm_locate` is the ground truth; it also self-heals `fleet_inventory` as a side effect.

If `llm_locate` is unavailable (MCP down), fall back to a direct `curl -s -m 5 http://<endpoint>/v1/models` against the WOPR tunnel port. Never fall back to "the inventory said so."

### 2. Cite the WOPR endpoint, not the box-local port

**When stating where a model lives, cite the WOPR reverse-tunnel endpoint (e.g. `WOPR:11513`), not the box-local serving port (e.g. `:8000`).** They differ, and the difference is exactly where confusion breeds:

- `WOPR:11513` → the public-facing endpoint (reverse tunnel on WOPR)
- Julia `:8000` → the box-local vLLM port (what WOPR tunnels to)

An agent that probes `:11513` *on Julia's box* will see no listener (because `:11513` lives on WOPR, not Julia) and wrongly declare the cluster down. This exact bug happened 2026-07-03. Citing the endpoint eliminates the ambiguity.

### 3. Never declare a Ray worker down for lacking a listener

**Ray worker boxes (Cato, Claudia, Tiberius) have NO inbound serving port by design (rule 157).** They connect *outbound* to the Ray head's GCS port (e.g. Julia's 192.168.100.2:6379) and contribute their GPU. A worker with no `ss -tlnp` listener is healthy, not down. The cluster serves ONLY via the head box's endpoint.

Wrong: "Claudia has no listeners → Claudia is down → cluster is down."
Right: "Claudia is a Ray worker (rule 157). It has no listener by design. Check the head (Julia) endpoint `WOPR:11513` and `ray status` to verify the worker is connected."

## Read-after-write verification (the discipline that catches the fleet_act trap)

After ANY `fleet_act mark_host_status` call, **re-read `fleet_inventory` to confirm the change landed.** Pre-idea-#16345, `fleet_act` wrote to `fleet_decision_log` but NOT `fleet_inventory`, so the inventory stayed stale while the agent believed it was fixed. Post-#16345, `mark_host_status` updates `fleet_inventory` directly (including `ip_wireguard`/`ip_primary`/`last_heartbeat`/`note_provenance`) — but verify anyway. Trust, then verify.

## Self-check before answering "where is model X served?"

1. Did I call `llm_locate(model)` (or equivalent live probe)? If no → call it now.
2. Am I citing a WOPR endpoint (`WOPR:NNNNN`), not a box port (`:NNNN`)? If no → re-cite.
3. If I'm declaring a box "down," is it a Ray worker with no listener? If yes → it's healthy by design; check the head.
4. If I just wrote via `fleet_act`, did I re-read `fleet_inventory` to confirm? If no → re-read.

## Cross-references

- Rule 157 — worker boxes have no inbound serving port by design
- Rule 248 — verify live state before declaring a box/endpoint down (never trust stale canary/log)
- Rule 252 — stale-info live-probe gate (probe serving ports before declaring any host down)
- Rule 146 — Frankenstein-LLM is the one router; free-local-first
- Idea #16345 — `fleet_act mark_host_status` now writes to `fleet_inventory` directly
- Idea #16346 — `llm_locate(model)` canonical live-probe tool (fleet-state MCP)
- Rule 91 — pickup prompt must cite real endpoints, not placeholders

## Source incident

2026-07-03 19:40 PT — agent reconciled fleet inventory WG IPs for Julia/Claudia/Cato. Pass 1 used `fleet_act mark_host_status` (which didn't update `fleet_inventory`), concluded the inventory was fixed. Pass 2 saw the inventory still stale, wrongly concluded the Julia+Claudia cluster was "down" (it was healthy — the agent probed `:11513` on Julia's box, but `:11513` is a WOPR reverse-tunnel port). Filed idea #16338 (cluster restoration) on bad data; rejected 30 min later after live re-verification. Root cause: no canonical live-probe tool + agent conflated box-local port with WOPR endpoint + forgot rule 157 for workers. This rule + ideas #16345/#16346 are the durable fix.

## Last updated

2026-07-03 — initial. Source: Ruben directive on recurring stale-LLM-location damage.
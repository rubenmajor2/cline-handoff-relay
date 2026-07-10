# 248 — Verify live state before declaring a box/endpoint/service down

Permanent rule. Workspace-scoped. Source: 2026-07-02 Ruben directive — agents must not use stale information and must investigate further before declaring infrastructure down.

## The bright-line rule

**Before declaring a box, endpoint, or service "down" / "dead" / "unreachable" in any handoff, ticket, ops chat, or pickup prompt, you MUST verify live state via a direct probe — never trust a monitoring log, cached health JSON, or canary output as ground truth.**

Monitoring logs (canary health JSON, `/tmp/*_health.json`, syslog, dashboard snapshots) are **observations**, not ground truth. They lag reality by seconds to minutes and can misread transient states (model-load, tunnel reset, prefill burst) as permanent failure.

## What counts as a "direct probe" (do at least ONE)

| Infrastructure type | Direct probe (ground truth) |
|---|---|
| vLLM / Ollama endpoint | `curl --connect-timeout 5 http://<host>:<port>/health` or `/v1/models` |
| Server service | `systemctl is-active <unit>` via SSH |
| Process liveness | `pgrep -f <proc>` or `ps aux | grep <proc>` via SSH to the BOX (not the tunnel) |
| Box reachability | SSH to the box directly (e.g. `ssh -p 2203 rubenmajor@127.0.0.1` for Cesar), not just the WOPR tunnel port |
| Moodle/MySQL/Nginx | `server_status` MCP or `mysql` query, not a stale dashboard cell |

**Key distinction:** probing the WOPR-side tunnel port (`127.0.0.1:11506`) is NOT the same as probing the box. Tunnels reset during model-load and show connection-refused even when vLLM is alive on the box. SSH to the box and probe its LOCAL port (`127.0.0.1:8000` on the box itself).

## Why this rule exists

On 2026-07-02, the Frankenstein canary reported 3 of 4 LLM boxes as "dead" (quarantined, fail_streak=2). I (Cline) trusted the canary JSON and told Ruben the boxes were down. Ruben corrected: "All those systems are up and running properly." Direct SSH to Cesar (:2203) and Julia (:2205) confirmed both vLLM processes were running mid-restart (model-load phase). The WOPR tunnel ports showed connection-reset during load, which the canary misread as permanent death. This caused a false "one-down-all-down" declaration and an unnecessary open-thread list of 3 dead boxes that were actually alive.

Rule 45 covers this pattern for model/API versions ("verify via live source, don't argue from training data"). This rule extends the same principle to **infrastructure state**: verify live, don't trust stale observation.

## The self-check (run BEFORE any "X is down" declaration)

1. *"Is my source a monitoring log, health JSON, or cached dashboard?"* → If yes, do a direct probe before declaring.
2. *"Am I probing the WOPR tunnel port when I could SSH to the box and probe its local port?"* → SSH to the box. Tunnels lie during load.
3. *"Did I check process liveness (pgrep/ps) on the box itself?"* → A dead port doesn't mean a dead process. Verify the process.
4. *"Could this be a transient state (model-load, prefill burst, tunnel reset)?"* → If the box was healthy recently, re-probe in 10-30s before declaring death.

## Anti-patterns that violate this rule

- "Cesar :11506 is down" based on `frankenstein_canary_health.json` showing `healthy: false` — without SSH-ing to Cesar to check `pgrep vllm` or curl its local :8000.
- Listing 3 boxes as "dead" in a pickup prompt open-thread when they're mid-restart.
- Declaring a service down based on a single failed probe without a retry.
- Trusting a stale dashboard snapshot over a live `systemctl is-active`.
- Treating connection-reset-on-tunnel as "box dead" when the box's local vLLM is loading.

## What to do instead

1. **When a monitoring source says a box is down:** SSH to the box directly and probe its local endpoint + check the process.
2. **If the box is mid-load (model shards loading):** state that clearly — "Cesar vLLM is loading (96% shards), not dead" — and monitor for completion. Do not declare it down.
3. **If genuinely dead (no process, no local endpoint):** THEN declare down and route to repair.
4. **In pickup prompts:** only list a box as a dead/open thread after direct verification. Otherwise it's undone work (rule 29 violation — you could have verified).

## Scope

Applies to:
- Any LLM endpoint (vLLM, Ollama, MLX) on any fleet box (WOPR, Cesar, Cato, Julia, Claudia, Artemis, Cicero)
- Any server service (LiteLLM, frankenstein-tools, PHP-FPM, MySQL, Nginx, Redis)
- Any MCP server health claim
- Any "the box is down" / "the service is dead" statement in handoffs, tickets, or ops chat

Does **not** apply to:
- Read-only status checks where you're already calling the live tool (e.g. `server_status` MCP is a live probe).
- Cases where you've already done the direct probe this turn.

## Cross-references

- Rule 45 — verify live source for model/API versions (this rule extends the principle to infrastructure)
- Rule 29 — act, don't defer: verifying live IS the act, not an optional step
- Rule 146 — never declare a box dead without checking `/tmp/emsu_router_audit.log` for recent `picked=<model>` (a failed health probe ≠ dead box)
- Rule 245 — verify host identity before declaring dead (fleet-state)

## Source incident

2026-07-02 11:00-11:15 PT — Frankenstein LLM ECONNREFUSED. Canary reported Julia :11513, Cesar :11506, Artemis-ollama :11434 all "dead." I trusted the canary JSON and declared 3 boxes down in the first completion. Ruben: "I actually believe your information is stale or incorrect or based on stale information. All those systems are up and running properly." Direct SSH verified both Cesar and Julia vLLM processes were running (mid model-load). The doorman's `fail_streak >= 2` exclusion caused the cascade; the stale-info problem was trusting the canary without direct verification.

## Last updated

2026-07-02 11:32 PT — initial rule per Ruben directive: "we also need to add to these tasks the ability for Agents NOT to use stale information and to investigate further."
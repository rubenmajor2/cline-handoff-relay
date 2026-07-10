# 252 — Stale-Info Live-Probe Gate: probe first, report second

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id=252)`.

**Trigger:** Before declaring ANY fleet host "down," reporting fleet state to a human, or acting on a host-status claim from fleet_inventory/heartbeat/prior-window-claim.

## The bright-line rule

**Before declaring a fleet host "down" or reporting fleet state, agents MUST live-probe the serving port. Never trust `fleet_inventory` status or heartbeat age alone.** Probe first, report second.

## The known-broken surface

The heartbeat write path is known-broken (idea #16032). A host can be healthy and serving but show `status=down` with a stale heartbeat in fleet_inventory. Conversely, a prior Cline window's claim that "Julia :11513 is serving ✅" can be days old and inaccurate.

**The rule is:** every fleet-status claim needs a live probe at the moment of reporting. Not a heartbeat timestamp. Not a prior-window memory. A live TCP connect or HTTP request.

## Required probe procedure

For any fleet host whose status you're about to report or act on:

```bash
# Check if the serving port has a listener (run on the host itself via ssh_command or MCP)
ss -tlnp | grep :<port>

# Or from the Mac side (TCP connect — doesn't need credentials):
curl -s --connect-timeout 5 http://<host_ip>:<port>/v1/models 2>&1 | head -5
```

**The `curl /v1/models` test is the canonical live probe.** If it returns JSON model data within 5 seconds, the host is serving. If it times out or connection-refuses, the host is genuinely down.

## Case study (2026-07-03 16:55 PT)

Fleet inventory showed Julia+Claudia as "down" with heartbeat 2026-07-02 00:39. A prior Cline window had claimed "Julia :11513 serving ✅" and reported it as up. When a fresh live probe was actually run — `ss -tlnp` on the host — port :11513 had NO listener. So "down" was correct in THIS case, but the prior window had TRUSTED a stale claim instead of probing.

The fix: **never carry forward a prior-window's "serving ✅" claim without re-probing.** Every status claim is stale the moment it's written. A fresh probe is the only ground truth.

## Rules of thumb

| Situation | Wrong | Right |
|---|---|---|
| fleet_inventory says host X is "down" | Trust it and tell Ruben X is down | Live-probe the port, then report with fresh evidence |
| Prior window said "serving ✅" | Carry that claim forward | Re-probe; prior claim could be hours old |
| Heartbeat age is 24h+ | "Heartbeat's old, must be dead" | Heartbeat path is known-broken. Probe the port. |
| fleet_now shows host missing | "Fleet must have lost it" | Probe the port. Missing from fleet_now ≠ dead. |
| Two hosts show status=down | "Both are out" | Probe both independently. False positive is possible on either. |

## The live-probe-says-up / heartbeat-says-down case

If a live probe confirms the host IS serving but fleet_inventory shows `status=down`, **do NOT mark the host as down.** Report "host is serving per live probe; fleet_inventory heartbeat is stale (known issue #16032)." File a repair idea to update the heartbeat if desired, but do not let a stale DB row override a live TCP connection.

## Cross-references

- Rule 248 — verify live state before declaring box/endpoint down (sibling rule: never trust stale canary/log)
- Rule 251 — Roman CX7 TP=2 ONLY constraint (Julia+Claudia mirror cluster is the failover target for TP=2)
- Rule 146 — frankenstein-llm routing (free-local-first; probe before spill-to-paid)
- Idea #16032 — heartbeat write path known-broken
- Idea #16261 — this rule's source idea
- fleet_inventory MCP — returns status + heartbeat_age (both UNTRUSTED without a live probe)

## Source

2026-07-03 — Ruben directive: "we also need to add to these tasks the ability for Agents NOT to use stale information and to investigate further." Converted from idea #16261. Directly motivated by a 2026-07-03 16:55 PT incident where a prior window claimed "Julia :11513 serving ✅" from stale memory while a live probe showed no listener.

## Last updated

2026-07-03 — initial. Idea #16261.
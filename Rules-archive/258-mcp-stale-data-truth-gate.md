# 258 — MCP stale/empty data truth gate: never report unverified transport-degraded data as fact

Source: 2026-07-06 Frankenstein Doctor incident. Ruben: "Info is stale and incorrect. MCP was down. Need a better rule for all this to avoid stale info coming in and doing damage."

## The failure mode

When MCP transport degrades (supergateway flapping, Cloudflare 502, SSH tunnel drops), MCP tool calls return empty results ("result missing") or stale cached data. The agent then **reports this empty/stale data as ground truth** in its analysis, handoff, or ops message — causing damage:

1. **False alarms**: agent reports "fleet down" when only the MCP probe failed (the fleet is fine)
2. **Wrong root cause**: agent diagnoses "supergateway spawn-storm" when the actual bug is a false-alarm in the smoke cron's NRestarts check
3. **Stale status**: agent reports a host as "down" based on a heartbeat that's 8 hours old, when live-probe would show it serving
4. **Cascade**: the false report gets filed as an idea, messaged to ops chat, and picked up by the next window as "verified" — compounding the error

## The bright-line rule

**Before reporting ANY MCP-sourced data as fact in analysis, handoff, ops message, or attempt_completion, the agent MUST verify the data is fresh and the transport was healthy.** If the MCP call returned empty, stale, or degraded data, the agent MUST either (a) re-probe via a different path, or (b) explicitly flag the data as unverified in the report.

### The 3-gate check (run before citing MCP data as fact)

**Gate 1 — Empty result check:** Did the MCP call return "result missing", empty body, or null? If yes → the transport is degraded. Do NOT report the data. Re-probe via SSH, local shell, or a different MCP server. If no alternative exists, explicitly state "MCP transport degraded, data unverified" in the report.

**Gate 2 — Staleness check:** Is the data timestamp older than 5 minutes for live-state claims (fleet status, host health, LLM serving)? Heartbeats older than 120min are STALE per rule 252/253 — live-probe before citing. If the data is stale → run `llm_locate` or `curl` the endpoint directly before declaring a host down.

**Gate 3 — Cross-source verification:** For material claims (host down, fleet outage, phone line outage), verify across at least 2 independent sources before reporting as fact. Example: fleet_now says "cesar down" → also run `llm_locate cesar-120b` and `curl http://127.0.0.1:11506/v1/models` before declaring it down. If sources disagree → report the disagreement, don't pick one.

### What counts as "material claim"

A material claim is any statement that would cause Ruben or another agent to take action:
- "Host X is down" / "endpoint Y is not serving"
- "Phone lines are dropping calls"
- "MCP is broken" / "supergateway is flapping"
- "All windows failed"
- "Implementation engine has 100% failure rate"
- Any claim that drives an ops message, idea filing, or pickup prompt open thread

## Banned behaviors

- ❌ Reporting "result missing" MCP data as "the system is down" without re-probing
- ❌ Citing a heartbeat older than 120min as proof a host is down without live-probe (rule 252)
- ❌ Filing an idea or sending an ops message based on a single degraded MCP call
- ❌ Using the word "verified" in a pickup prompt when the verification was a degraded MCP call
- ❌ Declaring a root cause ("supergateway spawn-storm") based on event log entries without checking whether the event itself is a false alarm (e.g., NRestarts check bug)
- ❌ Filing a P0 idea with "CRITICAL" in the title based on unverified MCP data

## The re-probe ladder (when MCP data looks wrong or empty)

1. **Retry the same MCP call** (may be a transient supergateway hiccup)
2. **Try a different MCP server** (emsu-operations ssh_command, fleet-state, mysql)
3. **SSH directly** (`ssh_command` with `curl`, `systemctl`, `journalctl`)
4. **Local shell** if the target is the Mac itself
5. If ALL paths fail → report "transport degraded, unable to verify" and stop. Do not fabricate.

## The false-alarm pattern (specific to MCP smoke cron)

The `cron_mcp_initialize_smoke.php` fires `mcp_initialize_failed` events when its `supergatewayStatefulCheck()` returns false. The original implementation checked `NRestarts < 5` — but NRestarts is a **cumulative counter since boot**, not a recent-window counter. Services that had accumulated restarts over days of uptime (mcp-context7: 155, mcp-mysql: 29) were falsely flagged as "UNSTABLE" every 5 minutes, even though they were perfectly healthy.

**Fix applied 2026-07-06 (idea #16643):** replaced `NRestarts < 5` with `ExecMainStartTimestamp` within last 2 minutes. This detects actual recent restarts, not cumulative history.

**Lesson:** before declaring a systemic failure based on event log entries, verify the event generator itself isn't buggy. The smoke cron was the event source, and it had a logic bug. The "supergateway_stateful=UNSTABLE" events were false alarms, not real transport failures.

## Cross-references

- Rule 249 — MCP flapping diagnostic (check NRestarts + uptime first)
- Rule 252 — stale-info live-probe gate (probe serving ports before declaring host down)
- Rule 253 — LLM location citation discipline (live-probe via llm_locate)
- Rule 255 — verify-then-report gate (live evidence required for material claims)
- Rule 29 — act on confidence, but confidence requires verified data
- Rule 91 — pickup prompt must contain verified state, not unverified claims

## Source incident

2026-07-06 20:00-20:15 PT — Frankenstein Doctor session. MCP transport was degraded (supergateway flapping). Agent reported stale fleet data as fact, declared "supergateway spawn-storm returned" as root cause, filed P0 idea #16643, and messaged ops chat 55 — all based on event log entries that were actually false alarms from a buggy NRestarts check. Ruben: "Info is stale and incorrect. MCP was down. Need a better rule for all this to avoid stale info coming in and doing damage."

The actual root cause was NOT a supergateway spawn-storm — it was a **false-alarm bug in the smoke cron's stateful check**. The services were healthy (returning `ok` on /health, session reuse working in journals). The NRestarts counter was cumulative since boot (6 days uptime), not a recent restart indicator. Fix: replaced `NRestarts < 5` with `ExecMainStartTimestamp < 2min` check.

## Last updated

2026-07-06 — initial. Source: Ruben directive after Frankenstein Doctor session produced stale/incorrect analysis due to MCP transport degradation.
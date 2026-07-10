# 245 — Verify host identity before declaring any box dead

Archived rule. Lookup via `clinerules_lookup(rule_id=245)`.

## The bright-line rule

**Before declaring any EMSU host dead, unreachable, or "down," verify its identity from at least two independent sources.** An IP address alone is not a host identity. Stale IPs, DDNS drift, and DHCP reassignment can make a single IP look like a separate dead box when it is actually the same box with a changed address.

## The two-source verification

When debugging an apparent host failure, check AT LEAST two of these before making any claim about host state:

1. **`fleet_inventory` MCP** — returns canonical host list with roles, current IPs, last heartbeat, status. This is the fastest way to see what hosts exist and what their current IPs are.
2. **Reverse DNS on the IP** — `dig -x <IP>` or `host <IP>`. A Spectrum/Comcast/ISP hostname (e.g., `syn-076-176-157-123.res.spectrum.com`) strongly suggests a residential/dynamic IP, not a dedicated server box.
3. **Direct SSH to the host by name** — `ssh wopr.emsuniversity.com` (not by raw IP). The DNS name resolves to the current IP; the raw IP may be stale.
4. **Compare current WAN IP** — `curl -s https://api.ipify.org` from the box itself, then cross-reference with DNS A records and `fleet_inventory`.

**If the IP in an error log doesn't match `fleet_inventory`'s current IP for any known host → the IP is probably stale, not a separate box.**

## What to do instead of declaring it dead

- "Box at X.X.X.X is unreachable" → FIRST run `fleet_inventory` MCP. Does any known host match that IP (or historically have it)? If yes, it's that host, not a new box. The IP changed.
- "Ping to X.X.X.X fails" → check if DNS resolves to a different IP for that hostname. DDNS drift during ISP flaps is the #1 cause of this pattern.
- "Payment sites are down" → the FIRST check is DNS vs WOPR WAN IP (see HANDOFF_NOTES.md runbook), not ping.

## Why this rule exists

2026-07-01: The payment-outage forensics runbook originally described "the on-prem box at 76.176.157.123" as a separate dead host needing an onsite power-cycle. In reality, `76.176.157.123` was WOPR's old WAN IP (pre-ISP-recovery on 6/29). WOPR IS the only on-prem box. The stale IP appeared dead because Spectrum reassigned it after the ISP flap — there was no second box to power-cycle. A `fleet_inventory` call + reverse DNS lookup would have caught this immediately. The cost was a wrong runbook step and a confused recovery path.

## Cross-references

- `fleet_inventory` MCP — canonical host list, always current
- Rule 77 — SSH/WOPR tunnel-down handling, wedged MCP transport
- HANDOFF_NOTES.md § "Payment-Outage Recovery Runbook" — correct DNS-first recovery procedure
- Rule 146 — Frankenstein-LLM routes every LLM; free-local-first design
- Idea #15965 — proactive DNS health monitor (detects DNS drift from WOPR WAN IP)

## Self-check before declaring any box dead

1. Have I called `fleet_inventory` MCP to see the canonical host list? If no → call it first.
2. Have I verified the IP's reverse DNS? If no → `dig -x <IP>` first.
3. Does the IP match a KNOWN host's current IP per fleet_inventory? If yes → it's that host, not a new box.
4. Is the IP close to a known host's IP range or historically associated with one? If yes → probably the same box after IP reassignment.

## Last updated

2026-07-01 — initial. Source incident: payment-outage forensics (6/28-7/1) — stale WAN IP (76.176.157.123) misidentified as a separate dead on-prem box; was actually WOPR's old IP after ISP flap + Spectrum reassignment. Idea #16013.
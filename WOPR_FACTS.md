# WOPR FACTS — instant-recall reference

> ╔══════════════════════════════════════════════════════════════════════╗
> ║  CURRENT STATUS (2026-06-29 21:18 PT): WOPR IS DOWN. GENUINELY         ║
> ║  UNREACHABLE. UniFi UDM (which HAS internet) cannot reach WOPR.        ║
> ║  This is NOT a local network issue and NOT a Cox outage (WOPR is on    ║
> ║  Spectrum Enterprise, not Cox). WOPR needs physical/out-of-band check. ║
> ╚══════════════════════════════════════════════════════════════════════╝

**Living document.** Lives at `/Users/rubenmajor/Documents/Cline/WOPR_FACTS.md` (Mac, authoritative).
Read the BANNER ABOVE first. Newest-relevant-last in the Update history at the bottom.

---

## What/Where WOPR is

| Field | Value |
|---|---|
| **Role** | EMSU production web server + LiteLLM gateway + DB primary (writer lease holder) |
| **Location** | **San Diego, CA** (NOT Oceanside — corrected 2026-06-29) |
| **Internet provider** | **Spectrum Enterprise** (business/enterprise fiber circuit, NOT residential Cox) |
| **Hostname** | `wopr.emsuniversity.com` |
| **Public IP (fleet inventory)** | `76.167.100.188` (Spectrum/Charter AS20001) |
| **WireGuard hub** | `10.100.0.1` : `51820/udp` OPEN + LISTENING |
| **OS** | Ubuntu 24.04 LTS |
| **Hardware** | Plesk + RTX PRO 2000 Blackwell 16GB |
| **Key services** | nginx, PHP-FPM, LiteLLM (:4000), MariaDB (writer), Imunify360, cloudflared tunnel |
| **Reverse tunnels hosted** | SMS Mac (:2223, :11455), M4 Mac (:2224, :11505), Joshua (:2222), Cesar (:2203), Cato (:2204), Artemis (:2225) |
| **Authoritative DNS** | Cloudflare (miki.ns.cloudflare.com + houston.ns.cloudflare.com) |
| **Cloudflare tunnel UUID** | `cc237a4f-2cda-45f2-9d16-6adc4aed0722` |
| **CF API token (on WOPR)** | `/root/.cloudflared/cf_api_token` |
| **LiteLLM config** | `/etc/litellm/config.yaml`, `/etc/litellm/router_hook.py`, `/etc/litellm/frankenstein_registry.yaml` |
| **Web root** | `/var/www/emtskills/` |

---

## How to reach WOPR (priority order)

1. **Direct public IP** — `ssh emsuserver@76.167.100.188` (or whatever the current Spectrum Enterprise IP is). WOPR does NOT answer ICMP ping by design; use a TCP/TLS test, not ping.
2. **Via DNS** — `ssh wopr` (resolves emsuniversity.com). Only works if Cloudflare DNS A record is current.
3. **Via WireGuard mesh** — `ssh emsuserver@10.100.0.1` (requires local WG client up + WOPR WG service alive + Spectrum uplink up).
4. **Via UniFi UDM** — UDM has internet; if WOPR is reachable from UDM but not from Mac, check Mac-side WG. If UDM also can't reach WOPR, WOPR itself is down.

---

## Known SPOF: DDNS updates Plesk, not Cloudflare

`emsu-ddns-sync.sh` on WOPR still updates **Plesk** (no longer authoritative since the HE.net → Cloudflare migration), so the Cloudflare DNS A record can go STALE when the Spectrum Enterprise WAN IP changes. The CF API token lives at `/root/.cloudflared/cf_api_token` on WOPR. Fix = repoint ddns to PATCH the CF apex via CF API (chicken-and-egg when WOPR is unreachable). `emsu-promote` already has the `zones/$ZONE/dns_records` PATCH pattern.

---

## WOPR Outage 2026-06-29

- **Went down** sometime after the 15:15 PT heartbeat.
- **Symptom**: UniFi UDM (which has working internet) cannot reach WOPR. WOPR is genuinely offline — not a local/UDM issue.
- **Both known IPs unreachable** on all ports (22, 80, 443, 4000, 51820, 8443):
  - `76.167.100.188` (fleet inventory, old)
  - `76.176.157.123` (current DNS A record, Spectrum SD)
- **Fleet API + all WOPR-dependent MCPs** returning fetch failures. `emsu-operations` MCP = Not connected.
- **Joshua (Peoria, different ISP)** is alive — confirms this is WOPR-specific, not area-wide.
- **Initial wrong diagnosis**: "Cox outage in Oceanside" — WRONG. WOPR is in San Diego on Spectrum Enterprise, not Cox. Corrected 2026-06-29 per Ruben.
- **Recovery**:
  1. Out-of-band check of WOPR (physical visit OR Spectrum Enterprise support call)
  2. Once reachable: verify/fix Cloudflare DNS A record (may be stale or may need new Spectrum IP)
  3. Verify services: nginx, PHP-FPM, LiteLLM, MariaDB writer lease
  4. Durable fix: rewrite `emsu-ddns-sync.sh` to PATCH CF API instead of Plesk

---

## What WOPR is NOT

- NOT in Oceanside (that was a wrong assumption)
- NOT on Cox (that was a wrong assumption — Spectrum Enterprise)
- NOT answerable by ICMP ping (by design — use TCP/TLS)
- NOT behind Imunify360-only blocking when both UDM and Mac can't reach it (Imunify blocks specific source IPs, not all connectivity)

---

## Cross-references

- `/Users/rubenmajor/Documents/Cline/ARTEMIS_FACTS.md` — Artemis (Tempe GPU box, Cox)
- `/Users/rubenmajor/Documents/Cline/FLEET_IP_BLOCK_RECOVERY.md` — Imunify360 IP-block recovery runbook
- `/Users/rubenmajor/Documents/Cline/HANDOFF_NOTES.md` — Mac-side operational notes
- Rule 144 — never write_to_file on server paths; use emsu-operations ssh_command
- Rule 77 — cline-router / tunnel-down recovery

## Update history

- **2026-06-29 21:18 PT** — initial creation. Corrected facts after wrong Cox/Oceanside diagnosis. WOPR is San Diego / Spectrum Enterprise. UDM has internet but can't reach WOPR = WOPR genuinely down. Persisted to memory MCP (entities: WOPR, UniFi UDM, WOPR Outage 2026-06-29).
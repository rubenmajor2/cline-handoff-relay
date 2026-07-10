# Tempe Office Network — credentials + recovery info

Source: Ruben provided 2026-05-05 18:11 PT during the Artemis pressure-stall incident.

## Cox business handoff
- Handoff Type: Ethernet (Copper)
- Demarc: Customer suite
- Usable IP: **68.227.47.137**
- WAN (Cox-facing) network: 68.227.47.136/31, mask 255.255.255.254
- WAN gateway: 68.227.47.136
- DNS: 68.105.28.16, 68.105.29.16

## NETGEAR router
- Wi-Fi SSID: **NETGEAR85**
- Wi-Fi password: **classycar633**
- Admin URL (on-LAN only by default): http://routerlogin.net  →  resolves to the LAN IP (typically 192.168.1.1 or 10.0.0.1 from inside Tempe)
- Admin user: **admin**
- Admin password: **password** (default; consider rotating)

## Remote admin path
- WAN port 80/443 closed/filtered (not exposed; verified 2026-05-05). NETGEAR remote management is OFF by default.
- To reach from outside: enable Remote Management on the NETGEAR (Advanced → Remote Management) once you're on the LAN, OR enable from the Nighthawk app, OR use NETGEAR's cloud (mynetgear.com).

## What this is for
- Power-cycling the upstream router if Artemis goes into kernel pressure stall and SSH/HTTP become unresponsive.
- Rebooting the router doesn't reboot Artemis directly, but it WILL drop all Artemis's external connections briefly. The kernel scheduler may fire OOM kill once memory pressure changes.
- Best path: use a smart plug on Artemis's power lead (NOT yet installed). Filed as future improvement.

## To set up MCP access (planned)
- Wrap NETGEAR admin into the existing `emsu-operations` MCP — add a `restart_tempe_router` tool that:
  1. SSHes (when Artemis is up) and runs `curl -u admin:password http://routerlogin.net/...` from the LAN side.
  2. Or via NETGEAR cloud API if Ruben enables Nighthawk cloud.
- Filed as orchestrator idea: "tempe-router-power-cycle-mcp-tool".

## Last incident
2026-05-05 18:00 PT — Artemis kernel pressure stall, SSH banner timeout. Snooze shipped on Plesk vhost (returns 503 instantly for cline-tempe URLs). Box would not self-recover. NETGEAR admin not WAN-exposed; no smart plug; AnyDesk Mac app stuck on permissions prompt; RustDesk daemon not on Artemis. Recovery required physical power button.

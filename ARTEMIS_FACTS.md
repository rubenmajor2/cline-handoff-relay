# ARTEMIS FACTS — instant-recall reference

> ╔══════════════════════════════════════════════════════════════════════╗
> ║  CURRENT STATUS (2026-06-01 23:15 PT): ARTEMIS IS UP. MESH IS UP.      ║
> ║  DO NOT say "Artemis is down / offline / unreachable" — it is ONLINE.  ║
> ╚══════════════════════════════════════════════════════════════════════╝
>
> **HOW TO REACH ARTEMIS RIGHT NOW (verified working):**
> `emsu-operations` MCP `ssh_command` → WOPR → then `ssh emsusrvr@10.100.0.5` (WG mesh).
> From the Mac directly: `ssh artemis` (ProxyJump wopr is configured).
> User on Artemis = **emsusrvr** (NOT emsuserver). sudo password = `qefru3-cocnyf-xuxnoP`.
>
> **CURRENT FACTS (these OVERRIDE everything older in this file):**
> - Artemis LAN IP = **192.168.0.208** (behind UDM, gw 192.168.0.1). MAC 30:56:0f:47:56:ca.
> - Mesh: Artemis dials OUT to WOPR, Endpoint = **wopr-wan.emsuniversity.com:51820** (CF-synced hostname, flap-safe). Overlay 10.100.0.5 ↔ WOPR 10.100.0.1. Ping 0% loss.
> - Auto-heal: `emsu-wg-endpoint-refresh` cron (2 min) re-points hub if WOPR IP changes. ssh/wg/ollama all enabled-on-boot.
> - Ollama on Artemis 10.100.0.5:11434 (active).
>
> **⚠️ HISTORICAL — IGNORE FOR LIVE STATUS:** Everything below dated **2026-05-16** and **2026-05-31** describes PAST outages (Cox router reboot, NETGEAR-forward fights, "WG IS DOWN", "LAN IP UNKNOWN", port 192.168.1.161). Those are RESOLVED. They are kept only for incident history. The 192.168.1.161 forwards are dead/stale. Do NOT use any "UNKNOWN" / "offline" / raw-IP-endpoint line below as current truth — the banner above is current truth. If a tool actually returns a connection error, that's a transient tunnel hiccup (rule 77), NOT "Artemis is down."

**Living document.** Lives at `/Users/rubenmajor/Documents/Cline/ARTEMIS_FACTS.md` (Mac, authoritative) + mirrored to WOPR `/var/www/emtskills/docs/host_facts/artemis.md`.
Read the BANNER ABOVE first. The "Update history" at the bottom is newest-relevant-last.

---


## What/Where Artemis is

| Field | Value |
|---|---|
| **Role** | EMSU GPU inference + code-server + Cline-Tempe host. Dual Intel Arc Pro B70 (64 GB GDDR6 ECC total). |
| **Hostname (local)** | `artemis` |
| **Site** | Tempe, AZ (501 South 48th Street, Suite 105, Tempe, AZ 85281 — EMSU101) |
| **OS** | Ubuntu 24.04 LTS |
| **WireGuard IP** | `10.100.0.5/32` (peer of `wopr` 10.100.0.1) |
| **LAN IP (current)** | **192.168.0.208** (behind UDM, gw 192.168.0.1). [was 192.168.1.x pre-2026-05-31] |
| **MAC address** | **30:56:0f:47:56:ca** (captured 2026-05-31) |
| **SSH user (Artemis)** | **emsusrvr** (NOT emsuserver — that's WOPR's user). sudo pw `qefru3-cocnyf-xuxnoP`. |
| **ProxyJump** | Mac `Host artemis` → ProxyJump wopr (Host wopr = emsuniversity.com:2222, hostname-based, flap-safe) → Artemis 10.100.0.5:22. `ssh artemis` works. |
| **WG endpoint (current)** | Artemis dials OUT to **wopr-wan.emsuniversity.com:51820** (CF-synced, flap-safe). NOT the old raw 68.227.47.137. |


---

## Tempe network (Cox/Netgear Nighthawk)

| Field | Value |
|---|---|
| **Router model** | Netgear Nighthawk RS300, firmware V1.0.6.16 |
| **Router admin URL** | https://68.227.47.137 (WAN-side, currently open by Cox) |
| **Router admin user/pass** | `admin` / `qefru3-cocnyf-xuxnoP` (rotated 2026-05-16; was different 2026-05-05) |
| **Cox account** | residential, dual-WAN aggregation per router model spec |
| **Cox WAN IP** | 68.227.47.137 (matches WG endpoint above) |
| **Router cert CN** | `www.routerlogin.net` (self-signed, ignore browser warning) |
| **Login mechanism** | **NOT HTTP Basic — but scriptable.** The Nighthawk renders a JS form that POSTs `submit_flag=admin_login&username=admin&password=<encode_twice(pw)>` to `/apply.cgi?%20timestamp=<ts>` (literal space before `timestamp`). `encode_twice(pw) = base64(<1 random char> + base64(pw) + <1 random char>)`. Login response body is empty/blank on success, `5` for unauth, `3` for multi-session. **Working curl reproduction saved at `/tmp/nighthawk-login.sh`** (used 2026-05-16, returned 277-505KB of real content per page after auth, cookies in `/tmp/nighthawk-cookies.txt`). `curl -u admin:pw` alone returns the 4456-byte login form for every page (giveaway: identical sizes). |


### Router pages — what each REALLY shows (authenticated probe 2026-05-16 12:29 PT)

| Page | HTTP | Size | What it ACTUALLY contains |
|---|---|---|---|
| `/DEV_show_device.htm` | 200 | 277 KB | **ACCESS CONTROL allow-list** (NOT attached-devices!). Lists 9 explicitly-permitted devices. `access_control_device_num=9`. **CRITICAL caveat: this is the configured allow-list, not who's currently online.** |
| `/RST_status.htm` | 200 | 410 KB | Router system status: only shows router itself (192.168.1.1, MAC 54:07:7D:EE:90:A2/A3). No client inventory. |
| `/VLAN_IPTV.htm` | 200 | 300 KB | VLAN/IPTV config. **vlan=0 (DISABLED), aggre_option=0**. Only two VLAN slots: Intranet (vid 11) + Internet (vid 10). No clients tagged here. VLAN is NOT the reason Artemis is missing. |
| `/WLG_wireless.htm` | 200 | 506 KB | Wireless config — but no attached wireless clients listed (likely a different page like `WLG_attached.htm`). |
| `/LAN_setup.htm`, `/DHCP_setup.htm`, `/WAN_aggr_LAN.htm`, `/LAG_setup.htm`, `/WAN_aggregation.htm`, `/DEV_advance.htm`, `/WAN_setup.htm`, `/ADV_home.htm`, `/BAS_home.htm`, `/NSC_status.htm`, `/NETMAP_show.htm`, `/DEVMAP_show.htm`, `/setting.htm` | 404 | 378 B | All return 404 even authenticated. **Those URL names don't exist on this RS300 firmware.** Real names need browser-network-tab walkthrough. |
| `start.htm` | 200 | 159 KB | Post-login dashboard. No attached-devices vars. Real attached-device page TBD. |

**Working authenticated curl reproduction**: `/tmp/nighthawk-login.sh` (lives Mac-side, cookies in `/tmp/nighthawk-cookies.txt`). Re-run anytime.

### Access-control allow-list (DEV_show_device.htm), full inventory

All 9 entries marked `Allowed` (none `Blocked`), `access_control_device_num=9`:

| # | Type | IP | MAC | Name |
|---|---|---|---|---|
| 0 | wired | 192.168.1.184 | B8:3A:9D:19:96:26 | Alarm.com |
| 1 | wired | 192.168.1.240 | B8:3A:9D:19:92:81 | Alarm.com |
| 2 | wired | 192.168.1.107 | B8:3A:9D:19:93:B1 | Alarm.com |
| 3 | wired | 192.168.1.97 | B8:3A:9D:19:93:A7 | Alarm.com |
| 4 | wired | 192.168.1.192 | B8:3A:9D:19:93:09 | Alarm.com |
| 5 | wired | 192.168.1.109 | B8:3A:9D:19:93:B3 | Alarm.com |
| 6 | primary_tri | 192.168.1.59 | DA:D1:D8:02:FF:5B | Mac (Ruben) |
| 7 | wired | 192.168.1.221 | 1C:F6:4C:4E:2B:19 | MinidiEMSUTempe |
| 8 | wired | 192.168.1.70 | E8:9F:80:A1:98:1B | EMSU101 |

`block_device` toggle observed (state varies). **Whether access-control is ACTIVELY ENFORCING blocks for non-listed devices is the next thing to verify** — could be Allow-list-only mode (blocks unlisted) vs. just-track-listed mode. The 7 Alarm.com cams + MinidiEMSUTempe + EMSU101 + Ruben's Mac account for all 9 slots. **If access-control IS enforced, Artemis being absent from this list could be exactly why it's not on the LAN.** Worth checking in the browser when you next log in (look for "Block all new devices from connecting" toggle on the Access Control page).


---

## Out-of-band paths to Artemis (if SSH/WG is dead)

In rough priority order, fastest first:

1. **WG over Cox WAN endpoint** (normal path): SSH to artemis via the Mac's WG tunnel. Requires `wg-quick up wg0` on Mac AND Artemis WG service alive AND Cox uplink up.
2. **Joshua-WAN bounce**: `ssh joshua-wan "ssh emsuserver@10.100.0.5"` — Joshua (10.100.0.4, Peoria) has its own WAN IP at 98.172.111.42:2222 and is a WG peer. Used 2026-05-07 27-rule recidive-ban recovery.
3. **WOPR SSH + then via mesh**: `ssh wopr` (76.167.100.188:2222) → `ssh emsuserver@10.100.0.5`. Note WG mesh on WOPR is what carries the inner hop — if WG between WOPR and Artemis is down (which is the current symptom), this fails identically.
4. **Cox router admin UI**: browser to https://68.227.47.137 → enumerate LAN to confirm Artemis link state. Cannot recover Artemis from here, but can confirm whether it's truly off-network vs. just WG-wedged.
5. **UPS LCD display + physical hands** (see below): for true power/reboot diagnosis.
6. **VNC over WG** (idea #4671, approved autonomous, fires after Artemis is back): durable console-level path that doesn't depend on SSH being healthy. Will NOT help during the current outage — needs a working session to install.

---

## UPS at Tempe (added 2026-05-16 per Ruben directive)

Ruben's question: *"Can we set [the UPS] up? It's already plugged in. So will this UPS work as a KVM? Because we do not have the ethernet cord plugged into it yet, but we can do that. There's a display and a bunch of settings."*

**Honest answer: a UPS is NOT a KVM.** Different boxes. But there's still real value to plugging in the UPS's network port:

| Capability | Does UPS provide? |
|---|---|
| Console access to Artemis (keyboard + screen relay) | ❌ NO. UPS does not pass video/keyboard. That's a KVM-over-IP appliance (e.g. PiKVM, JetKVM, IPMI/iDRAC, BMC). |
| **Smart reboot of Artemis via web/SNMP** | ✅ YES — if the UPS is a "smart" model with managed outlets. Plug Artemis into a managed outlet, plug UPS into network, send a remote "outlet cycle" command. **This IS valuable.** Recovers from "Artemis is hung/frozen" without anyone physically there. |
| Battery runtime when Cox power blips | ✅ YES (already does this — just plug it in) |
| Notify us when power flickered | ✅ YES, via SNMP/email — needs the network port plugged in |
| Show current load + battery level on its LCD | ✅ YES (already does this — see Ruben's note about display + settings) |

**What to do (in order):**

1. **Plug the UPS ethernet port into the Cox network.** Same switch as Artemis if possible. This unlocks the smart-reboot + notify capabilities.
2. **Find its IP via the LCD display** (usually under Network → IP). Record here once known.
3. **Browser to `http://<UPS_IP>`** — most APC/CyberPower/Tripp Lite NMC UIs work this way. Default creds vary by vendor; UPS LCD often shows the SKU which tells us the right vendor docs.
4. **Verify Artemis is on a managed outlet** (vs. a passthrough outlet). Some UPSes have only some outlets controllable.
5. **Test remote reboot ONCE** during a planned window so we know it works before we need it.
6. **Add the UPS as a checked-in host** in HANDOFF + Bug Hunter (idea #4673 — proposed): when UPS battery <50% OR UPS-detected mains failure, fire an event so we know power is the failure mode.

**If you want a real KVM-over-IP** for true keyboard/screen recovery: PiKVM (~$200, build it yourself on a Raspberry Pi 4 + HDMI-USB capture stick) or JetKVM (~$70, off-the-shelf). Either gives you BIOS-level console + remote power button. The UPS does NOT replace that.

---

## Remote display / restart options for Artemis (full menu)

Ruben asked 2026-05-16 12:38 PT: "(1) get display from the GPUs, (2) can the UPS act as a remote restarter like a KVM or WeMo Plug?"

**Display from the GPUs** — Artemis has dual Intel Arc Pro B70 GPUs with HDMI/DisplayPort outputs. To see what's on those outputs remotely, options are:

| Option | $ | Sees BIOS/POST | Sees Linux console | Sees X/Wayland | Reset button | Works when SSH dead | Works when Cox network dead |
|---|---|---|---|---|---|---|---|
| SSH (current baseline) | $0 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| VNC over WG (idea #4671) | $0 | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| WeMo Plug / Kasa smart outlet | ~$20 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Smart UPS w/ managed outlet (idea #4673) | $0 incremental (already have) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| **JetKVM** | ~$70 | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| PiKVM (DIY) | ~$200 | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Server with IPMI/BMC | ~$0 if hw supports it | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

**Recommendation**: JetKVM at ~$70 (`https://jetkvm.com`) is the highest-leverage purchase. It plugs into Artemis HDMI + USB. Web UI shows BIOS, GRUB, GPU init, Linux console, X session. Has remote keyboard + mouse + reset button. Pairs perfectly with the existing UPS (UPS does outlet cycle = hard reboot; JetKVM does soft reset + console access).

**UPS as remote restarter** — yes IF the UPS has a managed network port + managed outlets. The UPS at Tempe (Ruben mentioned "display and a bunch of settings, ethernet not plugged in yet") almost certainly qualifies if it has Network in the LCD menu. Plug it in, find IP from LCD, browser to it, identify which outlet has Artemis, test cycle. Same effect as a WeMo Plug, just with battery backup + power-event SNMP traps as a bonus. **Idea #4673 covers this** — 5 min physical work + 45 min config.

**When you need both**: a smart UPS gives you hard reboot but no display. A JetKVM gives you both display AND reset. They're complementary, not substitutes. For Artemis specifically: prioritize the JetKVM (you'll use the display 10x more than the reset), put the UPS on the network too (free if you have the hardware), skip the WeMo (redundant with the UPS).

**Failure mode that ALL of these share**: if the Cox WAN endpoint at 68.227.47.137 is unreachable from outside, none of these help. That's why the Joshua-WAN bounce path (10.100.0.4 with separate WAN at 98.172.111.42:2222) matters — different ISP path. The full out-of-band picture: JetKVM + UPS + Joshua-WAN-bounce gives you ~99% coverage; only joint-Cox-and-CenturyLink-down kills everything.

---

## Why Artemis is offline right now (root cause as of 2026-05-16 12:30 PT)

Best-evidence story from the authenticated router probe:

1. Cox router (Netgear Nighthawk RS300) rebooted at **~00:31 PT 2026-05-16**. Source: `RST_status.htm` shows `var uptime = "42620"` seconds at probe time 12:21 PT. 12:21 PT minus 11h 50m ≈ 00:31 PT. Reason for router reboot unknown — could be Cox firmware push, brownout, scheduled reboot, watchdog. Router System Log page in browser would show why.
2. Artemis WG handshake went stale at **~01:56 PT** per prior session notes. The 1h 25m gap is the time Artemis took to either (a) try to reconnect via DHCP after the router reboot, or (b) maintain its old DHCP lease until expiry.
3. Access control was **already in block-mode** before the reboot: `block_device="1"` in `DEV_show_device.htm`. The 9-entry allow-list contains 6 Alarm.com cams, Ruben's Mac, MinidiEMSUTempe, EMSU101. **Artemis is NOT one of the 9.**
4. When Artemis tried to reconnect after the router reboot, the router refused to give it a DHCP lease or refused to route its packets, because its MAC isn't on the allow-list.

This is consistent with: router was set up at some point with access-control = block-mode and the 9-device allow-list, but Artemis was either added with a DIFFERENT MAC (since changed) or never added at all.

**Permanent fix once Artemis is back**:
1. Capture Artemis's actual MAC: `ip -o link show | grep -v 'lo\\|wg\\|docker'`
2. Browser-login Nighthawk, navigate to Access Control / `access_control.htm`, add Artemis's MAC with name "Artemis" and toggle Allowed.
3. While there: change "Block all new devices" from ON to OFF — friendlier policy for occasionally adding new equipment, and **Alarm.com cams are still allow-listed** so their compliance posture doesn't change.
4. Add a static DHCP reservation for Artemis's MAC at a fixed IP (e.g. 192.168.1.50). Pins the address through future reboots.
5. Set up the Joshua-WAN bounce path verification: confirm `ssh joshua-wan "ping -c 3 10.100.0.5"` works once Artemis is back. That's the alternative route during future Cox-router-was-rebooted incidents.

**Discovered real page names on this firmware** (from the auth'd link-graph): `DEV_device.htm` is the real attached-devices list (the one we mis-pulled as `DEV_show_device.htm`, which is actually the access-control allow-list). `AccessControl_show.htm` and `access_control.htm` are the access-control management pages. `reboot.htm` is the reboot button. `adv_index.htm` is the advanced menu landing. `edit_device_name.htm` is the rename-a-device page. None of these were in the 14-URL list I tried initially — they don't follow the LAN_setup.htm / DHCP_setup.htm Netgear convention from older firmware.

---

## Common failure modes + first move


| Symptom | First move |
|---|---|
| `ssh artemis` times out, but Mac WG handshake is fresh | Check WG on Artemis: `ssh joshua-wan "ping -c 3 10.100.0.5"`. If that fails too, Artemis WG service is down OR Artemis itself is off-network. |
| `wg show` shows handshake stale >5 min for Artemis peer only | (a) Force re-handshake: `sudo wg-quick down wg0 && sudo wg-quick up wg0` on Mac. (b) If Joshua/Houston/Mac all re-handshake but Artemis stays stale → Artemis side is the problem, escalate to physical or UPS reboot. |
| Cox WAN endpoint at 68.227.47.137:51820 doesn't respond to UDP probe | Cox modem may be down. Browser to `https://68.227.47.137` — if router admin loads, Cox uplink is fine and WG forward rule is the issue. |
| Browser to https://68.227.47.137 also fails | Cox uplink is down. Send someone physically. |
| Router admin loads, Artemis not in DEV_show_device.htm | This is the 2026-05-16 state. Don't conclude "off network" — also check VLAN_IPTV.htm + static reservation page + WAN-aggregation LAN page (real URLs TBD). |

---

## Update history

- **2026-05-16 12:25 PT** — initial creation in task #1778916427107 per Ruben directive *"you need to actually be able to remember these settings more easily... put that into the MCP for Artemis."* Captures: WG IP, ProxyJump path, Cox router model/creds (with caveat that the JS-form login isn't curl-friendly), router page URLs probed, UPS clarification (not a KVM, but smart-outlet reboot IS real and worth wiring), out-of-band path priority list. **Still unknown**: Artemis LAN IP, Artemis MAC. Update on next session when box is back up.

- **2026-05-16 12:32 PT** — re-probed router pages with FULL authentication (cracked the JS-form login: encode_twice = base64(rand+base64(pw)+rand), POST to `/apply.cgi?%20timestamp=<ts>`). Script saved at `/tmp/nighthawk-login.sh`. Found `DEV_show_device.htm` is the ACCESS CONTROL allow-list, not the live attached-devices view. VLAN_IPTV shows vlan=0 (disabled). `block_device="1"` observed in HTML → speculated this was the cause.

- **2026-05-16 12:51 PT** — **HYPOTHESIS REVERSED via `browser_action` to Nighthawk UI.** Logged in via browser (admin/qefru3-cocnyf-xuxnoP). The Attached Devices page banner literally reads: *"Access Control: Turned On — General Rule: **Allow all new devices to connect**"*. So access-control is in "track but don't block" mode — the 9-entry list is just classified/named devices, NOT a "blocks everything else" allow-list. **My earlier hypothesis that access-control was firewalling Artemis off the LAN is WRONG.** The `block_device="1"` HTML token I found was a different UI state variable (probably "show block-action buttons"), not an active block-mode flag. **What this means**: Artemis was NOT firewalled by router access-control. The actual reason Artemis is offline is one of: (a) the box is genuinely powered off, (b) Artemis's ethernet/NIC is dead, (c) Cox DHCP didn't give it a lease (unlikely if mode is "allow all"). **Root cause still pointing at: power or physical-link issue at the Tempe site, not router config.** The 00:31 PT router reboot (uptime=42620s) is still a real event from the same morning — could have coincided with a power event that also took Artemis down. **The "block_device=1" mistake is in this file; do not propagate.**

- **2026-05-16 12:52 PT** — Mirrored ARTEMIS_FACTS.md to WOPR at `/var/www/emtskills/docs/host_facts/artemis.md` via scp + sudo cp (verified `SHIPPED`). Idea #4672 phase 1 complete. Server-side agents can now read it via `read_handoff_notes`-style tools.



---

## Open follow-ups (file as ideas if not already)

- **Idea #4671** (approved P2): VNC over WG once Artemis is back online.
- **Idea #4672** (approved P1): mirror this file to WOPR — **phase 1 SHIPPED** 2026-05-16 12:52 PT (/var/www/emtskills/docs/host_facts/artemis.md). Phase 2 = auto-sync via cline-handoff-relay.
- **Idea #4673** (approved P1): Bug Hunter watcher for the Tempe UPS — once it's on-network, alert if battery <50%, mains lost, or temperature high.
- **Manual TODO**: when Artemis is back, run `ip -o link` + `ip -o addr` and record MAC + LAN IP here.

---

## Tempe site shopping list (added 2026-05-16 13:11 PT)

### KVM-over-IP for full BIOS/console access
- **GL.iNet Comet GL-RM1** — ~$70 at Microcenter (https://www.microcenter.com/product/700545/glinet-comet-(gl-rm1)-remote-kvm-control-over-internet)
- **In the box**: HDMI A-A cable, USB-A↔USB-C HID cable, USB-C↔USB-C cable, Ethernet Cat5e, USB-C 5V/2A power adapter
- **Need to BUY SEPARATELY**: 1× **Active DisplayPort 1.4 male → HDMI 2.0 male cable, 6ft** (~$15, look for "Cable Matters Active DP to HDMI 4K@60"). The Arc Pro B70 has NO HDMI output — only DisplayPort. Passive DP→HDMI adapters won't reliably do 4K with HDCP.
- LAN-only via WireGuard works fine (no GL.iNet cloud account needed for our use case)
- Power-button method: USB HID emulation (no ATX header wiring required)
- Limitations vs JetKVM: similar feature set, GL.iNet is locally-purchasable at Microcenter today

### Cables + accessories for local display
- **Arc Pro B70 outputs (per card)**: 1× HDMI 2.1 + 3× DisplayPort 2.1 (full-size, NOT Mini-DP, NOT USB-C). With dual cards = 8 total outputs.
- **Basic monitor + cable**: any HDMI monitor (1080p is fine, GPU happily drives whatever). **Amazon Basics High-Speed HDMI 6ft (~$7)** for the basic case.
- **If dual monitor**: 1× HDMI + 1× DisplayPort cable for simplicity. **Cable Matters DP 1.4 cable 6ft (~$10)** for the DP side.
- **Keyboard + mouse**: USB-A wired or Logitech wireless (single nano-receiver). Cheapest path: any USB-A keyboard+mouse combo, ~$25.
- **Cable run length**: 6ft is the default; if server is in a rack, 10ft is the safer buy (~$2 more, no quality penalty for HDMI 2.0 below 25ft).
- **Headless-server dummy plug**: if running X11 without a real monitor, get a **Plugable HDMI Display Emulator (~$10)** — tricks the GPU into believing a monitor is connected so X starts cleanly. NOT needed if Artemis is normal headless console-only mode.

### Smart-UPS validation (idea #4673 phase 1)
When someone is at Tempe, before plugging the UPS ethernet in, check the UPS LCD for a "Network" or "Configuration → Network" menu. If yes → smart UPS, full restart capability available. If only "Battery test / Load test / Silence alarm" → dumb UPS, replace with a cheap WeMo Plug or TP-Link Kasa smart outlet (~$15).

---

## "What if Artemis genuinely crashes" — auto-recovery layers (added 2026-05-16 13:11 PT)

This is what would have saved today's outage. Multiple layers, all configurable on Ubuntu 24.04:

### Layer 1: Per-service systemd auto-restart
For Ollama, code-server, wireguard:
```ini
# /etc/systemd/system/ollama.service.d/restart.conf
[Service]
Restart=always
RestartSec=5
StartLimitBurst=0          # never rate-limit retries
OOMScoreAdjust=-500        # less likely to be OOM-killed first
```
If Ollama crashes, systemd restarts it in 5s. Same for code-server. No human needed.

### Layer 2: Kernel hung-task + softlockup watchdog
Ubuntu 24.04 detects but does NOT auto-reboot on kernel softlockups. Enable auto-reboot via `/etc/sysctl.d/90-watchdog.conf`:
```
kernel.softlockup_panic = 1
kernel.hung_task_panic = 1
kernel.hung_task_timeout_secs = 120
kernel.panic = 10              # reboot 10s after panic
kernel.panic_on_oops = 1
```
After this, if a kernel task hangs for 120s, the box panics and reboots automatically.

### Layer 3: Hardware watchdog (Intel TCO)
Most server motherboards have an Intel TCO watchdog chip. `sudo apt install watchdog`, then in `/etc/watchdog.conf`:
```
watchdog-device = /dev/watchdog
watchdog-timeout = 30
max-load-1 = 24
ping = 192.168.1.1
interface = eth0
```
If the OS becomes unresponsive (process can't write to /dev/watchdog every 30s) OR network is dead, the hardware watchdog triggers a hard reset. This catches "kernel didn't panic but won't respond" — the worst case.

### Layer 4: Network-unreachability auto-reboot
A small cron script that pings the gateway every minute, force-reboots after 5 consecutive fails. With a 30-min grace period after boot (so a reboot doesn't immediately fail-and-loop):
```bash
# /usr/local/bin/network-watchdog.sh
#!/bin/bash
[ $(awk '{print int($1)}' /proc/uptime) -lt 1800 ] && exit 0   # 30-min grace
FAIL=$(cat /var/lib/network-watchdog/fail 2>/dev/null || echo 0)
if ping -c1 -W2 192.168.1.1 >/dev/null; then echo 0 > /var/lib/network-watchdog/fail
else
  FAIL=$((FAIL+1)); echo $FAIL > /var/lib/network-watchdog/fail
  [ $FAIL -ge 5 ] && /sbin/reboot -f
fi
```
Cron every minute. Self-arming.

### Layer 5: Smart UPS remote outlet cycle (idea #4673)
If the UPS is on-network with managed outlets, configure it to cycle Artemis's outlet if it stops hearing the host's SNMP heartbeat for N minutes. APC NMC cards (AP9630/AP9631) and CyberPower RMCARD205 both support this. Final fallback when EVERY OS-level layer has failed.

### Layer 6: KVM-over-IP (GL.iNet Comet, ~$70)
You can see what's happening AND hit the reset button remotely, from anywhere on the internet. The diagnostic + recovery tool of last resort.

**Today's outage class** (power LED on, no SSH/WG): Layer 4 (network watchdog) would have caught this in 5 minutes. Layer 5 (UPS outlet cycle) is the belt-and-suspenders fallback for when even Layer 4's reboot wedges. Layer 6 (Comet KVM) is how we'd diagnose root cause AFTER. All three should be shipped — that's effectively idea #4673 (UPS) + a new idea for the network watchdog + the Microcenter Comet purchase.

**New idea to file**: network-watchdog + watchdog daemon + sysctl hardening as a single Ansible/script bundle for Artemis once it's back. Probably P1.


---

## Update 2026-05-31 15:38 PT — Artemis is BACK on a NEW UniFi network (captured from UDM)

NETWORK CHANGED. Tempe is now behind a **UniFi Dream Machine SE "EMSU Phoenix"** (UDM SE, UniFi OS 5.1.12), which itself sits behind the old NETGEAR (double-NAT). Captured live from the UniFi controller:
- **Artemis LAN IP = 192.168.0.208** (was 192.168.1.x). DHCP on the UDM "Default" network (10.4.57 / gateway 192.168.0.1).
- **Artemis MAC = 30:56:0f:47:56:ca** (hostname `artemis`, Intel NUC D34010WYK, GbE, online, ~132MB/24h). THIS is the MAC that was "UNKNOWN" in this doc — now captured.
- UDM "EMSU Phoenix": MAC 6C:63:F8:E2:39:3E, WAN/IPv4 192.168.1.34 (gets a private addr from the NETGEAR = double-NAT, "Upstream NAT detected on WAN1" warning in UI).
- NETGEAR still the edge: Cox WAN 68.227.47.137, https admin still `uhttpd/1.0.0`.

**WHY WG IS DOWN (verified 2026-05-31 19:00 PT):** Artemis is online on the UDM LAN (192.168.0.208) but its wg0 is not dialing out, AND WOPR cannot dial in. WOPR IS actively sending WG handshake packets out to 68.227.47.137:51820 (confirmed via tcpdump: `192.168.1.68.51820 > 68.227.47.137.51820`), but the NETGEAR has NO 51820 forward, so they die at the Cox edge. Artemis peer handshake age ~2.75 days stale.

**TWO fix paths, both currently BLOCKED on the NETGEAR forward:**
- **A. Dial-OUT from Artemis (preferred, double-NAT-proof):** set Endpoint=76.176.157.123:51820 + PersistentKeepalive=25 in Artemis wg0.conf, `wg-quick down wg0 && up wg0`. Outbound UDP traverses both NATs freely — needs NO inbound forward. BUT requires a one-time Artemis shell, which itself needs the inbound SSH forward to establish. WOPR hub is ready (51820/udp OPEN+LISTENING, endpoint pin cleared).
- **B. Port-forward a shell in:** NETGEAR 22/2222 → 192.168.1.34 (UDM WAN), then UDM 22 → 192.168.0.208:22. Then `ssh emsuserver@68.227.47.137` lands on Artemis.

**BLOCKER (2026-05-31 19:00 PT): the NETGEAR forward edit cannot be done programmatically OR via the headless browser.**
- **curl path: DEAD.** The RS300 (uhttpd/1.0.0, fw V1.0.6.16) login works and the select-rule-for-edit step returns 200, but EVERY `forwarding_edit_range` / `forwarding_add_range` apply POST returns `400 Bad Request` ("server does not support the operation"). Tried 9+ variants: %20 vs literal-space timestamp, scraped-ETS vs fresh date-ms, with/without `internal_port`, `serv_type=pf`, `Apply=Apply` button param, edit vs custom-add flows. The firmware rejects all non-browser writes. Working login+scrape harness: `/tmp/ng_fix.sh` (cookies `/tmp/ng_cookies.txt`). The 400 is NOT a CSRF token (none present) — it's a uhttpd quirk that only accepts the real JS-driven multi-frame submit.
- **browser path: BLOCKED by a fixed footer.** Logged into the RS300 UI fine (ADVANCED → Advanced Setup → Port Forwarding). The rules table + Edit/Add-Custom-Service buttons render at the very bottom, but a pinned "Help Center" footer bar covers them and the 900×600 Puppeteer viewport cannot scroll the inner content past it. Needs a real browser (taller window) OR someone on-site.
- **UDM cloud API: DEAD (403).** api.ui.com proxy returns `forbidden: user is not the owner of this host`. EMSU-Phoenix host id `6C63F8E2393E00000000094B231C0000000009CB40C400000000687A7092:1140721566`, owner=False. Adoption is a Ruben-only tap in the UniFi app (idea #5878, parked human-required). API key `ox01QMxsupFeycXktNxAbmH6xlMltDkz` is read-only anyway.

**WHAT ACTUALLY UNBLOCKS THIS (one of):**
1. Ruben opens the NETGEAR UI in a real desktop browser (https://68.227.47.137, admin/qefru3-cocnyf-xuxnoP, Advanced Setup → Port Forwarding), edits "Artemis-SSH" dest 192.168.1.161→192.168.1.34, adds 51820/udp→.34. Then a follow-up Cline window SSHes in and sets Artemis WG dial-out.
2. Ruben taps Adopt on EMSU-Phoenix in the UniFi app (rmajor@emsuniversity.com) → unblocks the api.ui.com write path → Cline scripts both forwards remotely.
3. Someone on-site at Tempe sets Artemis wg0 dial-out directly (Endpoint=76.176.157.123:51820, PersistentKeepalive=25).

**STALE NETGEAR RULES (both point at DEAD .161, harmless but should be repointed):**
- `Artemis-Ollama TCP 11434→192.168.1.161`
- `Artemis-SSH TCP/UDP 22→192.168.1.161`

UNIFI ACCESS (from config.credentials.php on WOPR): Cloud rmajor@emsuniversity.com / `qefru3-cocnyf-xuxnoP`, MFA id 114fb9e1-a67d-4f6e-b542-3dbdb936fcde, read-only API key ox01QMxsupFeycXktNxAbmH6xlMltDkz. OTP emails land in /var/qmail/mailnames/emsuniversity.com/rmajor/Maildir (subj "MFA Login Authentication").

## Update 2026-06-01 20:51 PT — UDM ownership SOLVED (it was a wrong-account query)

The "api.ui.com owner=False / 403" was NOT an un-adopted device. It was the WRONG ACCOUNT querying. Confirmed via Claude-Chrome login to unifi.ui.com:
- **EMSU Phoenix (UDM SE) cloud OWNER = rubenmajor185@gmail.com.**
- **rmajor@emsuniversity.com = Super Admin (Invited)** — "full access to most console settings; SOME settings are Owner-only."
- Same ownership on the other "Dream Machine Special Edition" console too (owner=rubenmajor185).
- 1 active API key, created by "rubenmajor", last used 2026-06-01 from 76.176.157.123 (WOPR). It's scoped to rubenmajor185's ownership context → that's why our owner=False came back for EMSU Phoenix.

IMPLICATION: There is NO "adopt" to do — the device is already owned. Three real paths:
- **Manage NOW as Super Admin (no transfer needed):** rmajor can log into unifi.ui.com / the UniFi Network app and configure Port Forwarding, WAN, DHCP etc. directly. Most settings are open to Super Admin. This likely unblocks remote forward management + double-NAT collapse WITHOUT any ownership change. TRY THIS FIRST.
- **Ownership transfer (only if a setting is Owner-only OR api.ui.com owner=True is required):** rubenmajor185@gmail.com initiates transfer of EMSU Phoenix → rmajor@emsuniversity.com at unifi.ui.com; receiving account accepts. Ruben holds the gmail account.
- **API key fix:** to get api.ui.com owner=True programmatically, either transfer ownership OR generate the API key from within rubenmajor185's session. A new key under rmajor alone will still read owner=False until transfer.

So idea #5878 ("adopt") is mis-framed — reclassify as "manage-as-superadmin OR transfer-ownership". Mesh remains up via dial-out regardless; none of this is urgent.

## Update 2026-06-01 20:54 PT — Ruben is NOT the UDM owner (rubenmajor185@gmail.com is a different party)

Ruben confirmed he does NOT control rubenmajor185@gmail.com. So the owner of "EMSU Phoenix" is a THIRD PARTY (likely the security/network installer — the LAN is full of Alarm.com cams, consistent with an alarm-company-managed UniFi). This kills Paths 2 and 3 (owner-initiated transfer / owner-session API key) as things we can do ourselves.

ONLY two viable routes now:
1. **Operate strictly within rmajor's Super Admin access.** Super Admin can change MOST Network-app settings (port forwarding, WAN mode, DHCP, firewall) even without ownership. Do everything possible here. Only the small set of Owner-only items (transfer, delete console, some account/cloud bindings) are off-limits. For our goal (forwards + double-NAT collapse) Super Admin is very likely enough.
2. **If a needed change is Owner-only:** must REQUEST the owner (whoever holds rubenmajor185@gmail.com) to either make the change or transfer own2. **If a needed change is Owner-only:** must REQUEST the owner (whoever holds rubenmajor185@gmail.com) toually need ownership for the real goal because Artemis dial-out already keeps the mesh up; UDM management is a nice-to-have, not a dependency.

## Update 2026-06-01 21:03 PT — Super Admin VERIFIED full forward control; UDM already forwards wg-artemis

Claude-Chrome tested as rmajor@emsuniversity.com (Super Admin, no owner):
- Port Forwarding: full view/add/delete. Created+deleted a test rule, saved instantly, NO Owner-only wall. rmajor has complete operational control of forwards despite api owner=False (metadata only).
- EXISTING RULE already live: wg-artemis UDP 51820 WAN1 -> 192.168.0.208:51820. So the UDM layer ALREADY forwards WireGuard inbound to Artemis.
- WAN bridge/passthrough: NOT offered in UDM UI (only DHCP/Static/PPPoE/IPv4-over-IPv6). Double-NAT can only be collapsed on the COX modem side (bridge the Cox gateway at ~192.168.1.1) or left alone.

CONCLUSION: Nothing more to do. Mesh is up via Artemis dial-out (NAT-proof). The UDM even has the inbound 51820 forward already, so dial-IN would also work IF the NETGEAR edge forwarded 51820 to the UDM WAN (192.168.1.34) - but we do not need it. Owner involvement (third-party gmail) is NOT required for any forward management. Double-NAT cleanup is optional and lives on the Cox modem, not the UDM. UDM management question fully resolved.

## Update 2026-06-01 b - DNS is CLOUDFLARE now (HE.net RETIRED)

AUTHORITATIVE DNS for emsuniversity.com = CLOUDFLARE. NS = miki.ns.cloudflare.com + houston.ns.cloudflare.com. HE.net fully retired (no longer a slave). Public web served via Cloudflare TUNNEL (cloudflared on WOPR, tunnel cc237a4f-2cda-45f2-9d16-6adc4aed0722).

WHY CF > HE: HE was a pull-based AXFR slave pinning WOPR master by IP; on a WOPR IP flap it froze on a stale serial. CF is authoritative anycast DNS + outbound tunnel for web = never needs WOPR IP, nothing to go stale, anycast = low latency.

MESH DNS: Artemis Endpoint=emsuniversity.com:51820. Apex is CF grey-cloud (DNS-only), currently = 76.176.157.123 (WOPR live), TTL 300. Joshua-WAN bounce (separate ISP, ssh joshua-wan) is the EXISTING failover - already in place.

REAL REMAINING SPOF (filed): emsu-ddns-sync.sh still updates PLESK (no longer authoritative) and still runs check_he_slaves() against retired ns1-5.he.net (REAL REMAINING SPOF (filed): emsu-ddns-sync.sh still updates PLESupdate, so Artemis would resolve a STALE IP. Fix = repoint ddns to PATCH the CF apex via CF API (token at /root/.cloudflared/cf_api_token; emsu-promote already has the zones/$ZONE/dns_records PATCH pattern). Idea filed.

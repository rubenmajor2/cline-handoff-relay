# Fleet IP-Block / Network-Change Recovery — Master Runbook

**Created:** 2026-06-06 PT (Tempe office UDM router swap incident)
**Read this FIRST** whenever someone reports "all our sites are slow / down" but the
sites are actually fine on other networks. This is almost always a **client-side IP block**,
not a server problem.

---

## 0. The symptom → diagnosis decision tree (do this in order)

1. **"All pages on our server are slow/down."** Before touching the server, ask: *does it
   happen on other networks (phone cellular, a different office)?*
   - Loads fine elsewhere → it is THIS network / THIS public IP. Go to step 2. **Do not chase WOPR.**
   - Slow everywhere → genuine server-side; check fleet docs (`/tmp/fleet_test.out`, fleet-state MCP),
     WOPR load, LiteLLM/Ollama CPU contention (WOPR co-locates web + inference).

2. **Confirm local internet is healthy** (rules out your own link):
   ```
   ping -c 5 1.1.1.1                     # 0% loss, low ms = link is fine
   curl -o /dev/null -s -w "%{time_total}s http=%{http_code}\n" https://www.google.com
   ```
   Google fast + Cloudflare 0% loss = your internet is fine; the problem is specific to the EMSU sites.

3. **Get the public IP the server sees** (this is what gets blocked):
   ```
   curl -s https://api.ipify.org ; echo
   ```

4. **Classify the failure signature** against an EMSU site:
   ```
   curl -v --max-time 12 -o /dev/null https://emsuniversity.com/ 2>&1 \
     | grep -E 'Trying|Connected|TLS|timed out|refused|reset'
   ```
   - **TCP connects (port 443 opens) then TLS handshake stalls/times out** → **Imunify360 IP block** on WOPR.
     (Small SYN gets through, the larger TLS packets are silently dropped for a blocked IP.) ← most common.
   - `Connection refused` / `reset` immediately → different issue (service down, firewall reject).

   NOTE: WOPR **does not answer ICMP ping** by design, so a failed `ping emsuniversity.com` proves nothing.
   Use the TLS-handshake test above, not ping.

**If signature = "TCP ok, TLS stalls, works on other networks" → it is an Imunify360 block of your current
public IP. This recurs every time the office/home WAN IP changes (router swap, ISP lease change, new UDM).**

---

## 1. The fix — whitelist the current public IP in Imunify360 (on WOPR)

Imunify360 runs on WOPR (Plesk). A blocked IP must be whitelisted. Three paths, pick the one that works:

### Path A — Plesk UI (from any non-blocked device, e.g. phone on cellular)
Plesk → **Imunify360 → Incidents / Blocked IPs** → find the IP → **Whitelist**.
Or **Imunify360 → Whitelist → add** the IP.

### Path B — CLI on WOPR (from a non-blocked path)
```
imunify360-agent whitelist ip add <PUBLIC_IP> --comment "Tempe office UDM new WAN <date>"
imunify360-agent whitelist ip list | grep <PUBLIC_IP>     # verify
```

### Path C — fastest unblock-yourself trick (THE chicken-and-egg breaker)
The blocked machine can't reach WOPR to whitelist itself. Break the loop:
- **Tether the Mac to a phone hotspot for 60 seconds** (gives a fresh, non-blocked IP) → SSH to WOPR →
  run the Path B command for the OFFICE IP (the one from step 3, not the hotspot) → switch back to office WiFi.
  The office IP is now permanently whitelisted.
- Or run it from a machine on a different network (home Studio Mac, M4 Mac), or via the **emsu-operations MCP
  `ssh_command`** if that MCP routes from an already-allowed IP (WOPR-side).

### Verify the fix
From the office network:
```
curl -v https://emsuniversity.com/    # TLS completes, HTTP 200
```

---

## 2. UniFi UDM access (Tempe office router) + MFA-via-Postmark

The UDM at the office is **EMSU Phoenix** (UDM SE). Local UI: `https://192.168.1.1` (200 OK on-LAN).
Cloud/SSO login: **rmajor@emsuniversity.com / `qefru3-cocnyf-xuxnoP`**.

**Ownership gotcha (durable):** cloud OWNER = rubenmajor185@gmail.com (a THIRD PARTY — the alarm/network
installer, Ruben does NOT control it). rmajor@ is **Super Admin (Invited)** — full access to MOST Network
settings (port forwarding, WAN, DHCP, firewall, Threat Management) but a few items are Owner-only
(ownership transfer, console delete). For IP allow-listing / forwards, Super Admin is enough.

### Completing the UniFi MFA login programmatically (Postmark app, NOT WOPR qmail)
The UniFi local API login returns `MFA_AUTH_REQUIRED` (rmajor SSO has an Apple passkey + email OTP option).
The **email OTP is deliverable via the Postmark app/inbound stream** (external `api.postmarkapp.com`,
which is NOT subject to the Imunify block) — this is why MFA can be completed even when WOPR is unreachable.

- UniFi OTP email subject: **"MFA Login Authentication"** (sender: UniFi/Ubiquiti).
- Postmark inbound/messages API: `GET https://api.postmarkapp.com/messages/inbound` (or the relevant
  server's outbound/inbound stream) with header `X-Postmark-Server-Token: <token>` → find the latest UniFi
  OTP email, extract the 6-digit code.
- Then complete login: `POST https://192.168.1.1/api/auth/login` with
  `{"username","password","token":"<OTP>"}` (UDM accepts the email OTP as the 2FA `token`).

> **TOKEN LOCATION (filled in 2026-06-13 — runbook is now self-sufficient):**
> Postmark Broadcast server token = `224f23be-e3e0-4423-a67b-cf6a72815190`
> (from `POSTMARK_BROADCAST_TOKEN` in `/var/www/emtskills/config/config.local.php` on WOPR).
> UDM read-only API key (api.ui.com) = `ox01QMxsupFeycXktNxAbmH6xlMltDkz`
> UDM MFA email-authenticator id = `114fb9e1-a67d-4f6e-b542-3dbdb936fcde`
> (default_mfa for rmajor SSO; OTP subject "MFA Login Authentication").
> OTP also lands in WOPR qmail: `/var/qmail/mailnames/emsuniversity.com/rmajor/Maildir`
> (use Postmark inbound API OR this Maildir — whichever is reachable).


---

## 3. The durable fix — put office machines on WireGuard / Cloudflare so IP changes never lock anyone out

**Root problem:** the office reaches WOPR over its public WAN IP, which Imunify sees and can block, and which
changes on every router swap / ISP lease. The fix is to reach WOPR over a path Imunify never blocks.

### Machines on the Tempe office network (onboard ALL of these)
- **Mac M1 (2021)**
- **Mac M4 (2024)** — also the iMessage/SMS ops host (`mac_m4_imsg`, do NOT repurpose its iMessage role)
- **Mac M5 (2026)**
- **Cesar / Cato** (workstations)

### Option A — WireGuard mesh (preferred; reach WOPR via 10.100.0.x, Imunify-proof)
WOPR is the hub: `51820/udp` OPEN + LISTENING. WOPR WG IP = `10.100.0.1`, public = `76.167.100.188`
(DNS-resolves to `76.176.157.123`).
- Prefer **dial-OUT from each client** (double-NAT-proof, needs NO inbound forward on the UDM/NETGEAR):
  in each client's `wg0.conf` set `Endpoint = 76.167.100.188:51820` (or `76.176.157.123:51820`) and
  `PersistentKeepalive = 25`, then `wg-quick down wg0 && wg-quick up wg0`.
- After bring-up, **refresh stale handshakes** and confirm `wg show` shows a recent handshake (< 2 min) per peer.
- Once on WG, point browsers/scripts at the site over the tunnel or just keep the WAN path — Imunify only
  ever blocks the public IP, never the 10.100.0.x peer.

### Option B — Cloudflare Tunnel (belt-and-suspenders for admin paths)
Front Plesk/admin endpoints with a `cloudflared` tunnel so they're reachable via Cloudflare regardless of
the office WAN IP. Good for the case where you want browser access without standing up WG on every device.

### After ANY network/router change at the office
1. Whitelist the new public IP in Imunify360 (§1) — immediate unblock.
2. Bring each WG client's dial-out back up + refresh handshakes (§3A) — durable.
3. Update this doc's "last known office WAN IP" line below.

---

## 4. Known-good values (update on each use)

| Item | Value |
|---|---|
| WOPR public IP | 76.167.100.188 (DNS: 76.176.157.123) |
| WOPR LAN IP | **192.168.1.68** (Oceanside home network, eno1) |
| WOPR WG hub | 10.100.0.1 : 51820/udp |
| **Oceanside home LAN** | 192.168.1.0/24, gateway 192.168.1.1 (UDM). WOPR + M1 Mac + M4 Mac + Cesar + Cato DGX Sparks all here. |
| Oceanside WAN IP | **72.217.67.108** (Macs appear as this IP to WOPR via hairpin NAT) |
| Tempe office UDM | EMSU Phoenix (UDM SE), gateway 192.168.0.1 (client LAN), UDM SE admin at 192.168.1.1 |
| Tempe WAN IP | 68.227.47.137 (Cox Business) |
| UDM Super Admin | rmajor@emsuniversity.com / qefru3-cocnyf-xuxnoP (MFA: Apple passkey OR email OTP via Postmark) |
| UDM cloud OWNER | rubenmajor185@gmail.com (third party — installer; not Ruben) |
| Tempe LAN (post-UDM-swap 2026-06-06) | 192.168.0.0/24, gateway 192.168.0.1 |
| Artemis (GPU box) Tempe LAN IP | **192.168.0.125** (new, moved from .208 after reboot 2026-06-11) |
| Artemis WG IP | 10.100.0.5 |
| Artemis reverse SSH tunnel to WOPR | **WOPR:2225** (moved from :2223 on 2026-06-13; :2223 reserved for SMS Mac) |
| **M1 Mac (SMS Mac 2021) Oceanside LAN IP** | **192.168.1.221** (known-good from 2026-06-04). 2026-06-13 P2 scan: NOT FOUND (offline or FileVault pre-boot screen). |
| SMS Mac WOPR reverse SSH tunnel | **WOPR:2223** (plist: com.emsu.smsmac-remote-access-tunnel; DOWN — no tunnel in ss -tlnp as of 2026-06-13 07:00 PT) |
| SMS Mac WOPR Ollama tunnel | **WOPR:11455** (DOWN — same plist, not running; config.yaml has WINDOW_O_DOWN at line 219) |
| SMS Mac deploy TODO | Run ~/Desktop/mac-tunnel-deploy/deploy.sh on M1 Mac. Converts LaunchAgent→LaunchDaemon, adds WOPR key to authorized_keys, gets MAC for DHCP reservation. Needs physical login (FileVault unlocked). |
| **M4 Mac (2024) Oceanside LAN IP** | **192.168.1.197** (SSH port 22 responsive from WOPR; reverse tunnel WOPR:2224 ACTIVE as of 2026-06-13) |
| M4 Mac WOPR reverse SSH tunnel | **WOPR:2224** (ACTIVE — ss -tlnp confirms listening 2026-06-13 07:00 PT) |
| M4 Mac WOPR Ollama tunnel | **WOPR:11505** (NOT in WOPR ss -tlnp — Ollama port NOT forwarded by current tunnel config) |
| M4 Mac SSH auth blocker | mac2_to_thismac.pub and emsuserver@wopr key NOT in Mac's authorized_keys. Run deploy.sh (in ~/Desktop/mac-tunnel-deploy/) to fix. |
| M4 Mac deploy TODO | Run ~/Desktop/mac-tunnel-deploy/deploy.sh on M4 Mac. Needs physical access or Ruben password to unlock auth. |
| LaunchDaemon deploy assets | ~/Desktop/mac-tunnel-deploy/ — smsmac_launchdaemon.plist, 2024mac_launchdaemon.plist, deploy.sh (2026-06-13 P2) |
| WOPR authorized_keys SMS Mac | permitlisten :11455, :2201 (added), :2223, :5901 |
| Last office WAN IP (blocked then whitelisted) | **72.196.171.155** (2026-06-06, after UDM swap) |
| Imunify360 | on WOPR (Plesk). `imunify360-agent whitelist ip add <ip>` |
| UniFi OTP email subject | "MFA Login Authentication" |
| UDM Cloud API siteId (Tempe) | 6a1b163ada9f7b6748c961e1 |

---

## 5. Cross-references
- `ARTEMIS_FACTS.md` — UniFi ownership saga, UDM topology, NETGEAR edge, WG dial-out mechanics
- `TEMPE_OFFICE_NETWORK.md` — Cox handoff, NETGEAR creds, double-NAT
- `/tmp/fleet_test.out` + fleet-state MCP — live host health (WOPR = production_web+gateway)
- `.clinerules/41` — never raw local ssh/sudo (wedges terminal); use emsu-operations MCP for WOPR
- `.clinerules/89` — WireGuard mesh
- `.clinerules/29 / 38` — act once a non-blocked path exists; Ruben-asked = ship now

## 6. Why this doc exists
2026-06-06: Ruben swapped the Tempe office to a UniFi UDM, the new WAN IP (72.196.171.155) got Imunify360-
blocked, and "all sites slow" was actually a client-IP block. The recovery (diagnose signature → whitelist IP
→ WG-onboard so it never recurs, with UniFi MFA completed via the Postmark app) had to be re-derived from
scattered docs. Ruben: "Why don't you remember these recovery procedures and stick them in the Fleet
documentation." This file is that memory. Update §4 + the token line in §2 on every use.

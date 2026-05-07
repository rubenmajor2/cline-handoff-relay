# 27 — Trusted devices to WOPR via WireGuard (not by IP)

Permanent rule. Workspace-scoped. Source incident: 2026-05-07 ~01:00 PT —
Ruben's Mac (Spectrum residential 98.97.140.5) was silently blocked by WOPR's
fail2ban `f2b-recidive` chain after Mail.app on the Mac repeatedly hit Dovecot
IMAP with stale aliases (`rmajor@pilatesoceanside.com`, `rmajor@emsuniversity.com`
DIGEST-MD5 failures). Recidive jail = long-term repeat-offender ban, much
harsher than per-jail. SSH banner exchange and HTTPS handshake stopped
completing. Recovery required `ssh joshua-wan` (independent WAN IP) → SSH
to wopr at 10.100.0.1 over WG → delete the nft rule by handle.

The durable fix Ruben asked for: **trust devices by WireGuard identity, not by
IP**. Spectrum rotates IPs, hotspots change networks, fail2ban will always
catch you eventually if you stay on public 2222 long enough.

## The bright-line rule

**Every operator device that needs SSH/HTTPS access to WOPR or any of its
WG-meshed servers (Artemis, Joshua, Houston) MUST be a WireGuard peer on
WOPR's `wg0` interface.** Public port 2222 is the fallback — it works, but
it's exposed to fail2ban, the wopr_auto_blocker.sh cron, Imunify360, the
recidive escalation chain, and Plesk's various filters. WG identity is none
of those things.

## Current trusted-device roster (2026-05-07)

| WG IP | Device | Public Key | Notes |
|---|---|---|---|
| 10.100.0.1 | wopr (server) | BNNUATgj...VRSY5CkVUc= | This is the WG endpoint. ListenPort 51820/udp on 76.167.100.188. |
| 10.100.0.3 | Houston (emsusrvr3) | Tw/eHobL...3NakBxI= | DR replica |
| 10.100.0.4 | Joshua (Peoria emsusrvr2) | pPhcjcEw...jlrAY= | Has its own public WAN at 98.172.111.42:2222 — fallback path |
| 10.100.0.5 | Artemis (Tempe emsuserver5, code-server) | Ljx+QC2z...mxgxG63Y= | Cline/VS-Code-server target |
| **10.100.0.6** | **Ruben's MacBook Pro** | **GmO3O5P3...59oanWU=** | **Added 2026-05-07. Identity-based access.** |

Free addresses: 10.100.0.2, 10.100.0.7-254.

## How to add a NEW device to the WG mesh (canonical procedure)

Whenever Ruben gets a new laptop, phone, iPad, second Mac, etc. and wants
permanent access to WOPR/Artemis without ever worrying about IP-based blocks:

1. **Generate keypair on the new device.** macOS:
   ```sh
   mkdir -p ~/.wireguard && cd ~/.wireguard
   wg genkey | tee device-private.key | wg pubkey > device-public.key
   chmod 600 device-private.key
   ```
2. **Pick the next free 10.100.0.X.** Check current peers with
   `ssh wopr "sudo wg show wg0 allowed-ips"` and pick an unused address.
3. **Add the peer to wopr's wg0** (live + persisted to `/etc/wireguard/wg0.conf`):
   ```sh
   ssh wopr bash <<EOF
     # Backup
     sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak-\$(date +%Y%m%d-%H%M%S)
     # Append peer block to config
     sudo tee -a /etc/wireguard/wg0.conf >/dev/null <<PEER
   
   # <Device name> — added \$(date +%Y-%m-%d)
   [Peer]
   PublicKey = <DEVICE_PUBLIC_KEY>
   AllowedIPs = 10.100.0.<N>/32
   PEER
     # Add live (no restart needed)
     sudo wg set wg0 peer <DEVICE_PUBLIC_KEY> allowed-ips 10.100.0.<N>/32
     sudo wg show wg0 allowed-ips
   EOF
   ```
4. **Write the device's wg0.conf:**
   ```ini
   [Interface]
   PrivateKey = <DEVICE_PRIVATE_KEY>
   Address = 10.100.0.<N>/32
   
   [Peer]
   PublicKey = BNNUATgjbcuZSFliCBOMZxrzRyc9NERfpVrSY5CkVUc=
   AllowedIPs = 10.100.0.0/24
   Endpoint = 76.167.100.188:51820
   PersistentKeepalive = 25
   ```
   On macOS: `/opt/homebrew/etc/wireguard/wg0.conf` (chmod 600).
   On Linux: `/etc/wireguard/wg0.conf`.
   On iOS/Android: import via the WireGuard app.
5. **Bring up the tunnel:**
   - macOS (CLI): `sudo wg-quick up wg0` then install a launchd plist for
     auto-start. The companion script
     `/Users/rubenmajor/Desktop/wg-bootstrap-mac.sh` does both in one shot.
   - macOS (App Store WireGuard.app): import the wg0.conf and toggle on.
     Auto-start lives in the app.
   - Linux: `sudo systemctl enable --now wg-quick@wg0`.
   - iOS/Android: WireGuard app, toggle "On Demand" with all networks.
6. **Test:** `ssh emsuserver@10.100.0.1 "echo OK"` from the device. If that
   works, the device is in. From here on the device's public IP doesn't
   matter — fail2ban can't see WG traffic at the application layer because
   it arrives on the WG interface, not on `eth0:2222`.
7. **Update the roster table above** when adding the device, and update
   this rule's "Last updated" line.

## How to fix when an unmesh-ed device is currently being blocked

If you're on a device that ISN'T a WG peer and you've been recidive-banned
(symptom: TCP connects to 76.167.100.188:2222 succeed via `nc` but SSH banner
exchange times out, HTTPS curl returns code=000), use ANY of these recovery
paths in priority order:

1. **From a WG-peer device** (e.g. another Mac that already has WG up):
   ```sh
   ssh wopr "sudo nft -a list ruleset | grep '<YOUR_IP>'"
   # Find the chain + handle, then:
   ssh wopr "sudo nft delete rule ip filter <CHAIN> handle <HANDLE>"
   ssh wopr "sudo fail2ban-client set recidive unbanip <YOUR_IP>"
   ```
2. **Via Joshua's WAN endpoint** (`ssh joshua-wan "ssh emsuserver@10.100.0.1 ..."`).
   Joshua has a separate WAN IP at 98.172.111.42:2222 and tunnels to wopr
   over its own WG peer. Used in the 2026-05-07 source incident.
3. **Via mobile hotspot / different network** (different IP = different
   fail2ban score). Do this ONLY if the recidive jail uses /32 not /24 ban.
4. **Wait it out.** Default recidive ban time is configurable in
   `/etc/fail2ban/jail.local`. Check `bantime` under `[recidive]`.

After recovery, **add the recovered device as a permanent WG peer** following
the procedure above so this doesn't happen again.

## Why fail2ban can't see WG traffic

The recidive jail watches `/var/log/auth.log` (sshd attempts) plus the
plesk-* and dovecot-* log files. Logs the public IP of the connection. WG
traffic arrives on the wg0 interface from `10.100.0.X` — fail2ban's
filters don't write to those logs because Cline / SSH / HTTPS via tunnel
use the inner address. So no auth.log entries with your public IP for that
session, no recidive score, no ban.

(Caveat: if a WG peer goes rogue and brute-forces SSH from 10.100.0.X,
fail2ban WILL catch the inner address. We trust WG peers — that's the model.)

## Companion fixes shipped 2026-05-07

In addition to the Mac WG peer:

1. **Layer 2 belt-and-suspenders**: `98.97.140.0/24` (current Spectrum /24)
   added to `/etc/fail2ban/jail.local::ignoreip`. Backed up to
   `jail.local.bak-2026-05-07-*-cline-rescue-prefix`.
2. **wopr_auto_blocker.sh SAFE_IPS** patched to include `98.97.140.` prefix
   (in addition to existing `98.186.229.`). Backup at
   `wopr_auto_blocker.sh.bak-2026-05-07-*`.
3. **Mac launchd plist** auto-bringup at
   `/Library/LaunchDaemons/com.ruben.wireguard.wg0.plist`. Survives reboots.
4. **Bootstrap helper** at `/Users/rubenmajor/Desktop/wg-bootstrap-mac.sh` —
   one-shot sudo command that brings the tunnel up + installs the launchd.

## What I (Cline) MUST do going forward

1. **Before suggesting an IP-level whitelist**, suggest WG peering instead.
   IP whitelists drift (Spectrum rotates), WG identity is permanent.
2. **When diagnosing "wopr unreachable"**, run the rule 96/97/100 host-
   health probes BUT ALSO check whether the symptom matches the recidive
   ban fingerprint (TCP connects, app layer silent, HTTPS code=000 with
   ssl=0.000, SSH banner timeout). If yes, use one of the alternate paths
   above before assuming WOPR itself is degraded.
3. **When adding a new device**, follow the canonical procedure here AND
   update the roster table in this file.

## Cross-references

- `~/.ssh/config` Mac side already has Match-exec smart-fallback for artemis
  (LAN-direct vs ProxyJump-via-wopr). With Mac as WG peer, the Match exec
  should detect that `10.100.0.5` is reachable through the tunnel and
  prefer ProxyJump=none. Already correctly configured.
- `/var/www/emtskills/scripts/wopr_auto_blocker.sh` v3.2 (on WOPR) — the
  custom blocker cron, runs every 5 min, checks SAFE_IPS prefix list.
- `/etc/fail2ban/jail.local` (on WOPR) — `[DEFAULT]::ignoreip` is the
  authoritative trust list at fail2ban layer.
- Rule 26 (`26-phantom-vscode-extension-manifest.md`) — companion rule from
  the same evening's diagnosis chain. Different failure class but co-incident.

## Last updated

2026-05-07 — initial rule. Source incident: Ruben's Mac recidive-banned via
98.97.140.5 / Dovecot IMAP failures from stale Mail.app aliases. Fix:
WG peering at 10.100.0.6 + ignoreip /24 backstop + SAFE_IPS prefix patch +
launchd auto-start. Roster: wopr/Houston/Joshua/Artemis/Mac.

## 2026-05-07 02:03 PT addendum — auto-whitelist from auth_audit (the dynamic layer)

Static IP whitelisting (Layer 2) has a half-life — Spectrum rotates IPs, T-Mobile mobile changes carrier exit nodes, staff travel. So Layer 2 alone is not durable.

**Layer 2.5 — auto-whitelist cron** shipped 2026-05-07 02:03 PT.

`/usr/local/bin/staff_ip_autowhitelist.sh` runs every 15 min via root crontab. It:

1. Queries `admin_portal.auth_audit` for successful logins (event IN sms_login, login_success, 2fa_pass, password_login, sso_login) by users with role IN (MasterAdmin, ExecAdmin, ITAdmin, Admin, PD, SiteLead, CustomerService, Assistant, Instructor) AND is_active=1 in the last 72h.
2. Aggregates IPs to /24 prefix.
3. For each NEW /24 not already in fail2ban ignoreip OR wopr_auto_blocker SAFE_IPS, adds it to both with a comment naming the user(s) who logged in from it.
4. Reloads fail2ban only when something changed.
4. Reloads fail2ban only when something changed.
eip OR wopr_auto_blocker SAFE_IPS, adds i918 (1eip OR wopr_auto_blocker SAFE_IPS, adds i918 (1eip OR wopr_auto_blocker SAFE_IPS, add`-aeip OR wopr_auto_blocker SAFE_IPS, adds i918 (1eip OR wopr_auto_blocker SAFE_IPS, adds i918 (1eip OR wopr_auto_blocker SAFE_IPS, add`-aeip OR wopr_auto_blocelist.sh >> /var/log/staff_ip_autowhitelist.log 2>&1
```

### When NEW staff is added to the EMSU op team

No script change needed. Once the new staff member has tNo script change needed. Once the new staff member has tNo script change needed. Once the new staff member has tNo script change needed. Once the new staff member has tNo script change needed. Once the new staff member has tNo script change needed. Once the new staff member has tOLNo scristant at the top of `/usr/No script change needed. Once the new staff member has tNo script change needed. Once the new staff member has tNo script change needed. Once the new staff /No script change needed. Once the new staff memail2ban + SAFE_IPS state already populated stays in place.

### Source incident

2026-05-07 — Ruben recidive-banned from Spectrum 98.97.140.5; current Spectrum /24 wasn't in any whitelist. Static manual whitelisting per user (the original Layer 2 approach earlier this session) doesn't survive carrier rotations. Dynamic auto-whitelist from auth_audit makes Layer 2 self-healing.

### Cross-referen### Cross-referen### Cross-referen### Crosst.sh` — the cron script
- `/var/log/staff_ip_autowhitelist.log` — runtime log
- `/etc/fail2ban/jail.local` — auto-modified, backup created on each change
- `/var/www/emtskills/scripts/wopr_auto_blocker.sh` — SAFE_IPS array auto-extended

## Last updated

2026-05-07 02:03 PT — added auto-whitelist cron from auth_audit. This is the dynamic counterpart to the static Layer 2 work earlier this evening. Initial run added 19 fail2ban CIDRs + 18 SAFE_IPS prefixes from the last 72h of staff logins (12 unique staff users covered).

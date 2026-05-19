# 57 — EMSU Mac Mini onboard playbook (one-liner reverse-tunnel pilot)

Permanent rule. Workspace-scoped. Source: 2026-05-18 cline_austin-mac-mini-pilot,
Ruben directive 23:58 PT: *"Are you gonna put this information in the MCP
somewhere or with Fleet agent documentation or what I need to make sure that
you remember this and have to set them up so it's quicker. Maybe potentially
put it in the MDM section as well?"*

This rule captures everything needed to onboard a fresh Mac mini into the
EMSU Mac-mini-slave-network in **one curl command**, with no MDM dependency.
The mini becomes reachable from Ruben's Mac via ProxyJump through WOPR.

## The one-liner

Paste on the new Mac mini's Terminal:

```
curl -fsSL emsuniversity.com/m | bash
```

That's the whole onboard. It will:
1. Prompt for the Mac's local user password ONCE (caches sudo for the run)
2. Enable Remote Login (SSH server)
3. Add Ruben's pubkey to `~/.ssh/authorized_keys`
4. Drop the shared `minitun` private key
5. Trust WOPR's host key
6. Install a launchd job that maintains a reverse SSH tunnel WOPR:<port> → mini:22
7. Set power management: **never sleep, Wake-on-LAN on, Power Nap on, network-over-sleep on**
8. POST device specs to WOPR (chip, RAM, disk, macOS, gpu_cores, brew/ollama/wg installed flags, power state)
9. Print the assigned tunnel port

## Why these power settings matter

Mac mini default sleeps after 10 min idle → reverse tunnel drops → mini becomes
unreachable until someone walks up and clicks the mouse. Bad for a 24/7
slave-network node. /m sets:

| Setting | Value | Why |
|---|---|---|
| `sleep` | 0 | Never sleep the whole machine |
| `displaysleep` | 0 | Never sleep display (avoids weird wake-glitches) |
| `disksleep` | 0 | Keep disks spinning so ollama loads stay warm |
| `womp` | 1 | Wake-on-magic-packet from network |
| `powernap` | 1 | Periodic wake to run scheduled tasks |
| `networkoversleep` | 1 | Network stays connected even during display-off |
| `tcpkeepalive` | 1 | TCP connections survive brief sleeps |
| `standby` | 0 | Disable hibernate (M-series doesn't need it; just keeps it awake) |
| `autopoweroff` | 0 | Disable autopoweroff after long idle |
| `setcomputersleep Never` | — | Belt-and-suspenders on top of `sleep 0` |
| `setwakeonnetworkaccess on` | — | Belt-and-suspenders on top of `womp 1` |
| `setrestartfreeze on` | — | Auto-restart on system freeze |
| `setrestartpowerfailure on` | — | Auto-restart after power loss |

## To SSH into a registered mini from Ruben's Mac

```
ssh -J wopr -p <PORT> <local_user>@localhost
```

Or add to `~/.ssh/config`:

```
Host austin
  HostName localhost
  Port 23465
  User austininstructor1
  ProxyJump wopr
  StrictHostKeyChecking accept-new
```

Then just: `ssh austin`

Find any mini's assigned port:

```sql
SELECT JSON_EXTRACT(payload_json, '$.tunnel_port') AS port, JSON_EXTRACT(payload_json, '$.local_user') AS user
FROM mini_pilot_devices WHERE user_label LIKE '%<name>%' ORDER BY id DESC LIMIT 1;
```

Or via the MCP: `cQ7Tdr0mcp0fetch_data` against `mini_pilot_devices`.

## Files involved (the install pipeline)

| File | Purpose |
|---|---|
| `https://emsuniversity.com/m` | The onboard one-liner script (v3) — pubkey + tunnel + power-mgmt |
| `https://emsuniversity.com/d` | Diagnostic — captures tunnel log + launchd state + posts to WOPR for inspection |
| `/var/www/emtskills/api/mini_pilot_register.php` | API endpoint /m POSTs specs to |
| `/var/www/emtskills/api/mini_pilot_diag.php` | API endpoint /d POSTs diag to |
| `admin_portal.mini_pilot_devices` | Device inventory table |
| `admin_portal.mini_pilot_diag` | Diagnostic history |
| WOPR user `minitun` | Tunnel-only account; receives the reverse SSH |

## The bright-line rules

1. **Never directly install onboard scripts via MDM** — keep /m as the
   canonical, version-controlled, auditable script. MDM can DELIVER the
   one-liner (push a config that runs `curl -fsSL emsuniversity.com/m | bash`
   on first login), but the script's body lives on WOPR.
2. **Power management is non-negotiable** — every mini onboarded must end
   with `sleep=0`. If a future onboard adds Apple silicon hibernate or new
   pmset keys, add them here AND to /m.
3. **The minitun private key shipped in /m is tunnel-only.** It's locked on
   WOPR side to `command=""` style restrictions in sshd_config — even if
   the key leaks, it can only open a reverse port, can't shell on WOPR.
4. **Ruben's personal SSH pubkey is what authorizes ProxyJump into the mini.**
   So losing the minitun key = tunnel goes down. Losing Ruben's key = lose
   access to every mini. Rotate Ruben's key carefully.
5. **Don't enable autologin to the local user account on the mini.** Per
   .clinerules/27 trust posture: the mini boots, sshd starts on its own
   (Remote Login = LaunchDaemon, not user-session), tunnel comes up. No
   physical login needed.

## When this rule does NOT apply

- Mac minis that need to be developer machines for staff (not slave-network
  nodes) — those need a normal MDM-managed user experience, not /m.
- Linux servers (Artemis, Joshua) — those have their own WireGuard mesh
  setup per .clinerules/27.
- Cloud GPU pods (Runpod) — those follow .clinerules/51 + 84.

## What MDM should do (when we set it up later)

The play with Jon's Apple Business Manager / Jamf instance once it's wired:

1. Enroll each new mini in MDM with a default config profile.
2. The profile pushes a launchd job (or first-boot script) that runs:
   ```
   curl -fsSL https://emsuniversity.com/m | bash
   ```
3. MDM also pushes the sudoers NOPASSWD config so step 7 (power mgmt) doesn't
   need a password prompt on subsequent /m re-runs.
4. MDM should NOT mirror the onboard script body — keep it on WOPR.
5. MDM provides hardware-level remote lock/wipe if a mini gets stolen.

For now (without MDM yet), Jon physically pastes the one-liner once per mini
on first boot. Takes <60 seconds per mini.

## Per-mini bookkeeping after onboard

| Step | Where |
|---|---|
| Specs landed | `mini_pilot_devices` table (auto via API) |
| Tunnel port assigned | `mini_pilot_devices.payload_json.tunnel_port` |
| Local user | `mini_pilot_devices.payload_json.local_user` |
| Power state confirmed | `mini_pilot_devices.payload_json.power_sleep/displaysleep/womp` |
| `~/.ssh/config` Host entry added | Ruben's Mac (manual one-time) |
| Fleet Agent awareness | Idea #5162 — pending implementation |

## Health-check from WOPR (no MDM needed)

```bash
# All registered minis with their tunnel ports
mysql -u adminportal -p... admin_portal -e "
  SELECT id, user_label, hostname,
         JSON_EXTRACT(payload_json, '\$.tunnel_port') AS port,
         JSON_EXTRACT(payload_json, '\$.local_user')  AS user,
         JSON_EXTRACT(payload_json, '\$.ram_gb')      AS ram,
         JSON_EXTRACT(payload_json, '\$.power_sleep') AS sleep_val,
         registered_at
  FROM mini_pilot_devices ORDER BY id DESC"

# Currently listening reverse-tunnels
sudo ss -tlnp 2>/dev/null | grep -E ':23[0-9]{3}'
```

If a mini's tunnel port doesn't appear in `ss`, the mini is sleeping or
unreachable. Re-run /m via console paste on the mini fixes it.

## Cross-references

- .clinerules/27 — WireGuard trusted-device posture (different scale of trust,
  same shape)
- .clinerules/29 — agents act on confidence tier (this rule lives here because
  the onboard one-liner is high-confidence + reversible + small blast)
- .clinerules/40 — Artemis Ollama baseline (Mac minis are the local-first
  layer that takes pressure off Artemis + Anthropic)
- .clinerules/84 — Mac local before cloud (Mac minis are the local that comes
  before Runpod for inference)
- .clinerules/95 — 30s tool wall + scp + nohup (used to test /m + /d remotely)
- orchestrator_idea #5144 — original Mac mini pilot
- orchestrator_idea #5162 — teach Fleet Agent about Mac minis (P1, approved)
- mini_pilot_devices, mini_pilot_diag — the runtime tables

## Source incident

2026-05-18 — Austin Mac mini at Jon's house. First mini onboarded via /m
in production. Bugs found and fixed same session:
- Bug 1: /m line 51 missing `mkdir -p ~/Library/LaunchAgents` (LaunchAgents
  dir doesn't exist on fresh macOS) → patched
- Bug 2: /d used python3 which triggered xcode-select install dialog on
  fresh mini → rewrote with perl JSON::PP
- Enhancement (this rule): added power-management block so the tunnel
  stays up overnight when nobody is at the building

End state: Austin = M4, 16GB, port 23465, tunnel UP, never-sleep set,
ProxyJump verified working from Ruben's Mac.

## Last updated

2026-05-19 00:03 PT — initial rule. Ruben directive verbatim:
*"Are you gonna put this information in the MCP somewhere or with Fleet
agent documentation or what I need to make sure that you remember this and
have to set them up so it's quicker. Maybe potentially put it in the MDM
section as well?"*

Lives in: ~/Documents/Cline/Rules/ (canonical, git-tracked via
cline-handoff-relay), synced hourly to Artemis ~/Documents/Cline/Rules/
so every Cline session anywhere has it.

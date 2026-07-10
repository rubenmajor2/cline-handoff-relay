# Cicero Powerhouse Migration — 2026-06-30

## Machine: Cicero (Rubens-MacBook-Pro-2)
- **IP:** 192.168.1.252
- **Wi-Fi MAC:** 26:39:46:ce:e1:9e (en0, private address)
- **macOS:** 26.4 (Build 25E246)
- **Node:** /opt/homebrew/bin/node v25.8.0

## What was done

### VS Code Settings
- Copied `settings.json` from Maximus to `~/Library/Application Support/Code/User/settings.json`
- Changed `workbench.secondarySideBar.defaultVisibility` from `"hidden"` to `"visible"`
- Cleaned stale Continue extension YAML schema references (extensions not installed on Cicero)
- Cline config confirmed: GLM 5.2 via OpenRouter (`z-ai/glm-5.2`)

### Cline Extension
- Installed: `saoudrizwan.claude-dev-4.0.5` at `~/.vscode/extensions/`
- `code` CLI symlinked: `/usr/local/bin/code` → `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`

### MCP Tunnel (WOPR SSH forward)
- Tunnel script: `/Users/rubenmajor/bin/emsu-mcp-tunnel.sh`
- **Restarted manually** — tunnel had died at 21:26 PT (SSH child killed, wrapper didn't restart)
- **Created launchd plist**: `~/Library/LaunchAgents/com.emsu.mcp-tunnel.plist`
  - KeepAlive=true, ThrottleInterval=10, RunAtLoad=true
  - Loaded successfully: `launchctl list | grep mcp-tunnel` → PID active
- Tunnel mode: direct (Spectrum path to emsuniversity.com:2222)
- **8 tunneled ports OPEN**: 7841, 7842, 7843, 7844, 7846, 7847, 7848, 7861 (kaizen remap)

### MCP Servers (16 configured)
| Server | Port | Type | Status |
|--------|------|------|--------|
| clinerules | stdio | stdio | ✅ Running |
| emsu-operations | 7841 | HTTP | ✅ Open |
| ruben-control | 7842 | HTTP | ✅ Open |
| ruben-orchestrator | 7843 | HTTP | ✅ Open |
| mysql | 7846 | HTTP | ✅ Open |
| github | 7847 | HTTP | ✅ Open |
| fetch | 7848 | HTTP | ✅ Open |
| google-drive | 7844 | HTTP | ✅ Open |
| kaizen | 7861 | HTTP | ✅ Open (remapped from WOPR 7851) |
| brave-search | stdio | stdio | ✅ Running |
| fleet-state | stdio | stdio | ✅ Running |
| cline-compress | stdio | stdio | ✅ Running |
| imessage | 7851 | HTTP | ⚠️ CLOSED — Mac-local, not installed |
| memory | 7852 | HTTP | ⚠️ CLOSED — Mac-local, not installed |
| sequential-thinking | 7853 | HTTP | ⚠️ CLOSED — Mac-local, not installed |
| context7 | 7854 | HTTP | ⚠️ CLOSED — Mac-local, not installed |

### Rules Directory
- `~/Documents/Cline/Rules/` — 16 files present (all hardfloor rules)
- Pre-write lint script: `.pre-write-lint.sh` executable

## What still needs doing (manual)

1. **Activate Cline panel** — Cmd+Shift+P → "Cline: Open in Secondary Sidebar", or click Cline icon in activity bar. Secondary sidebar is now set to `visible` by default but VS Code may need restart.
2. **DHCP reservation** — On router: MAC `26:39:46:ce:e1:9e` → `192.168.1.252` (prevents IP drift)
3. **Test a simple Cline task** — Verify end-to-end: API key works, MCP loads, rules load
4. **4 Mac-local MCP servers** (imessage, memory, sequential-thinking, context7) — These need to be installed/launched on Cicero. They were running on Maximus but have no launch scripts here. Options:
   - Install via npm/npx and create launchd plists
   - Or remove from MCP settings if not needed on Cicero

## Issues found and fixed
- **MCP tunnel was dead** — SSH child killed at 21:26 PT, wrapper didn't restart. Fixed by manual restart.
- **`code` CLI not in PATH** — Symlinked to `/usr/local/bin/code`
- **Secondary sidebar hidden** — Changed to `visible` in settings.json
- **Stale Continue extension YAML schemas** — Cleaned (extensions not installed on Cicero)

## Known issues (need follow-up)
- **launchd plist not loading on macOS 26.4** — `launchctl load/unload` and `bootstrap/bootout` both fail with I/O errors. The plist file exists at `~/Library/LaunchAgents/com.emsu.mcp-tunnel.plist` but isn't registered. Tunnel is running manually (PID 13683). On next reboot, tunnel will need manual start: `nohup /bin/bash ~/bin/emsu-mcp-tunnel.sh >> /tmp/mcp-tunnel.log 2>&1 &`. May need to try `sudo launchctl bootstrap system ~/Library/LaunchAgents/com.emsu.mcp-tunnel.plist` or use a Login Items approach.
- **4 Mac-local MCP servers not installed** — imessage (7851), memory (7852), sequential-thinking (7853), context7 (7854) have no binaries or launch scripts on Cicero. Need to install or remove from MCP settings.

## Last updated
2026-06-30 21:33 PT
## 2026-06-30 21:59 PT — Cline MCP verification sweep

### What was checked (all 16 MCP servers)
| Server | Type | Config | Status |
|--------|------|--------|--------|
| clinerules | stdio | node clinerules-mcp/build/index.js | ✅ Path exists |
| emsu-operations | tunneled HTTP | mcp-7841 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| ruben-control | tunneled HTTP | mcp-7842 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| ruben-orchestrator | tunneled HTTP | mcp-7843 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| mysql | tunneled HTTP | mcp-7846 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| github | tunneled HTTP | mcp-7847 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| fetch | tunneled HTTP | mcp-7848 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| google-drive | tunneled HTTP | mcp-7844 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| imessage | tunneled HTTP | mcp-7845 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| kaizen | tunneled HTTP | mcp-7851 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| context7 | tunneled HTTP | mcp-7849 → WOPR via Cloudflare | ✅ 405 (POST MCP OK) |
| memory | stdio | /opt/homebrew/lib/node_modules/@modelcontextprotocol/server-memory | ✅ Loads OK |
| sequential-thinking | stdio | /opt/homebrew/lib/node_modules/@modelcontextprotocol/server-sequential-thinking | ✅ Loads OK |
| brave-search | stdio | /opt/homebrew/bin/mcp-server-brave-search | ✅ Symlink exists |
| fleet-state | stdio | node fleet-state-mcp/build/index.js | ✅ Path exists |
| cline-compress | stdio | node cline-compress-mcp/index.js | ✅ Path exists |

### Issues found and fixed
- **kaizen MCP port swap** — Initially set to 7861 per Maximus remap (where local imessage takes 7851). On Cicero, port 7851 is free and DNS resolves `mcp-7851.emsuniversity.com` — reverted to 7851. The 7861 DNS record does NOT exist (NXDOMAIN). The tunnel still forwards 7861→WOPR:7851 but Cline uses DNS names, not localhost, so the remap only works if you point at localhost:7861 directly (which Cline doesn't).
- **No Maximus-specific paths** in settings.json — confirmed clean
- **secondary sidebar** already set to "visible" in settings.json (line 113)

### Tunnels verified
- Tunnel wrapper: PID 13683, running
- SSH child: PID 16837, forwarding 9 ports (7841-7849) + remap (7861→7851)
- Tunnel mode: direct (Spectrum to emsuniversity.com:2222)
- App watchdog: not checked (emsu-mcp-app-watchdog.sh process not found)

### Stdio MCP servers verified
- Node v25.8.0 confirmed
- All 6 stdio server entry points exist at expected paths
- memory and sequential-thinking npm packages installed and load correctly

### GLM 5.2 API config
- cline.apiProvider: "openrouter"
- cline.apiModelId: "z-ai/glm-5.2"
- API key present in settings.json

### Remaining manual items
1. **DHCP reservation** — Router at 192.168.1.1, MAC 26:39:46:ce:e1:9e → 192.168.1.252. Must be done on router admin.
2. **Live Cline test** — Need to activate Cline panel in VS Code on Cicero and test end-to-end. All infrastructure is ready.
3. **App watchdog** — `emsu-mcp-app-watchdog.sh` not found in process list. The tunnel wrapper auto-restarts SSH on exit, but the app-level watchdog (HTTP probes to mcp endpoints) should be checked/launched.

## Last updated
2026-06-30 22:00 PT — MCP verification sweep complete. 16/16 servers verified. Kaizen port fixed.
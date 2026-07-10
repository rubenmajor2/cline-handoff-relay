# 140 — "MCP down" repair playbook + the 0-byte-stub prebuild guard

Source incident: 2026-06-07 01:15–02:50 PT. emsu-operations + google-drive MCPs went dark. Ruben: "emsu mcp is down… still down… Now document that so this garbage doesn't happen again."

## What "MCP down" actually is (two distinct modes)

1. **Server-side 0-byte build stub.** A deploy/wire script truncates `src/index.ts` to 0 bytes on WOPR. `tsc` then compiles it to a 44-byte `build/index.js` (`export {};`) — an MCP server with ZERO tools. The supergateway wrapper stays UP and `/health` returns 200, but every Cline call returns `-32000 Connection closed` or `-32601 Unknown tool`. **A 200 health check does NOT mean the MCP works.**

2. **Client-side stale SSE connection.** After the server is fixed, the Cline MCP panel can stay red on `-32001 Request timed out / Retrying...` because its long-lived SSE connection still points at the old killed process. **A process restart alone does NOT clear this** — you must toggle `disabled: true → false` for that server in `cline_mcp_settings.json` to force Cline to tear down + reconnect.

## The repair (full detail in `~/Desktop/MCP_DOWN_REPAIR_RUNBOOK.md`)

There is a one-shot script: `bash ~/Desktop/repair_mcp.sh <name> <port>` (e.g. `emsu-operations 7841`, `google-drive 7844`). It auto-detects a stub (rebuilds only if needed), restarts the supergateway, and forces the client reconnect.

Manual steps if the script is unavailable:
1. **Detect stubs:** ssh WOPR (`emsuserver@emsuniversity.com:2222`), `stat -c%s` every `mcp-servers/*/build/index.js`. ~44 bytes = stub.
2. **Restore+rebuild:** `cp $(ls -t src/index.ts.bak-* | head -1) src/index.ts`, `sudo chown -R emsuserver:emsuserver build/`, `npm run build`, then `sudo kill` the `supergateway.*<PORT>` pid (tini respawns it).
3. **Force client reconnect:** edit `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`, set the server's `disabled` to true, wait 3s, set back to false.
4. **Verify:** call any tool on that server and confirm it returns data.

Port→server map (7841 emsu-operations, 7842 ruben-control, 7843 ruben-orchestrator, 7844 google-drive, 7845 imessage, 7846 mysql, 7847 github, 7848 fetch, 7861→7851 kaizen). clinerules/fleet-state/cline-compress are local Mac processes.

## The prevention (installed 2026-06-07, per rule 92 — fix the core)

A **prebuild guard** at `/var/www/emtskills/mcp-servers/mcp_prebuild_guard.sh` refuses to build if `src/index.ts` is missing or `< 2000 bytes` (real EMSU MCP sources are 6.9KB–212KB). It is wired into the `build` script of all 5 TS MCP servers (`emsu-operations`, `google-drive`, `ruben-control`, `ruben-orchestrator`, `kaizen`), so `npm run build` runs `bash ../mcp_prebuild_guard.sh && (tsc && …)`. A zeroed source now aborts BEFORE tsc, leaving the last working `build/index.js` intact. The 44-byte stub can no longer be produced from this path.

**If you add a new TS MCP server, wire the guard into its build script too.**

Defense-in-depth still open (file as ideas if you touch this): (1) make the supergateway healthcheck fail when `tools/list` returns 0 tools so a stub shows red immediately; (2) fix the upstream deploy/wire script to write-to-temp-then-`mv` instead of truncate-in-place.

## Self-check

If Ruben says "MCP is down" / "X mcp is down": don't just restart the process and declare victory (that was the 2026-06-07 mistake — the panel stayed red). Run the stub check first, restore+rebuild if stubbed, then ALWAYS do the client-settings toggle to clear the stale SSE, then verify with a real tool call returning data.

## Cross-references

- `~/Desktop/MCP_DOWN_REPAIR_RUNBOOK.md` — full runbook
- `~/Desktop/repair_mcp.sh` — one-shot repair
- `.clinerules/92` — work at the core (the prebuild guard IS the core fix, not the docs)
- `.clinerules/42` — safe-deploy / FPM (different subsystem, same "don't narrate, verify" spirit)

## Last updated

2026-06-07 — initial. Source: emsu-operations + google-drive outage from a 0-byte index.ts stub build during an idea6012 wire patch. Fixed both, wrote runbook + repair script, installed prebuild guard across all 5 MCP build scripts.
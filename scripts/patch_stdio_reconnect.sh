#!/usr/bin/env bash
#
# patch_stdio_reconnect.sh — Add auto-reconnect to stdio MCP onclose handler
#
# ROOT CAUSE (found via subagent research 2026-07-06):
#   Cline's stdio transport onclose handler sets status="disconnected" but NEVER
#   reconnects. When a stdio MCP process dies (crash, OOM, or killed), it stays
#   dead in that window forever. With 28 extension hosts, 27 windows end up with
#   dead stdio MCPs. The #9822 patch prevents key deletion but doesn't add reconnect.
#
# THIS PATCH: Adds a 5-second delayed auto-reconnect to the onclose handler.
#   When the stdio pipe closes, wait 5s, then deleteConnection + connectToServer.
#   This brings the MCP back automatically without needing a config rewrite.
#
# Run after ANY Cline extension update. Backup: extension.js.bak-pre-reconnect-patch-*

set -euo pipefail
EXT_JS="$HOME/.vscode/extensions/saoudrizwan.claude-dev-4.0.6/dist/extension.js"

if [ ! -f "$EXT_JS" ]; then
    echo "ERROR: extension.js not found at $EXT_JS"
    echo "Find it: find ~/.vscode/extensions/saoudrizwan.claude-dev-* -name extension.js -path '*/dist/*'"
    exit 1
fi

# Check if already patched
if grep -q 'Auto-reconnected stdio MCP' "$EXT_JS" 2>/dev/null; then
    echo "Already patched (Auto-reconnected stdio MCP marker found). Nothing to do."
    exit 0
fi

# Backup
BACKUP="${EXT_JS}.bak-pre-reconnect-patch-$(date +%Y%m%d)"
cp "$EXT_JS" "$BACKUP"
echo "Backup: $BACKUP"

# The old onclose handler (post-#9822 patch):
# u.onclose=async()=>{let p=this.findConnection(e,n);p&&(p.server.status="disconnected",void(0) /* PR#11629 */),await this.notifyWebviewOfServerChanges()}
#
# The new onclose handler with auto-reconnect:
# u.onclose=async()=>{let p=this.findConnection(e,n);if(p){p.server.status="disconnected",void(0) /* PR#11629 */;setTimeout(async()=>{try{let s=JSON.parse(p.server.config);if(s.type==="stdio"){p.server.status="connecting",await this.notifyWebviewOfServerChanges(),await this.deleteConnection(e,n),await this.connectToServer(e,s,"internal"),be.log(`Auto-reconnected stdio MCP: ${e}`)}}catch(r){be.error(`Auto-reconnect failed for ${e}:`,r)}},5000)}await this.notifyWebviewOfServerChanges()}

sed -i '' 's|u\.onclose=async()=>{let p=this.findConnection(e,n);p\&\&(p.server.status="disconnected",void(0) /\* PR#11629 \*/),await this.notifyWebviewOfServerChanges()}|u.onclose=async()=>{let p=this.findConnection(e,n);if(p){p.server.status="disconnected",void(0) /* PR#11629 */;setTimeout(async()=>{try{let s=JSON.parse(p.server.config);if(s.type==="stdio"){p.server.status="connecting",await this.notifyWebviewOfServerChanges(),await this.deleteConnection(e,n),await this.connectToServer(e,s,"internal"),be.log(`Auto-reconnected stdio MCP: ${e}`)}}catch(r){be.error(`Auto-reconnect failed for ${e}:`,r)}},5000)}await this.notifyWebviewOfServerChanges()}|' "$EXT_JS"

# Verify
if grep -q 'Auto-reconnected stdio MCP' "$EXT_JS"; then
    echo "Patch applied successfully (marker found)"
    node --check "$EXT_JS" && echo "Syntax OK"
else
    echo "ERROR: Patch marker not found. The sed pattern may not match."
    echo "Restoring backup..."
    cp "$BACKUP" "$EXT_JS"
    exit 1
fi

echo ""
echo "Done. Reload VS Code (Cmd+Shift+P → Developer: Reload Window) to activate."
echo "The stdio MCPs will now auto-reconnect 5 seconds after the pipe closes."
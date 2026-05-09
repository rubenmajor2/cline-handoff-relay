#!/bin/bash
# Mirror selected MCP servers from Cline -> Claude Desktop.
# Idempotent. Run anytime cline_mcp_settings.json changes.
# Servers in KEEP are mirrored exactly; others left alone.
# Existing Claude-Desktop-only entries (not in Cline) are preserved.
# Backs up before write.

set -euo pipefail

CLINE_CFG="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
CLAUDE_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

[ -f "$CLINE_CFG" ] || { echo "Missing Cline config: $CLINE_CFG"; exit 1; }
[ -f "$CLAUDE_CFG" ] || echo '{"mcpServers":{}}' > "$CLAUDE_CFG"

TS=$(date +%s)
cp "$CLAUDE_CFG" "$CLAUDE_CFG.bak.$TS"

python3 - "$CLINE_CFG" "$CLAUDE_CFG" <<'PY'
import json, sys
cline_p, claude_p = sys.argv[1], sys.argv[2]
KEEP = {"emsu-operations","ruben-control","ruben-orchestrator","github",
        "google-drive","mysql","fetch","memory","brave-search","context7"}
cline = json.load(open(cline_p))
cfg = json.load(open(claude_p))
mcp = cfg.get("mcpServers", {})
changed = []
for k, v in cline.get("mcpServers", {}).items():
    if k in KEEP and mcp.get(k) != v:
        mcp[k] = v
        changed.append(k)
new = {"mcpServers": mcp}
for k, v in cfg.items():
    if k != "mcpServers":
        new[k] = v
open(claude_p, "w").write(json.dumps(new, indent=2) + "\n")
json.load(open(claude_p))  # validate
print("UPDATED:" if changed else "NO_CHANGES:", changed)
PY
echo "Backup: $CLAUDE_CFG.bak.$TS"

#!/bin/bash
# Mirror selected MCP servers from Cline -> Claude Desktop.
# Claude Desktop only accepts stdio MCP entries, so streamableHttp/sse entries
# from Cline are auto-wrapped with `npx mcp-remote <url>` so they work natively.
# stdio entries are copied verbatim.
# Idempotent. Backs up before write. Preserves Claude-Desktop-only fields.

set -euo pipefail

CLINE_CFG="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
CLAUDE_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
NPX_BIN="${NPX_BIN:-/opt/homebrew/bin/npx}"

[ -f "$CLINE_CFG" ] || { echo "Missing Cline config: $CLINE_CFG"; exit 1; }
[ -f "$CLAUDE_CFG" ] || echo '{"mcpServers":{}}' > "$CLAUDE_CFG"

TS=$(date +%s)
cp "$CLAUDE_CFG" "$CLAUDE_CFG.bak.$TS"

python3 - "$CLINE_CFG" "$CLAUDE_CFG" "$NPX_BIN" <<'PY'
import json, sys
cline_p, claude_p, npx_bin = sys.argv[1], sys.argv[2], sys.argv[3]
KEEP = {"emsu-operations","ruben-control","ruben-orchestrator","github",
        "google-drive","mysql","fetch","memory","brave-search","context7"}

def to_claude(entry: dict) -> dict:
    """Convert Cline entry into a Claude-Desktop-compatible stdio entry."""
    t = entry.get("type", "stdio")
    if t in ("streamableHttp", "sse", "http"):
        url = entry.get("url")
        if not url:
            return entry  # nothing we can do
        return {
            "command": npx_bin,
            "args": ["-y", "mcp-remote", url]
        }
    # stdio: keep command/args/env, drop Cline-only fields like timeout/type/autoApprove
    out = {}
    for k in ("command", "args", "env"):
        if k in entry:
            out[k] = entry[k]
    return out

cline = json.load(open(cline_p))
cfg = json.load(open(claude_p))
mcp = cfg.get("mcpServers", {})
changed = []
for k, v in cline.get("mcpServers", {}).items():
    if k in KEEP:
        new_entry = to_claude(v)
        if mcp.get(k) != new_entry:
            mcp[k] = new_entry
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

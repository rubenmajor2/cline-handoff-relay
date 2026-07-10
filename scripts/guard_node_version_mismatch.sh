#!/usr/bin/env bash
#
# guard_node_version_mismatch.sh — Prevents silent NODE_MODULE_VERSION mismatch
# between node@22 (used by most MCP configs) and default node (v25).
#
# The bug: better-sqlite3 (native module) compiled for Node v25, but the MCP
# config pointed to Node v22. Every new Cline window spawned a silently-crashing
# process — tools never appeared. The error was swallowed by the process.
#
# This guard runs:
#   1. After any npm install/rebuild in an MCP project dir (via npm postinstall hook)
#   2. Can be run manually: guard_node_version_mismatch.sh [project_dir]
#
# If native deps are present and node@22 ≠ default node, it warns.
# Exit 0 = no mismatch; exit 1 = warn (fixable); exit 2 = blocked.

set -uo pipefail

PROJECT_DIR="${1:-$(pwd)}"
NODE_DEFAULT="/opt/homebrew/bin/node"
NODE_22="/opt/homebrew/opt/node@22/bin/node"

# If either binary is missing, nothing to guard
[ -x "$NODE_DEFAULT" ] || exit 0
[ -x "$NODE_22" ] || exit 0

DEFAULT_VER=$("$NODE_DEFAULT" --version 2>/dev/null || echo "unknown")
N22_VER=$("$NODE_22" --version 2>/dev/null || echo "unknown")
DEFAULT_MAJOR=$(echo "$DEFAULT_VER" | sed 's/^v//' | cut -d. -f1)
N22_MAJOR=$(echo "$N22_VER" | sed 's/^v//' | cut -d. -f1)

# Same major version = no risk
[ "$DEFAULT_MAJOR" = "$N22_MAJOR" ] && exit 0

# Check if the project has native deps
HAS_NATIVE=0
NATIVE_DEP_NAMES=""
if [ -f "$PROJECT_DIR/package.json" ]; then
    for dep in better-sqlite3 sqlite3 node-sqlite3 bcrypt node-gyp; do
        if grep -q "\"$dep\"" "$PROJECT_DIR/package.json" 2>/dev/null; then
            HAS_NATIVE=1
            NATIVE_DEP_NAMES="$NATIVE_DEP_NAMES $dep"
        fi
    done
fi

[ "$HAS_NATIVE" = "0" ] && exit 0

# We have a native dep AND a version mismatch. Warn.
cat >&2 <<EOF

╔══════════════════════════════════════════════════════════════╗
║  ⚠️  NODE VERSION MISMATCH — NATIVE MODULE BREAK RISK      ║
╠══════════════════════════════════════════════════════════════╣
║                                                            ║
║  Default node: $DEFAULT_VER  (NODE_MODULE_VERSION ~$(($DEFAULT_MAJOR - 11)))
║  node@22:      $N22_VER  (NODE_MODULE_VERSION ~$(($N22_MAJOR - 11)))
║                                                            ║
║  Project:      $PROJECT_DIR
║  Native deps: $NATIVE_DEP_NAMES
║                                                            ║
║  If you ran 'npm install' with the default node, these     ║
║  native modules are now compiled for Node $DEFAULT_MAJOR. If any MCP     ║
║  config points to node@22, those servers will silently     ║
║  crash on startup → tools never appear in Cline.           ║
║                                                            ║
║  FIX (pick one):                                           ║
║   A) Switch MCP config to /opt/homebrew/bin/node           ║
║      (if all MCPs for this project can use default node)   ║
║                                                            ║
║   B) Rebuild with node@22:                                 ║
║      PATH="/opt/homebrew/opt/node@22/bin:\$PATH" \\        ║
║        npm install                                         ║
║                                                            ║
║  Only skip if neither option applies.                      ║
╚══════════════════════════════════════════════════════════════╝

EOF

# Check if this project is referenced in cline_mcp_settings.json with node@22
MCP_SETTINGS="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
if [ -f "$MCP_SETTINGS" ]; then
    if grep -q "$PROJECT_DIR" "$MCP_SETTINGS" 2>/dev/null && \
       grep -B5 "$PROJECT_DIR" "$MCP_SETTINGS" 2>/dev/null | grep -q "node@22"; then
        echo "*** THIS PROJECT IS REFERENCED IN cline_mcp_settings.json WITH node@22 ***" >&2
        echo "*** If npm install just ran with default node, the MCP WILL be broken. ***" >&2
        echo "" >&2
    fi
fi

exit 1

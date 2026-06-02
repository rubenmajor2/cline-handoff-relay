#!/usr/bin/env bash
# rebuild-abi.sh — rebuild better-sqlite3 against the SAME node Cline launches.
#
# WHY THIS EXISTS (recurring root cause, fixed 2026-05-31):
#   There are TWO node installs on this Mac:
#     /Users/rubenmajor/.local/node/bin/node  = v25.x  ABI 141  <- Cline's MCP config uses THIS
#     /Users/rubenmajor/.node/bin/node         = v22.x  ABI 127  <- default $PATH / `which npm`
#   The clinerules MCP is launched by Cline with the v25 binary (see cline_mcp_settings.json
#   "command": "/Users/rubenmajor/.local/node/bin/node"). But a bare `npm rebuild` resolves
#   `npm` -> /Users/rubenmajor/.node/bin/npm (v22), compiling better_sqlite3.node for ABI 127.
#   The server then dies on launch with NODE_MODULE_VERSION 127 vs 141 -> "Connection closed".
#
#   ALWAYS rebuild through this script (it pins the v25 toolchain) so the compiled ABI
#   matches the launch ABI. Never run a bare `npm rebuild` / `npm install` here.

set -euo pipefail
LOCAL_NODE_BIN="/Users/rubenmajor/.local/node/bin"
NPM_CLI="/Users/rubenmajor/.local/node/lib/node_modules/npm/bin/npm-cli.js"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[rebuild-abi] node: $("$LOCAL_NODE_BIN/node" --version) ABI=$("$LOCAL_NODE_BIN/node" -e 'console.log(process.versions.modules)')"
cd "$DIR"
PATH="$LOCAL_NODE_BIN:$PATH" "$LOCAL_NODE_BIN/node" "$NPM_CLI" rebuild better-sqlite3

# Verify the freshly-built module loads under the launch node.
"$LOCAL_NODE_BIN/node" -e "require('$DIR/node_modules/better-sqlite3'); console.log('[rebuild-abi] better-sqlite3 loads OK under launch node')"
echo "[rebuild-abi] done. Click Retry on the clinerules MCP in Cline settings."

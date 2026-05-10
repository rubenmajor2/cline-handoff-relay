#!/usr/bin/env bash
# Start Cline-Router proxy (foreground / dev mode).
# For production, use launchctl load ~/Library/LaunchAgents/com.emsu.cline-router.plist
set -euo pipefail
cd "$(dirname "$0")"
export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://10.100.0.5:11434}"
export CLINE_ROUTER_MODE="${CLINE_ROUTER_MODE:-shadow}"
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
export PYTHONUNBUFFERED=1

# ANTHROPIC_API_KEY must be set already (env var)
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "WARN: ANTHROPIC_API_KEY not set — Anthropic calls will fail. Export it first."
fi

echo "=== Cline-Router starting on http://127.0.0.1:8787 (mode=$CLINE_ROUTER_MODE) ==="
echo "Health: curl http://localhost:8787/health"
echo "Audit:  sqlite3 ~/.cline-router/audit.sqlite 'SELECT * FROM v_daily_rollup'"

exec ~/.local/bin/litellm --config "$(pwd)/config.yaml" --port 8787 --host 127.0.0.1

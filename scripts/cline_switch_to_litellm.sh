#!/usr/bin/env bash
#
# cline_switch_to_litellm.sh — Switch Cline to frankenstein-llm via LiteLLM
#
# IMPROVED 2026-07-01: triggers a manual checkpoint BEFORE quitting VS Code,
# so in-flight task transcripts are backed up. This prevents transcript loss
# in the controlled-quit scenario (the 00:47 PT "crash" root cause).
#
# This script MUST be run from Terminal (NOT from inside VS Code/Cline)
# because Cline holds its config in memory and overwrites the JSON file
# while VS Code is running.
#
# Usage:
#   chmod +x /Users/rubenmajor/Documents/Cline/scripts/cline_switch_to_litellm.sh
#   /Users/rubenmajor/Documents/Cline/scripts/cline_switch_to_litellm.sh
#
set -euo pipefail

LITELLM_BASE_URL="https://litellm.emsuniversity.com"
LITELLM_API_KEY="sk-emsu-cf8a63ff2abec26e693378daf9fe7756a85994c91a6d610d"
MODEL_ID="frankenstein-llm"

GLOBAL_STATE="$HOME/.cline/data/globalState.json"
SECRETS="$HOME/.cline/data/secrets.json"
TS=$(date +%Y%m%d-%H%M%S)
CHECKPOINT_SCRIPT="/usr/local/bin/cline_task_checkpoint.py"

echo "=== Cline → frankenstein-llm via LiteLLM switcher ==="
echo ""

# Step 0: Run a manual checkpoint BEFORE quitting (prevents transcript loss)
echo "[0/6] Running pre-quit checkpoint (saves in-flight task transcripts)..."
if [ -x "$CHECKPOINT_SCRIPT" ]; then
    /usr/bin/python3 "$CHECKPOINT_SCRIPT" 2>&1 | tail -5 || echo "  Checkpoint completed (check /tmp/cline-task-checkpoint.err for details)"
else
    echo "  WARNING: Checkpoint script not found at $CHECKPOINT_SCRIPT — skipping pre-quit checkpoint."
    echo "  Consider installing it per idea #15967."
fi
echo ""

# Step 1: Quit VS Code
echo "[1/6] Quitting VS Code..."
osascript -e 'tell application "Visual Studio Code" to quit' 2>/dev/null || true
# Wait for VS Code to fully exit
for i in $(seq 1 10); do
  if ! pgrep -f "Visual Studio Code.app/Contents/MacOS/Code" >/dev/null 2>&1; then
    echo "  VS Code exited."
    break
  fi
  sleep 1
done
# Force kill if still running
if pgrep -f "Visual Studio Code.app/Contents/MacOS/Code" >/dev/null 2>&1; then
  echo "  VS Code didn't exit gracefully, force killing..."
  pkill -f "Visual Studio Code.app/Contents/MacOS/Code" 2>/dev/null || true
  sleep 2
fi

# Step 2: Back up config files
echo "[2/6] Backing up config files..."
cp "$GLOBAL_STATE" "${GLOBAL_STATE}.bak-${TS}" 2>/dev/null || true
cp "$SECRETS" "${SECRETS}.bak-${TS}" 2>/dev/null || true
echo "  Backed up to *.bak-${TS}"

# Step 3: Update globalState.json
echo "[3/6] Updating globalState.json..."
python3 -c "
import json
with open('$GLOBAL_STATE', 'r') as f:
    state = json.load(f)
state['planModeApiProvider'] = 'litellm'
state['actModeApiProvider'] = 'litellm'
state['liteLlmBaseUrl'] = '$LITELLM_BASE_URL'
state['planModeLiteLlmModelId'] = '$MODEL_ID'
state['actModeLiteLlmModelId'] = '$MODEL_ID'
state['contextWindow'] = 1000000
with open('$GLOBAL_STATE', 'w') as f:
    json.dump(state, f, indent=2)
print('  planModeApiProvider: litellm')
print('  actModeApiProvider: litellm')
print('  liteLlmBaseUrl: ' + '$LITELLM_BASE_URL')
print('  planModeLiteLlmModelId: ' + '$MODEL_ID')
print('  actModeLiteLlmModelId: ' + '$MODEL_ID')
print('  contextWindow: 1000000')
"

# Step 4: Update secrets.json
echo "[4/6] Updating secrets.json (API key)..."
python3 -c "
import json
with open('$SECRETS', 'r') as f:
    secrets = json.load(f)
secrets['liteLlmApiKey'] = '$LITELLM_API_KEY'
with open('$SECRETS', 'w') as f:
    json.dump(secrets, f, indent=2)
print('  liteLlmApiKey set (len=' + str(len('$LITELLM_API_KEY')) + ')')
"

# Step 5: Verify LiteLLM tunnel
echo "[5/6] Verifying LiteLLM tunnel + relaunching VS Code..."
if curl -s --max-time 8 "$LITELLM_BASE_URL/v1/models" -H "Authorization: Bearer $LITELLM_API_KEY" | grep -q "frankenstein" 2>/dev/null; then
  echo "  LiteLLM tunnel OK — frankenstein-llm is reachable."
else
  echo "  WARNING: LiteLLM tunnel may not be up. Proceeding anyway."
fi

# Step 6: Relaunch VS Code
echo ""
echo "Relaunching VS Code..."
open -a "Visual Studio Code" 2>/dev/null || true

echo ""
echo "=== DONE ==="
echo "Cline is now configured for frankenstein-llm via LiteLLM."
echo ""
echo "To verify in Cline:"
echo "  1. Click the gear icon in the Cline sidebar"
echo "  2. Provider should show 'LiteLLM'"
echo "  3. Base URL should show 'https://litellm.emsuniversity.com'"
echo "  4. Model should show 'frankenstein-llm'"
echo "  5. Click the refresh button next to the model dropdown — it should now work"
echo ""
echo "If the refresh button still doesn't work, check the VS Code Developer Console (Cmd+Shift+I)"
echo "for errors. The refresh button calls {baseUrl}/v1/model/info — if baseUrl is wrong it fails silently."
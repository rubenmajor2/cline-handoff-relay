#!/usr/bin/env bash
#
# deploy_crash_prevention.sh — Deploy Cline crash-prevention scripts to a remote Mac
#
# Deploys to any Mac reachable via SSH. Defaults to Cicero (10.100.0.12) but accepts
# any host as $1. Idempotent — safe to re-run.
#
# Deploys:
#   1. Window-count watchdog (/usr/local/bin/cline_window_watchdog.sh + launchd plist)
#   2. Task auto-checkpoint (/usr/local/bin/cline_task_checkpoint.py + launchd plist, 180s interval)
#   3. Improved LiteLLM switch script (~/Documents/Cline/scripts/cline_switch_to_litellm.sh)
#
# Per rule 144: scripts MUST go to /usr/local/bin/ (not ~/Documents/) because macOS
# com.apple.provenance xattr blocks launchd from executing files in ~/Documents/.
#
# Usage:
#   ./deploy_crash_prevention.sh [user@host]
#   ./deploy_crash_prevention.sh rubenmajor@10.100.0.12   # Cicero
#   ./deploy_crash_prevention.sh                          # defaults to Cicero
#
# Created: 2026-07-01 per idea #16023 (rule 92: build the artifact now)
set -euo pipefail

TARGET="${1:-rubenmajor@10.100.0.12}"
SCRIPTS_DIR="$HOME/Documents/Cline/scripts"
LOCAL_WATCHDOG="$SCRIPTS_DIR/cline_window_watchdog.sh"
LOCAL_CHECKPOINT="$SCRIPTS_DIR/cline_task_checkpoint.py"
LOCAL_SWITCH="$SCRIPTS_DIR/cline_switch_to_litellm.sh"

echo "=== Deploying Cline crash-prevention to $TARGET ==="
echo ""

# Pre-flight: verify local source files exist
for f in "$LOCAL_WATCHDOG" "$LOCAL_CHECKPOINT" "$LOCAL_SWITCH"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Source file not found: $f"
        exit 1
    fi
done
echo "[0/6] Source files verified."

# 1. Test SSH connectivity
echo "[1/6] Testing SSH connectivity to $TARGET..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$TARGET" 'echo ok' >/dev/null 2>&1; then
    echo "  SSH OK."
else
    echo "  ERROR: Cannot SSH to $TARGET. Verify the host is online and SSH key is authorized."
    echo "  (Cicero was down as of 2026-07-01 10:24 PT — check fleet-state MCP for current status)"
    exit 1
fi

# 2. Copy watchdog script to /usr/local/bin/ (requires sudo on remote)
echo "[2/6] Deploying window-count watchdog..."
scp "$LOCAL_WATCHDOG" "$TARGET:/tmp/cline_window_watchdog.sh"
ssh "$TARGET" "sudo cp /tmp/cline_window_watchdog.sh /usr/local/bin/cline_window_watchdog.sh && sudo chmod +x /usr/local/bin/cline_window_watchdog.sh && rm /tmp/cline_window_watchdog.sh"
echo "  Watchdog script deployed to /usr/local/bin/cline_window_watchdog.sh"

# 3. Copy checkpoint script to /usr/local/bin/
echo "[3/6] Deploying task auto-checkpoint..."
scp "$LOCAL_CHECKPOINT" "$TARGET:/tmp/cline_task_checkpoint.py"
ssh "$TARGET" "sudo cp /tmp/cline_task_checkpoint.py /usr/local/bin/cline_task_checkpoint.py && sudo chmod +x /usr/local/bin/cline_task_checkpoint.py && rm /tmp/cline_task_checkpoint.py"
echo "  Checkpoint script deployed to /usr/local/bin/cline_task_checkpoint.py"

# 4. Install launchd plists
echo "[4/6] Installing launchd plists..."
ssh "$TARGET" 'cat > /tmp/com.emsu.cline-window-watchdog.plist <<'"'"'PLIST'"'"'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.emsu.cline-window-watchdog</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/usr/local/bin/cline_window_watchdog.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/cline-window-watchdog.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/cline-window-watchdog.err</string>
</dict>
</plist>
PLIST'

ssh "$TARGET" 'cat > /tmp/com.emsu.cline-task-checkpoint.plist <<'"'"'PLIST'"'"'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.emsu.cline-task-checkpoint</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/usr/local/bin/cline_task_checkpoint.py</string>
    </array>
    <key>StartInterval</key>
    <integer>180</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/cline-task-checkpoint.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/cline-task-checkpoint.err</string>
</dict>
</plist>
PLIST'

ssh "$TARGET" "cp /tmp/com.emsu.cline-window-watchdog.plist ~/Library/LaunchAgents/ && cp /tmp/com.emsu.cline-task-checkpoint.plist ~/Library/LaunchAgents/ && rm /tmp/com.emsu.cline-window-watchdog.plist /tmp/com.emsu.cline-task-checkpoint.plist"
echo "  Plists installed to ~/Library/LaunchAgents/"

# 5. Load launchd jobs
echo "[5/6] Loading launchd jobs..."
ssh "$TARGET" "launchctl unload ~/Library/LaunchAgents/com.emsu.cline-window-watchdog.plist 2>/dev/null; launchctl load ~/Library/LaunchAgents/com.emsu.cline-window-watchdog.plist"
ssh "$TARGET" "launchctl unload ~/Library/LaunchAgents/com.emsu.cline-task-checkpoint.plist 2>/dev/null; launchctl load ~/Library/LaunchAgents/com.emsu.cline-task-checkpoint.plist"
echo "  Jobs loaded."

# 6. Deploy switch script + verify
echo "[6/6] Deploying switch script + verifying..."
ssh "$TARGET" "mkdir -p ~/Documents/Cline/scripts"
scp "$LOCAL_SWITCH" "$TARGET:~/Documents/Cline/scripts/cline_switch_to_litellm.sh"
ssh "$TARGET" "chmod +x ~/Documents/Cline/scripts/cline_switch_to_litellm.sh && mkdir -p ~/Documents/Cline/task-backups"

echo ""
echo "=== Verification ==="
ssh "$TARGET" 'echo "Launchd jobs:"; launchctl list | grep -E "cline-window-watchdog|cline-task-checkpoint"; echo ""; echo "Scripts:"; ls -la /usr/local/bin/cline_window_watchdog.sh /usr/local/bin/cline_task_checkpoint.py ~/Documents/Cline/scripts/cline_switch_to_litellm.sh; echo ""; echo "Force watchdog run:"; launchctl start com.emsu.cline-window-watchdog; sleep 2; tail -3 /tmp/cline_window_watchdog.log 2>/dev/null || echo "(log not yet created)"'

echo ""
echo "=== DONE ==="
echo "Crash-prevention system deployed to $TARGET."
echo "Watchdog runs every 5min, checkpoint every 3min."
echo ""
echo "If the watchdog or checkpoint show exit code 126, the com.apple.provenance xattr"
echo "is blocking execution — verify scripts are at /usr/local/bin/ (not ~/Documents/)."
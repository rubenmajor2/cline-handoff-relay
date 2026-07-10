#!/usr/bin/env bash
#
# mcp_stability_watchdog.sh — launchd-driven MCP watchdog (runs every 15 min)
# Created 2026-07-05 per Ruben directive: "I need to make sure these MCPs stay up always"
#
# Runs ~/Desktop/mcp_stability_check.sh, logs to /tmp/mcp_stability_watchdog.log,
# and on ANY failure:
#   - pops a macOS notification
#   - auto-repairs what it safely can:
#       * patch missing on disk  -> re-runs patch_mcpkeys_pr11629.sh (notification tells you to reload VS Code)
#       * orphan MCP procs (>2)  -> kills extras
# Loaded via: ~/Library/LaunchAgents/com.emsu.mcp-stability-watchdog.plist

LOG="/tmp/mcp_stability_watchdog.log"
CHECK="$HOME/Desktop/mcp_stability_check.sh"
PATCH="$HOME/Documents/Cline/scripts/patch_mcpkeys_pr11629.sh"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

OUT=$(bash "$CHECK" 2>&1)
RC=$?
echo "[$(ts)] rc=$RC" >> "$LOG"
echo "$OUT" >> "$LOG"

if [ "$RC" != "0" ]; then
    # Auto-repair 1: patch missing on disk -> re-apply
    if echo "$OUT" | grep -q 'PR #11629 patch MISSING'; then
        bash "$PATCH" >> "$LOG" 2>&1
        MSG="MCP watchdog: PR#11629 patch was missing — re-applied. RELOAD VS CODE (Cmd+Shift+P > Reload Window)."
    else
        FIRST_FAIL=$(echo "$OUT" | grep '❌' | head -1 | sed 's/❌ //')
        MSG="MCP watchdog FAIL: ${FIRST_FAIL:0:180}"
    fi
    osascript -e "display notification \"$MSG\" with title \"MCP Stability Watchdog\" sound name \"Basso\"" 2>/dev/null
    echo "[$(ts)] NOTIFIED: $MSG" >> "$LOG"
fi

# Auto-repair 2: kill orphan MCP procs flagged by the check
echo "$OUT" | grep 'possible orphans' | while read -r line; do
    pat=$(echo "$line" | sed -n "s/.*pkill -f '\([^']*\)'.*/\1/p")
    if [ -n "$pat" ]; then
        # keep the newest proc, kill older ones
        pgrep -f "$pat" | sort -n | sed '$d' | xargs -I{} kill {} 2>/dev/null
        echo "[$(ts)] killed orphan procs matching $pat (kept newest)" >> "$LOG"
    fi
done

# Trim log to last 2000 lines
tail -2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
exit 0

#!/usr/bin/env bash
#
# cline_window_watchdog.sh — Monitor VS Code window count and warn when too many are open
#
# Part of the Cline crash prevention system (companion to #15967 auto-checkpoint).
# The recovery side is the auto-checkpoint system; this is the prevention side.
#
# Runs every 5 minutes via launchd (com.emsu.cline-window-watchdog).
# When VS Code window count exceeds the threshold, posts an osascript notification
# and logs to /tmp/cline_window_watchdog.log.
#
# Threshold rationale: on a 128GB Mac, each VS Code window with Cline + MCP servers
# consumes 2-4GB RAM. 14 windows = ~42GB just for Cline. The 00:47 PT "crash" on
# 2026-07-01 was NOT memory pressure (it was a config-switch script), but 14 windows
# is still a risk factor for future incidents. Threshold = 8 (warn), 12 (critical).
#
# Created: 2026-07-01 per crash investigation (rule 92: work at the core)

WARN_THRESHOLD=8
CRITICAL_THRESHOLD=12
LOG="/tmp/cline_window_watchdog.log"
TS=$(date '+%Y-%m-%dT%H:%M:%S%z')

# Count unique VS Code windows (each window has a unique --vscode-window-config UUID)
WINDOW_COUNT=$(ps aux 2>/dev/null | grep "Code Helper (Renderer)" | grep -o "vscode-window-config=vscode:[a-f0-9-]*" | sort -u | wc -l | tr -d ' ')

# If VS Code isn't running at all, exit silently
if [ "$WINDOW_COUNT" -eq 0 ]; then
    exit 0
fi

# Log current state
echo "[$TS] windows=$WINDOW_COUNT (warn=$WARN_THRESHOLD, critical=$CRITICAL_THRESHOLD)" >> "$LOG"

# Critical threshold — post a prominent notification
if [ "$WINDOW_COUNT" -ge "$CRITICAL_THRESHOLD" ]; then
    echo "[$TS] CRITICAL: $WINDOW_COUNT VS Code windows open (>= $CRITICAL_THRESHOLD). Risk of memory pressure or instability. Consider closing some windows." >> "$LOG"
    osascript -e "display notification \"CRITICAL: $WINDOW_COUNT VS Code windows open. Close some to prevent instability.\" with title \"Cline Window Watchdog\" subtitle \"Window count: $WINDOW_COUNT\" sound name \"Basso\"" 2>/dev/null || true

# Warn threshold — post a gentler notification
elif [ "$WINDOW_COUNT" -ge "$WARN_THRESHOLD" ]; then
    echo "[$TS] WARN: $WINDOW_COUNT VS Code windows open (>= $WARN_THRESHOLD)." >> "$LOG"
    osascript -e "display notification \"$WINDOW_COUNT VS Code windows open. Consider closing inactive ones.\" with title \"Cline Window Watchdog\" subtitle \"Window count: $WINDOW_COUNT\" sound name \"Frog\"" 2>/dev/null || true
fi

# Prune log to last 1000 lines
if [ -f "$LOG" ]; then
    tail -1000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG" 2>/dev/null || true
fi

exit 0
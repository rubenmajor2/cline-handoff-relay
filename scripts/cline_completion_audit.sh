#!/usr/bin/env bash
#
# cline_completion_audit.sh -- Rule 91 + Rule 07 compliance auditor
#
# Scans recent Cline task dirs for:
# - Rule 91: attempt_completion without PICKUP PROMPT block
# - Rule 07: completed tasks without corresponding ledger row
#
# Runs alongside yolo_learner (every 30 min via cron).
# Posts violations to /tmp/cline_completion_audit.log.
#
# Usage: cline_completion_audit.sh [--quiet]

set -uo pipefail

TASKS_DIR="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
LEDGER="$HOME/Documents/Cline/cline_task_ledger.md"
LOG="/tmp/cline_completion_audit.log"
QUIET="${1:-}"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')

log() { echo "[${TIMESTAMP}] $*" >> "$LOG"; }
warn() { log "WARN: $*"; echo "WARN: $*" >&2; }

log "=== Rule 91 + Rule 07 audit ==="

MISSES=()
PASSES=0
TOTAL=0

if [ -d "$TASKS_DIR" ]; then
    for dir in $(ls -t "$TASKS_DIR" 2>/dev/null); do
        [ -d "$TASKS_DIR/$dir" ] || continue
        hist="$TASKS_DIR/$dir/api_conversation_history.json"
        [ -f "$hist" ] || continue
        if grep -q 'attempt_completion' "$hist" 2>/dev/null; then
            TOTAL=$((TOTAL + 1))
            if grep -q 'PICKUP PROMPT' "$hist" 2>/dev/null; then
                PASSES=$((PASSES + 1))
            else
                MISSES+=("$dir")
                warn "Rule 91 MISS: $dir = attempt_completion without PICKUP PROMPT"
            fi
        fi
        [ $TOTAL -ge 50 ] && break
    done
fi

COMPLIANCE=0
if [ $TOTAL -gt 0 ]; then
    COMPLIANCE=$(( PASSES * 100 / TOTAL ))
fi

log "Rule 91: ${PASSES}/${TOTAL} (${COMPLIANCE}%)"
[ ${#MISSES[@]} -gt 0 ] && log "MISSES: ${MISSES[*]}"

DONE_ROWS=$(grep -c '| done ' "$LEDGER" 2>/dev/null || echo 0)
log "Rule 07: ${DONE_ROWS} done rows in ledger (vs ${TOTAL} recent completions)"

SUMMARY="R91:${PASSES}/${TOTAL}=${COMPLIANCE}% | R07:${DONE_ROWS} rows"
echo "$SUMMARY"
log "$SUMMARY"
exit 0
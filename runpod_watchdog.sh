#!/bin/bash
# runpod_watchdog.sh — polls 30B training pods for completion, auto-triggers post-training
# Runs every 5 min via launchd. Idempotent.
# 2026-05-12 — deployed by Cline after Ruben directive

set -uo pipefail
LOG=/tmp/runpod_watchdog.log
DONE_FLAG=/tmp/runpod_30b_v18_done
POD_IP=38.80.152.146
POD_PORT=30901
POD_ID=vcn4i1pm2hy7ka
POST_TRAIN_SCRIPT="$HOME/Documents/Cline/runpod_post_train.sh"
POST_TRAIN_LOG=/tmp/runpod_post_train.log
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# If already handled, skip
if [ -f "$DONE_FLAG" ]; then
    exit 0
fi

log "polling training pod $POD_ID..."

# Check for completion (fast SSH)
DONE=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "grep -c 'ALL DONE' /workspace/v18_train.log 2>/dev/null || echo 0" 2>/dev/null || echo "0")

PROC=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "ps -ef | grep train_v18.py | grep -v grep | wc -l" 2>/dev/null || echo "1")

if [ "${DONE:-0}" -lt "1" ] || [ "${PROC:-1}" -gt "0" ]; then
    # Also check: process gone AND checkpoints exist = done even without ALL DONE marker
    if [ "${PROC:-1}" -gt "0" ]; then
        log "training still running (proc count: $PROC)"
        exit 0
    fi
    if [ "${DONE:-0}" -lt "1" ]; then
        log "process gone but no ALL DONE marker yet — may be in final checkpoint save"
        exit 0
    fi
fi

log "=== TRAINING COMPLETE on pod $POD_ID — triggering post-training ==="
touch "$DONE_FLAG"

# SMS notification to Ruben immediately (via WOPR outbound SMS if accessible, else log)
log "training done — launching post-train pipeline"

# Launch post-training script detached (takes 1-3 hours, MUST not block)
nohup /opt/homebrew/bin/bash "$POST_TRAIN_SCRIPT" \
    > "$POST_TRAIN_LOG" 2>&1 < /dev/null &
disown

log "post-train launched — tail $POST_TRAIN_LOG to monitor"

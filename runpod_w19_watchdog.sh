#!/bin/bash
# runpod_w19_watchdog.sh — monitors w19 eval harness, restarts if dead
# The w19 eval is a LONG-RUNNING loop (polls every 2h for 30B checkpoints).
# This watchdog ensures the loop stays alive. When the 30B training finishes
# and the final eval runs, it watches for a FINAL_EVAL_DONE marker.
# Runs every 5 min via launchd. Idempotent.
set -uo pipefail
LOG=/tmp/runpod_w19_watchdog.log
DONE_FLAG=/tmp/runpod_w19_final_done
POD_IP=213.173.111.133
POD_PORT=24572
POD_ID=gk6xz7q5uv4zcn
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

[ -f "$DONE_FLAG" ] && exit 0

log "polling w19-eval pod $POD_ID..."

PROC=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "ps -ef | grep -E 'work.sh|eval_harness|eval' | grep -v grep | wc -l" 2>/dev/null || echo "0")

LAST_EVAL=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "tail -2 /workspace/eval.log 2>/dev/null" || echo "no log")

# Check if final eval completed (30B training done + perplexity logged)
if echo "$LAST_EVAL" | grep -q "perplexity="; then
    log "=== W19 FINAL EVAL COMPLETE: $LAST_EVAL ==="
    touch "$DONE_FLAG"
    log "w19 done. Pod can be terminated: DELETE https://rest.runpod.io/v1/pods/$POD_ID"
    exit 0
fi

log "w19 eval status: proc=$PROC last_eval=$LAST_EVAL"

# If the work.sh process died but we haven't completed, restart it
if [ "${PROC:-0}" -eq "0" ]; then
    log "w19 work.sh process died — restarting eval harness..."
    ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
        "nohup bash /workspace/work.sh < /dev/null > /workspace/work_outer_restart.log 2>&1 & disown; echo RESTARTED" >> "$LOG" 2>&1
    log "w19 eval harness restarted"
fi

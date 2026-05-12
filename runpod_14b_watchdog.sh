#!/bin/bash
# runpod_14b_watchdog.sh — polls 14B training pod for completion, auto-triggers post-training
# Post-training: merge LoRA -> Q4 GGUF -> push to WOPR -> ollama create on WOPR -> terminate pod
# Runs every 5 min via launchd. Idempotent.
set -uo pipefail
LOG=/tmp/runpod_14b_watchdog.log
DONE_FLAG=/tmp/runpod_14b_v1_done
POD_IP=38.80.152.146
POD_PORT=30141
POD_ID=ftc337x9zb5img
WOPR_IP=76.167.100.188
WOPR_PORT=2222
MODEL_NAME=emsu-qwen-coder-14b-lora-v1
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

[ -f "$DONE_FLAG" ] && exit 0

log "polling 14B pod $POD_ID..."

DONE=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "grep -c 'ALL DONE 14B LORA' /workspace/v1_14b_train.log 2>/dev/null || echo 0" 2>/dev/null || echo "0")
PROC=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "ps -ef | grep train_14b | grep -v grep | wc -l" 2>/dev/null || echo "1")

if [ "${PROC:-1}" -gt "0" ] || [ "${DONE:-0}" -lt "1" ]; then
    [ "${PROC:-1}" -gt "0" ] && log "14B still running" && exit 0
    [ "${DONE:-0}" -lt "1" ] && log "14B process gone, no ALL DONE yet" && exit 0
fi

log "=== 14B TRAINING COMPLETE — starting post-training ==="
touch "$DONE_FLAG"

# Launch post-training detached (merge -> Q4 GGUF -> WOPR -> ollama create -> terminate)
nohup /opt/homebrew/bin/bash "$HOME/Documents/Cline/runpod_14b_post_train.sh" \
    > /tmp/runpod_14b_post_train.log 2>&1 < /dev/null &
disown
log "14B post-train launched — tail /tmp/runpod_14b_post_train.log"

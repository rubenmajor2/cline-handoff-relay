#!/bin/bash
# runpod_14b_watchdog.sh — polls 14B training pod, detects SUCCESS vs CRASH
# Fix from v1: checked for "ALL DONE" which fires even on crash.
# v2: checks for adapter_config.json in checkpoint dir = real success.
# Runs every 5 min via launchd. Idempotent.
set -uo pipefail
LOG=/tmp/runpod_14b_watchdog.log
DONE_FLAG=/tmp/runpod_14b_v3_done
POD_IP=38.80.152.146
POD_PORT=30141
POD_ID=ftc337x9zb5img
CHECKPOINT_DIR=/workspace/checkpoints/emsu-qwen-coder-14b-lora-v1
WOPR_IP=76.167.100.188
WOPR_PORT=2222
MODEL_NAME=emsu-qwen-coder-14b-lora-v1
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

[ -f "$DONE_FLAG" ] && exit 0

log "polling 14B pod $POD_ID (v3)..."

# SUCCESS = adapter_config.json exists in checkpoint dir (real LoRA was saved)
# This only exists if trainer.save_model() completed successfully
ADAPTER=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "[ -f ${CHECKPOINT_DIR}/adapter_config.json ] && echo 'FOUND' || echo 'NOT_FOUND'" 2>/dev/null || echo "SSH_ERR")

PROC=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "ps -ef | grep -E 'launch_14b|train_14b_v3' | grep -v grep | wc -l" 2>/dev/null || echo "1")

if [ "$ADAPTER" != "FOUND" ]; then
    if [ "${PROC:-1}" -gt "0" ]; then
        log "14B training still running (proc=$PROC)"
    elif [ "$ADAPTER" = "SSH_ERR" ]; then
        log "14B pod SSH unreachable — will retry"
    else
        log "14B training process gone, no adapter saved yet (may be crashed) — watching"
    fi
    exit 0
fi

log "=== 14B TRAINING SUCCESS — adapter_config.json found ==="
touch "$DONE_FLAG"

log "launching 14B post-training pipeline (merge -> GGUF -> WOPR -> ollama create)"
nohup /opt/homebrew/bin/bash "$HOME/Documents/Cline/runpod_14b_post_train.sh" \
    > /tmp/runpod_14b_post_train_v3.log 2>&1 < /dev/null &
disown
log "post-train launched — tail /tmp/runpod_14b_post_train_v3.log"

#!/bin/bash
# runpod_w11_watchdog.sh — polls w11 reward model pod for completion + deploys to WOPR
# Success signal: /workspace/STATUS.txt exists with accuracy line + model files present
# Runs every 5 min via launchd. Idempotent.
set -uo pipefail
LOG=/tmp/runpod_w11_watchdog.log
DONE_FLAG=/tmp/runpod_w11_v2_done
POD_IP=38.80.152.76
POD_PORT=30143
POD_ID=q9bgxdf2do53zq
WOPR_IP=76.167.100.188
WOPR_PORT=2222
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

[ -f "$DONE_FLAG" ] && exit 0

log "polling w11-reward pod $POD_ID..."

# SUCCESS = STATUS.txt has accuracy line AND model files exist
STATUS=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "cat /workspace/STATUS.txt 2>/dev/null" || echo "")

PROC=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
    "ps -ef | grep -E 'reward|work.sh|train' | grep -v grep | wc -l" 2>/dev/null || echo "1")

if echo "$STATUS" | grep -q "accuracy="; then
    log "=== W11 SUCCESS — reward model trained: $STATUS ==="
    touch "$DONE_FLAG"

    # Pull model files to Mac, then push to WOPR
    log "pulling reward model from pod to Mac..."
    mkdir -p /tmp/reward_model_v2
    scp $SSH_OPTS -r -P "$POD_PORT" \
        "root@$POD_IP:/workspace/reward_model/" \
        /tmp/reward_model_v2/ >> "$LOG" 2>&1

    log "pushing reward model to WOPR..."
    ssh $SSH_OPTS -p "$WOPR_PORT" emsuserver@$WOPR_IP \
        "mkdir -p /var/www/emtskills/models/reward_model_v2" >> "$LOG" 2>&1
    scp $SSH_OPTS -r -P "$WOPR_PORT" \
        /tmp/reward_model_v2/ \
        "emsuserver@$WOPR_IP:/var/www/emtskills/models/reward_model_v2/" >> "$LOG" 2>&1

    log "reward model deployed to WOPR — $STATUS"

    # SMS notification via WOPR
    ssh $SSH_OPTS -p "$WOPR_PORT" emsuserver@$WOPR_IP \
        "php -r \"
require_once '/var/www/emtskills/config/config.local.php';
\\\$sms = new SMS();
\\\$sms->send('+17605250530', 'W11 reward model done: $STATUS — deployed to WOPR');
\"" >> "$LOG" 2>&1 || log "SMS notification failed (non-fatal)"

    log "W11 done. Pod can be terminated: DELETE https://rest.runpod.io/v1/pods/$POD_ID"
else
    if [ "${PROC:-1}" -gt "0" ]; then
        log "w11 training still running (proc=$PROC)"
    else
        log "w11 process gone, no STATUS.txt yet — may have crashed. Checking log..."
        TAIL=$(ssh $SSH_OPTS -p "$POD_PORT" "root@$POD_IP" \
            "tail -3 /workspace/reward_v2.log 2>/dev/null || tail -3 /workspace/reward.log 2>/dev/null" || echo "no log")
        log "last log lines: $TAIL"
    fi
fi

#!/opt/homebrew/bin/bash
# runpod_hourly_report.sh — sends Ruben an hourly email with training progress for all pods
# Runs every hour via launchd. Sends to rmajor@emsuniversity.com via WOPR PHP mailer.
set -uo pipefail
LOG=/tmp/runpod_hourly_report.log
WOPR_IP=76.167.100.188
WOPR_PORT=2222
TO_EMAIL=rmajor@emsuniversity.com
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
log "=== HOURLY REPORT RUN ==="

NOW=$(date '+%Y-%m-%d %H:%M PT')

# Helper: get last N lines of a log from a pod
pod_tail() {
    local IP="$1" PORT="$2" LOGFILE="$3" LINES="${4:-5}"
    ssh $SSH_OPTS -p "$PORT" "root@$IP" "tail -${LINES} ${LOGFILE} 2>/dev/null || echo '(no log yet)'" 2>/dev/null || echo "(SSH failed)"
}

# Helper: get training step from a progress bar line
extract_step() {
    echo "$1" | grep -oE '[0-9]+/[0-9]+' | tail -1 || echo "?"
}

# ---- 30B pod (cline-lora-v18-b200) ----
POD_30B_IP=38.80.152.146
POD_30B_PORT=30901
LOG_30B=$(pod_tail "$POD_30B_IP" "$POD_30B_PORT" "/workspace/v18_train.log" 6)
PROC_30B=$(ssh $SSH_OPTS -p "$POD_30B_PORT" "root@$POD_30B_IP" "ps -ef | grep train_v18 | grep -v grep | wc -l" 2>/dev/null || echo "0")
STEP_30B=$(extract_step "$LOG_30B")
STATUS_30B="Running ($STEP_30B steps)"
[ "${PROC_30B:-0}" -eq "0" ] && STATUS_30B="Process gone — checking for completion"
[ -f /tmp/runpod_30b_v18_done ] && STATUS_30B="COMPLETE — post-train running"

# ---- 14B pod (cline-lora-14b-v1) ----
POD_14B_IP=38.80.152.146
POD_14B_PORT=30141
# Check newest log
LOG_14B=""
for LFILE in /workspace/v7_14b_train.log /workspace/v6_14b_train.log /workspace/v5_14b_train.log; do
    TMP=$(ssh $SSH_OPTS -p "$POD_14B_PORT" "root@$POD_14B_IP" "tail -6 $LFILE 2>/dev/null" 2>/dev/null)
    if [ -n "$TMP" ]; then LOG_14B="$TMP"; break; fi
done
[ -z "$LOG_14B" ] && LOG_14B="(no log yet)"
PROC_14B=$(ssh $SSH_OPTS -p "$POD_14B_PORT" "root@$POD_14B_IP" "ps -ef | grep train_14b | grep -v grep | wc -l" 2>/dev/null || echo "0")
STEP_14B=$(extract_step "$LOG_14B")
STATUS_14B="Running ($STEP_14B steps)"
[ "${PROC_14B:-0}" -eq "0" ] && STATUS_14B="Process gone — check v7 log"
[ -f /tmp/runpod_14b_v3_done ] && STATUS_14B="COMPLETE — post-train running"
ADAPTER_14B=$(ssh $SSH_OPTS -p "$POD_14B_PORT" "root@$POD_14B_IP" \
    "[ -f /workspace/checkpoints/emsu-qwen-coder-14b-lora-v1/adapter_config.json ] && echo DONE || echo PENDING" 2>/dev/null || echo "UNKNOWN")
[ "$ADAPTER_14B" = "DONE" ] && STATUS_14B="TRAINING COMPLETE — adapter saved"

# ---- w11 reward pod ----
POD_W11_IP=38.80.152.76
POD_W11_PORT=30143
W11_STATUS=$(ssh $SSH_OPTS -p "$POD_W11_PORT" "root@$POD_W11_IP" "cat /workspace/STATUS.txt 2>/dev/null" 2>/dev/null || echo "")
LOG_W11=$(pod_tail "$POD_W11_IP" "$POD_W11_PORT" "/workspace/reward_v3.log" 4)
if echo "$W11_STATUS" | grep -q "accuracy="; then
    STATUS_W11="DONE — $W11_STATUS"
else
    STATUS_W11="Training in progress"
fi

# ---- w19 eval pod ----
POD_W19_IP=213.173.111.133
POD_W19_PORT=24572
LOG_W19=$(pod_tail "$POD_W19_IP" "$POD_W19_PORT" "/workspace/eval.log" 4)
PROC_W19=$(ssh $SSH_OPTS -p "$POD_W19_PORT" "root@$POD_W19_IP" "ps -ef | grep work.sh | grep -v grep | wc -l" 2>/dev/null || echo "0")
STATUS_W19="Polling for checkpoints (proc=${PROC_W19})"
echo "$LOG_W19" | grep -q "perplexity=" && STATUS_W19="EVAL DONE"
echo "$LOG_W19" | grep -q "checkpoint" && STATUS_W19="Evaluating checkpoint"

# ---- Compose email body ----
SUBJECT="Runpod fleet hourly update — $NOW"
BODY=$(cat << EMAILBODY
Fleet status as of $NOW.

--- 30B (cline-lora-v18-b200) ---
Status: $STATUS_30B
Recent log:
$LOG_30B

--- 14B (cline-lora-14b-v1) ---
Status: $STATUS_14B  |  adapter: $ADAPTER_14B
Recent log:
$LOG_14B

--- W11 reward model (cline-w11-reward) ---
Status: $STATUS_W11
Recent log:
$LOG_W11

--- W19 eval harness (cline-w19-eval) ---
Status: $STATUS_W19
Recent log:
$LOG_W19

---
Watchdog logs:
  30B:  tail /tmp/runpod_watchdog.log
  14B:  tail /tmp/runpod_14b_watchdog.log
  W11:  tail /tmp/runpod_w11_watchdog.log
  W19:  tail /tmp/runpod_w19_watchdog.log
EMAILBODY
)

log "sending email to $TO_EMAIL..."

# Strip ANSI escape codes + control chars so PHP doesn't choke on them
CLEAN_BODY=$(echo "$BODY" | python3 -c "
import sys, re
txt = sys.stdin.read()
# strip ANSI escape sequences
txt = re.sub(r'\x1b\[[0-9;]*[mGKHF]', '', txt)
# strip carriage returns and other control chars except newline/tab
txt = re.sub(r'[\x00-\x08\x0b-\x0c\x0e-\x1f\x7f]', '', txt)
# collapse long runs of spaces (progress bar residue)
txt = re.sub(r'  +', ' ', txt)
print(txt, end='')
")
CLEAN_SUBJECT="$SUBJECT"

# Write body to temp file on WOPR, then PHP reads it (avoids all quoting nightmares)
echo "$CLEAN_BODY" | ssh $SSH_OPTS -p "$WOPR_PORT" "emsuserver@$WOPR_IP" \
    "cat > /tmp/runpod_email_body.txt" 2>/dev/null

ssh $SSH_OPTS -p "$WOPR_PORT" "emsuserver@$WOPR_IP" "php << 'PHPEOF'
<?php
require_once '/var/www/emtskills/config/config.local.php';
require_once '/var/www/emtskills/lib/mailer.php';
\$body = htmlspecialchars(file_get_contents('/tmp/runpod_email_body.txt'));
sendEmail(
    '$TO_EMAIL',
    '$CLEAN_SUBJECT',
    '<pre style=\"font-family:monospace;font-size:13px\">' . \$body . '</pre>',
    'rmajor@emsuniversity.com', 'Ruben Major',
    'rmajor@emsuniversity.com', 'Ruben Major',
    'rmajor@emsuniversity.com',
    null, null, 'none'
);
echo 'sent' . PHP_EOL;
PHPEOF
" >> "$LOG" 2>&1 && log "email sent" || log "email send failed"

log "=== REPORT DONE ==="

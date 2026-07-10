#!/opt/homebrew/bin/bash
# fleet_phase2.sh — push data + retry W4 + trigger W6/W7/W11 training.
set -uo pipefail
source /tmp/fleet_ssh.env 2>/dev/null || true  # harmless if names have dashes
LOG=/tmp/fleet_phase2.log
: > "$LOG"
ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# Helpers to read IP/PORT for a workstream
get_ip()   { grep "^IP_${1}=" /tmp/fleet_ssh.env | tail -1 | cut -d= -f2; }
get_port() { grep "^PORT_${1}=" /tmp/fleet_ssh.env | tail -1 | cut -d= -f2; }

# === W4 RETRY ===
push_w4() {
    local NAME=cline-w4-rag
    local IP=$(get_ip $NAME) PORT=$(get_port $NAME)
    log "W4: pushing retry2 to $IP:$PORT"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$PORT" \
        /tmp/pod_w4_retry2.sh "root@$IP:/workspace/work.sh" >> "$LOG" 2>&1 || {
        log "W4: scp FAILED"; return 1; }
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" \
        "chmod +x /workspace/work.sh; rm -f /workspace/work.log; nohup bash /workspace/work.sh < /dev/null > /workspace/work_outer.log 2>&1 & disown; sleep 1; ps -ef | grep work.sh | grep -v grep | head -2" >> "$LOG" 2>&1
    log "W4: launched"
}

# === W6 VOICE training ===
push_w6() {
    local NAME=cline-w6-voice
    local IP=$(get_ip $NAME) PORT=$(get_port $NAME)
    log "W6: pushing voice_train.jsonl (3349 rows) -> $IP:$PORT"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$PORT" \
        /tmp/voice_train.jsonl "root@$IP:/workspace/data/voice_train.jsonl" >> "$LOG" 2>&1 || {
        log "W6: scp FAILED"; return 1; }
    log "W6: launching launch_voice_train.sh"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" \
        "nohup bash /workspace/launch_voice_train.sh < /dev/null > /workspace/voice_outer.log 2>&1 & disown; sleep 1; ps -ef | grep -E 'launch_voice|train_voice' | grep -v grep | head" >> "$LOG" 2>&1
    log "W6: launched"
}

# === W7 EMAIL training ===
push_w7() {
    local NAME=cline-w7-email
    local IP=$(get_ip $NAME) PORT=$(get_port $NAME)
    log "W7: pushing email_train.jsonl (1179 rows) -> $IP:$PORT"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$PORT" \
        /tmp/email_train.jsonl "root@$IP:/workspace/data/email_train.jsonl" >> "$LOG" 2>&1 || {
        log "W7: scp FAILED"; return 1; }
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" \
        "nohup bash /workspace/launch_email_train.sh < /dev/null > /workspace/email_outer.log 2>&1 & disown; sleep 1" >> "$LOG" 2>&1
    log "W7: launched"
}

# === W11 reward bootstrap ===
push_w11() {
    local NAME=cline-w11-rwm
    local IP=$(get_ip $NAME) PORT=$(get_port $NAME)
    log "W11: pushing reward_bootstrap.jsonl (9431 rows, label=tie placeholder)"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$PORT" \
        /tmp/reward_bootstrap.jsonl "root@$IP:/workspace/data/reward_train.jsonl" >> "$LOG" 2>&1 || {
        log "W11: scp FAILED"; return 1; }
    # NOTE: all-tie labels won't train a useful classifier. Add synthetic win/loss
    # by perturbing responses — half the rows get response trimmed to first 5%
    # (degraded -> loss), half get full response (canonical -> win). Real
    # labels come later via W3 grading.
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" \
        "python3 -c \"
import json, random
random.seed(42)
rows = []
with open('/workspace/data/reward_train.jsonl') as f:
    for line in f:
        rows.append(json.loads(line))
# Bootstrap labels: full response = win, trimmed = loss, mid-trimmed = tie
import copy
out = []
for r in rows:
    out.append({**r, 'label':'win'})
    # 'loss' variant: response trimmed to 10%
    r2 = copy.deepcopy(r); r2['response'] = r['response'][:max(50,len(r['response'])//10)]; r2['label']='loss'
    out.append(r2)
    # 'tie' variant: response trimmed to 50%
    r3 = copy.deepcopy(r); r3['response'] = r['response'][:max(100,len(r['response'])//2)]; r3['label']='tie'
    out.append(r3)
random.shuffle(out)
with open('/workspace/data/reward_train.jsonl','w') as f:
    for r in out:
        f.write(json.dumps(r)+'\\n')
print('reward_train.jsonl now has', len(out), 'rows (win/loss/tie bootstrap)')
\"
nohup bash /workspace/launch_reward_train.sh < /dev/null > /workspace/reward_outer.log 2>&1 & disown
sleep 1
ps -ef | grep -E 'launch_reward|train_reward' | grep -v grep | head" >> "$LOG" 2>&1
    log "W11: launched"
}

log "=== PHASE 2 START $(ts) ==="
push_w4   &
push_w6   &
push_w7   &
push_w11  &
wait
log "=== PHASE 2 DONE $(ts) ==="

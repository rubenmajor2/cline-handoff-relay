#!/opt/homebrew/bin/bash
# fleet_orchestrate.sh — wait SSH ready, then scp + nohup-launch per pod.
# Uses bash 5 (homebrew) for associative arrays.
set -uo pipefail
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w)
LOG=/tmp/fleet_orchestrate.log
SSH_STATE=/tmp/fleet_ssh.env
: > "$LOG"
: > "$SSH_STATE"

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# Parse pod ids from fleet_pods.env. Names use dashes which aren't valid var
# names, so we use a parallel-arrays approach.
NAMES=()
POD_IDS=()
while IFS='=' read -r key val; do
    if [[ "$key" == POD_* ]]; then
        nm="${key#POD_}"
        NAMES+=("$nm")
        POD_IDS+=("$val")
    fi
done < /tmp/fleet_pods.env

log "=== ORCHESTRATE START $(ts) ==="
log "Pods to orchestrate (count=${#NAMES[@]}): ${NAMES[*]}"

wait_ssh() {
    local NAME="$1" PID="$2"
    local TRIES=0
    while [[ $TRIES -lt 80 ]]; do
        RESP=$(curl -sS -H "Authorization: Bearer $KEY" "https://rest.runpod.io/v1/pods/$PID")
        INFO=$(echo "$RESP" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    ip = d.get('publicIp') or ''
    pm = d.get('portMappings') or {}
    port = pm.get('22','')
    if ip and port:
        print(f'{ip} {port}')
except Exception:
    pass
" 2>/dev/null)
        if [[ -n "$INFO" ]]; then
            IP=$(echo "$INFO" | awk '{print $1}')
            PORT=$(echo "$INFO" | awk '{print $2}')
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" 'echo SSH_OK' 2>/dev/null | grep -q SSH_OK; then
                log "$NAME ($PID): SSH ready at $IP:$PORT (tries=$TRIES)"
                echo "IP_${NAME}=$IP"   >> "$SSH_STATE"
                echo "PORT_${NAME}=$PORT" >> "$SSH_STATE"
                return 0
            fi
        fi
        TRIES=$((TRIES+1))
        sleep 5
    done
    log "$NAME ($PID): TIMEOUT waiting for SSH"
    return 1
}

orchestrate_pod() {
    local NAME="$1" PID="$2"
    log "$NAME: starting orchestration (pod=$PID)"
    if ! wait_ssh "$NAME" "$PID"; then
        return 1
    fi
    IP=$(grep "^IP_${NAME}=" "$SSH_STATE" | tail -1 | cut -d= -f2)
    PORT=$(grep "^PORT_${NAME}=" "$SSH_STATE" | tail -1 | cut -d= -f2)
    SCRIPT="/tmp/pod_${NAME}.sh"

    if [[ ! -f "$SCRIPT" ]]; then
        log "$NAME: ERROR script $SCRIPT not found"
        return 1
    fi

    log "$NAME: scp $SCRIPT -> root@$IP:$PORT:/workspace/work.sh"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -P "$PORT" "$SCRIPT" "root@$IP:/workspace/work.sh" >> "$LOG" 2>&1 || {
        log "$NAME: SCP FAILED"
        return 1
    }
    log "$NAME: launching detached on pod"
    ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" "rm -f /workspace/work.log; chmod +x /workspace/work.sh; nohup bash /workspace/work.sh < /dev/null > /workspace/work_outer.log 2>&1 & disown; sleep 1; ps -ef | grep work.sh | grep -v grep | head -3" >> "$LOG" 2>&1
    log "$NAME: launched. Poll via ssh root@$IP -p $PORT 'tail -50 /workspace/work.log'"
}

# Parallel fan-out
for I in "${!NAMES[@]}"; do
    orchestrate_pod "${NAMES[$I]}" "${POD_IDS[$I]}" &
done
wait
log "=== ORCHESTRATE DONE $(ts) ==="
echo "--- SSH state ---" >> "$LOG"
cat "$SSH_STATE" >> "$LOG"

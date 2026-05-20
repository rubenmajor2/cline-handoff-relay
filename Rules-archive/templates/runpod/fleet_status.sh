#!/opt/homebrew/bin/bash
# fleet_status.sh — one-shot status of every pod in the fleet.
# Reports: pod_id, name, gpu, status, work.log tail (last 5 lines), STATUS file
set -uo pipefail
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w)

echo "=== FLEET STATUS $(date -Iseconds) ==="
echo
echo "--- ALL POD INVENTORY (Runpod API) ---"
curl -sS -H "Authorization: Bearer $KEY" https://rest.runpod.io/v1/pods 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
rows = d if isinstance(d,list) else d.get('pods',[])
for p in rows:
    print(f\"  {p.get('id','?'):<18} {p.get('name','?'):<24} status={p.get('desiredStatus','?')}  cost=\${p.get('costPerHr','?')}/hr\")
print(f'TOTAL = \${sum(float(p.get(\"costPerHr\",0)) for p in rows):.2f}/hr')
"
echo
echo "--- WORKSTREAM POD WORK.LOG TAILS ---"
# Read SSH state. Names like cline-w4-rag.
NAMES=()
IPS=()
PORTS=()
while IFS='=' read -r key val; do
    if [[ "$key" == IP_* ]]; then NAMES+=("${key#IP_}"); IPS+=("$val"); fi
done < /tmp/fleet_ssh.env

PORTS=()
for N in "${NAMES[@]}"; do
    P=$(grep "^PORT_${N}=" /tmp/fleet_ssh.env | tail -1 | cut -d= -f2)
    PORTS+=("$P")
done

for I in "${!NAMES[@]}"; do
    NAME="${NAMES[$I]}"
    IP="${IPS[$I]}"
    PORT="${PORTS[$I]}"
    echo
    echo "=== $NAME @ $IP:$PORT ==="
    ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" "root@$IP" "echo '[STATUS file]'; cat /workspace/STATUS.txt 2>/dev/null || cat /workspace/checkpoints/STATUS.txt 2>/dev/null || echo 'no STATUS yet'; echo; echo '[work.log tail]'; tail -8 /workspace/work.log 2>/dev/null || echo 'no work.log yet'; echo; echo '[ps]'; ps -ef | grep -E 'python|train' | grep -v grep | head -3" 2>/dev/null || echo "SSH FAILED"
done

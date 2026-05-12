#!/usr/bin/env bash
# fleet_mint.sh — mint the no-lock-in workstream fleet
#
# Workstreams (independent, parallel):
#   W4  RAG corpus + embeddings    -> 1x B200, no train, $5/hr * 2h ~$10
#   W6  Voice AI specialist        -> 1x B200, train 7B specialist ~$50
#   W7  Email AI specialist        -> 1x B200, train 7B specialist ~$50
#   W10 Spec decoding 0.5B draft   -> 1x B200, train tiny ~$15
#   W11 Reward model (small)       -> 1x B200, train classifier ~$15
#   W19 EMSU eval harness          -> 1x B200, no train, ~$15
#
# Strategy: mint each pod individually so a failure on one doesn't kill the
# whole fleet. Per rule 95, this script runs detached via nohup and writes to
# /tmp/fleet_mint.log so the Mac side can poll.
#
# B200 gpuTypeId proven: "NVIDIA B200" from prior 30B mint pattern. Falls back
# to H100 SXM5 if no B200 stock.

set -uo pipefail
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w)
LOG=/tmp/fleet_mint.log
STATE=/tmp/fleet_pods.env
PUB="$(cat ~/.ssh/id_ed25519.pub)"
: > "$LOG"
: > "$STATE"

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# Candidates from cheapest first (per Ruben "max parallel"). B200 first because
# it's biggest, then H100, then anything else with >=40 GB VRAM.
GPU_CANDIDATES=("NVIDIA B200" "NVIDIA H100 80GB HBM3" "NVIDIA H100 SXM 80GB" "NVIDIA H100 NVL" "NVIDIA H200" "NVIDIA A100 80GB PCIe")

mint_one() {
    local NAME="$1" DISK="$2"
    for GID in "${GPU_CANDIDATES[@]}"; do
        log "$NAME: trying gpu=\"$GID\""
        cat > /tmp/rp_body_${NAME}.json <<JSON
{
  "name": "$NAME",
  "imageName": "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04",
  "gpuTypeIds": ["$GID"],
  "gpuCount": 1,
  "cloudType": "SECURE",
  "volumeInGb": $DISK,
  "containerDiskInGb": $DISK,
  "volumeMountPath": "/workspace",
  "ports": ["22/tcp", "8888/http"],
  "env": {"PUBLIC_KEY": "$PUB"}
}
JSON
        HTTP=$(curl -sS -X POST \
            -H "Authorization: Bearer $KEY" \
            -H "Content-Type: application/json" \
            -d @/tmp/rp_body_${NAME}.json \
            "https://rest.runpod.io/v1/pods" \
            -o /tmp/rp_resp_${NAME}.json -w "%{http_code}")
        log "$NAME: http=$HTTP"
        if [[ "$HTTP" == "200" || "$HTTP" == "201" ]]; then
            POD_ID=$(python3 -c "import json; d=json.load(open('/tmp/rp_resp_${NAME}.json')); print(d.get('id',''))")
            log "$NAME: SUCCESS pod=$POD_ID gpu=$GID"
            echo "POD_${NAME}=${POD_ID}" >> "$STATE"
            echo "GPU_${NAME}=${GID}" >> "$STATE"
            return 0
        else
            REASON=$(head -c 300 /tmp/rp_resp_${NAME}.json 2>/dev/null)
            log "$NAME: failed http=$HTTP reason=$REASON"
        fi
    done
    log "$NAME: ALL GPU candidates failed"
    return 1
}

log "=== FLEET MINT START $(ts) ==="
log "Existing pods (NOT touched): 30B v17, 7B-B200 training, 14B-B200 training, W3 H100 replay"
log "Minting: W4, W6, W7, W10, W11, W19"

# Disk sizes per workstream needs:
# - W4 RAG: 50 GB (base model + corpus parquet)
# - W6/W7 specialists: 100 GB (base model + training data + checkpoints)
# - W10 spec-decoding: 100 GB (7B target + 0.5B draft + training)
# - W11 reward model: 50 GB (classifier base + features)
# - W19 eval: 50 GB (eval set + base model for self-eval)

mint_one "cline-w4-rag"   50 &
mint_one "cline-w19-eval" 50 &
mint_one "cline-w6-voice" 100 &
mint_one "cline-w7-email" 100 &
mint_one "cline-w10-spec" 100 &
mint_one "cline-w11-rwm"  50 &

wait
log "=== FLEET MINT DONE $(ts) ==="
log "State file:"
cat "$STATE" >> "$LOG"

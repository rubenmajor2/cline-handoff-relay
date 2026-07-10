#!/opt/homebrew/bin/bash
# runpod_post_train.sh — runs after 30B LoRA training completes
# Steps: merge LoRA on pod -> GGUF convert -> Q4 quantize -> rsync to Artemis -> ollama create -> terminate pod -> notify
# Triggered by runpod_watchdog.sh. Takes 1-3 hours. Run detached.

set -uo pipefail
LOG=/tmp/runpod_post_train.log
POD_IP=38.80.152.146
POD_PORT=30901
POD_ID=vcn4i1pm2hy7ka
ARTEMIS_HOST=10.100.0.5
MODEL_NAME=emsu-qwen3-coder-30b-lora-v18
GGUF_FILE=emsu-qwen3-30b-v18-Q4_K_M.gguf
LOCAL_TMP=/tmp/runpod_gguf
SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_POD="ssh $SSH_OPTS -p $POD_PORT root@$POD_IP"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "=== POST-TRAIN PIPELINE START ==="
mkdir -p "$LOCAL_TMP"

# ---------------------------------------------------------------------------
# STEP 1: Run merge+convert+quantize on the training pod (has the model + GPU)
# ---------------------------------------------------------------------------
log "STEP 1: deploying merge+quantize script to training pod..."

cat > /tmp/pod_merge_quantize.sh << 'MERGE_EOF'
#!/bin/bash
set -e
exec >> /workspace/merge_quantize.log 2>&1
echo "=== MERGE START $(date -Iseconds) ==="

# Merge LoRA adapter into base model (CPU merge, ~30 min for 30B)
echo "merging LoRA adapter..."
python3 - << 'PYEOF'
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

base = "/workspace/base/qwen3-coder-30b"
adapter = "/workspace/checkpoints/emsu-qwen3-coder-30b-lora-v18"
merged = "/workspace/merged"

import os; os.makedirs(merged, exist_ok=True)
tok = AutoTokenizer.from_pretrained(base)
tok.save_pretrained(merged)
print("loading base...")
m = AutoModelForCausalLM.from_pretrained(base, torch_dtype=torch.bfloat16, device_map="cpu", low_cpu_mem_usage=True)
print("applying adapter...")
m = PeftModel.from_pretrained(m, adapter)
print("merging...")
m = m.merge_and_unload()
print("saving...")
m.save_pretrained(merged, safe_serialization=True)
print("merge done")
PYEOF

# Install llama.cpp python bindings for GGUF convert
echo "installing llama-cpp for GGUF conversion..."
pip install -q --upgrade gguf

# Clone llama.cpp for convert script (lightweight, just the python script)
if [ ! -d /workspace/llama.cpp ]; then
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /workspace/llama.cpp
fi

echo "converting to GGUF f16..."
python3 /workspace/llama.cpp/convert_hf_to_gguf.py /workspace/merged \
    --outtype f16 \
    --outfile /workspace/emsu-qwen3-30b-v18-f16.gguf

echo "building llama.cpp quantize tool..."
cd /workspace/llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release 2>/dev/null | tail -3
cmake --build build --config Release -j8 --target llama-quantize 2>&1 | tail -5

echo "quantizing to Q4_K_M..."
./build/bin/llama-quantize \
    /workspace/emsu-qwen3-30b-v18-f16.gguf \
    /workspace/emsu-qwen3-30b-v18-Q4_K_M.gguf \
    Q4_K_M

ls -lh /workspace/emsu-qwen3-30b-v18-Q4_K_M.gguf
echo "=== ALL DONE MERGE QUANTIZE $(date -Iseconds) ==="
MERGE_EOF

scp $SSH_OPTS -P "$POD_PORT" /tmp/pod_merge_quantize.sh "root@$POD_IP:/workspace/merge_quantize.sh"
$SSH_POD "nohup bash /workspace/merge_quantize.sh < /dev/null > /workspace/merge_outer.log 2>&1 & disown; echo LAUNCHED"
log "merge+quantize launched on pod — polling every 10 min..."

# Poll for merge completion (max 4 hours)
for i in $(seq 1 24); do
    sleep 600
    DONE=$($SSH_POD "grep -c 'ALL DONE MERGE QUANTIZE' /workspace/merge_quantize.log 2>/dev/null || echo 0")
    TAIL=$($SSH_POD "tail -3 /workspace/merge_quantize.log 2>/dev/null")
    log "merge poll $i/24: done=$DONE  tail: $TAIL"
    if [ "${DONE:-0}" -ge "1" ]; then
        log "merge+quantize complete!"
        break
    fi
    if [ "$i" -eq "24" ]; then
        log "ERROR: merge timed out after 4 hours"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# STEP 2: rsync GGUF from pod to Mac local, then to Artemis
# ---------------------------------------------------------------------------
log "STEP 2: rsyncing GGUF from pod to Mac..."
rsync -avz --progress \
    -e "ssh $SSH_OPTS -p $POD_PORT" \
    "root@$POD_IP:/workspace/${GGUF_FILE}" \
    "${LOCAL_TMP}/" 2>&1 | tee -a "$LOG"

log "rsyncing GGUF from Mac to Artemis..."
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$ARTEMIS_HOST" "mkdir -p /opt/lora-checkpoints/v18"
rsync -avz --progress "${LOCAL_TMP}/${GGUF_FILE}" "emsuserver@${ARTEMIS_HOST}:/opt/lora-checkpoints/v18/" 2>&1 | tee -a "$LOG"
log "rsync to Artemis complete"

# ---------------------------------------------------------------------------
# STEP 3: Create Ollama model on Artemis
# ---------------------------------------------------------------------------
log "STEP 3: creating Ollama model on Artemis..."
ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no "$ARTEMIS_HOST" bash << ARTEMIS_EOF
cat > /opt/lora-checkpoints/v18/Modelfile << 'EOF'
FROM /opt/lora-checkpoints/v18/${GGUF_FILE}
PARAMETER num_ctx 8192
PARAMETER temperature 0.3
PARAMETER top_p 0.9
SYSTEM "You are an EMSU AI assistant specialized in EMS education, student support, externship coordination, exam policy, and EMSU operational workflows."
EOF
ollama create ${MODEL_NAME} -f /opt/lora-checkpoints/v18/Modelfile
ollama list | grep ${MODEL_NAME}
ARTEMIS_EOF
log "Ollama model $MODEL_NAME created on Artemis"

# ---------------------------------------------------------------------------
# STEP 4: Terminate the training pod (stop billing)
# ---------------------------------------------------------------------------
log "STEP 4: terminating pod $POD_ID..."
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w 2>/dev/null)
HTTP=$(curl -sS -X DELETE -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $KEY" \
    "https://rest.runpod.io/v1/pods/$POD_ID")
log "pod terminate HTTP $HTTP — billing stopped"

# ---------------------------------------------------------------------------
# STEP 5: Notify via RUBEN event (write sentinel for RUBEN pickup)
# ---------------------------------------------------------------------------
log "STEP 5: writing completion sentinel for RUBEN..."
cat > /tmp/runpod_v18_complete.json << SENTINEL
{
    "event": "runpod_training_complete",
    "model": "$MODEL_NAME",
    "pod_id": "$POD_ID",
    "gguf_path": "/opt/lora-checkpoints/v18/$GGUF_FILE",
    "ollama_model": "$MODEL_NAME",
    "completed_at": "$(date -Iseconds)"
}
SENTINEL

log "=== POST-TRAIN PIPELINE COMPLETE — $MODEL_NAME is live on Artemis ==="
log "Test it: ssh artemis 'ollama run $MODEL_NAME \"What is EMSU proctoring policy?\"'"

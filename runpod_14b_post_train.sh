#!/opt/homebrew/bin/bash
# runpod_14b_post_train.sh — runs after 14B LoRA training completes
# Steps: merge LoRA on pod -> GGUF convert -> Q4 quantize -> rsync to WOPR (16GB GPU)
#        -> ollama create on WOPR -> terminate pod -> notify
# NOTE: 14B goes to WOPR (not Artemis) because WOPR's 16GB GPU fits Q4_K_M 14B (~9GB)
set -uo pipefail
LOG=/tmp/runpod_14b_post_train.log
POD_IP=38.80.152.146
POD_PORT=30141
POD_ID=ftc337x9zb5img
WOPR_IP=76.167.100.188
WOPR_PORT=2222
MODEL_NAME=emsu-qwen-coder-14b-lora-v1
GGUF_FILE=emsu-qwen-coder-14b-v1-Q4_K_M.gguf
LOCAL_TMP=/tmp/runpod_14b_gguf
SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_POD="ssh $SSH_OPTS -p $POD_PORT root@$POD_IP"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "=== 14B POST-TRAIN PIPELINE START ==="
mkdir -p "$LOCAL_TMP"

# STEP 1: merge + GGUF convert + Q4 quantize on the pod
log "STEP 1: deploying merge+quantize script to 14B pod..."
cat > /tmp/pod_14b_merge_quantize.sh << 'MERGE_EOF'
#!/bin/bash
set -e
exec >> /workspace/merge_quantize_14b.log 2>&1
echo "=== 14B MERGE START $(date -Iseconds) ==="

python3 - << 'PYEOF'
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import os

base = "/workspace/base/qwen-coder-14b"
adapter = "/workspace/checkpoints/emsu-qwen-coder-14b-lora-v1"
merged = "/workspace/merged_14b"

os.makedirs(merged, exist_ok=True)
tok = AutoTokenizer.from_pretrained(base, trust_remote_code=True)
tok.save_pretrained(merged)
print("loading 14B base (CPU merge, ~5-10 min)...")
m = AutoModelForCausalLM.from_pretrained(base, torch_dtype=torch.bfloat16,
                                          device_map="cpu", low_cpu_mem_usage=True,
                                          trust_remote_code=True)
print("applying adapter...")
m = PeftModel.from_pretrained(m, adapter)
print("merging and unloading...")
m = m.merge_and_unload()
print("saving merged model...")
m.save_pretrained(merged, safe_serialization=True)
print("merge complete")
PYEOF

pip install -q --upgrade gguf
if [ ! -d /workspace/llama.cpp ]; then
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /workspace/llama.cpp
fi

echo "converting to GGUF f16..."
python3 /workspace/llama.cpp/convert_hf_to_gguf.py /workspace/merged_14b \
    --outtype f16 --outfile /workspace/emsu-qwen-coder-14b-v1-f16.gguf

echo "building quantize tool..."
cd /workspace/llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release 2>/dev/null | tail -2
cmake --build build --config Release -j8 --target llama-quantize 2>&1 | tail -5

echo "quantizing to Q4_K_M..."
./build/bin/llama-quantize \
    /workspace/emsu-qwen-coder-14b-v1-f16.gguf \
    /workspace/emsu-qwen-coder-14b-v1-Q4_K_M.gguf Q4_K_M
ls -lh /workspace/emsu-qwen-coder-14b-v1-Q4_K_M.gguf
echo "=== ALL DONE MERGE QUANTIZE 14B $(date -Iseconds) ==="
MERGE_EOF

scp $SSH_OPTS -P "$POD_PORT" /tmp/pod_14b_merge_quantize.sh "root@$POD_IP:/workspace/merge_quantize_14b.sh"
$SSH_POD "nohup bash /workspace/merge_quantize_14b.sh < /dev/null > /workspace/merge_14b_outer.log 2>&1 & disown; echo LAUNCHED"
log "merge+quantize launched on 14B pod — polling every 5 min (14B merge faster, ~10-20 min total)..."

for i in $(seq 1 12); do
    sleep 300
    DONE=$($SSH_POD "grep -c 'ALL DONE MERGE QUANTIZE 14B' /workspace/merge_quantize_14b.log 2>/dev/null || echo 0")
    TAIL=$($SSH_POD "tail -2 /workspace/merge_quantize_14b.log 2>/dev/null")
    log "merge poll $i/12: done=$DONE  tail: $TAIL"
    [ "${DONE:-0}" -ge "1" ] && log "merge complete!" && break
    [ "$i" -eq "12" ] && log "ERROR: 14B merge timed out" && exit 1
done

# STEP 2: rsync GGUF from pod to Mac, then to WOPR
log "STEP 2: rsyncing 14B GGUF from pod to Mac (~9GB Q4)..."
rsync -avz --progress \
    -e "ssh $SSH_OPTS -p $POD_PORT" \
    "root@$POD_IP:/workspace/${GGUF_FILE}" \
    "${LOCAL_TMP}/" 2>&1 | tee -a "$LOG"

log "rsyncing 14B GGUF from Mac to WOPR..."
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
    -p "$WOPR_PORT" "emsuserver@$WOPR_IP" "mkdir -p /opt/lora-checkpoints/14b-v1"
rsync -avz --progress -e "ssh -p $WOPR_PORT -o StrictHostKeyChecking=no" \
    "${LOCAL_TMP}/${GGUF_FILE}" "emsuserver@$WOPR_IP:/opt/lora-checkpoints/14b-v1/" 2>&1 | tee -a "$LOG"
log "rsync to WOPR complete"

# STEP 3: Create Ollama model on WOPR
log "STEP 3: creating Ollama model on WOPR..."
ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -p "$WOPR_PORT" "emsuserver@$WOPR_IP" << WOPR_EOF
mkdir -p /opt/lora-checkpoints/14b-v1
cat > /opt/lora-checkpoints/14b-v1/Modelfile << 'EOF'
FROM /opt/lora-checkpoints/14b-v1/${GGUF_FILE}
PARAMETER num_ctx 8192
PARAMETER temperature 0.3
PARAMETER top_p 0.9
SYSTEM "You are an EMSU AI assistant specialized in EMS education, student support, externship coordination, exam policy, and EMSU operational workflows. Answer concisely and accurately."
EOF
ollama create ${MODEL_NAME} -f /opt/lora-checkpoints/14b-v1/Modelfile
ollama list | grep ${MODEL_NAME}
echo "14B model created on WOPR"
WOPR_EOF
log "Ollama model $MODEL_NAME created on WOPR (local inference at $0/call)"

# STEP 4: Terminate the 14B training pod
log "STEP 4: terminating 14B pod $POD_ID..."
KEY=$(security find-generic-password -s RUNPOD_API_KEY -w 2>/dev/null)
HTTP=$(curl -sS -X DELETE -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $KEY" \
    "https://rest.runpod.io/v1/pods/$POD_ID")
log "pod terminate HTTP $HTTP — billing stopped"

# STEP 5: Write completion marker
log "STEP 5: writing completion marker..."
cat > /tmp/runpod_14b_complete.json << SENTINEL
{
    "event": "runpod_14b_training_complete",
    "model": "$MODEL_NAME",
    "pod_id": "$POD_ID",
    "gguf_path": "/opt/lora-checkpoints/14b-v1/$GGUF_FILE",
    "ollama_host": "WOPR (localhost:11434)",
    "vram_required_gb": 9,
    "completed_at": "$(date -Iseconds)",
    "next_step": "Update orchestrator_llm_routes to add 14B as primary for classify + ticket_triage surfaces"
}
SENTINEL

log "=== 14B POST-TRAIN COMPLETE === $MODEL_NAME on WOPR at 0/call"
log "test: ssh -p 2222 emsuserver@76.167.100.188 'ollama run $MODEL_NAME \"What is EMSU proctoring policy?\"'"

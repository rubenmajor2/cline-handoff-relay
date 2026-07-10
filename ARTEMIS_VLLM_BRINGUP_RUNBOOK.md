# Artemis Arc A770 vLLM Bring-Up Runbook (idea #9420)

**Status:** PREPPED — waiting on Jon to confirm box is up + on network.
**Access:** emsu-operations MCP `ssh_command` (host=artemis). NEVER raw `ssh artemis` (rule 136).
**Prepared:** 2026-06-05 16:53 PT by Cline. Research-backed (IPEX-LLM official docs + Arc A770 benchmarks).

When Jon says "go", execute the phases below in order. Each phase has an **acceptance check** (rule 137 Definition-of-Done) — do not proceed to the next phase until its check passes.

---

## Phase 0 — Reachability + BIOS sanity (before anything)

**Check with Jon (physical, BIOS-level — he confirms these):**
- [ ] Resizable BAR / "Above 4G Decoding" ENABLED in BIOS. **Arc A770 OOMs/fails init without ReBAR.** This is the #1 hardware gotcha.
- [ ] 4TB NVMe (slot 4) visible to the OS, will be mounted at `/models` for weights.

**Cline acceptance check (#9421):**
```
# via emsu-operations ssh_command host=artemis
echo ARTEMIS_REACHABLE && uname -a && lsblk
```
PASS = returns kernel string (want 6.8+ on Ubuntu 24.04) + shows the 4TB NVMe.

---

## Phase 1 — Mount the 4TB NVMe at /models

```bash
# identify the 4TB device from lsblk (e.g. nvme3n1)
sudo mkfs.ext4 -L models /dev/nvmeXn1          # ONLY if blank — confirm with Jon first
sudo mkdir -p /models
echo 'LABEL=models /models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
sudo mount -a
df -h /models
```
**Acceptance:** `df -h /models` shows ~3.6T available at `/models`.

---

## Phase 2 — Intel GPU driver + compute runtime

```bash
wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
  sudo gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
  https://repositories.intel.com/gpu/ubuntu noble client" | \
  sudo tee /etc/apt/sources.list.d/intel-gpu-noble.list
sudo apt update
sudo apt install -y intel-opencl-icd intel-level-zero-gpu level-zero \
  intel-media-va-driver-non-free libmfx1 libze-intel-gpu1 libze1 clinfo
sudo gpasswd -a $USER render
# log out/in or newgrp render for group membership to take effect
```
**Acceptance (#9421):**
```
sycl-ls
```
PASS = output contains `[level_zero:gpu] ... Intel(R) Arc(TM) A770 Graphics` AND `[opencl:gpu] ... A770`.
If A770 NOT listed → check: render group membership, ReBAR in BIOS, kernel ≥6.8. Do NOT proceed.

---

## Phase 3 — IPEX-LLM vLLM stack (#9422)

**Preferred path = Docker (less error-prone per IPEX-LLM docs):**
```bash
docker pull intelanalytics/ipex-llm-serving-xpu:latest
```

**Bare-metal venv path (if not using docker):**
```bash
sudo apt install -y python3.11 python3.11-venv
python3.11 -m venv ~/vllm-arc && source ~/vllm-arc/bin/activate
pip install --pre --upgrade "ipex-llm[xpu_2.6]" \
  --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
pip install "ipex-llm[serving]"
```
**Acceptance:**
```
source ~/vllm-arc/bin/activate && python -c "import ipex_llm; print(ipex_llm.__version__)"
```
PASS = prints a version, no import error.

---

## Phase 4 — Pull first model to /models

Target (per research): **Qwen2.5-14B-Instruct** at sym_int4 — best general+coding 14B that fits 16GB.
```bash
pip install huggingface_hub
huggingface-cli download Qwen/Qwen2.5-14B-Instruct \
  --local-dir /models/Qwen2.5-14B-Instruct --local-dir-use-symlinks False
```
**Acceptance:** `ls /models/Qwen2.5-14B-Instruct` shows config.json + safetensors shards.

(Fallback if 14B is tight: `Qwen/Qwen2.5-Coder-7B-Instruct` — fast, fits with long context.)

---

## Phase 5 — Start vLLM OpenAI server on the Arc GPU

```bash
export ONEAPI_DEVICE_SELECTOR=level_zero:0
export SYCL_CACHE_PERSISTENT=1
export VLLM_RPC_TIMEOUT=100000
python -m ipex_llm.vllm.xpu.entrypoints.openai.api_server \
  --model /models/Qwen2.5-14B-Instruct \
  --served-model-name qwen2.5-14b \
  --port 8000 --device xpu \
  --dtype float16 --enforce-eager \
  --load-in-low-bit sym_int4 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.90
```
Run under systemd or nohup for persistence (don't hold it in an ssh_command — rule 95).
**Acceptance (DoD for serve unit):**
```
curl -s http://192.168.40.55:8000/v1/models | jq .
curl -s http://192.168.40.55:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-14b","messages":[{"role":"user","content":"say OK"}],"max_tokens":5}' | jq .
```
PASS = `/v1/models` lists `qwen2.5-14b` AND the chat completion returns a response with content.

---

## Phase 6 — Wire into fleet + LiteLLM router (#9423)

1. `fleet-state` MCP `fleet_act mark_host_status host=artemis status=healthy` once serving.
2. Add Artemis to fleet_inventory `models: ["qwen2.5-14b"]`, port 8000.
3. Add a LiteLLM router entry pointing `qwen2.5-14b` → `http://192.168.40.55:8000/v1`. Edit `/etc/litellm/config.yaml` on WOPR, then restart via the **safe wrapper** (rule 118): `sudo /usr/local/bin/emsu-safe-litellm-restart.sh --reason="add artemis qwen2.5-14b serve node"`.
4. Verify a routed call lands on Artemis (send a prompt through LiteLLM with model=qwen2.5-14b, confirm Artemis serves it).
**Acceptance (#9423):** a LiteLLM call to `qwen2.5-14b` returns a completion served by Artemis (confirm via Artemis vLLM logs showing the request).

---

## Key gotchas (from research)

1. **ReBAR off = instant fail.** Confirm with Jon in BIOS before anything.
2. **render group membership** is the #1 silent failure — `sudo gpasswd -a $USER render` then re-login.
3. **Ubuntu 24.04 (kernel 6.8+)** — 22.04 has driver mismatch pain. Confirm OS version in Phase 0.
4. **sym_int4** is the smoothest quant on Arc — better than AWQ/GPTQ for first bring-up.
5. **14B int4 ≈ 8-9GB** weights, fits 16GB with 8k context at 0.90 util. Expect ~12-18 tok/s single stream.

## Cross-refs
- .clinerules/136 (Artemis access via emsu-operations MCP, never raw ssh)
- .clinerules/95 (long remote jobs: nohup/systemd, don't hold in ssh_command)
- .clinerules/118 (LiteLLM restart via safe wrapper)
- .clinerules/137 (Definition-of-Done convergence — each phase has an acceptance check)
- fleet-state MCP, ideas #9420 #9421 #9422 #9423
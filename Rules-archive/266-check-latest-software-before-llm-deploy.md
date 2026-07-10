# 266 — Check latest software/patches BEFORE any multi-node LLM deploy

Permanent rule. Workspace-scoped. Source: 2026-07-10 Ruben directive — "Make a cline rule in LLM training to check for the latest software."

## The bright-line rule

**Before deploying ANY multi-node LLM serving configuration (vLLM, SGLang, TGI, etc.) on GPU clusters, the agent MUST:**

1. **Check current versions** of all stack components: NCCL, vLLM, PyTorch, CUDA, GPU driver, OFED/RDMA stack, NIC firmware
2. **Search for known issues** on the exact hardware combination (GPU arch, NIC model, interconnect type) in:
   - GitHub issues for vLLM, NCCL, PyTorch
   - NVIDIA forums / developer zones
   - Brave/web search for the specific error symptoms
3. **Verify MLNX_OFED is installed** (not stock rdma-core) on any Mellanox/NVIDIA NIC (ConnectX-4 through CX-8). Stock rdma-core has known CX7 RoCEv2 QP compatibility issues.
4. **Check for version-specific regressions** — e.g. NCCL 2.30.4+ has an NVLS regression on sm_121/no-NVLink hardware (GitHub #2167). Match your NCCL version against known regression issues.

## The pre-deploy checklist (run BEFORE launching multi-node)

```bash
# On each node, check:
# 1. NCCL version (system + PyTorch)
python3 -c "import torch; print('PyTorch NCCL:', torch.cuda.nccl.version())"
strings /usr/lib/*/libnccl.so.2 | grep "NCCL version"

# 2. OFED vs stock rdma-core
ofed_info -s 2>/dev/null || echo "NO MLNX_OFED — using stock rdma-core (may cause QP issues on CX7)"
dpkg -l | grep -iE 'ibverbs|rdmacm|mlx5|ofed'

# 3. NIC firmware
cat /sys/class/infiniband/*/device/fw_ver 2>/dev/null
mstflint -d <pci_addr> q 2>/dev/null | grep FW

# 4. GPU driver + CUDA
nvidia-smi --query-gpu=driver_version --format=csv,noheader
nvcc --version 2>/dev/null || cat /usr/local/cuda/version.json 2>/dev/null

# 5. vLLM version
pip show vllm | grep Version
```

## Known regressions to check (maintain this list)

| Component | Version | Issue | Hardware | Fix |
|---|---|---|---|---|
| NCCL | 2.30.4+ | NVLS hang on weight loading | DGX Spark, sm_121, no NVLink | `NCCL_NVLS_ENABLE=0` (GitHub #2167) |
| NCCL | 2.30.4+ | QP transport hang (res=3) | CX7 RoCE, stock rdma-core (no OFED) | Install MLNX_OFED OR `NCCL_IB_DISABLE=1` (TCP fallback) |
| rdma-core | 50.0 (stock) | CX7 RoCEv2 QP creation failure | CX7, Ubuntu 24.04 | Install MLNX_OFED (replaces stock rdma-core) |

## When to search GitHub

**Before spending >30 minutes debugging any NCCL/RDMA/IB issue**, search:
- `github.com/NVIDIA/nccl/issues` for the exact error string
- `github.com/vllm-project/vllm/issues` for the exact hardware + symptom
- Brave search: `<error string> <GPU model> <NIC model> site:github.com`

The GLM-5.2 Hexarchy QP hang (72 hours debugging) would have been caught in 5 minutes by searching "NCCL CX7 QP hang res=3" on GitHub — multiple identical issues exist.

## Cross-references

- Rule 265 — Spatial/Analogy Thinking Protocol (when stuck, search for analogous solutions)
- Rule 262 — Bug library + community search before recycling debugging approaches
- Rule 156 — Bug library (diagnose FIRST before fixing)
- Rule 29 — Act on confidence tier (don't spend 72 hours on one issue)

## Source incident

2026-07-10 — GLM-5.2 Hexarchy (6× DGX Spark, CX7 200Gbps RoCE) QP hang. 72 hours spent debugging NCCL IB QP transport failure (res=3). Root cause: stock rdma-core 50.0 instead of MLNX_OFED, plus NCCL 2.30.7 NVLS regression. GitHub issue #2167 describes the exact hardware. TCP fallback (NCCL_IB_DISABLE=1) works at 3.1 tok/s but IB is needed for 15-25 tok/s target. Ruben directive: "Make a cline rule in LLM training to check for the latest software."

## Last updated

2026-07-10 — initial. Source: GLM-5.2 Hexarchy QP hang + Ruben directive.
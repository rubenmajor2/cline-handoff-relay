# 273 — EMSU Fleet LLM Inventory: Canonical Machine Roles + Hexarchy PP=6 Ring

Permanent rule. Workspace-scoped. Source: Ruben directive 2026-07-14 — agents keep forgetting which boxes are in the Hexarchy, trying to use PP=5/PP=4, and conflating Julia/Claudia (120B TP=2) with Hexarchy members. Updated 2026-07-14 (3rd pass) to be EVERGREEN: this is now the canonical fleet LLM inventory. When any box changes role, this rule MUST be updated.

## EVERGREEN MAINTENANCE PROTOCOL

**This rule is the single source of truth for which physical box serves which LLM.** When ANY box is repurposed, taken down for maintenance, or brought back online:
1. Update the Fleet Inventory table below
2. Update the corresponding role section
3. Check the registry (`/etc/litellm/frankenstein_registry.yaml`) for stale entries
4. Reindex the MCP (`node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only`)
5. Post to ops chat 55 if the change affects routing

**Do NOT rely on memory, stale docs, or old HANDOFF_NOTES for machine roles.** This rule + the live registry are the only valid sources. If they disagree, the registry wins for routing but this rule wins for "which physical box is which."

## Fleet LLM Inventory (CANONICAL — verified 2026-07-14)

| Box Name | Hardware | LAN IP | WG IP | Role | Model | Serve Port | Status |
|---|---|---|---|---|---|---|---|
| **Julia** | DGX Spark GB10 | 192.168.1.190 | 10.100.0.15 | 120B TP=2 HEAD | gpt-oss-120b | :11513 | ✅ LIVE |
| **Claudia** | DGX Spark GB10 | 192.168.1.194 | 10.100.0.16 | 120B TP=2 WORKER | gpt-oss-120b (Ray worker) | :11514 (do_not_probe) | ✅ LIVE |
| **Artemis** | Intel 4x Arc Battlemage | 192.168.1.x | 10.100.0.5 | 120B TP=4 | gpt-oss-120b | :8000 | ✅ LIVE |
| **Cato** | DGX Spark GB10 | 192.168.1.115 | 10.100.0.14 | Hexarchy PP=6 rank 0 | GLM-5.2 | :8210/:8211 | 🔧 MAINTENANCE |
| **Augustus** | DGX Spark GB10 | 192.168.1.244 | N/A | Hexarchy PP=6 rank 1 | GLM-5.2 | :8210/:8211 | 🔧 MAINTENANCE |
| **Pompey** | DGX Spark GB10 | 192.168.1.21 | N/A | Hexarchy PP=6 rank 2 | GLM-5.2 | :8210/:8211 | 🔧 MAINTENANCE |
| **Marcus** | DGX Spark GB10 | 192.168.1.171 | N/A | Hexarchy PP=6 rank 3 | GLM-5.2 | :8210/:8211 | 🔧 MAINTENANCE |
| **Tiberius** | DGX Spark GB10 | 192.168.1.32 | N/A | Hexarchy PP=6 rank 4 | GLM-5.2 | :8210/:8211 | 🔧 MAINTENANCE |
| **Cesar** | DGX Spark GB10 | 192.168.1.56 | 10.100.0.13 | Hexarchy PP=6 rank 5 | GLM-5.2 | :8210/:8211 | 🔧 MAINTENANCE |
| **Cicero** | M5 Mac 128GB | 192.168.1.120 | 10.100.0.12 | 235B reasoning | Qwen3-235B-A22B-Thinking | :11520 | ⚠️ WG DOWN |
| **Joshua** | Intel 2x Arc Pro B60 | 192.168.1.x | 10.100.0.4 | 70B | llama3.3-70b | :11434 | ✅ LIVE |
| **SMS Mac** | M1 Mac 64GB | 192.168.1.195 | N/A | 70B | llama3.3-70b | :11455 | ✅ LIVE |
| **WOPR** | Server | 192.168.1.68 | 10.100.0.1 | Router + Ollama | 14B/32B | :11434, :4000 | ✅ LIVE |
| **Ruben Mac** | M4 Mac Mini | 192.168.1.178 | N/A | 7B-LoRA + Cline | emsu-qwen2.5-coder:7b-lora | :11505 | ✅ LIVE |

**MARCUS ≠ CLAUDIA (corrected 2026-07-25):** Marcus and Claudia are TWO SEPARATE physical boxes, each with its own IP. Marcus = spark-63ce @ 192.168.1.171 (Hexarchy rank 3, runs vllm_slot). Claudia = spark-6d51 @ 192.168.1.194 (120B TP=2 Ray worker for Julia, NOT in the ring). The old "dual-role box" claim was wrong — verified live 2026-07-25 via on-box hostname + IP + MAC check across all 8 Sparks. Per Ruben: each box has its own IP.

## The Hexarchy (GLM-5.2 PP=6 Ring)

The GLM-5.2 local ring is exactly 6 DGX Spark (GB10) nodes. No more, no less. PP=6 is the ONLY valid configuration. NEVER attempt PP=5 or PP=4 — they fail (NCCL topology mismatch, hf-overrides pattern mismatch).

| Node Name | Hostname | LAN IP | RoCE IP 1 | RoCE IP 2 | PP Rank | SSH Access | SSH Password |
|---|---|---|---|---|---|---|---|
| Cato | spark-2aa8 | 192.168.1.115 | 10.100.1.1 | 10.100.6.2 | 0 (master) | WOPR proxy :2204 | qefru3-cocnyf-xuxnoP |
| Augustus | spark-e3b2 | 192.168.1.244 | 10.100.1.2 | 10.100.2.1 | 1 | ssh rubenmajor@192.168.1.244 | qefru3-cocnyf-xuxnoP |
| Pompey | spark-50c0 | 192.168.1.21 | 10.100.2.2 | 10.100.3.1 | 2 | ssh rubenmajor@192.168.1.21 | qefru3-cocnyf-xuxnoP |
| Marcus | spark-63ce | 192.168.1.171 | 10.100.4.2 | 10.100.5.2 | 3 | ssh rubenmajor@192.168.1.171 | qefru3-cocnyf-xuxnoP |
| Tiberius | spark-e9e0 | 192.168.1.32 | 10.100.4.2 | 10.100.5.1 | 4 | ssh rubenmajor@192.168.1.32 | qefru3-cocnyf-xuxnoP |
| Cesar | spark-3b41 | 192.168.1.56 | 10.100.5.2 | 10.100.6.1 | 5 | WOPR proxy :2203 | qefru3-cocnyf-xuxnoP |

All nodes use the same SSH credentials: user `rubenmajor`, password `qefru3-cocnyf-xuxnoP`. Key auth is also set up on all nodes.

## Julia/Claudia 120B TP=2 Cluster

**Julia (spark-6ae6, 192.168.1.190) = HEAD. Claudia (spark-6d51, 192.168.1.194) = WORKER.** (Claudia is its own box — NOT the same hardware as Marcus; Marcus is spark-63ce @ 192.168.1.171 in the Hexarchy.)

- Julia runs Ray head (`ray start --head --port=6379 --node-ip-address=192.168.100.2`) + vLLM serve
- Claudia runs Ray worker (`ray start --address=192.168.100.2:6379 --node-ip-address=192.168.100.1`)
- CX7 link: Julia=192.168.100.2, Claudia=192.168.100.1 (verify with `ping -c2 192.168.100.1` from Julia)
- Serve port: Julia:8000 → WOPR reverse tunnel :11513
- Launch script: `~/bin/vllm-head-docker.sh` on Julia (has all bug library fixes: LD_PRELOAD, CPATH, TIKTOKEN_ENCODINGS_BASE, HF_HOME, --enforce-eager)
- **CRITICAL:** `HF_HOME` must be `/home/rubenmajor/.cache/huggingface` (15 safetensors), NOT `/home/rubenmajor/hfcache_user` (1 safetensors, incomplete)
- **CRITICAL:** Before relaunch, nuclear cleanup: `pkill -9 -f vllm; pkill -9 -f ray; rm -rf /tmp/ray`
- Runbook: `~/Desktop/JULIA_CLAUDIA_120B_BRINGUP_RUNBOOK.md`
- Bug library: #1705, #1706

**Do NOT use `julia_serve_tp2_direct.sh`** — it's a simplified script missing critical env vars. Always use `~/bin/vllm-head-docker.sh`.

## CRITICAL: Cesar and Cato ARE Hexarchy Members — NOT 120B Standalone Boxes

**Cesar and Cato are PP=6 Hexarchy ring nodes (ranks 5 and 0 respectively). They are NOT standalone 120B boxes.** Do NOT attempt to run `gptoss-tp2` Docker containers or `cesar_serve_tp2.sh` / `cato_serve_tp1.sh` on them — those scripts are DEPRECATED leftovers from before the Hexarchy was formed (2026-07-10). Running them will:
1. Destroy the GLM-5.2 PP=6 ring (kills the Docker containers serving GLM-5.2)
2. Leave the Hexarchy unable to start (PP=6 requires all 6 nodes)
3. Potentially corrupt the NCCL/Ray state on the node

**The registry entries for `cesar-120b` and `cato-120b` (ports :11506, :11507) are STALE.** Those reverse-tunnel ports still listen (leftover SSH tunnels) but the vLLM processes behind them are dead because Cesar and Cato now run GLM-5.2 Hexarchy Docker containers, NOT gpt-oss-120b.

**If Cesar or Cato appears "down" on port :11506 or :11507 — that is CORRECT.** They now serve GLM-5.2 on port :8210/:8211 (Hexarchy), not 120B on :11506/:11507. Do NOT try to "fix" them by launching 120B vLLM.

## Cicero (M5 Mac 128GB) — LAN Access + WireGuard

Cicero is an M5 Mac (128GB unified memory) serving Qwen3-235B-A22B-Thinking-2507 (3bit-DWQ MLX) on localhost:11520.

**LAN access:** `ssh rubenmajor@192.168.1.120` (requires Mac password, not the Spark password). The machine IS on the local network — if WireGuard is down, use the LAN IP.

**WireGuard:** Cicero connects to WOPR via WireGuard (10.100.0.12). If 10.100.0.12 is unreachable:
1. Check WG handshake on WOPR: `sudo wg show | grep -A3 '10.100.0.12'` — no handshake = WG down on Cicero
2. SSH to Cicero via LAN: `ssh rubenmajor@192.168.1.120`
3. Restart WireGuard on Cicero: `sudo wg-quick up wg0`
4. Verify from WOPR: `ssh rubenmajor@10.100.0.12 'hostname'`
5. The serve port :11520 is likely bound to localhost — WireGuard must be up for WOPR to reach it

**MAC address:** `fc:b2:14:ca:2f:08` (for UDM DHCP reservation)

## Parallelism: TP=2 vs PP=6

**Question (Ruben 2026-07-14):** Can parallelism be applied to TP=2 boxes like it is to the Hexarchy?

**Answer:** TP=2 and PP=6 use fundamentally different parallelism paradigms:
- **PP=6 (Hexarchy):** Pipeline parallelism — each node holds a SUBSET of model layers. Requests flow through all 6 nodes sequentially. The "parallelism" is in the pipeline: multiple requests can be in-flight at different stages simultaneously.
- **TP=2 (Julia/Claudia):** Tensor parallelism — each tensor operation is SPLIT across both GPUs. Both nodes process the SAME layer but different portions of each matrix multiplication. This is already "parallel" — both GPUs work on every token simultaneously.

**What CAN be parallelized on TP=2:**
1. **Weight loading** (startup time): Use the rule 274 tar-pipe technique to copy safetensors from multiple sources simultaneously when provisioning a new TP=2 box. `ls *.safetensors | xargs -P4 -I{} rsync -av {} target:/path/` can cut the 122GB copy from ~90 min to ~25 min.
2. **Inference** is already parallel by design (TP=2 means both GPUs process every request).
3. **Multiple TP=2 clusters** can run in parallel (e.g., Julia/Claudia + a future second TP=2 pair) — the Frankenstein router distributes across them.

**What CANNOT be parallelized on TP=2:**
- A single request cannot use more than 2 GPUs (TP=2 is the limit for CX7-connected pairs)
- The CX7 link between Julia and Claudia is a single point of throughput — adding more nodes to a TP=2 cluster would require a switch, not daisy-chain

## RoCE Daisy-Chain Ring Topology (Hexarchy)

```
Cato (10.100.1.1) -- Augustus (10.100.1.2)
Augustus (10.100.2.1) -- Pompey (10.100.2.2)
Pompey (10.100.3.1) -- [routed to Marcus]
Marcus (10.100.4.2) -- Tiberius (10.100.4.2)  
Tiberius (10.100.5.1) -- Cesar (10.100.5.2)
Cesar (10.100.6.1) -- Cato (10.100.6.2)
```

NOT a switched fabric — daisy-chain ring. NCCL must use TCP (`NCCL_IB_DISABLE=1`), NOT RDMA.

## PP=6 Only — Never PP=5 or PP=4

The ring is configured for `--nnodes 6 --pipeline-parallel-size 6`. The `hf-overrides` `index_topk_pattern` and NCCL routing are tuned for PP=6. Changing to PP=5 or PP=4:
- Breaks NCCL process group init (hangs indefinitely)
- Breaks the sparse attention index pattern
- Has been attempted and FAILED multiple times (2026-07-14)

If a node is down, the ring CANNOT start. Fix the node, do not reduce PP.

## Launch Procedure (Hexarchy)

1. All 6 nodes must have: 83/83 safetensors + config.json + Docker image + launch script
2. Launch in reverse rank order (5, 4, 3, 2, 1) with 15s stagger, then master (0) last
3. Wait ~15-20 min for model load + NCCL init
4. Verify: `curl http://192.168.1.115:8210/v1/models`

Full runbook: `~/Desktop/GLM52_PP6_CLUSTER_RUNBOOK.md`

## SSH from WOPR

To reach Hexarchy nodes from WOPR:
- Cato: `ssh -p 2204 rubenmajor@127.0.0.1` (reverse tunnel)
- Cesar: `ssh -p 2203 rubenmajor@127.0.0.1` (reverse tunnel)
- Augustus: `ssh rubenmajor@192.168.1.244`
- Pompey: `ssh rubenmajor@192.168.1.21`
- Marcus: `ssh rubenmajor@192.168.1.171`
- Tiberius: `ssh rubenmajor@192.168.1.32`

All use password `qefru3-cocnyf-xuxnoP` if key auth fails. Use `-o IdentitiesOnly=yes -o PubkeyAuthentication=no -o PreferredAuthentications=password` to force password auth if SSH offers too many keys.

## Cross-references

- Rule 157 — Ray worker ports (conn-reset by design, never probe)
- Rule 250 — never hardcode LLM box statuses in _FLAGSHIP_MEMBERS
- Rule 251 — Roman CX7 TP=2 ONLY (Cesar+Cato, Julia+Claudia)
- Rule 268 — Fleet SSH access reference (canonical SSH matrix)
- Rule 274 — Parallel distributed file transfer (tar pipes, multi-node rsync)
- Bug library: #1687 (NCCL_NET=Socket deadlock), #1685 (spec decode PP=6 limitation), #1705 (Julia HF_HOME), #1706 (Julia/Claudia bringup)
- Fleet inventory: `fleet_inventory` MCP (note: claudia entry is stale for Hexarchy context)
- Runbooks: `~/Desktop/JULIA_CLAUDIA_120B_BRINGUP_RUNBOOK.md`, `~/Desktop/GLM52_PP6_CLUSTER_RUNBOOK.md`

## Source

2026-07-14 — Ruben directive: "Put this in all the places where you can't find things, the places that make you want to use PP5 and PP4. Stop forgetting because it's so damaging. Stop forgetting which boxes."

2026-07-14 (2nd update) — Ruben directive: "Cesar/Cato is not the 120B, it is part of the Hexarchy, your information is outdated. And dangerous."

2026-07-14 (3rd update) — Ruben directive: "Make sure that you update rule 273 with the proper information. This needs to be some sort of an evergreen rule... whenever we are changing a box... this rule gets updated properly... all the LLMs need to be put in the same place." Added: canonical fleet inventory table, evergreen maintenance protocol, Cicero LAN IP (192.168.1.120), Julia/Claudia TP=2 launch details, parallelism analysis (TP=2 vs PP=6).

2026-07-25 — Marcus/Claudia correction. Ruben: "Each box has it's own IP. I think this is wrong." Verified live via on-box hostname + IP + MAC on all 8 Sparks: Marcus = spark-63ce @ 192.168.1.171 (Hexarchy rank 3, vllm_slot running), Claudia = spark-6d51 @ 192.168.1.194 (separate TP=2 worker, NOT in ring). Removed the false "dual-role box" claim everywhere. Cross-ref bug #1962.

## Last updated

2026-07-14 (3rd update) — Evergreen rewrite. Added canonical fleet inventory, maintenance protocol, Cicero LAN access, TP=2 vs PP=6 parallelism analysis.
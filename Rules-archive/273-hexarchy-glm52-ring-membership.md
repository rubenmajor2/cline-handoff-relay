# 273 — GLM-5.2 Hexarchy PP=6 Ring: Canonical Node Membership + Julia/Claudia Exclusion

Permanent rule. Workspace-scoped. Source: Ruben directive 2026-07-14 — agents keep forgetting which boxes are in the Hexarchy, trying to use PP=5/PP=4, and conflating Julia/Claudia (120B TP=2) with Hexarchy members.

## The Hexarchy (GLM-5.2 PP=6 Ring)

The GLM-5.2 local ring is exactly 6 DGX Spark (GB10) nodes. No more, no less. PP=6 is the ONLY valid configuration. NEVER attempt PP=5 or PP=4 — they fail (NCCL topology mismatch, hf-overrides pattern mismatch).

| Node Name | Hostname | LAN IP | RoCE IP 1 | RoCE IP 2 | PP Rank | SSH Access | SSH Password |
|---|---|---|---|---|---|---|---|
| Cato | spark-2aa8 | 192.168.1.115 | 10.100.1.1 | 10.100.6.2 | 0 (master) | WOPR proxy :2204 | qefru3-cocnyf-xuxnoP |
| Augustus | spark-e3b2 | 192.168.1.244 | 10.100.1.2 | 10.100.2.1 | 1 | ssh rubenmajor@192.168.1.244 | qefru3-cocnyf-xuxnoP |
| Pompey | spark-50c0 | 192.168.1.21 | 10.100.2.2 | 10.100.3.1 | 2 | ssh rubenmajor@192.168.1.21 | qefru3-cocnyf-xuxnoP |
| Marcus | spark-6d51 | 192.168.1.194 | 10.100.4.2 | 10.100.5.2 | 3 | ssh rubenmajor@192.168.1.194 | qefru3-cocnyf-xuxnoP |
| Tiberius | spark-e9e0 | 192.168.1.32 | 10.100.4.2 | 10.100.5.1 | 4 | ssh rubenmajor@192.168.1.32 | qefru3-cocnyf-xuxnoP |
| Cesar | spark-3b41 | 192.168.1.56 | 10.100.5.2 | 10.100.6.1 | 5 | WOPR proxy :2203 | qefru3-cocnyf-xuxnoP |

All nodes use the same SSH credentials: user `rubenmajor`, password `qefru3-cocnyf-xuxnoP`. Key auth is also set up on all nodes.

## NOT in the Hexarchy — Julia and Claudia

**Julia (spark-6ae6, 192.168.1.190) and Claudia (spark-6d51, 192.168.1.194) are the 120B TP=2 pair. They are NOT part of the GLM-5.2 Hexarchy ring.**

- Julia = 120B TP=2 head (gpt-oss-120b), serves on :11513
- Claudia = 120B TP=2 worker (Ray worker, conn-reset BY DESIGN per rule 157)
- They serve gpt-oss-120b, NOT GLM-5.2

**IMPORTANT FLEET INVENTORY DRIFT:** The fleet inventory WRONGLY labels spark-6d51 (192.168.1.194) as "Claudia" in the `claudia` host_key. In the Hexarchy context, spark-6d51 at 192.168.1.194 IS Marcus (rank 3). The fleet inventory `claudia` entry is stale — it was labeled before the Hexarchy was formed. When working with GLM-5.2, 192.168.1.194 = Marcus. When working with 120B TP=2, 192.168.1.194 = Claudia (Ray worker for Julia). Same physical box, different roles.

NEVER run GLM-5.2 Hexarchy commands on Julia (192.168.1.190). Julia is a separate 120B TP=2 head.

## SSH from WOPR

To reach Hexarchy nodes from WOPR:
- Cato: `ssh -p 2204 rubenmajor@127.0.0.1` (reverse tunnel)
- Cesar: `ssh -p 2203 rubenmajor@127.0.0.1` (reverse tunnel)
- Augustus: `ssh rubenmajor@192.168.1.244`
- Pompey: `ssh rubenmajor@192.168.1.21`
- Marcus: `ssh rubenmajor@192.168.1.194`
- Tiberius: `ssh rubenmajor@192.168.1.32`

All use password `qefru3-cocnyf-xuxnoP` if key auth fails. Use `-o IdentitiesOnly=yes -o PubkeyAuthentication=no -o PreferredAuthentications=password` to force password auth if SSH offers too many keys.

## RoCE Daisy-Chain Ring Topology

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

## Launch Procedure

1. All 6 nodes must have: 83/83 safetensors + config.json + Docker image + launch script
2. Launch in reverse rank order (5, 4, 3, 2, 1) with 15s stagger, then master (0) last
3. Wait ~15-20 min for model load + NCCL init
4. Verify: `curl http://192.168.1.115:8210/v1/models`

Full runbook: `~/Desktop/GLM52_PP6_CLUSTER_RUNBOOK.md`

## Cross-references

- Rule 157 — Ray worker ports (conn-reset by design, never probe)
- Rule 250 — never hardcode LLM box statuses in _FLAGSHIP_MEMBERS
- Rule 251 — Roman CX7 TP=2 ONLY (Cesar+Cato, Julia+Claudia)
- Bug library: #1687 (NCCL_NET=Socket deadlock), #1685 (spec decode PP=6 limitation)
- Fleet inventory: `fleet_inventory` MCP (note: claudia entry is stale for Hexarchy context)

## Source

2026-07-14 — Ruben directive: "Put this in all the places where you can't find things, the places that make you want to use PP5 and PP4. Stop forgetting because it's so damaging. Stop forgetting which boxes."

## Last updated

2026-07-14 — initial. Hexarchy membership + Julia/Claudia exclusion + PP=6 only.
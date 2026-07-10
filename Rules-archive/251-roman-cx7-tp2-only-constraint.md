# 251 — Roman CX7 Cluster: TP=2 ONLY constraint

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id=251)`.

**Trigger:** Any Cesar+Cato or Julia+Claudia fleet operation — serve, restart, fault recovery, bringup.

## The bright-line rule

**Cesar+Cato and Julia+Claudia CX7-linked DGX pairs must ONLY serve TP=2 over the CX7 interconnect. NEVER TP=1 on either box.**

## Why

The CX7 point-to-point link (192.168.100.1/30 ↔ 192.168.100.2/30) is the dedicated TP=2 interconnect. Serving TP=1 on one box:
- Wastes the CX7 link (it's purpose-built for cross-box tensor parallel)
- Creates a duplicate 120B endpoint that confuses the fleet router
- Violates the hardware topology — these boxes are paired, not standalone
- Per Ruben (2026-07-03): "You can't per documentation serve a TP=1 and TP=2 on 2 boxes with the CX7 connected."

## Allowed states for Cesar+Cato

| State | When | How |
|---|---|---|
| **TP=2 serving on :11506** | Normal operation | Ray head (Cesar) + Ray worker (Cato), NCCL over CX7 |
| **Both OFF** | Hardware fault, maintenance, or pre-TP=2 bringup | No vLLM process on either box |
| **NEVER: TP=1 on Cesar alone** | — | Config violation |

## If Cesar GPU faults (Xid 31, etc.)

1. **Do NOT fall back to TP=1 on Cesar.** That's a config violation.
2. Leave Cesar+Cato both OFF.
3. Julia+Claudia (the mirror cluster) becomes the primary 120B on :11513.
4. Fix Cesar hardware (RMA/driver/reboot), then bring back TP=2 with Cato.

## TP=2 bringback sequence (Cesar+Cato)

Requires **sudo on Cesar** to kill the root-owned Ray cluster first:
```
sudo systemctl stop vllm-120b-head.service  # if exists
sudo pkill -9 -f "/usr/local/lib/python3.12/dist-packages/ray/"
sudo pkill -9 raylet gcs_server
sudo pkill -9 vllm
```

Then Ray head on Cesar:
```
source ~/.python-vllm-custom/bin/activate
rm -rf /tmp/ray/session_*
ray start --head --node-ip-address=192.168.100.1 --port=6379 --disable-usage-stats
```

Ray worker on Cato:
```
ssh -p 2204 rubenmajor@127.0.0.1  # via WOPR
source ~/.python-vllm-custom/bin/activate
rm -rf /tmp/ray/session_*
ray start --address=192.168.100.1:6379 --node-ip-address=192.168.100.2 --num-gpus=1
```

Then launch vLLM with P2P_DISABLE=0 (see Romans3.md for full env vars).

## Cross-references

- Rule 248 — verify live state before declaring box/endpoint down
- Rule 252 — stale-info live-probe gate (probe ports; don't trust fleet_inventory heartbeat)
- Romans3.md — full P2P RDMA + multi-IP patch procedure (Desktop)
- ROMAN_CX7_CONSTRAINT.md — source doc (Desktop)
- Idea #16163 — Cesar Xid 31 fault
- Idea #15144 — P2P RDMA enablement
- Fleet inventory: Julia WG 10.100.0.15, Claudia WG 10.100.0.16

## Source

2026-07-03 — Ruben directive: "You can't per documentation serve a TP=1 and TP=2 on 2 boxes with the CX7 connected." Converted from ROMAN_CX7_CONSTRAINT.md + idea #16254. Also cross-refs Romans3.md for the full TP=2 bringback procedure.

## Last updated

2026-07-03 — initial. Idea #16254.
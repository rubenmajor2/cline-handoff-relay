# 274 — Parallel Distributed File Transfer: multi-node rsync, tar pipes, and parallel xargs for bulk data

Permanent rule. Workspace-scoped. Source: Ruben directive 2026-07-14 — "there's a bunch of other leverage / use cases for the idea you just came up with. Parallel streams. Can this be applied for other operations?"

## When to use parallel/distributed transfer

Any time you need to copy a large dataset (>10GB) between EMSU fleet nodes, use these techniques instead of single-stream rsync. The 1Gbps management network is the bottleneck on DGX Spark boxes — a single rsync gets ~25MB/s. These techniques can get 100-125MB/s (near wire speed).

## Technique 1: Multi-node distributed rsync (best for Hexarchy/fleet-wide copies)

When copying FROM multiple source nodes TO one target, split the file list across sources. Each source sends different files simultaneously.

```bash
# Example: copy 83 safetensors from 5 source nodes to 1 target
# Cato sends files 1-16
ls /path/to/files/*.safetensors | sed -n '1,16p' | xargs -P4 -I{} rsync -av {} rubenmajor@TARGET:/path/ &
# Node2 sends files 17-32
ssh node2 'ls /path/to/files/*.safetensors | sed -n "17,32p" | xargs -P4 -I{} rsync -av {} rubenmajor@TARGET:/path/' &
# Node3 sends files 33-48
ssh node3 'ls /path/to/files/*.safetensors | sed -n "33,48p" | xargs -P4 -I{} rsync -av {} rubenmajor@TARGET:/path/' &
wait
```

**When to use:** Multiple source nodes have the same dataset and one node needs it. Distributes the send load across multiple 1Gbps uplinks.

**Caveat:** Target's 1Gbps downlink is the hard cap. More than 3-4 sources causes TCP contention. Sweet spot is 3 sources with 4 streams each (12 parallel).

## Technique 2: tar pipe over SSH (best for single-source bulk transfer)

```bash
# Fastest single-source bulk transfer — near-zero protocol overhead
cd /source/dir && tar cf - files* | ssh target "cd /dest/dir && tar xf -"

# With compression (if CPU is available, network is bottleneck):
cd /source/dir && tar cf - --use-compress-program=pigz files* | ssh target "cd /dest/dir && tar xf - --use-compress-program=pigz"

# Without compression (if files are already compressed like safetensors):
cd /source/dir && tar cf - files* | ssh target "cd /dest/dir && tar xf -"
```

**When to use:** Single source, bulk transfer, files are large. tar pipe has near-zero overhead vs rsync's per-file checksum negotiation. Gets ~110-120MB/s on 1Gbps link (vs rsync's ~25-90MB/s).

**Caveat:** No resume capability — if interrupted, must restart. Use `--partial` with rsync for resumable transfers.

## Technique 3: Parallel xargs rsync (best for many medium files from one source)

```bash
# 8 parallel rsync streams from one source
ls /source/*.safetensors | xargs -P8 -I{} rsync -av --partial {} rubenmajor@TARGET:/dest/
```

**When to use:** Many files (20+), single source, want parallelism without multi-node coordination. Gets ~100MB/s with 8 streams on 1Gbps.

**Caveat:** Too many streams (>12) causes TCP contention and actually slows down. Sweet spot is 4-8 streams.

## Technique 4: Netcat (nc) pipe (fastest possible, no encryption overhead)

```bash
# On target (receiver first):
nc -l -p 12345 | tar xf - -C /dest/dir

# On source (sender):
tar cf - files* | nc TARGET_IP 12345
```

**When to use:** Trusted LAN only, maximum speed, no encryption needed. Gets ~125MB/s (wire speed on 1Gbps).

**Caveat:** No encryption, no authentication. LAN-only. If interrupted, no resume.

## Decision matrix

| Scenario | Best technique | Speed (1Gbps) |
|---|---|---|
| 1 source → 1 target, bulk | tar pipe over SSH | ~110-120 MB/s |
| 1 source → 1 target, many files | xargs -P8 rsync | ~100 MB/s |
| 1 source → 1 target, need resume | rsync --partial (single stream) | ~25-90 MB/s |
| N sources → 1 target | Distributed rsync (3 sources) | ~100-125 MB/s |
| Trusted LAN, max speed | nc pipe | ~125 MB/s |
| N sources → N targets | Parallel rsync from each source | ~125 MB/s each |

## Use cases beyond weight sync

- **Docker image distribution:** `docker save image | ssh target "docker load"` (tar pipe)
- **Log aggregation:** `ssh node "tar cf - /var/log/*.log" | tar xf - -C /central/logs/`
- **Config deployment:** `tar cf - config/ | ssh target "tar xf - -C /etc/app/"`
- **Database dumps:** `ssh db "pg_dump db | pigz" | pigz -d | psql target_db`
- **Model weights:** distributed rsync across Hexarchy (this is the primary use case)
- **Backup/restore:** tar pipe for full-speed bulk backup to NAS

## Cross-references

- Rule 273 — Hexarchy PP=6 ring membership (node IPs and SSH credentials)
- Rule 95 — scp+nohup for long-running remote commands
- Rule 268 — Fleet SSH access reference (ports, IPs, passwords)
- Bug library #1687 — NCCL deadlock (use NCCL_IB_DISABLE=1, not NCCL_NET=Socket)

## Source

2026-07-14 — Ruben directive: "there's a bunch of other leverage / use cases for the idea you just came up with. Parallel streams. Can this be applied for other operations? What about a tar pipe?"

## Last updated

2026-07-14 — initial. 4 techniques + decision matrix + use cases beyond weight sync.
# 268 — Fleet SSH Access & Connection Reference (durable, never guess)

Source: 2026-07-08 Ruben directive (repeated 2+ dozen times): "I can't keep going back and forth with you about the LLMs and whether they are connected and hard rebooting boxes because you didn't look at the proper source. We need a durable solution for this."

## THE CANONICAL LIVE-STATE SOURCE

**Before declaring ANY box down or unreachable, check the live router snapshot:**
```
cat /tmp/emsu_router_snapshot.json | python3 -m json.tool
```
This is written every 60s by `cron_llm_router_snapshot.php` and shows which models are actively routing. The web dashboard is at `https://emsuniversity.com/emtskills/routes/llm_router_live.php` (MasterAdmin session required; fetch the JSON file directly instead).

**ALSO check `fleet_inventory` MCP tool** for stored SSH paths, IPs, and passwords BEFORE trying to SSH anywhere. Do NOT guess IPs or SSH paths.

## Fleet SSH Access Matrix (verified 2026-07-08)

| Host | Hostname | LAN IP | WG IP | RoCE IP | WOPR Reverse Tunnel | SSH User | Auth | Password |
|---|---|---|---|---|---|---|---|---|
| WOPR | wopr.emsuniversity.com | 172.116.115.101 | 10.100.0.1 | N/A | N/A (this IS the gateway) | emsuserver | key | N/A |
| Julia | spark-6ae6 | 192.168.1.190 | 10.100.0.15 | 192.168.100.2 | :2205 | rubenmajor | key | qefru3-cocnyf-xuxnoP |
| Claudia | spark-6d51 | 192.168.1.194 | 10.100.0.16 | 192.168.100.1 | :2206 | rubenmajor | key+password | qefru3-cocnyf-xuxnoP |
| Cesar | spark-3b41 | 192.168.1.136 | 10.100.0.13 | 192.168.100.1 | :2203 | rubenmajor | key | qefru3-cocnyf-xuxnoP |
| Cato | spark-2aa8 | 192.168.1.115 | 10.100.0.14 | 192.168.100.1 | :2204 | rubenmajor | key | qefru3-cocnyf-xuxnoP |
| Augustus | spark-e3b2 | 192.168.1.16 | 10.100.0.8 | N/A | via Cesar jump | rubenmajor | password | qefru3-cocnyf-xuxnoP |
| Tiberius | spark-e9e0 | 192.168.1.16 | 10.100.0.9 | N/A | via Cesar jump | rubenmajor | password | qefru3-cocnyf-xuxnoP |
| Artemis | artemis.emsuniversity.com | 192.168.0.208 | 10.100.0.5 | N/A | N/A | emsuserver | key | N/A |
| Cicero | Ruben's MacBook Pro (3) | 192.168.1.252 | 10.100.0.12 | N/A | N/A | rubenmajor | key | Mac password |
| Joshua | joshua.emsuniversity.com | 98.172.111.42 | 10.100.0.4 | N/A | :2222 | emsusrvr2 | key | N/A |
| Mac M4 | rubens-2024-m4-mac | 192.168.1.156 | N/A | N/A | :2224 | rubenmajor | key | Mac password |
| SMS Mac | rubens-mac-studio | 98.186.229.82 | N/A | N/A | :2223 | rubenmajor | key | Mac password |

## SSH Command Patterns (copy-paste ready)

### From WOPR (the gateway — all MCP ssh_command runs here)
```bash
# Julia (via reverse tunnel — MOST RELIABLE)
ssh -p 2205 rubenmajor@127.0.0.1

# Claudia (via reverse tunnel)
ssh -p 2206 rubenmajor@127.0.0.1

# Cesar (via reverse tunnel)
ssh -p 2203 rubenmajor@127.0.0.1

# Cato (via reverse tunnel)
ssh -p 2204 rubenmajor@127.0.0.1

# Julia via WireGuard (if reverse tunnel down)
ssh rubenmajor@10.100.0.15

# Claudia via WireGuard
ssh rubenmajor@10.100.0.16

# Artemis via WireGuard (NOTE: emsuserver, NOT rubenmajor)
ssh -i /home/emsuserver/.ssh/id_ed25519 emsuserver@10.100.0.5

# Augustus/Tiberius (via Cesar jump)
ssh -J rubenmajor@127.0.0.1:2203 rubenmajor@<augustus_or_tiberius_LAN_IP>
```

### From Julia (to Claudia — direct LAN, fastest)
```bash
# LAN (preferred — same subnet)
ssh rubenmajor@192.168.1.194

# RoCE (GPU-to-GPU link, for Ray/NCCL)
ssh rubenmajor@192.168.100.1
```

### SSH Config on WOPR (~/.ssh/config)
The DGX Spark boxes have SSH config entries for the RoCE IPs (192.168.100.x) with `StrictHostKeyChecking no` and `UserKnownHostsFile /dev/null`. These are set on Julia, not WOPR.

## LiteLLM Model Endpoints (from /etc/litellm/config.yaml)

| Model Name | api_base | Served By |
|---|---|---|
| cesar-120b / cato-120b | http://127.0.0.1:11506/v1 | Cesar+Cato CX7 TP=2 (WOPR reverse tunnel) |
| julia-120b | http://127.0.0.1:11513/v1 | Julia+Claudia CX7 TP=2 (WOPR reverse tunnel) |
| cicero-235b | http://10.100.0.12:11520/v1 | Cicero MLX (M5 Mac) |
| frankenstein-405b | (Tetrarchy ring) | Augustus+Tiberius+Cesar+Cato |
| ollama-14b/32b | http://127.0.0.1:11434 | WOPR local ollama |
| ollama-7b-lora | http://10.100.0.4:11434 | Joshua |
| deepseek-v4-pro | https://api.deepseek.com | Cloud (paid) |
| glm-5.2 | (OpenRouter or Tetrarchy) | Cloud or local ring |

## Diagnostic Decision Tree (when a box seems unreachable)

1. **CHECK `/tmp/emsu_router_snapshot.json` FIRST** — is the model routing? If yes, the box is serving; don't declare it down.
2. **CHECK `fleet_inventory` MCP** — what are the stored SSH paths and IPs?
3. **Try WOPR reverse tunnel** (e.g., `:2205` for Julia) — most reliable path.
4. **Try WireGuard IP** (e.g., `10.100.0.15`) — if reverse tunnel down.
5. **Try from a sibling box** (e.g., Julia → Claudia via `192.168.1.194`) — different network path.
6. **Ping first** — if ping works, kernel is alive. If SSH hangs on "banner exchange", userspace is frozen (not a network issue).
7. **Port scan** — `for p in 22 8000; do timeout 2 bash -c "echo > /dev/tcp/IP/$p" && echo OPEN || echo closed; done`. If 22 is open but banner exchange hangs, sshd is frozen, not the network.
8. **NEVER use `-o BatchMode=yes`** when testing a box that might require password auth. It silently disables password prompt. Use `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no` for password-only.
9. **Raw socket test** — `python3 -c "import socket; s=socket.socket(); s.settimeout(8); s.connect(('IP',22)); print(s.recv(1024))"` — if this times out, sshd cannot fork (userspace exhausted).

## Common Failure Modes (don't misdiagnose)

| Symptom | Cause | NOT |
|---|---|---|
| Ping works, SSH "banner exchange timeout" | Userspace frozen (sshd can't fork) | Network issue, firewall |
| Ping works, SSH "connection refused" | sshd not started (boot) or crashed | Network issue |
| Ping 100% loss | Network/WG down or box powered off | sshd issue |
| Port 22 open, raw socket gets no data | Userspace resource exhaustion | SSH config issue |
| All paths fail identically | Box-level freeze (kernel alive, userspace dead) | Per-path network issue |

## Box Reboot Notes

- **Julia and Claudia share power** — pulling one's plug may reboot both. Always check both after a power event.
- **DGX Spark boot time**: 3-5 minutes for full boot including GPU init. Don't declare down before 5 min.
- **After reboot, verify**: (1) ping works, (2) SSH banner exchange completes, (3) `nvidia-smi` returns GPU info, (4) vLLM/Ray services start (may need manual `bash ~/julia_full_relaunch.sh`).

## Source

2026-07-08 — Ruben directive after 20+ instances of agents guessing SSH paths, misdiagnosing connection issues, and requesting unnecessary box reboots. The live router page (`llm_router_live.php`) and `fleet_inventory` MCP exist for exactly this purpose but were not being consulted.

## Last updated

2026-07-08 — initial. IPs and passwords verified against fleet_inventory + live SSH tests this session.
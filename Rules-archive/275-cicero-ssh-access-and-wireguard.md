# 275 — Cicero SSH Access + WireGuard Restart Procedure

Permanent rule. Workspace-scoped. Source: 2026-07-14 session — agent spent 30+ minutes trying to SSH to Cicero, didn't know the access pattern.

## The Access Pattern

Cicero (M5 Mac 128GB, hostname `rubens-mbp-2`, MAC `fc:b2:14:ca:2f:08`) is accessible via:

1. **Primary: WOPR → WireGuard (10.100.0.12)** using WOPR's `/home/emsuserver/.ssh/id_ed25519` key:
   ```
   ssh -i /home/emsuserver/.ssh/id_ed25519 rubenmajor@10.100.0.12
   ```
   This requires WireGuard to be UP on Cicero.

2. **Fallback: Mac → LAN (192.168.1.120)** — requires the Mac's `id_ed25519` key to be in Cicero's `~/.ssh/authorized_keys`. If not authorized, use `ssh-copy-id` (requires Mac password — CANNOT be automated by Cline):
   ```
   ssh-copy-id -i ~/.ssh/id_ed25519.pub rubenmajor@192.168.1.120
   ssh rubenmajor@192.168.1.120
   ```

3. **NO reverse tunnel exists for Cicero on WOPR** (unlike smsmac:2223, 2024mac:2224). The plan was to use WireGuard exclusively (see CICERO_REMAINING_COPY_PROMPTS.md).

## When WireGuard Is Down on Cicero

Symptoms:
- WOPR: `sudo wg show | grep -A3 '10.100.0.12'` shows no handshake
- WOPR: `ssh rubenmajor@10.100.0.12` → "No route to host"
- WOPR: `ssh rubenmajor@192.168.1.120` → "Connection timed out" (Cicero firewall blocks non-WG SSH from WOPR's subnet)
- Mac: `ssh rubenmajor@192.168.1.120` → asks for password (key not authorized) or works if key was previously copied

## Fix Procedure

1. **From Ruben's Mac** (192.168.1.178, same LAN as Cicero):
   ```bash
   # If key not yet authorized (first time):
   ssh-copy-id -i ~/.ssh/id_ed25519.pub rubenmajor@192.168.1.120
   
   # Then SSH in and restart WireGuard:
   ssh rubenmajor@192.168.1.120 'sudo wg-quick up wg0'
   ```

2. **Verify from WOPR:**
   ```bash
   sudo wg show | grep -A3 '10.100.0.12'  # should show latest handshake
   ssh -i /home/emsuserver/.ssh/id_ed25519 rubenmajor@10.100.0.12 'hostname'
   curl -s http://10.100.0.12:11520/v1/models
   ```

3. **If 235B model not serving**, check launchd:
   ```bash
   ssh -i /home/emsuserver/.ssh/id_ed25519 rubenmajor@10.100.0.12 'launchctl list | grep cicero; ps aux | grep mlx | grep -v grep'
   ```

## Why Cline Can't Auto-Fix This

- `execute_command` does NOT support interactive password prompts
- `ssh-copy-id` and password-based SSH both require typing a password
- Cline can only use key-based (non-interactive) SSH
- If no key is authorized on Cicero, Ruben must manually run `ssh-copy-id` once

## Fleet SSH Key Inventory

| Machine | Key Used | From Where |
|---|---|---|
| Cicero (192.168.1.120) | `/home/emsuserver/.ssh/id_ed25519` via WG, or Mac's `id_ed25519` via LAN | WOPR (WG) or Mac (LAN) |
| SMS Mac (192.168.1.195) | `~/.ssh/id_ed25519` via reverse tunnel :2223 | Mac → WOPR → smsmac |
| 2024 Mac (192.168.1.156) | `~/.ssh/mac2_to_thismac` via reverse tunnel :2224 | Mac → WOPR → 2024mac |
| Julia (192.168.1.190) | `~/.ssh/id_ed25519` via reverse tunnel :2205 | Mac → WOPR → cesar |
| Claudia (192.168.1.194) | `~/.ssh/id_ed25519` via reverse tunnel :2206 | Mac → WOPR → cato |
| Hexarchy nodes | `~/.ssh/id_ed25519` via LAN | Mac direct |
| WOPR | `~/.ssh/id_ed25519` via :2222 | Mac direct |

## Cross-references

- Rule 268 — Fleet SSH access reference
- Rule 273 — Fleet LLM inventory (evergreen)
- Rule 144 — Server paths via SSH, not local file tools
- CICERO_BABYSIT_PROMPT.md — original SSH access documentation
- CICERO_REMAINING_COPY_PROMPTS.md — WireGuard setup instructions

## Source

2026-07-14 — Ruben: "you have SSH access to this computer... you have had access SSH access to cicero for months"

## Last updated

2026-07-14 — initial. Documents the WOPR→WireGuard access pattern, LAN fallback, and why Cline can't auto-fix when WireGuard is down (interactive password required).
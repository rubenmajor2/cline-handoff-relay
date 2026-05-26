# 117 — Lookup fleet_inventory.ssh_path before any host probe; do not guess IPs

Permanent rule. Workspace-scoped.

## Source incident

2026-05-26 task `cline_fleet_llm_smsmac` — Cline probed `76.167.100.188:11434` (WOPR's public IP) for ~30 min thinking it was SMS-Mac's Ollama endpoint. SMS-Mac's actual Ollama is reachable via the WOPR reverse-tunnel port `11455`, NOT at WOPR's primary IP. The `fleet_inventory` record for `sms_mac` contained the correct path (`ssh -p 2223 rubenmajor@127.0.0.1 via WOPR`), but the agent skipped the lookup and guessed from a stale IP in memory. The 30-min panic-cycle cost a full task window.

Known correct paths (as of 2026-05-26):
- **SMS-Mac SSH**: `ssh -p 2223 rubenmajor@127.0.0.1` (run FROM WOPR; works regardless of SMS-Mac LAN IP)
- **SMS-Mac Ollama**: `http://localhost:11455` (via WOPR forward-tunnel, also FROM WOPR)
- **WOPR SSH**: `ssh -p 2222 emsuserver@76.167.100.188` (direct)
- **Artemis SSH**: per fleet_inventory record (WireGuard VPN, 10.100.0.5)

## The bright-line rule

**Every host probe — `ssh`, `ping`, `curl`, `nc`, `telnet`, any connectivity check — MUST be preceded by a `fleet_inventory` MCP lookup. Use the recorded `ssh_path`. Do not guess IPs from memory, chat history, or prior-task context.**

The check takes one tool call. The wrong-IP panic cycle takes 30 minutes.

## Decision tree

Before issuing any probe:

1. **Call `fleet_inventory`** (no args) → get the full inventory JSON.
2. **Find the target host** by `host_key` (wopr / sms_mac / artemis / joshua / mac_ruben).
3. **Read `ssh_path`** (or the structured `ssh_paths` JSON once rule-38 migration lands).
4. **Use exactly that path.** Do not substitute, abbreviate, or "try a shortcut."
5. If `ssh_path` is null or stale (host says "unknown"), update it via `fleet_act` BEFORE probing further.

Only exception: if you are ON WOPR already running a command inside an `ssh_command` MCP call, you may use the WOPR-relative paths (`localhost:11455`, `127.0.0.1:2223`) directly — those are WOPR-local, not IP guesses.

## Common wrong-IP traps

| What you think | What it actually is | Correct path |
|---|---|---|
| SMS-Mac Ollama at 192.168.1.X:11434 | WOPR proxypass port 11455 → SMS-Mac | `curl http://localhost:11455/...` FROM WOPR |
| SMS-Mac SSH at 192.168.1.221 | Only works if Cline is on same LAN | `ssh -p 2223 rubenmajor@127.0.0.1` FROM WOPR |
| Artemis at some guessed IP | WireGuard VPN 10.100.0.5 | fleet_inventory → ssh_path |
| Joshua at any IP | Only reachable via WOPR tunnel | fleet_inventory → ssh_path |

## Structured ssh_paths migration

The current `ssh_path` column is freeform varchar, which caused the ambiguity. An approved schema migration (idea #XXXX) will replace it with a structured `ssh_paths JSON` column containing:

```json
{
  "direct_ssh": "<user@host:port or null>",
  "via_jump": "<user@jumphost:port + -J flag or null>",
  "reverse_tunnel_port": <WOPR-side port or null>,
  "lan_only_note": "<note or null>"
}
```

Until that migration lands, always read the full `ssh_path` varchar text from `fleet_inventory` and parse it — do not extract partial IPs.

## Self-check before any probe

Ask:
1. *"Did I call `fleet_inventory` in this task already?"* If no → call it first.
2. *"Am I using the `ssh_path` value from that call?"* If no → stop, re-read the record.
3. *"Am I on the correct host to use this path?"* (some paths are WOPR-relative). Check.

If all three yes → proceed. If any no → back to step 1.

## Cross-references

- `.clinerules/92` — work at the core (fix the fleet record if it's wrong; don't keep probing)
- `.clinerules/116` — HTTP-probe before trust (gate for trusting a probe result)
- `.clinerules/99` — YOLO prevention (ssh:connect/timeout is a top failure class)
- `fleet_inventory` MCP tool (fleet-state server) — the lookup target
- `fleet_act` MCP tool — to update host status if a probe fails

## Last updated

2026-05-26 — initial rule. Source: 30-min wrong-IP panic cycle probing WOPR's IP thinking it was SMS-Mac during `cline_fleet_llm_smsmac`.
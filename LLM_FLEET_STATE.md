# EMSU LLM Fleet — CANONICAL LIVE STATE

**Last updated:** 2026-07-08 14:04 PT
**Maintained by:** Cline agents + Ruben
**Purpose:** Single source of truth for LLM fleet topology, spill order, and box roles. Every Cline agent MUST read this file before making any claim about fleet/model status. Do NOT trust error_watchdog summaries — always live-probe via `llm_locate` or HTTP check.

## Spill Order (free-first, paid last resort)

```
1. GLM-5.2 Local (Tetrarchy ring, free)     → WOPR:11516
2. DeepSeek v4 Pro (free, prefix-cached)    → via litellm routing
3. GLM 5.2 (free)                           → via litellm routing
4. Claude Sonnet (paid, LAST RESORT only)   → via litellm routing
```

**NEVER suggest Opus.** Opus is not in the active spill ladder. If anyone suggests Opus/Sonnet as the default model for an unrelated task, that is a rule violation (rule 146).

## Active Models (live-probed 2026-07-08)

### GLM-5.2 Tetrarchy (504B, free)
- **Endpoint:** WOPR:11516 (`glm-5.2-local`)
- **Boxes:** Cato + Tiberius + Cesar + Augustus (4x DGX Spark GB10)
- **Status:** HEALTHY, 4.4 tok/s, PP=4, native FP4
- **Config:** `/tmp/glm52_launch_fix9.sh` on Cato
- **Watchdog:** @reboot cron + 5-min watchdog on Cato
- **Tunnel:** `glm52-tunnel.service` (WOPR:11516 → Cato:8000)

### 120B (gpt-oss, free)
- **Artemis:** 44 tok/s (mxfp4) — `gpt-oss-120b`
- **Julia:** 60 tok/s (LoRA `emsu_distill`) — `gpt-oss-120b` + adapter
- **Endpoint:** via `litellm.emsuniversity.com` routing

### 70B (free)
- **Box:** Joshua (2x 60B GPUs)
- **Endpoint:** via `litellm.emsuniversity.com` routing

### 32B/14B/7B (free, local)
- On-device local models
- **Endpoint:** via `litellm.emsuniversity.com` routing

## Box Roles

| Box | Role | Notes |
|---|---|---|
| WOPR | Main server (LiteLLM, EMSU app, MySQL, MCP) | `litellm.emsuniversity.com` (CF tunnel → WOPR:4000) |
| Artemis | 120B inference | `gpt-oss-120b` mxfp4 |
| Julia | 120B inference + LoRA training | `gpt-oss-120b` + `emsu_distill` adapter |
| Joshua | 70B inference | 2x 60B GPUs |
| Cato | GLM-5.2 ring head | Tetrarchy rank 0 |
| Tiberius | GLM-5.2 ring worker | Tetrarchy rank 1 |
| Cesar | GLM-5.2 ring worker | Tetrarchy rank 2 |
| Augustus | GLM-5.2 ring worker | Tetrarchy rank 3 |
| **Cicero** | **Ruben's workstation** | **NOT available for fleet inference** |
| SMS Mac | Ops terminal | iMessage bot host |

## DEPRECATED (do NOT reference)

- **RunPod:** NOT IN USE. Removed. Never suggest RunPod as a serving option.
- **Opus/Sonnet paid spill:** Only as absolute last resort. Never the default suggestion.
- **Connecteam:** Decommissioned 2026-05-15. Team Hub is the replacement (rule 246).

## Canonical LiteLLM Endpoint

**`https://litellm.emsuniversity.com`** (Cloudflare tunnel → WOPR:4000)

This is the PERMANENT, reboot-surviving base URL. Do NOT use `http://127.0.0.1:4000` or localhost SSH tunnels — those die when the Mac→WOPR SSH tunnel drops. The CF tunnel is in `/etc/cloudflared/config.yml` and is monitored by the `cloudflared` systemd service.

## How to Live-Probe (run BEFORE any fleet health claim)

1. `llm_locate(model="")` — returns all models + live HTTP probe status
2. `fleet_now` — live aggregate snapshot
3. `fleet_inventory` — canonical host inventory
4. Direct HTTP probe: `curl -s -o /dev/null -w '%{http_code}' http://WOPR:11516/v1/models`

**Never trust `error_watchdog` for fleet state.** It reports stale cron health probes that may reference already-resolved issues. Always live-probe.
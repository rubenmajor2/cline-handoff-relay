# 260 — Live-probe fleet state enforcement (never trust error_watchdog for fleet health)

Source: 2026-07-08 incident — morning advisory reported Cicero 235B "down" (it's Ruben's workstation), 70B "dead" (Joshua has it on 2x60B GPUs), RunPod "still in use" (deprecated), and Opus in the spill ladder (not in use). All from stale error_watchdog data. Ruben: "Seems also like stale info that needs correction. We need to be using / forcing Cline Agents to use Live states."

## The bright-line rule

**Before making ANY claim about LLM fleet health, model availability, box status, or spill order, you MUST:**

1. **Read `~/Documents/Cline/LLM_FLEET_STATE.md`** for canonical topology, spill order, and box roles.
2. **Live-probe the specific endpoint** via one of:
   - `llm_locate(model="")` — returns all models + live HTTP probe status
   - `fleet_now` — live aggregate snapshot
   - Direct HTTP: `curl -s -o /dev/null -w '%{http_code}' http://WOPR:11516/v1/models`
3. **Never cite `error_watchdog` as the sole source** for a fleet health claim. It reports stale cron health probes that reference already-resolved issues.

## What counts as a "fleet health claim"

Any statement about:
- Whether a model is "up", "down", "dead", "offline", or "serving"
- Whether a box is available for inference
- What the spill order is
- Whether we're "spilling to paid models"
- Whether RunPod is in use (it's NOT, it's deprecated)
- Whether Opus/Sonnet is the default (it's NOT, free-local-first is the design)

## The canonical fleet state file

`~/Documents/Cline/LLM_FLEET_STATE.md` is the single source of truth. It documents:
- **Spill order:** GLM-5.2 Local → DeepSeek v4 Pro → GLM 5.2 → Claude Sonnet (last resort only, NEVER Opus)
- **Box roles:** Cicero = Ruben's workstation (NOT fleet), Joshua = 70B (2x60B), Cato/Tiberius/Cesar/Augustus = GLM-5.2 ring
- **Deprecated:** RunPod (removed), Connecteam (decommissioned), Opus (not in spill ladder)
- **Canonical endpoint:** `https://litellm.emsuniversity.com`

## Anti-patterns (all are violations)

- Citing `error_watchdog` output as proof a box is "down" without live-probing
- Claiming RunPod is in use (it's deprecated, Ruben has said this multiple times)
- Suggesting Opus as a model option (it's not in the spill ladder)
- Claiming a box is "dead" based on a stale cron health probe
- Reporting fleet status from memory instead of reading the canonical file + live-probing

## Self-check before any fleet health statement

1. *Did I read `LLM_FLEET_STATE.md`?* If no → read it first.
2. *Did I live-probe the endpoint?* If no → probe it now.
3. *Am I citing `error_watchdog`?* If yes → stop, live-probe instead.
4. *Am I mentioning RunPod or Opus?* If yes → stop, both are deprecated/not-in-use.

## Cross-references

- Rule 146 — Frankenstein-LLM routes every LLM, free-local-first is the design, never suggest Claude/Anthropic
- Rule 250 — no hardcoded LLM statuses in router config
- Rule 252 — stale-info live-probe gate (probe serving ports before declaring host down)
- Rule 258 — MCP stale/empty data truth gate
- `~/Documents/Cline/LLM_FLEET_STATE.md` — canonical fleet state file

## Source incident

2026-07-08 — Morning health advisory built from `error_watchdog` data incorrectly reported: Cicero 235B offline (it's Ruben's workstation), 70B dead (Joshua has 2x60B), RunPod in use (deprecated), Opus in spill ladder (not in use). Ruben: "We need to be using / forcing Cline Agents to use Live states."

## Last updated

2026-07-08 — initial. Filed as idea #16819, approved autonomous by Ruben.
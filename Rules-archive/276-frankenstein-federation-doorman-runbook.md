# 276 — Frankenstein Federation/Doorman: consult runbook + bug library BEFORE diagnosing routing

Source: 2026-07-14 — Frankenstein-LLM 524 timeout incident. All local models dead simultaneously, Federation/Doorman had 3 structural defects that prevented graceful fallback to cloud. Fixed + documented.

## The rule

**Before diagnosing ANY Frankenstein-LLM routing issue (524, timeout, empty response, wrong model), you MUST:**

1. **Consult the bug library FIRST** (`bug_library_check_before_fix()`) — rule 156, mandatory
2. **Read the Federation/Doorman runbook** at `/var/www/emtskills/docs/FRANKENSTEIN_FEDERATION_RUNBOOK.md` (on WOPR via `read_server_file`)
3. **Check Federation lane status** via the diagnostic commands in the runbook
4. **Check adapter canary health** at `/tmp/frankenstein_canary_health.json`
5. **Do NOT work on individual models** — fix the Federation/Doorman layer so it routes AROUND any dead model. Individual models are handled in separate threads.

## The 3-layer routing architecture

```
Cline/Executor → LiteLLM (config.yaml deployments) → router_hook.py (Federation lanes) → _router_core.py (Doorman) → adapter (:11510) → upstream models
```

- **Layer 1 (LiteLLM config)**: Multiple deployments per model_name = fallback chain. `frankenstein-llm`, `frankenstein-tools`, `emsu-executor-auto` MUST have DeepSeek cloud fallback.
- **Layer 2 (Federation)**: `router_hook.py` + `hooks/*.py`. Classifies model to a lane, lane hook probes health, spills to next lane on failure.
- **Layer 3 (Doorman)**: `_router_core.py` pre-filters dead tiers from host-probe cache. Adapter has its own canary health system.

## Key invariants (must always hold)

1. `frankenstein_glm52.py` fallback = `frankenstein-llm` (NOT `deepseek-v4-pro`) — local-first
2. LiteLLM config has DeepSeek cloud fallback for all frankenstein-* model_names
3. `hooks/tools.py` checks adapter upstream health BEFORE routing — fast-spills when all dead
4. Canary health check requires `decode_live=True` OR `tok_s>0` (not just `healthy` flag)
5. `frankenstein-llm` with tools → `tools` lane (NOT `glm52` or `frankenstein_120b`)

## Cross-references

- Rule 239 (Frankenstein Doctor) — Step 0b Federation consultation, this rule IS the Federation reference
- Rule 146 — Frankenstein routes every LLM, free-local-first
- Rule 140 — Verify routing from live headers
- Rule 156 — Bug library first (mandatory)
- Rule 142 — Graceful degradation (no dead-ends)
- Runbook: `/var/www/emtskills/docs/FRANKENSTEIN_FEDERATION_RUNBOOK.md`
- Bug library incidents: #1710 (524 all upstreams dead), #1711 (glm52 bypasses 120B), #1712 (no cloud fallback), #1713 (tools hook no health check)
- MCP tools: `frankenstein_tier_health`, `frankenstein_registry`, `frankenstein_host_probe`, `frankenstein_verify_routing`

## Source incident

2026-07-14 — Ruben reported "Frankenstein-LLM does not appear to be loading" with 524 errors and minutes-long delays. All local models (GLM, cesar, julia, cicero, artemis) were dead/saturated simultaneously. Three Federation/Doorman defects prevented graceful cloud fallback. Fixed: glm52 fallback, LiteLLM config cloud deployments, tools hook health check. Bug library #1710-1713.

## Last updated

2026-07-14 — initial. All fixes deployed, tested, documented.
# 141 — Before answering any Project Frankenstein or LLM-routing question, call the project-frankenstein MCP tools FIRST

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-07 — Window D built the project-frankenstein MCP so agents never re-derive (and get wrong) the LLM architecture.

## The bright-line rule

**Before stating ANY fact about Project Frankenstein architecture, LLM routing, tier health, pod status, or model serving, call the project-frankenstein MCP `now` + `failover` actions FIRST (see "ACTUAL MCP actions" below — the real actions are `inventory, now, act, failover, routing_map`). Never answer from file-reads, memory, subagent reconstructions, or config greps.**


This is the Frankenstein-specific hardening of rule 140 (verify LLM routing from live headers, not file-reads). Rule 140 applies to routing claims specifically. This rule applies to the ENTIRE Frankenstein architecture domain — how the head/body/stitches model works, which tiers are up, what the spill ladder is, what "warm" means, what the fast-train levers are, what the M1 70B cap is, what NOT to do.

## The ACTUAL project-frankenstein MCP actions (corrected 2026-06-08)

The MCP exposes exactly FIVE actions. Earlier versions of this rule named tools that DO NOT EXIST (`frankenstein_architecture`, `frankenstein_tier_health`, `frankenstein_verify_routing`, `frankenstein_pod_status`, `frankenstein_autoscaler_state`, `frankenstein_fast_train`) — calling those returns `unknown_action` and sends you flailing. The real actions are:

```
inventory    → fleet inventory (hosts, roles, ports, models served)
now          → live snapshot (what is serving right now, tier health)
failover     → the designed spill ladder + current failover state
routing_map  → per-surface routing + fallback chain + cost
act          → take a fleet action (WRITE)
```

Always start with `now` + `failover` for any "is X serving / what's down / why spilling to Claude" question.

## ALSO read PROJECT_FRANKENSTEIN.md §8 FIRST on any serving/failover task (hard first step)

**On ANY task that is "a model is down," "X is spilling to Claude," "fix serving," "failover," or "repoint routing" — your FIRST action is to read `docs/PROJECT_FRANKENSTEIN.md` §8.1 (the live spill ladder) + §8.4 (the frankenstein-llm fallback chain), OR call the MCP `failover` action — BEFORE any live probe, config edit, or tunnel-building.**

The spill ladder is ALREADY DESIGNED and auto-recovering (§8.1):
```
frankenstein-llm → DeepSeek-V4-Pro (primary) → vllm-llama3.3-70b-tools (RunPod frank-serve-pod, AUTO-MINTED/AUTO-WIRED) → ollama-llama3.3-70b (SMS Mac M1) → claude-sonnet (last resort)
```
"Machines flap, route by health." The autoscaler + watchdog auto-recover RunPod pods with NO human intervention. **The RunPod `frank-serve-pod` IS the designed L2 failover for an M1/70B outage.**

### BRIGHT LINE: do NOT hand-build serving infra that already auto-fails-over

When the M1 70B (SMS Mac, WOPR:11455) is unreachable, the designed response is: let the spill ladder route to the RunPod serve pod (or DeepSeek), OR kick the autoscaler/tunnel-watchdog. Do **NOT**:
- hand-build a bespoke reverse SSH tunnel M1→WOPR:11455
- manually `sed` LiteLLM `api_base` to a one-off endpoint
- reinvent the failover the doc already specifies

That is the rule-92 bandaid the ladder exists to prevent. Source incident 2026-06-08: a window did exactly this (hand-built the 11455 reverse tunnel + manual api_base repoint) instead of reading §8.1. Ruben: "why are you reinventing anything at all. Why did you not consult this documentation in the first place?"


## Forbidden moves (each produced wrong answers in prior sessions)

- Stating routing behavior from `router_hook.py` source or config.yaml without a live header probe — those are HYPOTHESES (rule 140)
- Trusting a subagent's reconstruction of the architecture when the subagent said "MCP tools not available, reconstructed from Desktop files"
- Asserting "the 70B is down" or "the SMS Mac is offline" from one failed tunnel probe when the model is resident and serving on the box (see PROJECT_FRANKENSTEIN.md CORRECTION 2026-06-05)
- Claiming "the spill ladder is X → Y → Z" from memory when the canonical doc has been updated
- Recommending a config flip without first checking the MCP `routing_map` + a live header probe for the current binding

## Self-check before any Frankenstein/LLM-routing answer

1. *Did I call the MCP `now` action?* If no → call it now before answering.
2. *Did I call the MCP `failover` action (for any serving/down/spill question)?* If no → call it now before answering.
3. *Is this a serving outage / "model is down" / "spilling to Claude" task?* → read `docs/PROJECT_FRANKENSTEIN.md` §8.1 + §8.4 FIRST, and let the DESIGNED spill ladder (RunPod frank-serve-pod / DeepSeek) handle it. Do NOT hand-build a tunnel or manually repoint api_base.
4. *Am I stating a routing fact?* → MCP `routing_map` + a live header probe (rule 140) are ground truth. Config files are not.
5. *Am I about to reinvent serving infra?* → STOP. The ladder in §8.1 already auto-fails-over. Use it.


## Cross-references

- Rule 140 — verify LLM routing from live headers, not file-reads (this rule's domain parent)
- Rule 00 — subagent dispatch is the default first move (subagents MAY NOT answer Frankenstein questions — they don't have MCP tools)
- Rule 92 — work at the core (the MCP is the core; file-reads are bandaids)
- Rule 135 — SLS naming (same lesson: a name is only true where a read-at-runtime surface proves it)
- fleet-state-mcp `fleet_routing_map` — per-surface routing facts (a good hypothesis, still confirm with `frankenstein_verify_routing` for load-bearing claims)
- `PROJECT_FRANKENSTEIN.md` — the full canonical doc on WOPR (the MCP's `frankenstein_architecture` tool returns the structured summary)
- `FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md` — fast-train runbook (the MCP's `frankenstein_fast_train` tool returns the levers + hardfloor)

## Last updated

2026-06-07 — initial. Source: Window D built the project-frankenstein MCP after (a) rule 140 was created because Cline answered Frankenstein routing questions wrong 3 times from file-reads, and (b) the prior fleet-state SSE transport caused YOLOs. The MCP uses STDIO (cannot hang, cannot YOLO) and serves the canonical architecture struct instantly. The rule exists so agents use it instead of re-deriving from files.
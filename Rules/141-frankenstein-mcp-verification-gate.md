# 141 — Before answering any Project Frankenstein or LLM-routing question, call the project-frankenstein MCP tools FIRST

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-07 — Window D built the project-frankenstein MCP so agents never re-derive (and get wrong) the LLM architecture.

## The bright-line rule

**Before stating ANY fact about Project Frankenstein architecture, LLM routing, tier health, pod status, or model serving, call `frankenstein_architecture` + `frankenstein_tier_health` from the project-frankenstein MCP FIRST. Never answer from file-reads, memory, subagent reconstructions, or config greps.**

This is the Frankenstein-specific hardening of rule 140 (verify LLM routing from live headers, not file-reads). Rule 140 applies to routing claims specifically. This rule applies to the ENTIRE Frankenstein architecture domain — how the head/body/stitches model works, which tiers are up, what the spill ladder is, what "warm" means, what the fast-train levers are, what the M1 70B cap is, what NOT to do.

## The two mandatory first calls

```
frankenstein_architecture    → canonical struct (head/body/stitches, spill ladder, warmth, caps, fast-train, prefix-caching, what-NOT-to-do)
frankenstein_tier_health     → live tier UP/DOWN + latency
```

These return instantly over STDIO (no network hang, no YOLO risk). Always call both. If tier_health returns `fleet_api_unreachable`, note it in your answer and fall back to `fleet-state-mcp` `fleet_now` for host-level health.

## Add for specific questions

| If the question involves | Also call |
|---|---|
| "Is the 70B warm?" or "Are RunPods serving?" | `frankenstein_pod_status` |
| "What model is serving surface X?" or "Is Cline on Claude?" | `frankenstein_verify_routing(model_id="...")` |
| "What did the autoscaler do?" or "Should we spin up pods?" | `frankenstein_autoscaler_state` |
| "How do I train a LoRA?" or "What are the fast-train levers?" | `frankenstein_fast_train` |

## Forbidden moves (each produced wrong answers in prior sessions)

- Stating routing behavior from `router_hook.py` source or config.yaml without a live header probe — those are HYPOTHESES (rule 140)
- Trusting a subagent's reconstruction of the architecture when the subagent said "MCP tools not available, reconstructed from Desktop files"
- Asserting "the 70B is down" or "the SMS Mac is offline" from one failed tunnel probe when the model is resident and serving on the box (see PROJECT_FRANKENSTEIN.md CORRECTION 2026-06-05)
- Claiming "the spill ladder is X → Y → Z" from memory when the canonical doc has been updated
- Recommending a config flip without first checking `frankenstein_verify_routing` for the current binding

## Self-check before any Frankenstein/LLM-routing answer

1. *Did I call `frankenstein_architecture`?* If no → call it now before answering.
2. *Did I call `frankenstein_tier_health`?* If no → call it now before answering.
3. *Am I stating a routing fact?* → `frankenstein_verify_routing` is the ground truth. Config files are not.
4. *Am I stating a pod/model-is-up/down fact?* → `frankenstein_pod_status` is the ground truth. One failed curl is not.

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
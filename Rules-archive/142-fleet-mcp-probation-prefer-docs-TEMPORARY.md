# 142 — [TEMPORARY / BAND-AID] Fleet MCP is on probation: prefer docs for routing/infra facts, reload on any fleet_* stall

> ⚠️ **THIS RULE IS A BAND-AID WITH A REMOVAL CONDITION. IT IS NOT PERMANENT.**
> Do NOT read this as "never use the Fleet MCP." The durable fix is the STDIO rewrite
> (v0.5.0) proving reliable over time. Delete this rule once the removal condition below is met.

Temporary rule. Workspace-scoped. Source: 2026-06-07 — Fleet MCP (`fleet-state`) was rewritten from HTTP/SSE to STDIO (v0.5.0) after the HTTP transport hung every call and caused YOLOs. Re-verified passing 2026-06-07 19:27 PT (smoke test 4002ms, no hang). Ruben's explicit directive: ship TEMPORARY doc-first guidance, NOT a permanent "never use Fleet MCP" rule — "why have a Fleet MCP if it can never be used?"

## The temporary guidance (while on probation)

While the Fleet MCP is on probation, when you need a routing/infra fact:

1. **Prefer the docs + the sibling MCP first** (these are not on probation):
   - `project-frankenstein` MCP — `frankenstein_architecture`, `frankenstein_tier_health`, `frankenstein_pod_status`, `frankenstein_verify_routing` (STDIO, separate server, reliable; see rule 141)
   - `PROJECT_FRANKENSTEIN.md` (canonical, WOPR `/var/www/emtskills/docs/`)
   - `/Users/rubenmajor/Desktop/FLEET_MCP_TRACKER.md` (the live tracker)
2. **You MAY call a `fleet_*` tool** (`fleet_inventory`, `fleet_now`, `failover_status`, `fleet_routing_map`, `fleet_act`) — it is not banned. The STDIO rewrite is expected to return in ~4s.
3. **If a `fleet_*` call does NOT return within a few seconds: do NOT retry it.** Reload the VS Code window / restart Cline MCP servers, then continue. A stall almost certainly means a stale Cline session opened before the 2026-06-07 16:15 PT rewrite is holding the dead HTTP connection — retrying is the YOLO-triple entry point (rule 99). Reloading picks up the stdio entry.

## Why this exists (and why it is temporary)

The HTTP/SSE transport opened an SSE stream that never terminated promptly, so every call stalled to the 60s client timeout → 30s tool wall → retry → prose → YOLO on the 3rd strike. The TRANSPORT was the bug, not the data. The core fix already shipped: STDIO serving a synchronous snapshot read that cannot hang (per rule 92 — fix the core, not the symptom). This rule is only the interim guard while we accrue confidence that the rewrite holds.

## Removal condition (delete this rule when ALL are true)

1. **N clean days:** the Fleet MCP runs **5 consecutive days (through 2026-06-12)** with zero new stall/YOLO reports attributable to a fleet_* call from a freshly-reloaded window.
2. The `FLEET_MCP_TRACKER.md` "Issue log" shows no reopened ISSUE #1 (HTTP hang) and ISSUE #2 (stale-session) has not recurred.
3. Once met: delete this file (`142-fleet-mcp-probation-prefer-docs-TEMPORARY.md`), note the removal in FLEET_MCP_TRACKER.md, and reindex the clinerules MCP. The Fleet MCP returns to first-class status — no doc-first preference, no special reload caveat beyond the normal rule-99 timeout handling.

If the rewrite instead proves unreliable, do NOT escalate this into a permanent ban — fix the core again per rule 92 and update this rule's source incident.

## Self-check

Before relying on a routing/infra fact: did I reach for a doc / project-frankenstein MCP first? If I called a fleet_* tool and it stalled, did I RELOAD instead of retrying? If yes to both, the band-aid is doing its job.

## Cross-references

- Rule 92 — work at the core (the STDIO rewrite is the core fix; this rule is the temporary symptom guard)
- Rule 141 — project-frankenstein MCP verification gate (the reliable sibling to prefer)
- Rule 99 — YOLO prevention (retrying a stalled tool is the canonical trip; reload instead)
- Rule 29 — act on confidence (a stalled tool is not a reason to defer; reload and proceed)
- `FLEET_MCP_TRACKER.md` — the live issue tracker + 30-second re-verify runbook

## Last updated

2026-06-07 — initial. Source: Fleet MCP STDIO v0.5.0 rewrite re-verified passing (smoke test 4002ms, no hang); Ruben directed a TEMPORARY removable doc-first guard, not a permanent ban. Removal condition: 5 clean days through 2026-06-12.

# 122 — Pickup prompts must reference MCP tools by SERVER + bare name, never the hashed prefix

Permanent rule. Workspace-scoped. Source: 2026-05-30 23:08 PT — early-YOLO scan.

## Source incident

The YOLO learner DB (`~/Documents/Cline/yolo_learner/yolo_trips.sqlite`) was found at 0 bytes (wiped). After repopulating via `scan.py`, the only trips present were 4 fresh **early** YOLOs (all `turns_since_user=0` — the model tripped before completing a single tool call):

| task_id | user task | mistakes | triple |
|---|---|---|---|
| 1780207317838 | "Artemis is up now..." | 99 | no-tool-use ×3 |
| 1780205121936 | "Pick up: get RUBEN out of shadow... **First tool call: `cwSNwH0mcp0check_ruben_state`**" | 99 | no-tool-use ×3 |
| 1780204404174 | "i do not see the RUBEN orchestrator here. Can you open it?" | 3 | no-tool-use ×2 |
| 1780202133692 | "It definitely appears that you don't have access to all MCPs" | 3 | no-tool-use ×2 |

All four share one root cause: **the MCP tools the task instructed the model to call did not exist in the session's tool namespace.** Three were explicitly about MCP access ("don't have access to all MCPs", "don't see RUBEN orchestrator"). One (1780205121936) carried a pickup prompt that **hardcoded a session-specific hashed tool prefix** — `cwSNwH0mcp0check_ruben_state` and `cRZROs0mcp0ssh_command`. When the new window opened, those prefixes had rotated (this session's equivalents are `c3ObCC0mcp0check_ruben_state` and `cxzUHL0mcp0ssh_command`), so the named tool 404'd, the model narrated around the missing tool, and burned to YOLO — in two cases through all **99** consecutive-mistake slots.

## The bright-line rule

**A pickup prompt (rule 91) must NEVER name an MCP tool by its hashed per-session prefix.** The prefix (`cwSNwH0mcp0`, `c3ObCC0mcp0`, `cxzUHL0mcp0`, ...) is assigned per connection and rotates between sessions. A hardcoded prefix in a pickup prompt is a guaranteed dead reference the moment the next window opens.

Reference tools by **server name + bare tool name** instead:

- ❌ `First tool call: cwSNwH0mcp0check_ruben_state`
- ✅ `First tool call: ruben-control → check_ruben_state`
- ❌ `Run cRZROs0mcp0ssh_command "..."`
- ✅ `Run emsu-operations → ssh_command with command "..."`

The new window resolves the bare name against whatever prefix it was assigned. The hash never appears in durable artifacts.

## Companion guard: if a named tool isn't in the namespace, do not narrate

If a pickup prompt (or any instruction) names a tool you cannot find in the current session:

1. Do NOT emit prose explaining that the tool is missing (that's the no-tool-use trip — see rule 41 / rule 99).
2. Pick the nearest equivalent tool that IS available and call it, OR
3. Call `attempt_completion` with status "blocked — MCP server X not connected this session; reconnect and retry." That surfaces the blocker as a clean completion instead of churning to YOLO.

This is the rule-41 "post-error pivot" applied to the missing-tool case: a missing tool is an error condition, and the next turn must be a tool call (different tool / attempt_completion), never narration.

## Operational note: the MCP-down session is the real trigger

Three of the four trips were literally "I don't have access to the MCPs." When the MCP servers are not connected, every tool-shaped instruction becomes prose-bait. The durable fixes are upstream:

- Verify MCP connectivity at session start when the task depends on it (a single live call like `ruben-control → check_ruben_state` or `emsu-operations → server_status` proves the namespace is up).
- If the namespace is empty/partial, `attempt_completion` immediately with "MCP servers not connected, reconnect and re-run" — do not attempt the MCP-dependent work and narrate failures.

As of this scan (2026-05-30 23:12 PT) MCP access is restored and verified live: `emsu-operations → server_status` and `ruben-control → check_ruben_state` (RUBEN mode=shadow, paused=false) both returned cleanly.

## Cross-references

- Rule 91 — every-completion-needs-pickup-prompt (this rule constrains the pickup-prompt CONTENT)
- Rule 41 — post-deploy/post-error: call the tool, do not narrate
- Rule 99 — yolo-prevention-learned (no-tool-use is the #1 trip class)
- Rule 92 — work at the core, not bandaids (the core fix is prefix-free pickup prompts + a connectivity preflight, not "try harder not to narrate")

## Last updated

2026-05-30 — initial. Source: 4 early-YOLO trips, all turns_since_user=0, all MCP-access-related; one carried a hardcoded `cwSNwH0mcp0` prefix in its pickup prompt that 404'd in the next window.

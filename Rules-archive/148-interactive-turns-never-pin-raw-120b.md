# 148 — Interactive Cline turns route THROUGH the frankenstein-tools adapter (:11510), NEVER pin to a raw 120B. And anticipate Cline: warm the next box.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-15 — Ruben, repeatedly ("I have said this numerous times and Cline keeps trying to make the 120B Artemis do everything... like a broken record"). A live Cline frankenstein-llm window wedged ~5 minutes on ONE turn with no spill. Root cause verified live (rule 140): the LiteLLM router sent the interactive turn DIRECTLY to the raw `artemis-gpt-oss-120b` box instead of through the `frankenstein-tools` adapter (:11510), bypassing every protection the adapter already has. This rule exists so it is NEVER re-derived wrong again.

## Scope gate (READ FIRST — applies ONLY when frankenstein-llm is the chosen entrypoint)

**This rule applies ONLY to interactive tool-bearing turns whose requested model is `frankenstein-llm` (the Cline interactive entrypoint).** It does NOT govern any other surface: NOT executor/orchestrator batch chains, NOT the anthropic passthrough, NOT direct-model calls where a caller explicitly requested `cato-120b`/`cesar-120b`/`artemis-gpt-oss-120b` by name, NOT `emsu-executor-auto` or other entrypoints. Those legitimately pin to specific boxes and must not be forced through the adapter by this rule. If `req != frankenstein-llm`, this rule is silent — do not apply it, to avoid conflicts elsewhere.

## The bright-line rule (when req == frankenstein-llm)

**A `frankenstein-llm` interactive tool-bearing turn MUST be served through the `frankenstein-tools` adapter (:11510), which load-balances across ALL 120Bs (cesar/cato/artemis) and enforces the interactive SLO. It must NEVER be pinned directly to a single raw gpt-oss 120B box (`artemis-gpt-oss-120b`, `cesar-120b`, `cato-120b` as direct picks) on the frankenstein-llm path.**


Why: the raw-box path has only LiteLLM's long `request_timeout` — none of the adapter's protections. The adapter (:11510) is where these live and they ONLY apply on its path:
- `FRANK_SLO_TTFB_INTERACTIVE=18` — abandon + spill if no first token in 18s
- `FRANK_STREAM_IDLE_ABORT=8` — mid-stream idle abort
- total-budget 45s, 30s per-box cooldown after a TTFB abort
- saturation fast-fail (`FRANK_TOOLS_SAT_INTERACTIVE=1`) — spill the instant a box has no free slot
- 3-box balancing across `FRANK_TOOLS_UPSTREAMS` (cesar/cato/artemis)

When a turn pins to raw artemis, ALL of that is bypassed → it wedges for minutes while two healthy 120Bs sit idle. That is the recurring bug.

## "Artemis is not the router. Artemis is ONE rung."

Per rule 146: `frankenstein-llm` routes the WHOLE fleet; artemis-gpt-oss-120b is ONE body member, the interactive-PRIMARY rung — NOT "the box that does everything." Any design, config, or diagnosis that funnels all interactive traffic onto artemis is wrong by construction. The adapter exists precisely so no single 120B is the whole interactive capacity. If you catch yourself (or a config) routing interactive turns to a single raw 120B, STOP — that is this rule's violation.

## Anticipatory readiness (Ruben's "get ready for me for the next turn")

Cline is PRIORITY (rule 146), and priority means ANTICIPATE, not just react. When interactive Cline usage is detected, the fleet must proactively prepare the next turn's capacity so iterations stay fast and ORDERLY:

1. **Keep-warm the interactive pool:** the 120Bs behind the adapter must stay hot (prefix cache warm, model resident) so turn-1 and every next turn first-token is <30s — ideally faster. A keep-warm gap that forces a cold first-token is a violation.
2. **Reserve ahead:** when a Cline window is active, reserve interactive headroom on the adapter pool for its NEXT turn (batch/executor/orchestrator queue behind it per rule 146 — they have buffers, Cline does not). Don't let batch fill the box such that Cline's next turn has no slot.
3. **Orderly, not greedy:** "Cline gets priority" does NOT mean Cline monopolizes one box. It means the adapter balances Cline across the warm pool AND keeps a lane open for Cline's next turn. Batch waits; Cline flows.

## The interactive SLO (the target to hold)

- **Initial call (new window / first turn): < 30s** to first token. Longer than 30s on an initial call is unacceptable.
- **Between iterations: < 30-60s.** A window must be able to "go go go" — keep working turn after turn without multi-minute stalls.
- If a turn exceeds the TTFB budget on the adapter path, it SPILLS (cesar→cato→artemis→70B→…) — it must never sit on one box past the budget.

## Self-check (before any routing/config statement or change touching interactive turns)

1. *Am I about to route/pin an interactive Cline turn to a raw 120B box (artemis/cesar/cato direct)?* → STOP. It goes through the `frankenstein-tools` adapter (:11510).
2. *Am I treating artemis as "the box that handles Cline"?* → Wrong (rule 146). Artemis is one rung; the adapter balances the pool.
3. *Does my change keep the interactive pool WARM and reserve headroom for Cline's next turn?* → If not, it fails the anticipatory-readiness requirement.
4. *Will an interactive turn that stalls SPILL within the TTFB budget?* → It must, via the adapter path. Verify with a live header probe (rule 140): a Cline tool turn returns `x-litellm-model-api-base=127.0.0.1:11510`, NOT `10.100.0.5:8000` (raw artemis).

## Cross-references

- Rule 146 — frankenstein-llm routes the full fleet; Cline is PRIORITY; artemis is one rung, not the router
- Rule 142 — no dead-end entrypoint; tool turns pinned to a verified tool-parser path
- Rule 140 — verify routing from live headers (the :11510-vs-:8000 header is the proof)
- Rule 141 — call the project-frankenstein MCP first for routing truth
- Rule 118 — interactive-path router_hook.py changes deploy via the safe wrapper, in a quiet window
- idea #12643 (P0, approved) — the deploy that makes interactive turns route through the adapter + enforce the SLO
- Troubleshooting doc: lines 175-177 (slow spill / TTFB), 202-205 (canonical 120B baseline / pool balancing), 157-159 (stall on first iteration / keep-warm)

## Source incident

2026-06-15 — conv_45a7578 wedged ~5 min on raw artemis-gpt-oss-120b with no spill; 8-11 interactive convs all pinned to raw artemis while cesar/cato sat idle (only null-conv keepwarm pings). All 3 120Bs verified HOT (0.2-0.37s first-response), TTFB time-box verified configured on the adapter — proving the turn never took the adapter path. Ruben: "Cline keeps trying to make the 120B Artemis do everything. I keep reminding, like a broken record. This needs to be hardened to not keep happening."

## Last updated

2026-06-15 — initial.

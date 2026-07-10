# 256 — Doorman output-quality gate: the Doorman must validate OUTPUT, not just HEALTH

Source: 2026-07-06 Ruben directive — "Curious what keep breaking the routing/preventing doorman from stopping LLMs from breaking into the show trying to be the star actors? Should this not be some kind of cline rule or something."

## The architectural gap

The Frankenstein Doorman has two layers:
1. **HEALTH gate** (proactive): probes `/v1/models`, `/api/tags`, `num_requests_waiting`. Asks "is the box alive and not saturated?"
2. **OUTPUT quality gate** (reactive): the garbage-200 spill gate in `async_post_call_success_hook`. Asks "did the model emit valid tool calls?"

**The gap:** layer 2 only ran for NON-STREAMING traffic (executor/cron). Cline's traffic is streaming chat-completions, and `async_post_call_success_hook` does NOT fire for streaming in this LiteLLM build (the code itself documents this). So the Doorman was health-gating but NOT output-quality-gating for the highest-volume traffic type.

**Result:** a box could be "healthy" (responds to probes) but emit garbage tool calls (XML-in-content, missing required params, empty content with finish=length). The Doorman never caught it because the output gate was on the wrong hook. Cline saw "empty or unparsable response" → retried 3x → YOLO death. The LLM "broke into the show trying to be the star actor" because there was no bouncer checking whether its performance was valid before it reached the audience (Cline).

## The bright-line rule

**The Doorman must validate OUTPUT QUALITY on EVERY response path, including streaming.** A box that returns HTTP 200 with garbage content is NOT healthy, regardless of what `/v1/models` says. The output-quality gate is NOT optional and NOT path-specific.

**Implementation requirements (all must be true):**
1. **Streaming path:** `async_stream_hook` must buffer tool-call turns, validate at stream-end, and repair/spill on garbage.
2. **Non-streaming path:** `async_post_call_success_hook` must run the garbage-200 gate (existing).
3. **Detection patterns:** empty content + no tool_calls, missing required params, malformed JSON arguments, XML-in-content (`<tool_call name=X>...`), DSML markers, finish_reason=length with empty content.
4. **Doorman coordination:** on garbage detection, call `_mark_box_stalled()` so the health gate skips that box for `STALL_COOLDOWN_SEC`. The reactive gate feeds the proactive gate.
5. **Repair > spill:** when possible, repair the output (inject `requires_approval: false`, translate XML to tool_calls JSON) rather than spilling to a sibling. Spill is the fallback when repair is impossible.

## The prevention > repair principle

**Schema strengthening in `async_pre_call_hook` is the first line of defense.** Mark `requires_approval` as REQUIRED in the tool schema so the model emits it. Prevention > repair > spill. The repair gate is the safety net; the schema is the seatbelt.

## Why this is a rule, not just a code patch

Code patches rot. A Cline rule ensures:
1. Future agents touching `router_hook.py` know the streaming output gate is mandatory, not optional.
2. If the gate breaks (e.g., someone moves it back to `async_post_call_success_hook` only), the rule documents why that's wrong.
3. The Doorman's job is defined as "health + output quality", not just "health". This prevents the single-layer assumption.

## Self-check before modifying router_hook.py

Before ANY change to `async_stream_hook` or the garbage-200 gate:
1. *Does the change affect the streaming path?* If yes, verify `_stream_validate_tool_call` still runs at stream-end for tool-bearing turns.
2. *Does the change move validation to a hook that doesn't fire for streaming?* If yes, STOP. That's the bug.
3. *Does the change remove `_mark_box_stalled` on garbage?* If yes, STOP. The Doorman loses output-quality coordination.

## Bug library entry

**bug_library: gpt_oss_120b_xml_toolcall_in_content_2026_07_06**
- **Pattern:** gpt-oss-120b emits `<tool_call name="execute_command"><command>...</command></tool_call_tool>` as TEXT in the content field instead of using OpenAI `tool_calls` JSON structure.
- **Impact:** Cline sees prose, not a tool call → "Invalid API Response: empty or unparsable" → retry 3x → YOLO death.
- **Root cause:** The model's training data includes XML-style tool calling, but the serving path expects OpenAI JSON. The garbage-200 gate was on `async_post_call_success_hook` (non-streaming only), so streaming traffic was never caught.
- **Fix:** `_stream_validate_tool_call` in `async_stream_hook` detects `<tool_call` markup in content, parses it to OpenAI tool_calls JSON, emits synthetic tool_calls deltas, and clears the content. Pairs with schema strengthening (mark `requires_approval` as required).
- **Cross-ref:** idea #16584, rule 92 (fix at the core), rule 142 (no dead-end).

## Cross-references

- Rule 92 — fix at the core (the router, not the client)
- Rule 142 — no dead-end (garbage must spill to sibling, not loop)
- Rule 146 — Frankenstein-LLM routing (free-local-first, paid last resort)
- Rule 158 — discover by health, not hardcode
- Idea #16584 — stream-level tool-call repair
- Idea #16351 — original REQUIRED-PARAM REPAIR (was in wrong hook)

## Source incidents

- **2026-07-06 09:36 PT:** Ruben reported "Cline tried to use execute_command without value for required parameter 'requires_approval'. Retrying..." — the REQUIRED-PARAM REPAIR (#16351) lived in `async_post_call_success_hook` which doesn't fire for streaming. 0 fires ever. Fixed by moving to `async_stream_hook`.
- **2026-07-06 10:30 PT:** Ruben reported "Invalid API Response: empty or unparsable response" (multiple) + YOLO death. Root cause: model emits `<tool_call name="execute_command">` as XML in content field, not as `tool_calls` JSON. Cline sees prose → retry → YOLO. Fixed by adding XML-to-tool_calls translation in `_stream_validate_tool_call`.
- **2026-07-06 10:45 PT:** Ruben asked "what keeps breaking the routing/preventing doorman from stopping LLMs from breaking into the show?" — the Doorman only checked health, not output quality, for streaming traffic. This rule created.

## Last updated

2026-07-06 — initial. The Doorman's job is health + output quality. Both layers must run on ALL paths (streaming + non-streaming). Prevention (schema) > repair (stream validate) > spill (sibling fallback).
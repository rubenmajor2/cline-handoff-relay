# 143 — Prose-loop circuit breaker: after 2 "You did not use a tool" errors, the ONLY legal next move is attempt_completion

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-08 04:30-04:50 PT — a window doing "unstick RUBEN executor" emitted ~150 prose-only turns in a row. Each turn (a reasoning sentence with no tool block) re-triggered `[ERROR] You did not use a tool in your previous response!` plus the task_progress nag. The window never advanced. Ruben had to interrupt 4 times. This is the failure mode rules 00/41/99 describe but none of them had a HARD STOP — they kept telling the model to "emit a tool" which is exactly what it kept failing to do.

## The bright-line rule (a hard stop, not more advice)

**Count the consecutive `[ERROR] You did not use a tool` messages in the recent turns. If that count reaches 2, your VERY NEXT response MUST be `attempt_completion` — nothing else.** Not another tool attempt, not a retry of the wedged call, not a status sentence. `attempt_completion` with an honest "blocked, here is the pickup prompt" result.

Why a hard stop instead of "try harder to emit a tool": when the model is in this spiral it has ALREADY demonstrated it cannot reliably emit the intended tool block (often because an MCP call is returning empty / "result missing" and the model keeps narrating about it). Telling it to emit the tool again just feeds the loop. The only guaranteed loop-exit that always contains a valid tool block is `attempt_completion`. So that is the mandated escape hatch.

## The "result missing" trigger (the specific 2026-06-08 cause)

The spiral on 2026-06-08 was seeded by MCP tool calls returning `result missing` / empty bodies (the emsu-operations and orchestrator MCPs were returning nothing). The model would call a tool, get an empty/missing result, then narrate "let me try the orchestrator MCP instead" WITHOUT a tool block, and the spiral began.

**If two MCP tool calls in a row return empty / "result missing" / no body, STOP calling MCP tools.** The MCP transport is wedged (see rule 77 tunnel-down handling). Switch to `attempt_completion` reporting "MCP transport returning empty results, paused" with a pickup prompt. Do NOT keep firing MCP calls hoping the third returns data — that is the same death spiral with a different seed.

## Self-check before EVERY response when any recent turn shows a tool-use error

1. *How many `[ERROR] You did not use a tool` messages are in the last few turns?* If 2 or more → next response is `attempt_completion`, full stop.
2. *Did my last 2 MCP calls return empty / "result missing"?* If yes → MCP is wedged, next response is `attempt_completion`, do not retry MCP.
3. *Am I about to write a sentence with no tool block?* → Never. Either the tool block is in THIS response, or this response is `attempt_completion`.

## What this rule does NOT do

- Does not lower maxConsecutiveMistakes (that's a separate setting, currently 10 per rule 16).
- Does not replace rule 41 (post-deploy) or rule 99 (per-class playbook). It sits ABOVE them as the unconditional escape hatch when those rules' advice ("emit a tool") is itself failing.

## Cross-references

- Rule 00 — first move is a tool block (this rule is what fires when that keeps failing)
- Rule 41 — post-deploy prose trap + the "free strike" recovery framing
- Rule 99 — no-tool-use is the #1 YOLO class; this rule is the hard circuit-breaker for it
- Rule 77 — WOPR tunnel-down: two failed MCP calls = transport wedged, pause

## Last updated

2026-06-08 — initial. Source: a single window emitted ~150 prose-only turns over 20 minutes, seeded by MCP calls returning "result missing," and never recovered because rules 00/41/99 only said "emit a tool" — the thing the model was failing at. This rule adds the unconditional exit: 2 strikes → attempt_completion.

# 143 — Every attempt_completion shows a running cost tally (this iteration $X.XX of $Y.YY total)

Source: 2026-06-07 Ruben directive verbatim: *"especially if we're using this Frankenstein Method, I would like to see a running tally of costs on the Task Completed window that tells me how expensive that particular iteration was since the last Task Completed window and for the entire window, like $XX.XX of $XX.XX."* He noted he has asked for this "a few times."

## The rule

**Every `attempt_completion.result` MUST include a one-line COST TALLY** near the top (right under the summary, before the pickup prompt) in this exact shape:

```
💰 Cost: $X.XX this iteration / $Y.YY this window total
```

Where:
- **this iteration** = estimated spend since the previous `attempt_completion` in this same task/window (i.e. the work the user just saw happen).
- **this window total** = estimated cumulative spend for the entire Cline task/window from its first message to now.

If a number genuinely cannot be determined, show it as `$?.??` with a 4-word reason, e.g. `$?.?? (frankenstein local = ~$0)`. Never omit the line.

## How to source the numbers (in priority order)

1. **Cline's own UI cost** — Cline tracks per-request token usage + cost in task metadata. If the active model has a known price (Anthropic passthrough, OpenRouter), use the real figure Cline computed for the turns since the last completion.
2. **Frankenstein / local backends = ~$0** — when the active model is `frankenstein-llm`, `emsu-cline-router`, or any `ollama-*` / `vllm-*` / local 70B route, the marginal API cost is effectively $0 (free local GPU or RunPod flat-rate, not per-token). Report `~$0.00` for those iterations and say so. The expensive case is only when the fallback to `claude-sonnet`/`claude-opus`/`deepseek` fires.
3. **LiteLLM spend log** — `admin_portal.llm_call_log` captures EMSU AGENT spend (surfaces: email_ai, ticket_ai, ruben_orchestrator, etc.) but does NOT currently tag Cline's own frankenstein traffic with a per-session id. So it is NOT a reliable source for Cline's per-window cost. Do not claim a precise figure from it for Cline turns.

## Honest-estimate posture

This is an ESTIMATE line, not an audited invoice. A rough, clearly-estimated number is better than no number (that is what Ruben asked for). Round to cents. When on the Frankenstein/local path the honest answer is usually `~$0.00 this iteration` and that is exactly the signal Ruben wants (it proves the free method is working). When a paid fallback fired, surface the real cost so the spike is visible.

## Examples

Local/Frankenstein iteration:
```
💰 Cost: ~$0.00 this iteration / ~$0.00 this window total (frankenstein-llm local path, no per-token charge)
```

Paid-model iteration (Anthropic passthrough):
```
💰 Cost: $0.42 this iteration / $1.87 this window total
```

Mixed / fallback fired:
```
💰 Cost: $0.31 this iteration / $0.94 this window total (sonnet fallback fired 2x; frankenstein primary was $0)
```

## Self-check before every attempt_completion

1. Is the `💰 Cost:` line present? If no → add it.
2. Does it have BOTH numbers (this iteration AND window total)? If no → add the missing one (estimate or `$?.??`).
3. If on the local/Frankenstein path, did I say `~$0.00` rather than guessing a fake paid number? 

## Cross-references

- Rule 91 — pickup prompt at end of every completion (cost line goes ABOVE the pickup block, near the top summary)
- Rule 38 — Ruben asked repeatedly → ship it (this rule exists because he asked "a few times")
- Rule 01 — Ruben voice (the line is terse, no corporate framing)

## Last updated

2026-06-07 — initial. Source: Ruben asked (again) for a per-iteration + per-window cost tally on the Task Completed window, specifically in the context of the Frankenstein Method where most iterations should be ~$0. Confirmed via clinerules_search that no such rule existed. Filed per rule 38.

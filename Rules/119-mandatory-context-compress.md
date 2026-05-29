# 119 — Mandatory context compression (token-count based, not percentage)

Source: 2026-05-28 Ruben directive — "LiteLLM router shows 100k+ on first call even though capacity is 1M, so percentage thresholds were meaningless."

## The rule (two thresholds, that's it)

Check the raw token count in environment_details (`Context Window Usage: X / Y tokens used`). Use **X** (the absolute token count), not the percentage.

| Token count | Required action |
|---|---|
| < 300K | Normal operation. No compress action needed. |
| 300K – 499K | MUST call `should_compress_now` at least once before the next major tool call. If it returns `should_compress: true` → compress now. |
| 500K+ | MUST call `cline_compress_session` immediately, then `attempt_completion`. No deferral. |

**"Major tool call"** = any call that is NOT `should_compress_now`, `cline_compress_session`, or `attempt_completion`.

## Why absolute tokens, not percentages

The LiteLLM router reports a context ceiling (e.g. 200K) that does not reflect the model's actual capacity (1M tokens). At startup, the displayed usage is already 100K+ due to system prompt inflation — meaning percentage thresholds like "≥70% → stop" fire immediately and incorrectly on nearly every task. Token-count thresholds are stable regardless of what ceiling the router reports.

## Tool call arguments

### `should_compress_now`

```json
{
  "task_id": "<Cline task ID from environment_details or context>",
  "last_compress_size": 0,
  "growth_threshold": 100000
}
```

### `cline_compress_session`

```json
{
  "task": "<one-line task statement>",
  "pickup_prompt": "<rule-91 PICKUP PROMPT block verbatim, ≤5KB>",
  "tool_rounds": ["<tool>(args) → outcome", "..."],
  "last_turns": ["<last 3 message bodies, oldest first>"]
}
```

After `cline_compress_session` returns the `═══ SESSION MEMORY ═══` blob, call `attempt_completion` with that blob as the result.

## Do not change behavior due to context size

**Do NOT change your behavior — rushing, skipping steps, doing shallower work, or cutting corners — because the displayed context percentage looks high.** The percentage is unreliable (LiteLLM router reports a false ceiling). The only valid responses to context pressure are the two thresholds above: check at 300K, compress at 500K. Between 0 and 500K, work at full quality. "Context looks high, I'll be brief" is not a valid response. See rule 120 for the companion rule on this.

## Anti-patterns that violate this rule

- Stopping work / calling `attempt_completion` solely because the displayed percentage looks high
- Using percentage thresholds from environment_details instead of the raw token count X
- "Just one more tool call then I'll compress" at 500K+ — no. Compress now.
- Calling `should_compress_now` but ignoring a `should_compress: true` result at 300K-499K
- **Rushing, skimping, or doing less thorough work because context percentage appears high** — this is a rule violation regardless of what the percentage shows

## Self-check before any tool call when token count ≥ 300K

1. Count ≥ 500K? → call `cline_compress_session` now, then `attempt_completion`. Nothing else.
2. Count 300K–499K? → have I called `should_compress_now` this task? If no → that is the next call.
3. Count < 300K? → proceed normally.

## Cross-references

- Rule 91 — pickup prompt shape required at every `attempt_completion`
- Rule 00 — subagent dispatch is still the default first move
- Rule 120 — context size is never an excuse to shortcut work

## Last updated

2026-05-28 — added "do not change behavior due to context size" section. Source: Ruben directive — "add to rule 119: do not change your behavior such as trying to rush because of context size."

2026-05-28 — rewrite. Replaced percentage-based thresholds (broken due to LiteLLM router ceiling inflation) with absolute token-count thresholds: 300K–499K → `should_compress_now`, 500K+ → `cline_compress_session`. Removed the "≥70% → attempt_completion immediately" gate. Source: Ruben directive — LiteLLM shows 100K+ on first call even though actual model capacity is 1M, making percentage-based rules fire incorrectly on every task.

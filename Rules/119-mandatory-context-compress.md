# 119 — Mandatory context compression at 30%+ (observable-trigger, hardfloor)

Source: 2026-05-28 Ruben directive: "the rule has NEVER been obeyed"

## Why this rule exists

Rule 91 said "agent should poll `should_compress_now` every ~150K tokens." The word "should" made it advisory. Agents never called it. High context became a silent excuse to shortcut: skip subagent dispatch, truncate investigation, cut tool calls. This rule replaces the aspiration with a binary, observable enforcement gate identical in strength to rule 00's tripwire.

## The observable trigger (no tool call required)

**On EVERY assistant turn, environment_details shows:**

```
Context Window Usage: X / 1,000K tokens used (Y%)
```

This number is visible before any tool call fires. Read it. Act on it.

## Mandatory thresholds — no judgment, no exceptions

| Context % | Required action |
|---|---|
| < 30% | Normal operation. No compress action needed. |
| 30–49% | MUST call `should_compress_now` at least once before the next major tool call. If it returns `should_compress: true` → treat as 50–69% and compress now. |
| 50–69% | MUST call `cline_compress_session` immediately, then `attempt_completion`. No deferral. Not after "one more thing." Now. |
| ≥ 70% | MUST call `attempt_completion` immediately. Cline's built-in auto-condense fires at 75% — do not race it. |

**"Major tool call"** = any call that is NOT `should_compress_now`, `cline_compress_session`, or `attempt_completion`.

## The binary test (run before EVERY tool call when context ≥ 30%)

Before composing any tool call, check environment_details:

1. Context ≥ 70%? → call `attempt_completion` now. Nothing else.
2. Context 50–69%? → call `cline_compress_session` now, then `attempt_completion`. Nothing else.
3. Context 30–49%? → have I called `should_compress_now` this task? If no → that is the next call.
4. Context < 30%? → proceed normally.

The test takes 3 seconds. Skipping it is a hardfloor violation.

## Tool call arguments

### `should_compress_now`

```json
{
  "task_id": "<Cline task ID from environment_details or context>",
  "last_compress_size": 0,
  "growth_threshold": 100000
}
```

If task_id is unknown, omit it. The tool falls back to the global `/tmp/cline_budget_status.json`.

### `cline_compress_session`

```json
{
  "task": "<one-line task statement>",
  "pickup_prompt": "<rule-91 PICKUP PROMPT block verbatim, ≤5KB>",
  "tool_rounds": ["<tool>(args) → outcome", "..."],
  "last_turns": ["<last 3 message bodies, oldest first>"]
}
```

After `cline_compress_session` returns the `═══ SESSION MEMORY ═══` blob, call `attempt_completion` with that blob as the result. The next Cline window pastes it and picks up from there.

## Why 30%/50%/70% specifically

- **30% = 300K tokens**: early enough to compress cleanly, before context balloons
- **50% = 500K tokens**: aligns with rule 91's YELLOW tier — the budget watchdog already flags this
- **70% = 700K tokens**: 5% margin before Cline's built-in auto-condense fires at 75%

The built-in `useAutoCondense=true` (Cline setting, already on) condenses at 75% using `claude-haiku-4-5`. Rule 119 fires at 50% using the structured MCP compressor — better quality, earlier, more context preserved.

## Anti-patterns that violate this rule

- "Just one more tool call then I'll compress" — no. 50% = compress now.
- "The context isn't that high, I can finish" — read the number. Binary threshold.
- "I'll note in the pickup prompt that context was high" — not a substitute. Compress.
- "should_compress_now returned false, so I'm fine" — only valid if context < 50%. At 50%+, compress regardless.
- Calling `should_compress_now` but ignoring a `should_compress: true` result.

## What this rule does NOT replace

- **Rule 91** — pickup prompt shape is still required at every `attempt_completion`
- **Rule 00** — subagent dispatch is still the default first move
- **Cline's built-in auto-condense** — this is the 75% backstop if rule 119 is violated. It is not the target; rule 119 fires first.

## Self-check before any tool call ≥ 30% context

> "Is my next tool call `should_compress_now`, `cline_compress_session`, or `attempt_completion`?"
> If no AND context ≥ 50% → that tool call is illegal under this rule. Rewrite it.

## Source incident

2026-05-28 — Ruben: *"The entire reason behind compressing/condensing automatically context was so you couldn't complain about it and take shortcuts because of it. Why are you not compressing/condensing automatically? How can this be resolved properly? I know we have a rule for it that has NEVER been obeyed."*

Root cause: Rule 91 budget-watchdog section used "should" language ("agent should poll every ~150K tokens"). Agents skipped it entirely. `should_compress_now` was called zero times across hundreds of tasks. The word "should" is the bug. This rule replaces it with binary thresholds tied to an observable number in environment_details.

## Last updated

2026-05-28 — initial. Cross-refs: rule 91 (budget-watchdog mandate, superseded by this rule's enforcement), rule 00 (tripwire pattern this rule follows), cline-compress MCP (`should_compress_now` + `cline_compress_session` tools).
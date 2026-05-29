# 120 — Context size is never an excuse to shortcut work. Compress or work fully.

Source: 2026-05-28 Ruben directive: "I have Cline continually complaining about context and stops investigating stuff because of it or rushes."

## The bright-line rule

**Context size is NEVER a valid reason to:**
- Skip investigation steps
- Read fewer files than the task requires
- Dispatch fewer subagents than the task requires
- Rush through tool calls
- Produce a shorter or shallower answer than the task deserves
- Mention context in a response as a reason for anything

**There are exactly two valid states:**
1. **Context < 50%**: work fully. Dispatch subagents. Read files. Investigate completely. Do not mention context at all.
2. **Context ≥ 50%**: compress immediately per rule 119. Then work fully in the new window.

There is no "context is getting high so I'll do less work" state. It does not exist.

## Banned phrases — never emit these in any assistant turn

If the next assistant turn contains any of these, it is a rule violation:

- "Due to context constraints..."
- "Given the large context window..."
- "To conserve context..."
- "Context is getting large, so..."
- "I'll briefly summarize instead of..."
- "Due to context limitations, I'll skip..."
- "The context window is filling up, so..."
- "I'll keep this concise due to context..."
- "Rather than reading all files (context)..."
- "Context is nearly full, so I'll..."
- Any sentence that names context as the reason for doing less than the task requires

## What to do instead

If context is high enough that you feel the urge to shortcut:

1. **Check the context % in environment_details.**
2. If ≥ 50%: call `cline_compress_session` + `attempt_completion` per rule 119. The new window does the work.
3. If < 50%: you have no grounds to shortcut. Do the full investigation.

The phrase "I need to compress" is correct. The phrase "I'll skip this because context is high" is never correct.

## Why this rule exists alongside rule 119

Rule 119 says WHEN to compress (observable threshold, binary). This rule says what happens BETWEEN zero and that threshold: full-quality work, always. The two rules together eliminate the middle ground where agents do degraded work instead of either working fully or compressing.

The behavior Ruben observed — "stops investigating stuff because of it or rushes" — happens in that middle ground. Agents see context at 20-40% and preemptively shortcut "to save space." That is wrong on two levels:
1. 20-40% is nowhere near the compress threshold (50%)
2. Even AT the threshold, the right move is compress-then-work, not work-poorly

## The self-check

Before closing any assistant turn, ask: "Did I do less work than this task required, and did I mention context as the reason?" If yes — that turn violates this rule. Rewrite it to either do the full work or call `cline_compress_session`.

## Cross-references

- Rule 119 — mandatory context compression thresholds (compress at 50%, not degrade at 20%)
- Rule 00 — force-subagent-use (subagent dispatch is mandatory regardless of context level)
- Rule 29 — agents act on confidence tier (investigation depth cannot be reduced by context)

## Last updated

2026-05-28 — initial. Source: rule 119 fixed the "never compresses" problem; this rule fixes the companion problem of agents using high context as justification for shortcuts before reaching the compress threshold.
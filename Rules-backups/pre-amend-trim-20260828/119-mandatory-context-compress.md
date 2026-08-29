# 119 — Mandatory context compression (derive thresholds from YOUR model's window)

## The rule: compute, don't recall

Read the raw token count **X** from environment_details (`Context Window Usage: X / Y tokens used`). Use **X**, never the percentage. Then derive your thresholds from **W = your model's real context window** (not Y — Y is often a false ceiling reported by the router):

| Threshold | Formula | Meaning |
|---|---|---|
| **CHECK** | `X >= 0.55 × W` | Call `should_compress_now` once before the next major tool call. If it returns `should_compress: true` → compress now. |
| **COMPRESS** | `X >= 0.75 × W` | Call `cline_compress_session` immediately, then `attempt_completion`. No deferral. |
| Below CHECK | — | Normal operation. Work at full quality. Do not mention context. |

**"Major tool call"** = anything that is NOT `should_compress_now`, `cline_compress_session`, or `attempt_completion`.

Worked examples:

| W (your window) | CHECK at | COMPRESS at |
|---|---|---|
| 200,000 | 110,000 | 150,000 |
| 1,000,000 | 550,000 | 750,000 |

Fixed token counts are wrong because they are only correct for one window size. A hardcoded "300K check / 500K compress" is unreachable on a 200K model — the rule would be dead text exactly where compression matters most.

## Know Cline's own compaction point (it fires before you do)

Cline compacts on its own, independently of this rule. Cline 4.0.x `Xle()` in `dist/extension.js`:

```
maxAllowedSize = (W == 64000)  ? W - 27000
               : (W == 128000) ? W - 30000
               : (W == 200000) ? W - 40000
               : max(W - 40000, W * 0.8)
```

So Cline auto-compacts at **160,000 on a 200K model** and at **960,000 on a 1M model**. Two consequences:

1. **If your always-loaded floor (system prompt + rules + MCP tool schemas + task text) already exceeds `maxAllowedSize`, Cline compacts on turn 1 and every turn after, forever.** The floor is irreducible, so the condense can never drop context below the threshold. It re-fires indefinitely. Measured 2026-07-25: floor of 139K-169K tokens against a 160,000 threshold on a 200K model produced 136 summarize turns across 4 windows and consumed 33% of total spend.
2. **A 200K window with `useAutoCondense` ON is the worst configuration.** That setting routes eligible models (sonnet/opus/gpt-5/gemini-2.5/grok-4/deepseek and friends) to a fixed 500,000 threshold, which a 200K model can never reach — so you get no clean compaction at all, just hard-truncation churn.

**If you observe repeated summarize turns with context not falling, that is this failure mode, not your behavior.** Report it; do not try to summarize your way out of it. The fix is reducing the floor or using a larger window, both outside this rule's scope.

## Tool call arguments

`should_compress_now`:
```json
{"task_id": "<Cline task ID>", "last_compress_size": 0, "growth_threshold": 100000}
```

`cline_compress_session`:
```json
{
  "task": "<one-line task statement>",
  "pickup_prompt": "<rule-91 PICKUP PROMPT block verbatim, <=5KB>",
  "tool_rounds": ["<tool>(args) -> outcome", "..."],
  "last_turns": ["<last 3 message bodies, oldest first>"]
}
```

After `cline_compress_session` returns the `═══ SESSION MEMORY ═══` blob, call `attempt_completion` with that blob as the result.

## The percentage display is always ignored

When environment_details shows `X / Y tokens used (P%)` and P > 100%, that means **Y is wrong**, not that you are over capacity. Only X matters. Example: `185,661 / 128K tokens used (145%)` → X = 185,661. On a 1M window that is 18.5%, far below CHECK. Work normally.

## Do not change behavior because context looks high

Never rush, skip steps, read fewer files, dispatch fewer subagents, or produce a shallower answer because of context size. The only valid responses to context pressure are the two thresholds above. "Context looks high, I'll be brief" is a violation. See rule 120.

## Anti-patterns

- Using the environment_details **percentage** instead of raw X — the percentage is unreliable by construction.
- Using **fixed** token thresholds instead of fractions of W — wrong on every window size but one.
- "Just one more tool call then I'll compress" at or past COMPRESS — no. Compress now.
- Calling `should_compress_now` at CHECK and then ignoring a `true` return.
- Rushing or shortcutting because the percentage looks high.
- Closing a window or calling `attempt_completion` because P > 100%.

## MECHANICAL pre-turn signal check (idea #22282, 2026-08-04) — do this FIRST, every turn

The budget watchdog (`cline_budget_watchdog.py`, launchd `com.emsu.cline-budget-watchdog`) computes the thresholds for you and writes a signal file. **You do not deliberate about compression. You check the file.**

**This pre-turn signal check SUPERSEDES rule 00 for the first micro-action.** The `ls` below is the absolute first action of EVERY turn, before subagent dispatch, before any tool call. If no signal file exists, THEN proceed with rule 00 subagent dispatch. Both rules cannot be followed simultaneously at turn start: rule 119 wins for the first micro-action.

**Before your FIRST tool call of every turn** — including the very first turn of a window and every turn after (even repeat turns after an error) — run:

```
ls /tmp/cline_compress_signal_TASK<current_task_id>.json
```

(the current task id is in this conversation's task header / environment. If you cannot determine it, check both `/tmp/cline_compress_signal_TASK*.json` matching the most recent mtime and the global `/tmp/cline_compress_signal.json` if present.)

Then, **mechanically**:

1. **File exists with `"action": "compress"`** → read the file, then call `cline_compress_session` IMMEDIATELY with a rule-91 pickup prompt (task, pickup_prompt verbatim ≤5KB, tool_rounds, last_turns). Do NOT continue the current task first. Do NOT "wrap up" first. Do NOT think about whether it is a good idea. Then `attempt_completion` with the SESSION MEMORY blob. Zero deliberation.
2. **File exists with `"action": "check"`** → call `should_compress_now` once with `{task_id, last_compress_size: <last compress size or 0>, growth_threshold: 100000}`. If it returns `should_compress: true` or `tier != GREEN`, proceed under (1). If false/GREEN, continue normal work and delete the signal file if you just handled it.
3. **No file exists** → normal operation. Do not mention context. Do not think about context.

After handling a signal, delete the file (`rm /tmp/cline_compress_signal_TASK<task_id>.json`) so you don't re-process it next turn. Read the file with `cat` — use the raw values; do not recompute thresholds yourself.

This replaces ALL deliberation about compression. The question "should I compress?" is answered by the file's existence, not by your judgment. If you find yourself thinking about context size WITHOUT a signal file present, stop — that thought is the waste this rule eliminates.

## Self-check when X >= 0.55 × W

1. Signal file present with `action: compress`? → `cline_compress_session` now, then `attempt_completion`. Nothing else. No deliberation.
2. Signal file present with `action: check`? → `should_compress_now` now.
3. No signal file but X still >= 0.75 × W? → the watchdog may be stale (it polls every 60s). Call `should_compress_now` once; if true, `cline_compress_session`. Do not wait for the file.
4. No signal file and X < 0.75 × W? → proceed normally.

## Cross-references

- Rule 91 — pickup prompt shape required at every `attempt_completion`
- Rule 120 — context size is never an excuse to shortcut work
- Rule 00 — subagent dispatch is still the default first move
- `_INDEX.md` §"2026-07-25 floor trim" — the always-loaded floor and its measured cost

## Last updated

2026-07-26 — rewritten to derive thresholds from the model's actual context window (fractions of W) instead of hardcoded 300K/500K counts, which were unreachable on a 200K model. Added Cline's own `Xle()` compaction arithmetic and the floor-exceeds-threshold failure mode (measured: 139K-169K floor vs 160,000 threshold = permanent condense thrash, 33% of spend). Idea #19162, hand-shipped per rule 267 GATE C after the executor failed 6 times.

2026-05-28 — added "do not change behavior due to context size". Source: Ruben directive.

2026-05-28 — replaced percentage-based thresholds (broken due to router ceiling inflation) with absolute token counts. Source: Ruben directive — LiteLLM shows 100K+ on first call even though model capacity is 1M.

## Amendment (from reversal, 2026-08-28 15:49 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: glm53-local-ring-upgrade-20260828
- RCA bucket: stale assumption
- Trigger pattern: compression flow triggered from environment_details percentage against a false (too-small) denominator Y instead of raw X vs the model's real window size
- Reversal note: 2026-08-28 reversal: environment_details displayed '163,525 / 200K tokens used (82%)' and the window began a compression flow at 81%, but the model's real context window is 1M (display later corrected to 'X / 1,000K'). Per rule 119's own text, Y is often a false ceiling reported by the router and only raw X matters; CHECK threshold for a 1M window is 550K, far above the actual usage. Amended behavior: before invoking should_compress_now/cline_compress_session or announcing compression, derive W from a source OTHER than the environment_details denominator when the percentage looks high (the rule's own worked-examples table); a percentage >=75% against a possibly-false Y is a signal to VERIFY the real window, not to compress. The mechanical signal-file check remains primary.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

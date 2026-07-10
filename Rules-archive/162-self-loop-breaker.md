# 162 — Self-Loop Breaker: detect identical-result repetition and stop

Source: 2026-06-17 — live analysis of /tmp/emsu_router_audit.log found 105 genuine stuck windows in a single 7-hour window. Verified loop signature: loopers have identical `user_preview` repeated 6-183 consecutive times; healthy windows have repeat=0-1. The watchdog (idea #13132) injects a stop-note into `/tmp/emsu_loop_stop_<conversation_id>.txt` per rule 160 for active windows.

**Status: PROPOSED — pending Ruben review before promotion to hardfloor.**

## The bright-line rule

**When a Cline window's last N assistant turns have all returned the same tool result (identical content), the window is stuck in a loop. It MUST call `attempt_completion` BLOCKED.**

N = 3 (three consecutive identical tool results = stuck). This is the self-detection counterpart to what the watchdog (idea #13132) detects externally from the audit log.

### The trigger pattern

The following are the verified loop signatures from live data (emsu_router_audit.log 2026-06-17):

1. **Tool result loop**: the same tool returns the same content 3+ times in a row (e.g., `read_file` returning the same PHP file 43 times, `execute_command` returning the same SSH error 22 times).
2. **No-tool-use loop**: the model keeps emitting prose and getting `[ERROR] You did not use a tool in your previous response!` — covered by rule 143, but also flagged here.
3. **PLANNED_ACTIONS_JSON missing loop**: executor chain keeps returning `"error": "Unknown action"` from the same MCP call.

All three have identical `user_preview` in the audit log. All three are stuck.

## The self-check (run before every assistant turn)

Before composing any response, mentally scan the last 3 tool results:

1. **Are the last 3 tool results all identical content?** (Same text, same error, same file content.) → If yes: you are stuck. Do NOT emit another tool call of the same type. Proceed to stop.
2. **Did I already stop iterating on this and loop back anyway?** → If yes: you are stuck. Stop.
3. **Stop action**: call `attempt_completion` with:
   - `result`: "BLOCKED: identical-result loop detected (N consecutive identical results). Last result: [first 100 chars]. Per rule 161: stopped. Fresh window pickup: [brief task description + last verified state]"

## What counts as "identical"

- Tool result text trimmed and compared: if `result[:200] == previous_result[:200]`, they are identical for loop-detection purposes.
- Minor whitespace/timestamp differences that don't represent progress are NOT different (e.g., same PHP file content returned again is still the same file).
- A tool returning `null` or empty three times in a row counts as identical.
- **Does NOT count**: different tool calls that happen to return similar-but-different content, or tool calls that make incremental progress (each `read_file` reading a DIFFERENT file is not a loop).

## What to write in the blocked completion

```
BLOCKED: identical-result loop detected.

I repeated the same result N times:
  Tool: <tool_name>
  Result preview: <first 100 chars>

Per rule 161 (self-loop breaker): stopping to prevent wasted GPU/cloud tokens.

PICKUP PROMPT (paste into a fresh Cline window):
Pick up task — <one-line task description>.

Where we left off:
- Last known good state: <what was verified working>
- The loop I was stuck in: <brief description>
- Next concrete action needed: <what a fresh window should try instead>

If the watchdog injected a note at /tmp/emsu_loop_stop_<conversation_id>.txt,
that file has full details about the loop signature.
```

## Why this rule exists

From live data: 105 windows were stuck in identical-result loops in a single 7-hour window. The top looper repeated the same Python file content 43 times over 300 minutes. Chat-summary loopers sent the same content 31 times each over 275 minutes. All burned GPU/cloud tokens with zero productive progress.

Rule 143 (prose-loop circuit breaker) covers no-tool-use loops. Rule 161 covers the complementary case: tool-use that makes no progress (same result every time). Together they close the two dominant stuck-window failure modes.

## Composes with

- **Rule 143** (prose-loop circuit breaker): 143 covers no-tool-use streaks, 161 covers identical-tool-result streaks. Non-overlapping.
- **Rule 160** (cross-window injection): the watchdog (idea #13132) writes `/tmp/emsu_loop_stop_<conversation_id>.txt` when it detects this externally. If you see such a file in your working directory, stop immediately per this rule.
- **Rule 158** (Frankenstein Doctor): Doctor uses `frankenstein_what_served` with the same identical-repeat detection to identify patient windows.
- **Rule 99** (YOLO prevention): identical-result loops don't trip YOLO directly, but the no-tool-use response to a failing tool call does. Rule 161 catches the loop before it escalates.

## What this rule does NOT do

- Does NOT fire on varied-progress tool calls (even slow ones, even long windows).
- Does NOT fire on time or turn-count thresholds — ONLY on identical content.
- Does NOT fire on the first or second identical result — gives the window 2 tries before declaring stuck (3rd identical = stop).
- Does NOT replace rule 143 — they cover different failure modes.

## Source incident

2026-06-17 — live /tmp/emsu_router_audit.log analysis: 105 genuine identical-result loop conversations in 7 hours. Worst: conv_b63791b1ff38727d (130 hits, 43 identical repeats, 300min duration, artemis-gpt-oss-120b). Chat-summary class: 31 identical repeats each, 275min, cycling across artemis/cesar/deepseek. PLANNED_ACTIONS_JSON class: 13 identical repeats, 275min. All burning compute with zero progress.

Dashboard: https://www.emsuniversity.com/emtskills/routes/ruben_loop_dashboard.php
Watchdog: /usr/local/bin/emsu-loop-watchdog (cron */2 * * * *)
Ideas: #13131 (dashboard), #13132 (watchdog), #13133 (this rule)

## Last updated

2026-06-17 — proposed pending Ruben review. Source: idea #13133 (Loop Detection System).

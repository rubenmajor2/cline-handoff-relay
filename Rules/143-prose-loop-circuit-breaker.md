# 143 — Prose-loop circuit breaker: bail to attempt_completion at strike (CEILING-1)

Permanent hardfloor rule. Workspace-scoped. v4 (2026-07-04) replaces v3.

## The fix (2026-07-04 11:28 PT)

The root cause of the YOLO storm is now FIXED. The Cline extension v4.0.6 hardcoded `maxConsecutiveMistakes:{default:3}` in `dist/extension.js`. This setting is NOT exposed in the Cline Settings UI or VS Code settings — there is no way to change it via the UI. The fix was a direct source patch: `maxConsecutiveMistakes:{default:3}` → `maxConsecutiveMistakes:{default:10}`. Backup at `extension.js.bak-pre-yolo-fix`. A re-patching script at `~/Documents/Cline/scripts/patch_yolo_ceiling.sh` survives extension updates.

**After reloading VS Code (Window: Reload), the live ceiling will be 10.** Until you reload, the running extension still uses ceiling=3. After reload, bail at strike 9.

## CEILING DETECTION (know your budget)

The live `maxConsecutiveMistakes` ceiling is the number in the YOLO trip message: `"[YOLO MODE] Task failed: Too many consecutive mistakes (N)"`.

- **After VS Code reload (post-fix):** N=10. Bail at strike 9. Recover strikes 1-8.
- **Before reload (old running process):** N=3. Bail at strike 2. Recover strike 1 only.

The formula is always `bail = ceiling - 1`.

## The bright-line rule (v4)

**Count only CONSECUTIVE errors — a streak broken by ANY successful tool call resets the count to ZERO.** This includes no-tool-use errors, tool execution failures, AND API hiccups.

| Consecutive strikes | Required next move (ceiling=10 post-reload) |
|---|---|
| 1-8 | **Recover.** Emit the intended tool block silently — no narration, no apology. If the error was an API hiccup (overloaded/timeout), emit a SIMPLER tool. You have 8 recovery chances — use them wisely. |
| 9 | **BAIL.** Your next response MUST be `attempt_completion` with a pickup prompt (rule 91). Do NOT attempt another tool. Strike 10 will kill the task with no pickup prompt — you are exiting to SAVE the task, not abandoning it. |

**Strike 9 is the exit, not strike 10.** The entire point of v4 is: never reach strike 10. A bailout `attempt_completion` at strike 9 (with a pickup prompt) preserves the task state for the next window. A YOLO death at strike 10 loses everything.

### The "two API hiccups = bail" sub-rule

If you get 2 `api: overloaded/rate-limit` errors in a row: the third call has ~0% success chance. With ceiling=10 you CAN afford a 3rd attempt, but if it also fails, bail to `attempt_completion` with "Anthropic overloaded, pausing, re-prompt me in 60s" — do NOT keep retrying.

### What does NOT count toward the streak

- Errors that occurred earlier but were followed by ANY successful tool call (streak reset). Count the CURRENT uninterrupted run only, not "across the task."
- Errors before you took ANY action in a fresh task. A fresh window that hits 1 error on its opening turn recovers and starts working; it does not bail before doing work (that would be a rule-29 violation).

## Self-audit before bailing at strike 9

Before writing the strike-9 `attempt_completion`, verify ALL of:
1. The strikes are CONSECUTIVE (no successful tool call between them) — check actual recent turns.
2. The current streak is exactly 9 (you already tried recovery at strikes 1-8 and they failed).
3. The errors are real (not just "I feel stuck" — there must be actual `[ERROR]` or tool-failure output).

If any check fails, you still have recovery chances available — emit a tool.

## The MCP "result missing" trigger

If **3+ MCP tool calls in a row** (same server, no intervening success) return empty / "result missing" / no body, classify the failure per rule 261 (4 modes: server-down, session-expired, transport-error, transient-empty) and run the 3-gate check before declaring wedge. Pivot to a different tool path (local shell, file tools, different MCP server) on the next turn, OR `attempt_completion` reporting the classified failure mode.

## What this rule does NOT do

- Does not change `maxConsecutiveMistakes` at runtime — the fix was a source patch (2026-07-04). v4 adapts to whatever the live ceiling is.
- Does not replace rule 41 (no-prose pivot table) or rule 99 (per-class playbook). Those govern HOW to recover at strikes 1-8. This rule is the strike-9 exit.
- Does not authorize bailing for any reason other than 9 consecutive errors (context size, "feels stuck" = rule 119/120/29 violations).

## Cross-references

- Rule 00 — first move is a tool block (this rule fires when that keeps failing)
- Rule 41 — silent tool emission is strike-1 recovery; no-prose pivot table
- Rule 99 — per-class failure playbook (strike 1 recovery tactics)
- Rule 261 — MCP failure classification: 4 modes before declaring "wedge" (replaces broken rule 77 cross-ref — rule 77 is LiteLLM router overload, not MCP transport)
- Rule 29 — bailing on work the agent could do is inaction; but with ceiling=10, strike-9 bail is NOT premature — it is survival

## Source incidents

- 2026-06-08 — v1: ~150-prose-turn death spiral. v1 stopped it but was too aggressive (bail at 2 non-consecutive).
- 2026-06-11 — v2: recalibrated for ceiling=10, recover 1-3, bail at 4. Post-v1 trips fell to ~1/day. But the ceiling assumption was wrong.
- 2026-07-04 — v3: Ruben reported "numerous yolos across multiple llms." Forensic analysis of 40 trips / 26 tasks revealed the live ceiling is 3, not 10. v2's strike-4 bail was unreachable. v3 bails at strike (ceiling-1) = strike 2.
- 2026-07-04 — v4: ROOT CAUSE FOUND AND FIXED. The setting `maxConsecutiveMistakes` is NOT exposed in the Cline Settings UI or VS Code settings — it is hardcoded in `dist/extension.js` as `{default:3}`. Ruben could not change it in the UI because it does not exist in the UI. Fix: direct source patch `default:3` → `default:10` in the extension JS. Backup at `extension.js.bak-pre-yolo-fix`. Re-patching script at `~/Documents/Cline/scripts/patch_yolo_ceiling.sh` for extension updates. After VS Code reload, ceiling=10, bail at strike 9. Idea #16415.

## Last updated

2026-07-04 — v4 rewrite. Root cause: `maxConsecutiveMistakes` hardcoded as `{default:3}` in extension source, NOT exposed in UI. Fix: source patch to `{default:10}`. After VS Code reload, bail at strike 9 (ceiling-1). Re-patching script handles extension updates.

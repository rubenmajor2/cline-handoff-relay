# 143 — Prose-loop circuit breaker: recover FIRST; bail to attempt_completion only after 4 CONSECUTIVE no-tool-use errors

Permanent hardfloor rule. Workspace-scoped. v2 (2026-06-11) replaces v1.

## Why v1 was rewritten (read this before applying the rule)

v1 said "after 2 'You did not use a tool' errors, the ONLY legal move is attempt_completion." It stopped the 2026-06-08 ~150-prose-turn death spiral, but a 2026-06-11 audit of 288 tasks showed it was killing healthy tasks: ~70% of tasks hit at least one no-tool-use error (often an API hiccup like "Failure: I did not provide a response", not a real format error), and 39 tasks invoked the breaker — several bailing BEFORE doing any work, or mid-task with non-consecutive errors counted across the whole task. With `maxConsecutiveMistakes=10`, a hard stop at 2 fired at 20% of the actual budget. v2 makes recovery the default and the bail the rare exception.

## The bright-line rule (v2)

**Count only CONSECUTIVE `[ERROR] You did not use a tool` strikes — a streak broken by ANY successful tool call resets the count to ZERO.**

| Consecutive no-tool-use strikes (current streak) | Required next move |
|---|---|
| 1 | **Recover.** Emit the intended tool block silently — no narration, no apology, no explanation. This succeeds the vast majority of the time. |
| 2 | **Recover, simplified.** Emit a SIMPLER tool call than the one you were narrating about (a bounded read, a status check, or the smallest version of the intended action). Still no prose-only turn. |
| 3 | **Last recovery attempt.** One more tool emission. If you cannot identify ANY tool to call, this turn is `attempt_completion`. |
| 4 | **Bail.** Your next response MUST be `attempt_completion` with an honest "blocked, here is the pickup prompt" result. No further tool attempts. |

### What does NOT count toward the streak

- Errors that occurred earlier in the task but were followed by ANY successful tool call (the streak reset). Do not count errors "across the task" — only the current uninterrupted run.
- API/infra hiccups: "Failure: I did not provide a response", connection errors, timeouts, overloaded errors. Those are NOT format failures by you — recover per rule 41's pivot table instead.
- Errors before you have taken ANY action in a fresh task. A fresh window that hits 1-2 errors on its opening turns recovers and starts working; it does not bail with "the task hasn't started yet." Bailing before doing any work is a rule-29 violation, not a 143 compliance.

### Self-audit before invoking the breaker

Before writing an `attempt_completion` that cites this rule, verify ALL of:
1. The strikes are CONSECUTIVE (no successful tool call between them) — check the actual recent turns, do not estimate.
2. The current streak is ≥ 4 (or 3 with genuinely no identifiable tool to call).
3. The strikes are real no-tool-use format errors, not API hiccups.

If any check fails, the breaker does not apply — recover by emitting the tool.

## The MCP "result missing" trigger (unchanged in spirit, tightened)

If **3 MCP tool calls in a row** (same server, no intervening success) return empty / "result missing" / no body, the MCP transport is wedged (see rule 77). Do not keep firing calls at that server. Either pivot to a DIFFERENT tool path (local shell, file tools, a different MCP server) or, if no alternative path exists for the task, `attempt_completion` reporting "MCP transport returning empty results, paused" with a pickup prompt. One empty result is noise; do not bail on it.

## What this rule does NOT do

- Does not lower or replace `maxConsecutiveMistakes` (currently 10 per rule 16). The breaker at 4 leaves real recovery headroom below the hard YOLO ceiling.
- Does not replace rule 41 (post-deploy / post-error pivot table) or rule 99 (per-class playbook). Those govern strikes 1-3 (HOW to recover). This rule is only the strike-4 exit when recovery itself keeps failing.
- Does not authorize ending a task early for any other reason (context size, parallel windows, "feels stuck"). Those are rule 119/120/29 violations.

## Cross-references

- Rule 00 — first move is a tool block (this rule fires only when that keeps failing consecutively)
- Rule 41 — silent tool emission is the recovery shape for strike 1; the per-error-class pivot table is the recovery shape for tool errors
- Rule 99 — no-tool-use is the #1 YOLO class; this rule is the calibrated circuit-breaker for it
- Rule 77 — WOPR tunnel-down: wedged MCP transport handling
- Rule 29 — bailing on work the agent could do is inaction needing justification; a premature 143 bail is a 29 violation

## Source incidents

- 2026-06-08 04:30-04:50 PT — a window emitted ~150 prose-only turns in a row; rules 00/41/99 kept saying "emit a tool" with no hard stop. v1 created the stop.
- 2026-06-11 — Ruben: "These 143s are ridiculous and killing a bunch of tasks off." Audit of 288 tasks (4 days): 202 hit ≥1 no-tool-use error, 39 invoked the breaker, multiple bails were premature (non-consecutive errors counted, API hiccups counted, bails before any work). Post-v1 trips fell to ~1/day, proving the stop works — but the threshold and counting were miscalibrated. v2: consecutive-only, reset-on-success, threshold 4, hiccups excluded, recovery-first.

## Last updated

2026-06-11 — v2 rewrite per Ruben directive.

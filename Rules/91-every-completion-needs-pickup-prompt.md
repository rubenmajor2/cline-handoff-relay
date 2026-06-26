# 91 — Every attempt_completion MUST end with a ═══ PICKUP PROMPT ═══ block

Permanent hardfloor rule. Source: 2026-05-19 Ruben directive.

## BINARY GATE — run BEFORE calling attempt_completion

**An `attempt_completion` is INVALID unless `result` ends with the `═══ PICKUP PROMPT ═══` block.** No pickup prompt = do not ship the completion. Add the block first.

The ONLY exemption: when the result's first 100 characters contain the exact string `"Not a task completion — conversational/read-only only, no system-state changes"` AND zero system-state changes occurred (no files, SQL, deploys, configs, restarts, MCP fixes). Infrastructure fixes are NEVER exempt.

## Required shape (copy this template)

**COPY THIS EXACT DIVIDER LINE:** `═══════════════════════════════════════════════` (39 equals signs on the first and last line — NOT hyphens, NOT dashes, NOT different unicode characters). Then fill in the middle:

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════

Pick up task #<real task id> — <one-line topic>.

Where we left off (verified <real PT timestamp>):
- <1-3 bullets of current state with IDs>
- <key resource: ticket #, idea #, file path>

Open threads to drive next:
1. #<real idea number> — <actionable item with MCP tool/SQL/file needed>
2. #<real idea number> — <next item>
3. #<real idea number> — <next item>

Reference IDs:
- Ticket: <ticket_number>
- Ideas filed: #<id1>, #<id2>
- Files touched: <paths>

When done, append a row to cline_task_ledger.md per rule 07 and run order 66.
═══════════════════════════════════════════════
```

## The two-gate procedure (execute before writing open threads)

**Gate 0 (rule 29):** Can I do this right now with a tool I have? → YES = DO IT, don't list it. NO = proceed to Gate 1.

**Gate 1:** File via `create_idea`. Get the real integer id. List it as `#<real id>`.

Every open-thread item MUST carry a filed idea number. An item without one is either undone work (rule 29 violation) or deferred work not filed (also a violation). "Optional"/"nice-to-have" is not an exemption.

## Hardfloor bans

- **NO placeholders:** Never emit literal `#NNNN`, `#0000`, `#XXXX`, `<task_id>`, `<timestamp PT>`, or any angle-bracket token. Every `#` is a real idea number from `create_idea`.
- **NO PICKUP-BY-REFERENCE:** The ═══ block must be INLINE in `result`, not "see handoff file." Ruben copies the completion bubble, not Desktop files.
- **NO mid-task ═══ block:** The divider block is ONLY legal inside `attempt_completion.result`, never as a mid-task turn.
- **NO wait-state phrases:** Never write "hold until Ruben confirms," "wait before acting," "pause until," "ask first if." The next window has authority to act.

## Anti-patterns
- ❌ Vague pickup ("check on the progress") — be specific with IDs and tools
- ❌ Pickup prompt not at the END of result
- ❌ "Ideas this task: none" when ideas were filed — cite every `#NNNN` in the body AND pickup prompt

## Self-check before attempt_completion

**HARD BINARY GATE (run BEFORE calling the tool):** scan `result` text. If the exact string `═══ PICKUP PROMPT ═══` does NOT appear, the completion is BROKEN. Do not ship it. This is a binary test — the string is either present or absent. If absent, add the pickup prompt block before calling `attempt_completion`.

1. Does `result` contain `═══ PICKUP PROMPT ═══` as the final section? If no → **DO NOT CALL attempt_completion yet. Add it first.**
2. Scan for literal `#NNNN`/`#0000`/`<...>` placeholders. If found → substitute real values.
3. Did I file/approve/reject any idea this task? If yes → all `#NNNN` are cited in the body with disposition.
4. Did I answer every question Ruben asked? If no → answer them inline before the pickup prompt.

## Cross-refs
- Rule 29 — act-or-defer test (Gate 0)
- Rule 38 — Ruben-asked = file at autonomous tier minimum
- Rule 119/120 — context thresholds (compress, don't shortcut)
- Rule 137 — Completion Gate: pasted proof per Definition-of-Done line

## Source incident
2026-05-19 — Calderon recovery chain. Ruben: *"in every single task completed window need a pickup prompt to continue that task in a new window."*
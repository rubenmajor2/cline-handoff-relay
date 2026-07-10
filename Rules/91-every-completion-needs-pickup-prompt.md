# 91 — Every attempt_completion MUST end with a ═══ PICKUP PROMPT ═══ block

Permanent hardfloor rule. Source: 2026-05-19 Ruben directive.

## BINARY GATE — run BEFORE calling attempt_completion

**An `attempt_completion` is INVALID unless `result` ends with the `═══ PICKUP PROMPT ═══` block.** No pickup prompt = do not ship the completion. Add the block first.

The ONLY exemption: when the result's first 100 characters contain the exact string `"Not a task completion — conversational/read-only only, no system-state changes"` AND zero system-state changes occurred (no files, SQL, deploys, configs, restarts, MCP fixes). Infrastructure fixes are NEVER exempt.

## Required shape

### ⛔ THE DIVIDER (copy mechanically — do NOT retype)

```
═══════════════════════════════════════════════
```

That is 47 characters of U+2550 (BOX DRAWINGS DOUBLE HORIZONTAL, ═). NOT ASCII equals (=). NOT hyphens (-). NOT any other glyph or count. The divider appears TWICE in every pickup prompt — once before "PICKUP PROMPT" and once at the very end. Both lines must be identical.

**Why retyping fails:** every agent that tries to type this manually gets it wrong — wrong count, hyphens mixed in, wrong unicode glyph. Copy the line above mechanically. Do not type it. Your eyes cannot count 47 double-line characters reliably; your clipboard can.

### The full template (fill in the middle after copying the dividers)

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════

Pick up task #<real task id> — <one-line topic>.

Where we left off (verified <real PT timestamp>):
- <1-3 bullets of current state with IDs>
- <key resource: ticket #, idea #, file path>

Open threads to drive next:
1. #<real idea number> [<disposition>] — <actionable item with MCP tool/SQL/file needed>
2. #<real idea number> [<disposition>] — <next item>
3. #<real idea number> [<disposition>] — <next item>

Reference IDs:
- Ticket: <ticket_number>
- Ideas filed: #<id1> [deployed], #<id2> [approved:autonomous]
- Ideas closed: #<id3> [rejected], #<id4> [superseded]
- Files touched: <paths>

When done, append a row to cline_task_ledger.md per rule 07 and run order 66.
═══════════════════════════════════════════════
```

### Disposition tags (required on EVERY idea mention)

Every `#NNNN` in the pickup prompt MUST carry a disposition in brackets showing what happened to it after rule 29 was applied. Use one of:

| Tag | Meaning |
|---|---|
| `[deployed]` | Shipped to production this task |
| `[approved:autonomous]` | Approved, executor will auto-implement |
| `[approved:supervised]` | Approved, needs human review on deploy |
| `[proposed]` | Filed but not yet approved (open thread) |
| `[rejected]` | Closed — not a valid fix / superseded / moot |
| `[superseded]` | Replaced by a newer idea |
| `[deferred]` | Legit but intentionally left for later |

**Rule:** every `#NNNN` in the pickup prompt body AND the Reference IDs section gets a tag. No bare idea numbers. The disposition is the output of running the idea through rule 29's Gate 0 — what actually happened to it, not what the next window should do.

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

**PROGRAMMATIC GATE (preferred):** Call `clinerules_validate_completion(result_text=<your result>)` BEFORE `attempt_completion`. It checks structurally: 47-char U+2550 divider, then a `PICKUP PROMPT ...` header on the next line, then a closing 47-char divider, plus task-id presence, placeholders, pickup-by-reference, and wait-state phrases. If it returns any FAILURE → fix that specific failure before shipping. (This tool was fixed 2026-07-03 — it previously had a false-negative bug; see Source incidents.)

**HARD BINARY GATE (if you cannot call the tool):** scan `result` for a line that is exactly 47 U+2550 chars, immediately followed by a line beginning `PICKUP PROMPT`. That is the opening of the block; a closing 47-char divider must follow. The block is STRUCTURAL (divider on its OWN line, header on the NEXT line) — do NOT search for an inline 3-char `═══ PICKUP PROMPT ═══` substring, because that substring NEVER appears in a canonical prompt and searching for it causes false negatives (this was the exact bug).

1. Does `result` end with a 47-char U+2550 divider, preceded by a `PICKUP PROMPT ...` header line, preceded by an opening 47-char divider? If no → **DO NOT CALL attempt_completion yet. Add the block first.**
2. Does the first content line after the header read `Pick up task #<numeric id> — <topic>`? If the `#<numeric id>` is missing → add the real Cline task id. (A line like `Pick up task — final-notice cleanup` with NO `#id` is a rule-91 violation.)
3. Scan for literal `#NNNN`/`#0000`/`<...>` placeholders. If found → substitute real values.
4. Did I file/approve/reject any idea this task? If yes → all `#NNNN` are cited in the body with disposition.
5. Did I answer every question Ruben asked? If no → answer them inline before the pickup prompt.

## Cross-refs
- Rule 29 — act-or-defer test (Gate 0)
- Rule 38 — Ruben-asked = file at autonomous tier minimum
- Rule 119/120 — context thresholds (compress, don't shortcut)
- Rule 137 — Completion Gate: pasted proof per Definition-of-Done line

## Source incidents
2026-05-19 — Calderon recovery chain. Ruben: *"in every single task completed window need a pickup prompt to continue that task in a new window."*
2026-07-02 — executor-storm task: agent violated rule 91 (wrong divider — 3 chars instead of 47). "Required shape" section rewritten with standalone copy-paste divider block + explanation of why retyping fails. Disposition tags added — every idea mention now requires a bracketed tag showing what rule 29 determined. Companion fix in _RULE_TREE.md Gate 9.
2026-07-03 — Ruben directive: rule 91 itself had a self-contradiction — the description said "39 equals signs" but the actual copy-paste template was 47 characters of U+2550 (BOX DRAWINGS DOUBLE HORIZONTAL, not ASCII equals). Corrected all references from "39 equals signs" to "47 U+2550 chars" in rule 91 and _RULE_TREE.md. Filed idea #16223 (divider spec fix) and #16224 (programmatic enforcement gate in attempt_completion).
2026-07-03 (later) — validator false-negative RCA. The `clinerules_validate_completion` Gate 1 searched for the inline substring `═══ PICKUP PROMPT ═══` (3 glyphs + text + 3 glyphs on ONE line), but the canonical template puts 47-char dividers on their OWN lines with `PICKUP PROMPT (paste into a fresh Cline window)` on a separate line — so a perfectly-formatted prompt NEVER contained that substring and ALWAYS failed (MISSING_PICKUP_PROMPT), while a broken inline short-divider prompt passed (false positive). Root cause: the rule 91 self-check text said "scan for the exact string `═══ PICKUP PROMPT ═══`," and the validator author implemented that literally. Telemetry showed MISSING_PICKUP_PROMPT dominating recent VALIDATION_FAIL rows. FIX: (a) validator Gate 1 rewritten to detect the block structurally (47-char divider → header line → closing divider); (b) new Gate 4b catches a MISSING task id (`Pick up task — foo` with no `#<id>`), which was the real violation in the final-notice handoff that prompted this RCA; (c) this rule's self-check rewritten to reference the programmatic gate + structural test instead of the inline substring. Verified live: canonical prompt now PASSES, missing-task-id prompt now FAILS with MISSING_TASK_ID. Also caught a build/src divergence (build had been hand-edited with extra R29/R120/R01/R02 gates not in src) — both now synced.

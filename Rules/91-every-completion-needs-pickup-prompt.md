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
- <1-3 bullets of current state — include idea #s WITH brackets>
- <resource: ticket #N, idea #M [deployed|executing|queued|blocked|proposed|rejected], file path>

Open threads to drive next:
1. #<real idea number> [<disposition>] — <actionable item with MCP tool/SQL/file needed>
2. #<real idea number> [<disposition>] — <next item>
3. #<real idea number> [<disposition>] — <next item>

Reference IDs:
- Ticket: <ticket_number>
- Ideas filed: #<id1> [deployed], #<id2> [executing], #<id3> [queued]
- Ideas closed: #<id4> [rejected], #<id5> [superseded]
- Ideas blocked: #<id6> [blocked] — <one-line unblocker>
- Files touched: <paths>

When done, append a row to cline_task_ledger.md per rule 07 and run order 66.
═══════════════════════════════════════════════
```

### Disposition tags (required on EVERY idea mention) — VERIFIED live executor state

Every `#NNNN` in the pickup prompt MUST carry a disposition in brackets showing the idea's LIVE executor state — verified by a rule-267 GATE B reconcile tool call (`list_decisions` / `get_idea_progress`) run THIS session, not a filing-time memory. Ruben reads the tag to decide whether the thread can be closed or needs his hand. Use one of:

**Verified live-state tags (the goal — what the executor is doing RIGHT NOW):**

| Tag | Meaning | Ruben reads this as |
|---|---|---|
| `[deployed]` | Shipped to production AND verified-executed this session | Done — thread closed |
| `[executing]` | Executor is actively building it now (in_progress, dev stage) | Executor owns it — thread closed |
| `[queued]` | Approved, waiting on executor cron (not yet picked up) | Will run on its own — thread closed, check back later |
| `[blocked]` | Failed / stuck / impl_failed — needs a fix or re-file | ACT — fix inline (rule 29) or re-file |

**Filing-tier tags (used when the idea is NOT yet in the executor's hands):**

| Tag | Meaning | Ruben reads this as |
|---|---|---|
| `[proposed]` | Filed but not yet approved (no executor action yet) | ACT — approve/reject or promote to autonomous |
| `[approved:supervised]` | Approved but human must review before deploy | Human gate — Ruben/Vicky reviews |
| `[rejected]` | Closed — not a valid fix / superseded / moot | Thread closed — dismissed |
| `[superseded]` | Replaced by a newer idea | Thread closed — see the successor |
| `[deferred]` | Legit but intentionally left for later | Parked — not this cycle |

**`[approved:autonomous]` is a MID-TASK-ONLY fallback.** You may use it transiently right after `idea_action(approve)` while the build pipeline spins up, but it MUST be replaced by a verified tag (`[executing]` / `[queued]` / `[deployed]` / `[blocked]`) before `attempt_completion`. Shipping `[approved:autonomous]` in a final pickup prompt is a rule-91 violation — it is ambiguous between "executor is working on it" and "it is sitting in a queue," and that ambiguity is exactly what this rule eliminates.

**Rule:** every `#NNNN` in the pickup prompt body AND the Reference IDs section gets a verified tag. No bare idea numbers. The tag is the output of the rule-267 GATE B reconcile call mapped to the table above — what the executor is ACTUALLY doing, not what the next window should do.

**Reconcile evidence MUST be quoted inline next to the tag** when the idea was reconciled this session (rule 267 GATE B). Format: `#17537 [rejected] (verified: decision_action returned "superseded by manual implementation")`. This prevents agents from inventing fake tags — if you can't quote the reconcile return, you didn't run the reconcile call, and the tag is not verified. The parenthetical is optional for ideas filed by prior sessions (where you're carrying forward a known state), but those still need a tag.

## The two-gate procedure (execute before writing open threads)

**Gate 0 (rule 29):** Can I do this right now with a tool I have? → YES = DO IT, don't list it. NO = proceed to Gate 1.

**Gate 1:** File via `create_idea`. Get the real integer id. List it as `#<real id>`.

Every open-thread item MUST carry a filed idea number. An item without one is either undone work (rule 29 violation) or deferred work not filed (also a violation). "Optional"/"nice-to-have" is not an exemption.

## Hardfloor bans

- **NO placeholders:** Never emit literal `#NNNN`, `#0000`, `#XXXX`, `<task_id>`, `<timestamp PT>`, or any angle-bracket token. Every `#` is a real idea number from `create_idea`.
- **NO PICKUP-BY-REFERENCE:** The ═══ block must be INLINE in `result`, not "see handoff file." Ruben copies the completion bubble, not Desktop files.
- **NO mid-task ═══ block:** The divider block is ONLY legal inside `attempt_completion.result`, never as a mid-task turn.
- **NO wait-state phrases:** Never write "hold until Ruben confirms," "wait before acting," "pause until," "ask first if." The next window has authority to act.
- **⛔ NO BARE IDEA NUMBERS — anywhere in the entire `result`, not just the pickup prompt.** Every scrap of text that mentions `#NNNN` MUST carry a disposition bracket. This includes: prose descriptions ("idea #17537 [rejected] was the tracking idea"), Where-we-left-off bullets, parenthetical notes, cross-references, and the pickup prompt block. A bare `#17537` with no bracket is a rule-91 violation — Ruben cannot tell from a raw number whether the thread is dead, alive, or needs his hand. This ban applies to the WHOLE `result`, not just the pickup-prompt block.

## Anti-patterns
- ❌ Vague pickup ("check on the progress") — be specific with IDs and tools
- ❌ Pickup prompt not at the END of result
- ❌ "Ideas this task: none" when ideas were filed — cite every `#NNNN` in the body AND pickup prompt
- ❌ Bare idea number in prose: "idea #17537 is now closed" → MUST be "idea #17537 [rejected] — superseded" with the tag

## Self-check before attempt_completion

**PROGRAMMATIC GATE (preferred):** Call `clinerules_validate_completion(result_text=<your result>)` BEFORE `attempt_completion`. It checks structurally: 47-char U+2550 divider, then a `PICKUP PROMPT ...` header on the next line, then a closing 47-char divider, plus task-id presence, placeholders, pickup-by-reference, and wait-state phrases. If it returns any FAILURE → fix that specific failure before shipping. (This tool was fixed 2026-07-03 — it previously had a false-negative bug; see Source incidents.)

**HARD BINARY GATE (if you cannot call the tool):** scan `result` for a line that is exactly 47 U+2550 chars, immediately followed by a line beginning `PICKUP PROMPT`. That is the opening of the block; a closing 47-char divider must follow. The block is STRUCTURAL (divider on its OWN line, header on the NEXT line) — do NOT search for an inline 3-char `═══ PICKUP PROMPT ═══` substring, because that substring NEVER appears in a canonical prompt and searching for it causes false negatives (this was the exact bug).

**MANUAL TAG-SCAN GATE (run before shipping — IF any idea was filed or mentioned):**

1. Python one-liner: `python3 -c "import re,sys; t=sys.argv[1]; bare=re.findall(r'(?<!#)\d{4,6}(?!\s*\[)', t); print('BARE:', bare if bare else 'none')" "$(pbpaste)"`
   This regex finds every 4-6 digit number that is NOT immediately followed by `[` — those are bare idea numbers. If ANY appear, STOP. Tag them before shipping.
2. If you cannot run the one-liner, manually scan: find every `#NNNN` in `result`. For each: is there a `[disposition]` bracket within the same paragraph/bullet? If ANY are bare → DO NOT CALL `attempt_completion` yet. Tag them first.
3. For every tagged idea you filed or reconciled THIS session: is there a `(verified: <tool> returned ...)` parenthetical quoting the reconcile evidence? If not → run the reconcile call now. No parenthetical + this session = tag not verified.

1. Does `result` end with a 47-char U+2550 divider, preceded by a `PICKUP PROMPT ...` header line, preceded by an opening 47-char divider? If no → **DO NOT CALL attempt_completion yet. Add the block first.**
2. Does the first content line after the header read `Pick up task #<numeric id> — <topic>`? If the `#<numeric id>` is missing → add the real Cline task id. (A line like `Pick up task — final-notice cleanup` with NO `#id` is a rule-91 violation.)
3. Scan for literal `#NNNN`/`#0000`/`<...>` placeholders. If found → substitute real values.
4. **TAG-SCAN GATE:** Does `result` contain ANY bare idea number (a `#NNNN` with no `[disposition]` bracket in the same paragraph)? If yes → **STOP. Tag every bare idea number before shipping.** This is the mechanical gate that catches the "idea #17537" in prose without brackets. Run the Python one-liner or scan manually.
5. Did I file/approve/reject any idea this task? If yes → all `#NNNN` are cited in the body with a VERIFIED disposition tag (not `[approved:autonomous]`).
6. For every idea I filed, did I run a rule-267 GATE B reconcile call (`list_decisions` / `get_idea_progress`) THIS session and map its return to the live-state tag? If no → run it now. `[approved:autonomous]` in a final prompt = FAIL.
7. For every idea reconciled THIS session: is the reconcile evidence quoted in a parenthetical next to the tag? If no → add it. Format: `(verified: <tool> returned "<key field>")`.
8. Did I answer every question Ruben asked? If no → answer them inline before the pickup prompt.

## Cross-refs
- Rule 29 — act-or-defer test (Gate 0), pre-completion audit item 5 (bare-number-gate check)
- Rule 38 — Ruben-asked = file at autonomous tier minimum
- Rule 119/120 — context thresholds (compress, don't shortcut)
- Rule 137 — Completion Gate: pasted proof per Definition-of-Done line
- Rule 267 GATE B — reconcile gate (producing the verified tags)

## Source incidents
2026-05-19 — Calderon recovery chain. Ruben: *"in every single task completed window need a pickup prompt to continue that task in a new window."*
2026-07-02 — executor-storm task: agent violated rule 91 (wrong divider — 3 chars instead of 47). "Required shape" section rewritten with standalone copy-paste divider block + explanation of why retyping fails. Disposition tags added — every idea mention now requires a bracketed tag showing what rule 29 determined. Companion fix in _RULE_TREE.md Gate 9.
2026-07-03 — Ruben directive: rule 91 itself had a self-contradiction — the description said "39 equals signs" but the actual copy-paste template was 47 characters of U+2550 (BOX DRAWINGS DOUBLE HORIZONTAL, not ASCII equals). Corrected all references from "39 equals signs" to "47 U+2550 chars" in rule 91 and _RULE_TREE.md. Filed idea #16223 (divider spec fix) and #16224 (programmatic enforcement gate in attempt_completion).
2026-07-03 (later) — validator false-negative RCA. The `clinerules_validate_completion` Gate 1 searched for the inline substring `═══ PICKUP PROMPT ═══` (3 glyphs + text + 3 glyphs on ONE line), but the canonical template puts 47-char dividers on their OWN lines with `PICKUP PROMPT (paste into a fresh Cline window)` on a separate line — so a perfectly-formatted prompt NEVER contained that substring and ALWAYS failed (MISSING_PICKUP_PROMPT), while a broken inline short-divider prompt passed (false positive). Root cause: the rule 91 self-check text said "scan for the exact string `═══ PICKUP PROMPT ═══`," and the validator author implemented that literally. Telemetry showed MISSING_PICKUP_PROMPT dominating recent VALIDATION_FAIL rows. FIX: (a) validator Gate 1 rewritten to detect the block structurally (47-char divider → header line → closing divider); (b) new Gate 4b catches a MISSING task id (`Pick up task — foo` with no `#<id>`), which was the real violation in the final-notice handoff that prompted this RCA; (c) this rule's self-check rewritten to reference the programmatic gate + structural test instead of the inline substring. Verified live: canonical prompt now PASSES, missing-task-id prompt now FAILS with MISSING_TASK_ID. Also caught a build/src divergence (build had been hand-edited with extra R29/R120/R01/R02 gates not in src) — both now synced.
2026-07-13 (evening) — Ruben directive: the agent shipped a pickup prompt with bare "idea #17537" in a prose paragraph with no bracket. The rules SAID every idea needs brackets, but the template had "idea #" bare on line 34 and there was no mechanical gate. FIX: (a) template line 34 now shows `idea #M [deployed|executing|...]` with brackets; (b) new hardfloor ban: NO BARE IDEA NUMBERS anywhere in result — not just the pickup prompt block; (c) new manual TAG-SCAN GATE (Python one-liner or manual scan) that mechanically catches bare numbers before shipping; (d) reconcile-evidence quoting requirement (parenthetical showing the tool+return) to prevent fake tags; (e) rule 29 audit item 5 now cross-checks bare numbers; (f) rule 267 GATE B now requires the evidence quote + adds bare-number=self-fail clause. This is the third pass at the same problem (disposition tags added 7/2, refined 7/13 morning, mechanical gate added 7/13 evening) — the escalation tree is: tag format → [approved:autonomous] banned → mechanical tag-scan gate. Root cause of the failure: the agent reads the tag requirement as applying to the "Open threads" and "Reference IDs" sections only, not to prose descriptions in "Where we left off." The mechanical gate (Python one-liner scanning the WHOLE result) catches prose sections too.
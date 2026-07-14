# 91 — Every attempt_completion MUST end with a ═══ PICKUP PROMPT ═══ block

Permanent hardfloor rule. Source: 2026-05-19 Ruben directive.

## BINARY GATE

**An `attempt_completion` is INVALID unless `result` ends with the `═══ PICKUP PROMPT ═══` block.** No pickup prompt = do not ship.

The ONLY exemption: `result` begins with "Not a task completion — conversational/read-only only" AND zero system-state changes occurred.

## THE DIVIDER — copy mechanically, do NOT retype

```
═══════════════════════════════════════════════
```

47 characters of U+2550 (BOX DRAWINGS DOUBLE HORIZONTAL). NOT ASCII equals. NOT hyphens. Copy the line above.

## Required template

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════

Pick up task #<real task id> — <one-line topic>.

Where we left off (verified <real PT timestamp>):
- <1-3 bullets of current state with IDs>
- <key resource: ticket #, idea #, file path>

Open threads to drive next:
1. #<real idea number> [<disposition>] — <actionable item>
2. #<real idea number> [<disposition>] — <next item>

If genuinely no open threads (all work done inline per rule 29), write: None — all work done inline per rule 29 Gate 0.

Reference IDs:
- Ticket: <number>
- Ideas filed: #<id> [disposition], ...
- Ideas closed: #<id> [disposition], ...
- Files touched: <paths>

When done, append a row to cline_task_ledger.md per rule 07 and run order 66.
═══════════════════════════════════════════════
```

## Disposition tags — every #NNNN MUST carry one

| Tag | Meaning |
|---|---|
| `[deployed]` | Shipped + verified in prod — thread closed |
| `[executing]` | Executor is building it now — thread closed |
| `[queued]` | Approved, waiting on cron — thread closed, check later |
| `[blocked]` | Failed/stuck — ACT: fix or re-file |
| `[proposed]` | Filed, not yet approved — ACT: approve/reject |
| `[rejected]` | Closed, dismissed — thread closed |
| `[superseded]` | Replaced by newer idea — thread closed |

## Hardfloor bans — ALL optional until violated, then permaban

- **NO fake idea numbers:** Never write `IDEA-001`, `IDEA-002`, `IDEA-003`. Always call `create_idea` for real integer IDs. Invented idea numbers are poison — Ruben cannot look them up in the orchestrator.
- **NO bare idea numbers:** Every `#NNNN` anywhere in `result` (prose, bullets, cross-refs) MUST have a `[disposition]` bracket.
- **NO placeholders:** Never emit `#NNNN`, `#0000`, `#XXXX`, `<task_id>`, `<timestamp PT>`.
- **NO missing open threads:** "Open threads to drive next:" section MUST appear. Write "None — [reason]" if empty.
- **NO PICKUP-BY-REFERENCE:** The ═══ block must be INLINE in `result`, not "see handoff file."
- **NO wait-state phrases:** "hold until Ruben confirms," "wait before acting," "pause until."

## Self-check before attempt_completion

1. Does `result` end with the ═══ PICKUP PROMPT ═══ block?
2. Is the divider exactly 47 U+2550 chars (copied, not retyped)?
3. Does `Pick up task #[real id]` appear with a real integer id?
4. Scan ENTIRE `result` for `#NNNN` — does EVERY one have a `[disposition]` bracket?
5. Are ALL idea numbers real integers from `create_idea`? Any `IDEA-001` = FAIL.
6. Does "Open threads to drive next:" appear?
7. Does "Reference IDs:" cite every idea from the body?
8. No literal placeholders (`#NNNN`, `<...>`)?

## Cross-refs

- Rule 29 — Gate 0: act, don't defer. Pre-completion audit item 5b (TAG-SCAN).
- Rule 267 GATE B — reconcile before completion, tag live executor state.
- Rule 38 — Ruben-asked = autonomous tier minimum.
- _RULE_TREE.md Gate 9 — pre-completion gate.

## Source incidents

2026-05-19 — First hardfloor. Ruben: "in every single task completed window need a pickup prompt."
2026-07-02 — Wrong divider (3 chars instead of 47). Divider section rewritten.
2026-07-03 — Self-contradiction: 39 equals ≠ 47 U+2550. Corrected all references.
2026-07-13 — Bare idea numbers in prose. Added disposition tags + TAG-SCAN.
2026-07-14 — Regression: agents invented IDEA-001 format, skipped pickup prompts entirely. Root cause: rule bloated to 151 lines, agents ignored it. Trimmed to ~90 lines, added fake-ID ban. Also: `clinerules_validate_completion` MCP tool does NOT exist — the self-check is the ONLY gate.
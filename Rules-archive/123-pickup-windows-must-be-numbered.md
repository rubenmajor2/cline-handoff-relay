# 123 — Multi-window pickup prompts MUST be numbered (Window 1 / Window 2 / ...)

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="123")` or `clinerules_search(query="pickup window number")`. Companion to .clinerules/91.

## The bright-line rule

**When an `attempt_completion` contains more than one PICKUP PROMPT block, each block MUST start with an explicit window number** in one of these accepted forms:

- `PICKUP PROMPT — Window 1: <subject>`
- `Window 1 — <subject>`
- `1 — <subject>`
- `═══ PICKUP WINDOW 1: <subject> ═══`

The number MUST appear in the divider line so Ruben can tell at a glance which window each block is for. Subject after the dash gives him a one-glance summary.

## Why this exists

When Cline ships multiple pickup prompts in one completion, Ruben needs to paste each one into a different Cline window so they run in parallel. Without numbers, the prompts blur into each other when scrolling — "is this Window 3 or Window 4?" — and he has to count divider blocks to figure out which is which. Numbering eliminates that friction.

Source incident: 2026-05-28 07:18 PT. End of stranded-EA backfill chain. Cline shipped 5 pickup prompts back-to-back labeled only with subject lines (no W1/W2). Ruben directive verbatim: *"cline rule when you give multiple pickup windows you need to give a number, i.e. Window 1 or 1 - Subject, etc..."*

## Required shape

```
═══════════════════════════════════════════════
PICKUP PROMPT — Window 1: <Short subject in Ruben voice>
═══════════════════════════════════════════════
Pick up: <one-line description>

Where we left off (verified <timestamp PT>):
- <state>

First tool call: <exact tool + args>

Open threads to drive next:
1. <action>
...

Reference IDs:
- <IDs>

Cross-refs:
- .clinerules/<...>

When done, append a row to cline_task_ledger.md per rule 07 and run order 66.
═══════════════════════════════════════════════
```

The Window number must appear:
1. In the title line of the divider block (top divider) — required
2. Optionally repeated in the closing divider for very long prompts — nice-to-have

## Numbering rules

- Start at Window 1, increment by 1.
- If a single completion has only ONE pickup prompt, the number is OPTIONAL (no parallel-window confusion possible). Subject-only labeling per .clinerules/91 is fine.
- If a single completion has 2+ pickup prompts, ALL of them get numbers — no mix-and-match.
- The number resets to 1 every `attempt_completion`. Don't carry numbering across tasks; that's only confusing.

## Cross-refs

- `.clinerules/91` — every-completion-needs-pickup-prompt (shape, divider, body, no-PICKUP-BY-REFERENCE rule)
- `.clinerules/29 v3` — agents-act-on-confidence-tier (the pickup prompts only contain work that the next agent can do, not human-policy items)
- `.clinerules/38` — Ruben-asks = autonomous (each pickup window points at an autonomous-approved idea or has a clear hardfloor reason)

## Source incident

2026-05-28 — initial. Source: 5-window EA-stranded backfill handoff at 07:18 PT. Ruben directive verbatim above.

## Last updated

2026-05-28 — initial.

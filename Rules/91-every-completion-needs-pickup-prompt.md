# 91 — End completions with a proper PICKUP PROMPT

Hardfloor. 2026-05-19.

## The BARE MINIMUM (minimum delivery — skip everything else and still get this right)

Every `attempt_completion` MUST have all 5 of these, or DON'T SHIP:

1.  **PICKUP PROMPT block** at the very end of `result`
2.  **Real idea numbers** from `create_idea` (NEVER `IDEA-001`, `IDEA-002` — that's fake)
3.  **`[bracket]` on every `#NNNN`** everywhere in `result` — prose, pickups, bullets, all of it
4.  **Open threads section** — even if `None`
5.  **Reference IDs section** — every idea filed or closed, with its bracket

## Pickup prompt template (copy the divider mechanically — do NOT retype it)

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════

Pick up task #<real task id> — <one-line topic>.

Where we left off (verified <real PT timestamp>):
- <1-3 bullets — every idea ref gets a bracket>

Open threads to drive next:
1. #<real idea number> [<disposition>] — <actionable item>
...or "None — [reason]"

Reference IDs:
- Ideas filed: #<id> [disposition], ...
- Ideas closed: #<id> [disposition], ...
- Files touched: <paths>

When done, append to cline_task_ledger.md per rule 07, run order 66.
═══════════════════════════════════════════════
```

### Disposition tags (use these or nothing)

`[deployed]` | `[executing]` | `[queued]` | `[blocked]` | `[proposed]` | `[rejected]` | `[superseded]`

## How to follow this (the ONLY steps)

1.  Build your prose result. Answer Ruben's questions.
2.  Scan the ENTIRE `result` for `#NNNN`. Every one gets a `[tag]`.
3.  Every `#NNNN` is from `create_idea` — real integer IDs only.
4.  Append the ═══ PICKUP PROMPT block from the template above.
5.  Call `attempt_completion` with the enriched result.

That's it. No special tools, no validators — just do it.

## Cross-refs
- Rule 29 Gate 0 — act now, don't defer
- Rule 267 GATE B — reconcile ideas before completion
- _RULE_TREE.md Gate 9 — pre-completion check

## Source
2026-05-19 Ruben: "every completed task window needs a pickup prompt."  2026-07-14 Ruben: agents inventing `IDEA-001` format + shipping no pickup block → regressed. Rule trimmed from 151 lines of walls-of-text to this tight format. The template is FIRST, the bans are SECOND, agents with 2 seconds of attention can still obey.
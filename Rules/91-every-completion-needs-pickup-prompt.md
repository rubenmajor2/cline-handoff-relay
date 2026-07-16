# 91 — MUST end with PICKUP PROMPT block

Hardfloor. 2026-05-19.

**The PICKUP PROMPT block MUST end every `attempt_completion` result.** No exceptions for status reports, investigations, bug analysis, or "read-only" tasks. The ONLY exemption: zero system-state changes AND the result starts with `"Not a task completion — conversational/read-only only"`.

## Template (copy divider — do NOT retype)

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════

Pick up task #<real task id> — <topic>.

Where we left off (verified <PT timestamp>):
- <bullet — every #NNNN gets a [bracket]>

Open threads to drive next:
1. #<id> [disposition] — action
...or "None — reason"

Reference IDs:
- Ideas filed: #<id> [tag], ...
- Ideas closed: #<id> [tag], ...
- Files touched: <paths>

When done, append to cline_task_ledger.md (rule 07), run order 66.
═══════════════════════════════════════════════
```

## Hardfloor bans

| Ban | Why |
|-----|-----|
| **NO fake IDs** (`IDEA-001`) | Must be real `create_idea` integer |
| **NO bare `#NNNN`** | Every idea number gets `[deployed|executing|queued|blocked|proposed|rejected|superseded]` |
| **NO unfiled open threads** | Every open-thread item MUST cite a real filed idea `#NNNN [tag]`, OR be explicitly marked `(human-only decision — no idea)`. A thread with no idea number is undone work: file it via `create_idea` BEFORE shipping (2026-07-15 violation: 5 open threads shipped with zero filed ideas — the bare-number scan passed trivially because no numbers existed) |
| **NO missing open-threads** | Section mandatory — write "None — reason" if empty |
| **NO "pure Q&A" self-exemption** | Status reports, investigations, bug analysis, diagnostics are NOT Q&A |
| **NO `[approved:autonomous]` tags** | Ambiguous between executing/queued. Banned in final pickup prompts — must be replaced by verified live-state tag from reconcile call per rule 267 GATE B |
| **NO placeholders** | `#NNNN`, `<...>`, `#0000` are banned |
| **NO pick-up-by-reference** | Block must be inline in result, not in a separate file |

## Quick check before shipping

1. Does result end with ═══ PICKUP PROMPT ═══ block?
2. Is divider exactly 47 U+2550 chars?
3. Every `#NNNN` in entire result — does it have a `[tag]`?
4. Any `IDEA-001`, `#0000`, `<real_idea_number>`? → FAIL
5. Open-threads section present? Reference IDs present?
6. Does EVERY open-thread item have a filed idea `#NNNN [tag]` or `(human-only decision — no idea)` marker? If any item has neither → STOP, call `create_idea` first

## Orders of magnitude

If rule 91 is **1,000 words** → agents skip it. If it's **this short** (~400 words) → agents can obey. The pickup prompt is the LAST thing the agent writes — the one most prone to omission on context pressure. A SHORT rule survives context pressure. Verbose rules are ignored.

## Cross-refs

- Rule 29 — act, don't defer
- Rule 267 — reconcile ideas before completion
- _RULE_TREE.md Gate 9 — pre-completion gate

## Source

2026-05-19 Ruben directive. 2026-07-14: 3 violations in one window (no pickup block, bare #NNNN, no open threads). Root cause: steering injection's "pure Q&A exception" + bloated 151-line rule. Both fixed.
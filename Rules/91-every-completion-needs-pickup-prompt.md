# 91 — MUST end with PICKUP PROMPT block

Hardfloor. 2026-05-19. 2026-08-01: `[queued]` disposition BANNED (Ruben directive — queued is a parking-lot excuse, not a state). See .clinerules/161-ideas-never-queued.

**The PICKUP PROMPT block MUST end every `attempt_completion` result.** No exceptions for status reports, investigations, bug analysis, or "read-only" tasks. The ONLY exemption: zero system-state changes AND the result starts with `"Not a task completion — conversational/read-only only"`.

## Do NOT retype the divider. Use the template below.

Copy the 47-char U+2550 divider from the template block below — do NOT retype it from memory. Every observed rule-91 failure came from a model retyping the divider and getting the glyphs wrong.

**Then verify before shipping: call `clinerules_validate_completion`** with BOTH `result_text` and `task_prompt`. Passing `task_prompt` turns on the coverage gate: every `#NNNN` enumerated in the original task must appear in the result, or the gate names the missing ids.

## The gate is STRUCTURAL now. A FAILURE writes a file.

`clinerules_validate_completion` used to be advisory: it printed failures and did nothing, so agents read `BARE_IDEA_NUMBERS` and called `attempt_completion` anyway. As of 2026-07-30 (#20251) a FAILURE **writes a gate file**; a PASS **deletes it**.

Two-call sequence, every completion, no exceptions:

1. `clinerules_validate_completion(result_text, task_prompt, task_id)` - fix every failure it names, then call it again. Repeat until ALL PASSED.
2. `clinerules_check_gate(task_id)` - must return `GATE CLEAR`.

**If `clinerules_check_gate` returns `GATE BLOCKED`, calling `attempt_completion` is a hardfloor violation.** The block names the exact failures. Fix them, re-validate, re-check. Never ship past a blocked gate.

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

## Valid dispositions (NO `[queued]` — 2026-08-01 ban)

| Tag | Meaning |
|-----|---------|
| `[deployed]` | Live in production, verified |
| `[executing]` | In active motion — being worked THIS session or by a live agent (approved ideas are EXECUTING, not queued) |
| `[awaiting_review]` | Ready for review but not yet reviewed — NOT a parking state; must carry a review deadline |
| `[blocked]` | Stuck on a real obstruction — name the obstruction |
| `[proposed]` | Not yet approved |
| `[rejected]` | Denied |
| `[superseded]` | Replaced by a newer idea |

`queued` is NOT a valid disposition. An approved idea is `[executing]`. An idea sitting "in the queue" is either `[executing]` (active motion) or `[blocked]` (real obstruction named). Parking an idea as queued so it sits indefinitely is a hardfloor violation (Ruben directive 2026-08-01, rule 161).

## Hardfloor bans

| Ban | Why |
|-----|-----|
| **NO `[queued]` tags** | Banned 2026-08-01. Approved = executing. No parking lot. |
| **NO fake IDs** (`IDEA-001`) | Must be real `create_idea` integer |
| **NO unfiled-but-plausible IDs** | Every `#NNNN` you cite as filed must have come back from a `create_idea` call **in THIS session**. Inventing a plausible sequential integer is the worst violation shape: the id space is dense, so a made-up number usually resolves to a REAL but UNRELATED idea, and every syntax gate passes. If you did not see the id in a `create_idea` return this session, you do not have it (2026-07-28: agent invented #19898-#19904, all seven existed, all seven were Argus/email/Artemis work, validator said ALL PASSED) |
| **NO bare `#NNNN`** | Every idea number gets `[deployed|executing|awaiting_review|blocked|proposed|rejected|superseded]` |
| **NO unfiled open threads** | Every open-thread item MUST cite a real filed idea `#NNNN [tag]`, OR be explicitly marked `(human-only decision — no idea)`. A thread with no idea number is undone work: file it via `create_idea` BEFORE shipping (2026-07-15 violation: 5 open threads shipped with zero filed ideas — the bare-number scan passed trivially because no numbers existed) |
| **NO tag-without-number** | A `[tag]` written next to an open-thread item with NO `#NNNN` beside it is FAKE PROVENANCE — worse than a bare number, because it implies a filed idea that does not exist (2026-07-22 violation #14: 4 open threads shipped `[proposed]` with zero `create_idea` calls; agent pattern-matched "I have tags" instead of "I have filed IDs"). Mechanical test per item: "what integer idea ID backs this tag?" None → `create_idea` first, or mark `(human-only decision — no idea)` |
| **NO missing open-threads** | Section mandatory — write "None — reason" if empty |
| **NO "pure Q&A" self-exemption** | Status reports, investigations, bug analysis, diagnostics are NOT Q&A |
| **NO `[approved:autonomous]` tags** | Ambiguous between executing/queued. Banned in final pickup prompts — must be replaced by verified live-state tag from reconcile call per rule 267 GATE B (reconcile_ideas no longer emits approved; it emits executing) |
| **NO placeholders** | `#NNNN`, `<...>`, `#0000` are banned |
| **NO pick-up-by-reference** | Block must be inline in the `attempt_completion` **`result`** parameter string itself — not a separate file, and not `task_progress` or any other tool parameter (2026-07-22 violation #15: agent wrote a structurally-perfect block but put it in `task_progress`; `result` had zero rule-91 structure, so from Ruben's read it was "nowhere near a rule 91") |

## Quick check before shipping

1. Extract ONLY the `result` string in isolation (ignore `task_progress` and every other parameter) — does THAT string end with ═══ PICKUP PROMPT ═══ block?
2. Is divider exactly 47 U+2550 chars?
3. Every `#NNNN` in entire `result` — does it have a `[tag]`?
4. Does ANY `#NNNN` carry `[queued]`? → FAIL, re-tag as `[executing]` or `[blocked]`
5. Any `IDEA-001`, `#0000`, `<real_idea_number>`? → FAIL
6. Open-threads section present? Reference IDs present?
7. Does EVERY open-thread item have a filed idea `#NNNN [tag]` or `(human-only decision — no idea)` marker? If any item has neither → STOP, call `create_idea` first
8. **Provenance check — for EACH `#NNNN`, name the tool call it came from.** A `create_idea` return this session, a reconcile call, or the task prompt. If you cannot point at one, the number is fabricated. Run `clinerules_validate_completion` and READ THE IDENTITY ECHO: it prints the real DB title of every id you cited. If a printed title does not match what you wrote beside that number, you cited the wrong idea.


## Orders of magnitude

If rule 91 is **1,000 words** → agents skip it. If it's **this short** (~400 words) → agents can obey. The pickup prompt is the LAST thing the agent writes — the one most prone to omission on context pressure. A SHORT rule survives context pressure. Verbose rules are ignored.

## Cross-refs

- Rule 29 — act, don't defer
- Rule 161 — ideas never queued (2026-08-01 Ruben directive)
- Rule 267 — reconcile ideas before completion
- _RULE_TREE.md Gate 9 — pre-completion gate

## Degraded-mode escape hatch (2026-08-08, idea #24995)

**Degraded-mode escape hatch:** if the agent has attempted a valid PICKUP PROMPT 2+ times AND all MCP `create_idea` calls fail with documented transport errors, the agent may use a pre-allocated pool ID (from the reserved pool, IDs 25002-25029) and complete. The pool slot is burned by updating its title to the actual topic. A sync process later reconciles.

Conditions (ALL must be true):
1. The agent has attempted at least 2 valid PICKUP PROMPT blocks that the transport layer dropped.
2. `create_idea` calls via `ruben-orchestrator` MCP fail with documented errors (not silent success).
3. The agent uses the `/var/www/emtskills/scripts/burn_pool_id.sh` helper to consume the next available pool slot.
4. The agent cites the burned pool ID in the PICKUP PROMPT with `[executing]` tag and the note "(pool #<id> burned for transport-degraded completion)".

This is a LAST RESORT. If `create_idea` works, the agent MUST file ideas normally. Pool IDs are a finite resource (28 slots, 25002-25029).

## Source

2026-05-19 Ruben directive. 2026-07-14: 3 violations in one window (no pickup block, bare #NNNN, no open threads). Root cause: steering injection's "pure Q&A exception" + bloated 151-line rule. Both fixed. 2026-07-22 violation #15 (per Cline_Obedience.md): agent shipped a structurally-correct PICKUP PROMPT block inside `task_progress` instead of `result` — added explicit ban + quick-check step 1 rewording to gate on `result` specifically. 2026-08-01: `[queued]` disposition banned by Ruben directive — queued was being used as an excuse to park ideas indefinitely instead of implementing them. reconcile_ideas no longer derives `[queued]` (approved → executing, ready_for_review → awaiting_review, default → unknown). See rule 161.

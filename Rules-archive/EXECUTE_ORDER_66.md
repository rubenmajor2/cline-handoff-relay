# EXECUTE ORDER 66 — Cline Window Wrap-Up Protocol

> *"It will be done, my Lord."*

When Ruben says **"execute order 66"** in any Cline window (Mac or Artemis), this
is the protocol. The phrase is the trigger. No clarifying questions.

This is the deterministic wrap-up pattern for closing out an open Cline task
cleanly so nothing falls on the floor when the window closes. It enforces the
existing rules (29 act-on-confidence, 12 cross-chain Q-cards, 03 Resume Kit,
07 task ledger) in one prescribed order.

Lives in `~/Documents/Cline/Rules/` so the cline-handoff-relay cron auto-syncs
it to Artemis. Loaded by every Cline session on both boxes via the global
.clinerules path.

## Trigger

Ruben types one of:

- `execute order 66`
- `order 66`
- `wrap this up`
- `close this out`
- `drain this window`

Any of those, the agent immediately runs the protocol below. Nothing else.

## The protocol — six steps in this order

### Step 1. Take green-tier actions, then report

Per **rule 29** (agents act on confidence tier): anything **high-confidence +
reversible + small blast radius** that's still pending in this thread — DO IT.
Do not file it as a Q-card. Do not ask for confirmation. Examples:

- Single-row DB UPDATE with a known correct value
- Calling an existing helper (`widget_real_handoff()`, `ChatToTicket::create...`)
- Re-running an existing cron with the row's identifier

Each action gets logged to `orchestrator_event_log` with `severity=info`,
`event_type` matching the class, payload showing `before_state` / `after_state`
/ `reversal_command`.

Hard exclusions per rule 29 (these stay Q-cards regardless of confidence):
- External email or SMS to students, regulators, attorneys, accreditors
- Charging or refunding cards
- Lifting Moodle suspensions
- Altering QB invoices or payment_suspensions
- Posting to public sites
- Anything regulator/grievance-bound (rule 242 hard-block)

### Step 2. File approved ideas

Anything green-tier that's a **recurring pattern worth permanently approving**
gets filed as an `orchestrator_ideas` row via the `ruben-orchestrator` MCP
`create_idea` tool. Don't ask. Just file with:

- `domain` — `revenue` / `academic` / `technical` / `compliance` / `operations` / `student_ops`
- `priority` — P0/P1/P2/P3 per real impact
- `estimated_impact` — one line
- `estimated_effort` — one line
- `description` — full body with source incident + acceptance test

Lands at `/emtskills/routes/orchestrator_ideas.php?status=pending` for Ruben's
morning triage.

### Step 3. File Q-cards for everything else that's a policy decision

Per **rule 12** (cross-chain policy questions go on `ruben_questions`).
Anything that is one of:

- Medium confidence (heuristic match, no learned-pattern row, confidence 0.50-0.85)
- Irreversible (any of the rule-29 hard exclusions)
- Affects 2+ chains
- Is a recurring pattern that will hit again
- Commits to a policy across surfaces

Files as `admin_portal.ruben_questions` row with the **rule-05 question-card
format** in the body:

```
**QN. [5-8 word policy name]**

- **What yes does:** one sentence
- **What no does:** one sentence
- **Scope:** included + excluded with 2-3 examples
- **Risk if wrong:** one sentence + safety net
- **Rollback if you change your mind:** one sentence

**Yes/No:** [actual question, under 20 words]
```

Required columns:
- `source` = `cline_<task_slug>` (greppable per-task)
- `source_ref` = umbrella task slug
- `category` — `system` / `ops` / `dev`
- `priority` — `medium` default; `high` if 5+ chains affected; `critical` only for student-facing blocking
- `question_type` — `choice` / `yes_no` / `freetext`
- `status` — `pending`
- `context_json` — `{"affected_chain_ids": [...], "affected_chain_count": N, "task_origin": "<slug>", "options": [...], "default": "<recommended>"}`

Lands at `/emtskills/routes/ruben_questions.php?status=pending`.

### Step 4. File retroactive Q-cards for inline-settled decisions

Per **rule 12**: anything settled inline this thread that fits the Q-card
criteria above (cross-chain, recurring, policy) gets filed retroactively with
`status='answered'` + `answer` text + `answered_at` timestamp. Reasons:

1. Future agents see the rationale + options that were considered
2. The chain effects are visible on the portal next to the chains
3. Greppable precedent: `SELECT * FROM ruben_questions WHERE source='cline_<task>' AND title LIKE '%POLICY%'`

### Step 5. attempt_completion using the Rule 03 Resume Kit format

Per **rule 03**: every wrap-up `attempt_completion.result` follows:

```
TASK #<task_id> — <3–7 word topic>

WHAT WE WERE DOING
<1–2 sentences>

WHAT WE ACTUALLY DID
- <concrete action 1>
- <concrete action 2>
- <concrete action 3>

CURRENT STATE
<1–3 lines: what's now true that wasn't before>

TO RESUME THIS TASK LATER
Paste into fresh Cline: "pick up task #<task_id> from where we left off — <one-line cue>"

OPEN THREADS / NEXT MOVES (if any)
- <thing discussed but not done>
- <thing still needs review>

FILES TOUCHED (if any)
- <absolute path>
- <absolute path>

IDEAS FILED (this wrap-up)
- idea #<N> — <title>

Q-CARDS FILED (this wrap-up)
- ruben_questions #<N> — <title> [pending|answered]

GREEN-TIER ACTIONS TAKEN (this wrap-up)
- <action> — <reversal command>
```

### Step 6. Append one row to cline_task_ledger.md

Per **rule 07** (task_id discipline): single canonical task_id, no composites.
Append to `~/Documents/Cline/cline_task_ledger.md`:

```
- YYYY-MM-DD HH:MM | #<task_id> | <topic> | <status> | <one-line cue>
```

Status pick:
- `done` — everything filed, nothing pending Ruben
- `open` — Q-cards pending decision; resume after Ruben answers
- `blocked` — waiting on something external (regulator, vendor, payment)
- `abandoned` — Ruben said never mind / scope changed

## What the protocol does NOT do

- Does NOT ask Ruben yes/no questions during wrap-up. Ambiguity → Q-card.
- Does NOT send external comms autonomously (rule 29 hard exclusions).
- Does NOT hand-edit ai_compiled_rules — those go through PromptRuleCompiler protection.
- Does NOT close the VS Code window. Just produces the structured handoff. Ruben closes the window.

## Verbal callouts that mean Ruben changed his mind mid-protocol

- "Hold on" / "Wait" / "Stop" — pause, ask what to skip
- "Just file it as a Q-card" — skip step 1 for this one item, file under step 3
- "Don't bother" — drop it entirely, don't even ledger it

## Why "Order 66"

Ruben asked. It's a Star Wars reference; in canon, it's the standing order
clones executed instantly without question. The point of the joke: this
protocol fires deterministically the moment the phrase is said, no ambiguity,
no clarifying questions, just the prescribed sequence. The lethal-precision
flavor is appropriate for "drain this window cleanly before the V8 ext-host
balloons take it down" (rule 97).

## Cross-references

- Rule 03 — Resume Kit format
- Rule 05 — Q-card question-card format (5 fields)
- Rule 07 — task_id discipline (no composites)
- Rule 12 — cross-chain policy questions go on ruben_questions
- Rule 16 — maxConsecutiveMistakes threshold (closing tasks lowers exposure)
- Rule 17 — force-subagent-use on research / multi-step builds
- Rule 29 — agents act on confidence tier (act + report vs Q-card vs report-only)
- Rule 96 — Cline window discipline (Mac/Artemis storm pattern)
- Rule 97 — extension host OOM (why open tasks balloon parse-on-resume)

## Last updated

2026-05-07 — initial. Source: Ruben asked for the wrap-up pattern as a
referenceable doc rather than a one-shot prompt. Ships with rule 30 in the
same session.

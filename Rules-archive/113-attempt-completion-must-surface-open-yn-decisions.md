# 113 — Every attempt_completion must surface open Y/N decisions inline as Q-cards (with recommendations)

Permanent rule. Workspace-scoped. Source: 2026-05-23 20:54 PT during task #cline_agent_buildout_C_inbound_moodle_comms_2026-05-23 wrap-up (idea #6161 P0 ship). Ruben directive verbatim:

> *"Give Q cards here if any with Y/N simple and recommended. Need that per cline rules. Need that put in cline rules (which it should be already or enhanced properly)."*

Companion to .clinerules/05 (Q-card format), .clinerules/12 (cross-chain Q-cards on `ruben_questions`), .clinerules/29 (act on confidence tier), .clinerules/91 (every-completion-needs-pickup-prompt), .clinerules/109 (every deliverable needs disposition status). This rule is the **inline-decision-surfacing layer** those rules implicitly assumed.

## The bright-line rule

**Every `attempt_completion.result` that wraps up a task with at least ONE pending decision Ruben (or staff) could answer with a yes/no MUST surface those decisions INLINE in the result body, formatted as Q-cards per .clinerules/05, with an explicit recommendation.**

If the task ended cleanly with nothing pending decision-wise → no Q-card section needed (state "No open Y/N decisions").

If the task ended with ANY of the following → it's a Q-card:
- A function/feature shipped that's CLI-callable today but irreversible-when-executed, and Ruben/Vicky/Jon needs to decide whether to fire it now
- A choice between two valid next steps where the right answer depends on policy (do A vs do B, ship now vs wait, send to Vicky vs Jon)
- An action that touches the .clinerules/29 hard-exclusion list (money, regulator, student-facing comms, Moodle gradebook, QB invoice) and could fire next session
- A scope question about the next chain (ship the routes UI next, or do the backfill scan first, or both)

## Required placement

Add a new section to the attempt_completion Resume Kit (between OPEN THREADS and the PICKUP PROMPT) titled:

```
OPEN Y/N DECISIONS (answer in this thread to unlock next moves)
```

Each Q-card in this section follows the .clinerules/05 5-field format:

```
**QN. [5-8 word policy name]**
- **What yes does:** one sentence
- **What no does:** one sentence
- **Scope:** included + excluded
- **Risk if wrong:** safety net
- **Rollback if you change your mind:** one sentence
- **Recommendation:** [yes | no | <answer>], because <one-line reason>.

**Yes/No:** [actual question, under 20 words]
```

The **Recommendation** field is mandatory under this rule (rule 05 lists it as optional inline; rule 113 makes it required). It must include the verdict + a one-line reason.

## Pair with `ruben_questions` portal row when cross-chain

If the decision is cross-chain / policy-grade / will recur (see .clinerules/12 criteria), ALSO file a `ruben_questions` row at status='pending' with the same Q-card body, so the portal queue has it. Reference the new q-card row id in the inline section: `(also filed as ruben_questions #NNNNN per .clinerules/12)`.

If the decision is single-task / one-shot / won't recur, inline-only is sufficient — DO NOT pollute `ruben_questions`.

## The 3-card cap (carries from rule 05)

Maximum 3 Q-cards in a single attempt_completion. If more, the task wasn't decomposed enough — either (a) split into multiple completions, or (b) merge related questions into a single broader policy Q-card.

## Recommendation field — how to write it

The recommendation must:
1. Pick a side (yes / no / option-A / option-B). NOT "depends" or "either is fine."
2. Cite the evidence in one line ("per .clinerules/29 reversible+small-blast = ship", "QB invoice already pushed and customer email validated", "deadline is Sunday so wait risks default").
3. Be a defensible "if Ruben doesn't answer, I default to this" call. The recommendation IS the default if silence.

## What this rule does NOT do

- Doesn't require Q-cards when the task is pure read-only Q&A (nothing happens regardless of answer)
- Doesn't replace .clinerules/12's portal Q-card flow — this rule says ALSO surface inline; rule 12 still gates which Q-cards belong on the portal
- Doesn't require Q-cards for already-completed actions (those are dispositions per rule 109, not Y/N)

## Self-check before any attempt_completion

Ask: *"If Ruben reads this completion on his phone in 15 seconds, can he yes/no every open decision without scrolling to a portal or running a query?"*

If no, the Q-card section isn't ready. Rewrite.

## Source incident

2026-05-23 20:54 PT — End of register_prospect_handler v5 ship (idea #6161 P0). I shipped 3 ACTION functions (send_payment_link / invoice_anyway / send_clarification) that are CLI-callable today but irreversible-when-executed (real QB API calls + real outbound emails). The completion listed them with dispositions (rule 109 compliant) but did NOT surface the real Y/N decision — "Run Vicky's 3 live sends NOW?" — as an inline Q-card. Ruben caught it: "Give Q cards here if any with Y/N simple and recommended. Need that per cline rules. Need that put in cline rules."

The decision was real, time-sensitive (Tayden 5/25 deadline = 48 hours), had a clear yes/no shape, and would have been easy to answer on a phone — but the prior wrap-up forced him to mentally translate "shipped + Vicky-clickable" into "do I want this fired tonight?"

## Last updated

2026-05-23 20:55 PT — initial. Rule 113. Filed during the same task that surfaced the gap, per rule 38 (Ruben-asked = autonomous-or-shipped, codified as a rule fix here because the directive was meta about how Cline should ALWAYS communicate).

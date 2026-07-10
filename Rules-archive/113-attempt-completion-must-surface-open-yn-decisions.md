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

## Two valid formats — pick per question complexity

### Format A — SIMPLE INLINE (default for 1-line questions)

Use when the decision is a single-axis pick (which-box, ship-now-vs-wait, A-vs-B). 1-2 lines per Q. This is the format Ruben asks for "Y/N simple and recommended" — keep it phone-readable.

```
**Q1. Cline router target box?** SMS-Mac vs Artemis vs RunPod. **Rec: SMS-Mac** (already 24/7, M1 Max headroom, Artemis tunnel-wedged).
**Q2. Ship FPM reload now?** **Rec: No** (Sonnet flip already live without it, FPM corrupts this window).
**Q3. Flavor A for prebuilder?** **Rec: Yes** (already filed #6513 approved, gates only on backtest signal).
```

Each Q-card in Format A MUST have:
- Short title (≤8 words)
- Concrete options (the two-or-three things being chosen between)
- **Rec:** [yes | no | option-name] + one parenthetical reason

This is enough — don't expand to 5 fields if 1 line suffices. Phone-readable wins.

### Format B — FULL 5-FIELD (for policy/irreversible/cross-chain)

Use when the decision IS irreversible / touches money or regulator / sets policy across chains. Pair with `ruben_questions` portal row per rule 12.

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

The **Recommendation** field is mandatory in BOTH formats (rule 05 lists it as optional inline; rule 113 makes it required).

## When to pick A vs B

- Question is 1 line, no policy implications, decided in 5 seconds → **Format A**
- Question affects 2+ chains or irreversible (money/regulator/student-email) → **Format B + ruben_questions row per rule 12**
- Mixed batch (some simple, some policy) → mix freely; group all Format A's first, then Format B's

## The 3-card cap (carries from rule 05)

Maximum 3 Q-cards in a single attempt_completion. If more, the task wasn't decomposed enough — either (a) split into multiple completions, or (b) merge related questions into a single broader policy Q-card.

**EXCEPTION:** when the cap is exceeded because Ruben himself raised multiple questions in one feedback message (e.g. 5 yes-decisions in one paragraph), surface ALL of them as Format-A (since each is presumably simple), no cap.

## Recommendation field — how to write it

The recommendation must:
1. Pick a side (yes / no / option-A / option-B). NOT "depends" or "either is fine."
2. Cite the evidence in one line ("per .clinerules/29 reversible+small-blast = ship", "QB invoice already pushed and customer email validated", "deadline is Sunday so wait risks default").
3. Be a defensible "if Ruben doesn't answer, I default to this" call. The recommendation IS the default if silence.

## Pair with `ruben_questions` portal row when cross-chain

If the decision is cross-chain / policy-grade / will recur (see .clinerules/12 criteria), ALSO file a `ruben_questions` row at status='pending' with the same Q-card body (use Format B). Reference the new q-card row id in the inline section: `(also filed as ruben_questions #NNNNN per .clinerules/12)`.

If the decision is single-task / one-shot / won't recur, inline-only is sufficient — DO NOT pollute `ruben_questions`.

## What this rule does NOT do

- Doesn't require Q-cards when the task is pure read-only Q&A (nothing happens regardless of answer)
- Doesn't replace .clinerules/12's portal Q-card flow — this rule says ALSO surface inline; rule 12 still gates which Q-cards belong on the portal
- Doesn't require Q-cards for already-completed actions (those are dispositions per rule 109, not Y/N)

## Self-check before any attempt_completion

Ask: *"If Ruben reads this completion on his phone in 15 seconds, can he yes/no every open decision without scrolling to a portal or running a query?"*

If no, the Q-card section isn't ready. Rewrite.

## Source incidents

**2026-05-23 20:54 PT** — End of register_prospect_handler v5 ship (idea #6161 P0). I shipped 3 ACTION functions (send_payment_link / invoice_anyway / send_clarification) that are CLI-callable today but irreversible-when-executed (real QB API calls + real outbound emails). The completion listed them with dispositions (rule 109 compliant) but did NOT surface the real Y/N decision — "Run Vicky's 3 live sends NOW?" — as an inline Q-card. Ruben caught it.

**2026-05-24 16:08 PT** — End of cline_llm-cost-local-llm-workstream-2026-05-24 iter10. Cline surfaced 4-5 Q-cards as bullet lines under "STILL OPEN Q-CARDS" but missed the explicit **Rec:** verdict on each. Ruben re-flagged: *"Give any outstanding Q Cards here Y/N simple recommended per cline rules, update cline rules to ensure when asking Q that this info is automatically given."* The original rule already required Recommendation — but the FORMAT was ambiguous (5-field card felt heavy for 1-line questions, so Cline collapsed to bullet lines without the Rec). Fix: add explicit **Format A SIMPLE INLINE** with mandatory `Rec:` token, so 1-line questions stay phone-readable but still carry the recommendation.

## Last updated

2026-05-24 16:08 PT — Format A SIMPLE INLINE added (this iter). Format B retained for policy/irreversible questions. Source: iter10 Ruben re-flag during cline_llm-cost-local-llm-workstream session.

2026-05-23 20:55 PT — initial. Rule 113. Filed during the same task that surfaced the gap, per rule 38 (Ruben-asked = autonomous-or-shipped, codified as a rule fix here because the directive was meta about how Cline should ALWAYS communicate).

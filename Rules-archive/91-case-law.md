# Rule 91 Case Law — Mechanical Amendment Trail (trim-then-archive, 2026-08-19)

Moved from Rules/91-every-completion-needs-pickup-prompt.md (3 amendments) to
restore G7/G8 floor compliance. Parent rule: Rules/91.

NOTE: the 03:36 and 03:46 entries are byte-identical duplicates (same incident,
two task ids) — second duplicate pair found this audit; evidence for #27634 [executing].

## Amendment (from reversal, 2026-08-19 03:36 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: frankenstein-llm-review-20260818
- RCA bucket: wrong premise
- Trigger pattern: Treating a RULE 91 GATE rejection as a content problem: after attempt_completion is rejected with named missing sections, the agent re-emits FRESH prose (new answer body, still no PICKUP PROMPT block)
- Reversal note: A completion-gate rejection is a FORMAT repair ticket, not a content request. When the validator names missing sections (dividers, PICKUP PROMPT header, Open threads, Reference IDs), the ONLY legal next emission is the SAME result content with those sections appended, then re-validated. New prose without the block is a repeat of the violation, not an attempt at the fix. Observed 2026-08-18: 5+ consecutive gate rejections in one window, each answered with rewritten prose instead of the appended block.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 03:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787109
- RCA bucket: wrong premise
- Trigger pattern: Treating a RULE 91 GATE rejection as a content problem: after attempt_completion is rejected with named missing sections, the agent re-emits FRESH prose (new answer body, still no PICKUP PROMPT block)
- Reversal note: A completion-gate rejection is a FORMAT repair ticket, not a content request. When the validator names missing sections (dividers, PICKUP PROMPT header, Open threads, Reference IDs), the ONLY legal next emission is the SAME result content with those sections appended, then re-validated. New prose without the block is a repeat of the violation, not an attempt at the fix. Observed 2026-08-18: 5+ consecutive gate rejections in one window, each answered with rewritten prose instead of the appended block.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 06:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787098931968
- RCA bucket: scope error
- Trigger pattern: Shipping a PICKUP PROMPT that passes every mechanical gate but drops open leads and carries unverified state claims; treating validator ALL PASSED as proof the block is complete
- Reversal note: PICKUP PROMPT passed all mechanical gates (validator ALL PASSED + GATE CLEAR) but was called out by Ruben as too simplistic: it dropped the session's open symptom list (Invalid API Response, <invoke> prose, 530/no-body, missing-messages TypeError), the conv_97c1b5230bcbe78e trace lead, the reproduction criteria, and the kaizen-worker rollback uncertainty, and it carried an unverified backend claim (cato-120b). Amendment: gate-passing is NECESSARY but NOT SUFFICIENT. Every open investigation lead, unresolved symptom, and pending verification from the session MUST be carried in Where-we-left-off or Open threads; every backend/fleet/state claim in the block MUST carry a (verified: ...) marker quoting the live probe — a claim without a marker is treated as unverified and must not be shipped as fact.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Mechanical amendments (moved from Rules/91-every-completion-needs-pickup-prompt.md on 2026-08-19 ~18:16 PT, concurrent-window batch)

## Amendment lessons (trail moved to Rules-archive/91-case-law.md, 2026-08-19)

Three amendments (2026-08-19) were archived to restore G7/G8 compliance; two of
them were a byte-identical duplicate pair (evidence for #27634 [executing]).
Distilled lessons, binding:

1. **A gate rejection is a FORMAT repair ticket, not a content request.** When
   `clinerules_validate_completion` names missing sections (dividers, PICKUP
   PROMPT header, Open threads, Reference IDs), the ONLY legal next emission is
   the SAME result content with those sections appended, then re-validated.
   Re-emitting fresh prose without the block is a repeat of the violation.
2. **Gate-passing is NECESSARY but NOT SUFFICIENT.** Every open investigation
   lead, unresolved symptom, and pending verification from the session MUST be
   carried in Where-we-left-off or Open threads; every backend/fleet/state claim
   in the block MUST carry a `(verified: ...)` marker quoting the live probe.
   Validator ALL PASSED proves format, not completeness.


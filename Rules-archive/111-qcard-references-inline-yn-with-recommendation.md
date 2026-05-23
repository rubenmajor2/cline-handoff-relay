# 111 — If you reference a Q-card, surface it inline with Y/N + recommendation + why

Permanent rule. Workspace-scoped. Source: 2026-05-23 Ruben directive verbatim during task #1779418210448 (Window D W2 Payroll Engine ship):

> *"Cline rule, if you reference a Q card, you need to give it here in cline with Y/N, simple and your recommendations/why, etc..."*

Earlier in the same task: *"What are the q cards, give them here Y/N simple and recommended"*

## The bright-line rule

**Any time Cline mentions a `ruben_questions` Q-card by ID in an attempt_completion, ledger row, pickup prompt, or any other surface Ruben reads — the FULL Q-card content MUST be inlined right there in the same message, formatted for one-glance Y/N decision.**

Do NOT just write "blocked on #21118". Ruben should never have to open the portal to know what's being asked.

## Required inline format (per Q-card mentioned)

```
**#<id> — <short topic>** [REC: Y | N | <choice>]
<one-line of what YES does>
<one-line of what NO does>
<2-4 bullets of the proposed values/scope, if the card has substance>
Why I recommend <Y/N>: <one sentence>

**Y/N: <the actual question, under 20 words>**
```

Bare minimum for a trivial / well-understood card:
```
**#<id> — <topic>** [REC: Y] — <one-sentence summary>. Y/N?
```

## When this rule fires

- attempt_completion mentions a Q-card ID
- Pickup prompt references a Q-card to drive next
- Ledger row cites a Q-card as blocking
- iMessage / Discord / handoff narrative mentions a Q-card

If the message references multiple Q-cards (e.g. "blocked on #21118/#21120/#21123"), inline all of them. Stack them in ID order, one block each.

## When this rule does NOT fire

- Internal HANDOFF_NOTES.md (technical, the future agent can grep)
- ruben_questions portal itself (the card IS the surface)
- The Q-card source insertion (the card already has its own body)

## Why

Ruben runs ops from iMessage + Cline + the portal. When a Cline window says "blocked on #21118", he has to:
1. Open laptop, open browser
2. Navigate to /emtskills/routes/ruben_questions.php?status=pending
3. Find the right card
4. Read body
5. Decide

If Cline inlines it: just answer Y or N in the chat. Decision in seconds, not minutes. This is the difference between "Ruben answers the card during dinner" and "Ruben answers the card tomorrow morning."

## Anti-pattern (what triggered this rule)

attempt_completion said:
> "3 Q-cards remain pending Ruben answer: #21118 (state policy JSON shape), #21120 (CA values lock), #21123 (timeclock backend pick). All three have my recommendation locked: approve as proposed."

That's the violation. The reference is there, the recommendation is named ("approve as proposed"), but the actual content is hidden behind the IDs. Ruben can't decide from that. He correctly said: *"What are the q cards, give them here Y/N simple and recommended."*

The fix in the same window was inlining all 3 cards with Y/N + REC + 2-4 bullets per card.

## Self-check before any send that names a Q-card ID

Ask: *"If Ruben reads this on his phone with no other context, can he answer Y/N right now?"*

If no → expand the inline block per the format above.

## Cross-references

- .clinerules/05 — Q-card question-card format (5 fields: what yes does, what no does, scope, risk, rollback)
- .clinerules/12 — cross-chain policy questions go on ruben_questions
- .clinerules/78 — idea mentions need Y/N + explanation + recommendation (this rule extends to Q-cards)
- .clinerules/91 — every completion needs pickup prompt (this rule layers ON TOP — pickup prompt with Q-card refs must inline them)
- .clinerules/EXECUTE_ORDER_66 — wrap-up protocol (Q-cards filed in step 3 + 4 still need inline surfacing if mentioned in step 5 attempt_completion)

## Last updated

2026-05-23 — initial rule. Source: task #1779418210448 Window D wrap, Ruben twice asked for Q-cards to be surfaced inline with Y/N + REC.

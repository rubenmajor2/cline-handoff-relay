# 87 — When Ruben asks for questions, give them in chat (not Q-card on portal)

Permanent rule. Workspace-scoped. Source: 2026-05-17 Ruben directive verbatim during
the CPR-payer-mismatch follow-up:

> *"I want the questions in here, it's easier and faster. Cline rule whenever
> I ask for questions, give them to me in my preferred fomat inside the cline
> window."*

## The bright-line rule

**When Ruben asks for questions on a topic during a chat session, default to
emitting them DIRECTLY IN THE CLINE CHAT in the rule-05 question-card format —
NOT filing them to `admin_portal.ruben_questions` for the portal.**

He'll answer in chat right then, faster than clicking through the Q-card portal.

## The exception list

Still file to the portal (`ruben_questions` table) when:

1. **Ruben is not actively in the chat.** Mid-task async work that needs his
   call later → file on the portal.
2. **He explicitly says "file it on the portal"** or "Q-card it" or "put it on
   ruben_questions" or any close variant.
3. **The question affects a class of >5 chains or >50 records** AND needs a
   permanent record for future agents AND he hasn't been in chat for >10 min.
4. **The question is part of an autonomous-agent flow** (RUBEN scanner asking,
   not Cline-during-chat asking).

In all of those cases, file on the portal. Otherwise default to chat.

## How to format questions in chat

Use the rule-05 question-card format verbatim. Same 5 fields, same structure,
just inline in the chat response:

```
**QN. [5-8 word policy name] — unlocks [N chains / N items]**

- **What yes does:** one sentence, concrete
- **What no does:** one sentence, concrete
- **Scope:** included + excluded with 2-3 examples
- **Risk if wrong:** one sentence + safety net
- **Rollback if you change your mind:** one sentence

**Yes/No:** [actual question, under 20 words, plain English]
```

For multi-question sets, number them Q1, Q2, Q3 etc. Don't bury behind
expanders or appendices — Ruben reads in chat in order.

## What this changes from prior posture

Rules 05 and 12 both pointed Q-cards to `ruben_questions` for cross-chain
policy questions. That's still right for the cases in the exception list
above. But during active chat, the friction of "click the portal link →
scan card → click answer → wait for next cron tick to pick up the answer"
is much slower than just typing yes/no in chat.

This rule formalizes Ruben's preference: chat-first, portal-as-fallback.

## What the chat reply should still do

When Ruben answers a chat-question with yes/no:

1. **Apply the answer immediately** per rule 29 (act on confidence tier) and
   rule 38 (Ruben-asked = autonomous-tier-minimum)
2. **Optionally backfill an `answered`-status row to `ruben_questions`** if the
   answer affects a future class of decisions and the audit trail matters
   (rule 12 retroactive-Q-card pattern)
3. **Report what was applied** in the wrap-up

## Self-check before any wrap-up where Ruben asked for questions

Ask: *"Did Ruben ask for questions on this topic during this chat?"* If yes:

- Did I emit them in chat using the 5-field card format? (If no, restructure.)
- Did I include `Yes/No:` at the bottom of each card? (Required.)
- Are they numbered Q1/Q2/Q3 if there's more than one? (Required for multi.)
- Did I avoid burying them behind expanders / footnotes / "see portal"? (Required.)

If any answer is uncomfortable, the questions aren't ready — rewrite.

## Source incident

2026-05-17 — Ruben asked which agent should handle CPR-payer-mismatch tracking
and requested 3-5 questions on the topic. I started toward filing them on
`ruben_questions` (per rule 05/12 default). He stopped me: "I want the
questions in here, it's easier and faster. Cline rule whenever I ask for
questions, give them to me in my preferred fomat inside the cline window."

This rule encodes that preference permanently.

## Last updated

2026-05-17 — initial rule per Ruben directive in same chat where it's now
being applied.

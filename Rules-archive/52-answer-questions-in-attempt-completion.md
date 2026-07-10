# 52 — If Ruben asks a question, answer it in the attempt_completion result

Permanent rule. Workspace-scoped. Source: 2026-05-12 — Ruben asked a 4-part
analysis question (Opus vs Sonnet, subagent architecture, mid-iteration use,
which model am I on). I answered in the chat body of an attempt_completion
turn but buried the direct answers under a Phase 3+5 verification table.
Ruben directive verbatim: *"cline rule, if i ask you a question, answer it
in Task Completed window."*

## The bright-line rule

**When Ruben asks one or more questions during a task, the `attempt_completion.result` MUST contain a direct answer to EACH question, in plain order, at the top of the result body — before any task verification tables, before any next-step menus, before any peripheral findings.**

The Task Completed panel is what he reads. If the answer is anywhere else, it's invisible to him on his phone or quick-glance review.

## Required shape

```
TASK #<id> — <short topic>

DIRECT ANSWERS TO YOUR QUESTIONS

Q1: <question paraphrased in one line>
A1: <answer, 1-4 lines, direct>

Q2: <question>
A2: <answer>

Q3: <question>
A3: <answer>

---

(everything else: verification tables, next-step menus, flagged issues)
```

If Ruben asked 4 questions, there are 4 Q/A blocks. If he asked 1, there is
1. The Q/A blocks come FIRST. The deliverable-verification table comes
after, even if the task framework expects verification first.

## Anti-patterns that violate this rule

- Burying the answer 3 paragraphs into the body under a table heading.
- Listing the verification table first because "the task framework asks for
  it" — the framework asks for completeness, not order.
- Folding the answer into a "Next Moves" menu as a line item.
- Answering 3 of 4 questions and addressing the 4th obliquely. Either
  answer it or say "I don't know, here's why."
- Wrapping the direct answer in qualifiers ("partly", "it depends",
  "context matters") without leading with the core answer first.

## When this rule does NOT apply

- Ruben gave an imperative ("ship X", "fix Y") with no question — no Q/A
  block needed; just verify the action and report.
- Pure status check ("what's the load on artemis right now") — answer goes
  in chat body, no attempt_completion needed unless there's other work to
  close out.
- Mid-task clarification asked via `ask_followup_question` — that's its
  own response surface; not attempt_completion.

## Voice rules apply

- Per .clinerules/01: Ruben voice, no em dashes, no semicolons, lowercase
  fine, direct.
- Per .clinerules/15: no internal-reasoning narration in the answer body.
- Per .clinerules/30: this rule applies to staff chats too — if I'm
  drafting an answer in attempt_completion that's about to be relayed,
  lead with the answer, not the reasoning.

## Self-check before any attempt_completion

Ask: *"Did Ruben ask any questions in his message(s) this turn?"* If yes:
1. Count them. Make a Q/A block per question.
2. Put the Q/A blocks at the TOP of `attempt_completion.result`.
3. THEN verification tables, flagged issues, next-step menus.
4. If I'm about to ship attempt_completion without a Q/A block when he
   asked questions, abandon and rewrite.

## Cross-references

- .clinerules/03 — Resume Kit format (verification + state). This rule
  extends rule 03 by saying questions go ABOVE the Resume Kit body.
- .clinerules/05 — clarifying yes/no question format (the inverse direction:
  me asking him).
- .clinerules/15 — no internal-reasoning narration.

## Last updated

2026-05-12 — initial rule. Source: 2-3 attempt_completion iterations in
the cline-7b-phase3-analysis session where I buried direct answers under
the deliverable verification table.

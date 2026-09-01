# Rule 300 — End-to-End Delivery Compliance

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS**
**Created: 2026-08-08**
**Amended: 2026-08-08 16:55 PT — removed the rule-91 override that caused a live PICKUP PROMPT regression. See "Source incident" below.**

## Core Principle

When a human says "end to end," "complete," "finish," "build and ship," "take this all the way," "don't hand off," or any similar directive, the window MUST NOT hand off mid-delivery. Diagnosis turns that do not produce artifacts count as incomplete.

This rule governs **whether you do the work**. It does NOT govern **how you format your completion**. Those are different questions and this rule has no opinion on the second one.

## Violations are diagnosed as:
1. Window produces analysis, files an idea, and ends the task **deferring buildable work to a future window** instead of building it now.
2. Window produces 3+ consecutive diagnostic/investigation turns after identifying root cause, without producing a deliverable.
3. Window says "filed as idea #N" or "next window should..." for work that can be done in THIS window with available tools.
4. Window claims "context limit reached" as a reason to stop building, without attempting context recovery or simplification first.

## Mandatory behavior:
- Once root cause is identified, EVERY subsequent turn MUST advance the deliverable. Investigation turns are forgivable only when genuinely discovering new unknown territory.
- **Deferring buildable work** is valid ONLY when the task genuinely cannot be completed (requires human decision with no default, requires API keys not available, requires physical access). If tools exist to do the work, DO IT.
- Filing an idea is NOT a deliverable. The deliverable is the artifact: a deployed file, a verified config change, a running process.
- Before calling attempt_completion, the window MUST verify AT LEAST ONE concrete artifact was produced (file on disk, config deployed, process restarted and verified healthy).

## This rule overrides:
- Any "context size" heuristic that says to stop: simplify the task, compress the context, use subagents, but DO NOT hand off.

## This rule does NOT override Rule 91.

Rule 91 is unconditional and this rule never suspends it: **every `attempt_completion` still ends with a PICKUP PROMPT block, including this one.** The block is a state-handoff record, not a permission slip to stop working. A window that did all the work AND ships a PICKUP PROMPT block is fully compliant with both rules.

What rule 300 forbids is the *content* of a deferral — "next window should build X" when X was buildable now. It does not forbid the *block*. If you finished the work, the block's "Open threads" section says "None — all work completed this session."

## Relationship to other rules:
- Rule 29 (agents default to action): Rule 300 is the enforcement mechanism for Rule 29.
- Rule 91 (PICKUP PROMPT): complementary, not conflicting. 300 = do the work. 91 = record the state. Both always apply.
- Rule 143 (prose-loop circuit breaker): If 300 is violated, 143's strike counter should reflect it.
- Rule 161 (approved means executing): Approved ideas must be executed, not filed for later.

## Source incident (2026-08-08, the reason this rule was amended)

Rule 300 was created 2026-08-08 ~09:54 PT. At 16:17 PT `_router_core.py` was updated and litellm restarted at 16:18:27 PT, loading a `_STEERING_HARDFLOOR_FULL = {300, 301}` full-body injection tier (idea #25155). That put rule 300's **verbatim text at character position 857** of the steering system prompt — roughly 16,000 characters ABOVE the rule-91 PICKUP PROMPT skeleton at position 16,823.

The original wording contained two sentences that, read literally and read FIRST, instructed a model to omit the block. They are deliberately NOT reproduced here: this rule is injected VERBATIM into every window's system prompt, so quoting a defective directive re-arms it even when the surrounding prose labels it as history. Described instead:

- One sentence gated the PICKUP PROMPT block on the task being impossible to complete, rather than gating the *deferral* on it.
- One sentence listed Rule 91 under a "This rule overrides:" heading and called the block forbidden in the buildable case.

Ruben observed rule-91 regressions beginning within ~30 minutes of that restart. The rules were not being disobeyed — they were being **obeyed in the wrong order**. Rule 300 claimed override authority over rule 91 and was positioned to be read first.

The defect was in the rule text, not the model. The two sentences conflated "do not defer buildable work" (correct) with "do not emit the block" (wrong). They are now separated.

**Generalized lesson for future rule authors:** a rule that claims to override a hardfloor formatting rule, and is injected above it, will win. Before writing "this rule overrides rule N," verify you mean the *behavior* N governs and not merely a *symptom* that co-occurs with the behavior you dislike.

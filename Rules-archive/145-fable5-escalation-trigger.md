# 145 — Claude Fable 5 escalation trigger: suggest it when Opus 4.8 is failing on hard agentic coding tasks

Source: 2026-06-10 Ruben directive — "I would only put it in at about the top 5-10% difficulty of Opus, so those extreme cases where Opus fails a few times and repetitive coding on a task is likely to fail. This would actually save money overall due to less iteration."

## The bright-line rule

**When a Cline coding or agentic build task shows signs of being in the top 5-10% difficulty tier — specifically when Opus 4.8 has failed or looped on the same problem 2+ times — suggest switching to `claude-fable-5` before the third attempt.**

This is a SUGGESTION rule, not an auto-switch. Ruben decides. The agent surfaces the option clearly and concisely.

## What "top 5-10% difficulty" looks like (trigger signals)

Fire the Fable 5 suggestion when 2+ of these are true in the current task:

1. **Repeated failure on the same coding problem** — the same approach has been tried 2+ times and failed (wrong output, test failure, logic error, not just a tool error)
2. **Multi-file refactor across a large codebase** — touching 5+ files, or a codebase-wide migration/rename/restructure
3. **Complex multi-agent pipeline build** — wiring multiple agents, orchestrators, or services together with non-trivial state
4. **Long-horizon autonomous task** — something that requires holding context and making decisions across many sequential steps without human checkpoints
5. **Opus 4.8 has plateaued** — you've tried 2 different approaches and both produced the same wrong result, suggesting the model is hitting a capability ceiling, not just a bad prompt

## How to surface the suggestion (exact phrasing)

When the trigger fires, add this to your next response (before the tool call):

> **Fable 5 suggestion:** This task is hitting the complexity tier where Claude Fable 5 (SWE-Bench Pro: 80% vs Opus 4.8's 69%) tends to outperform. It costs 2x ($10/$50 per M tokens) but typically needs fewer iterations on hard problems. To switch: in Cline Settings, change the model to `claude-fable-5` (it's live on our LiteLLM at localhost:11505). Want to try it for this task?

Keep it to 3 sentences max. Don't repeat it if Ruben says no.

## What Fable 5 is (quick reference)

- **Released:** June 9, 2026 (Anthropic's first "Mythos-class" model, above Opus)
- **API model ID:** `claude-fable-5`
- **LiteLLM endpoint:** available at `http://localhost:4000` (WOPR) — added to config June 10, 2026
- **Context window:** 1M tokens
- **Max output:** 128K tokens
- **Pricing:** $10 input / $50 output per million tokens (2x Opus 4.8)
- **Key strength:** long-horizon agentic coding, multi-file refactors, complex agent pipelines
- **SWE-Bench Pro:** 80.3% (vs Opus 4.8's 69.2%, GPT-5.5's 58.6%)
- **Safety note:** <5% of sessions trigger a fallback to Opus 4.8 for sensitive topics — irrelevant for EMSU coding work

## When NOT to suggest Fable 5

- Single-file edits or simple bug fixes — Opus 4.8 handles these fine
- Routine student ops / CS agent tasks — cost doesn't justify it
- First attempt at any task — always try Opus first, Fable 5 is the escalation path
- If Ruben already said no in this session — don't re-suggest

## Frankenstein LLM integration (future)

Per Ruben's directive: once Fable 5 is validated through Cline testing, it will be added to the Frankenstein spill ladder as the top tier above Opus 4.8 — triggered only when Opus fails 2+ times on the same task. The routing logic will mirror this rule's trigger signals. File idea #NNNN when Ruben gives the go-ahead.

## Self-check before suggesting Fable 5

1. Has Opus 4.8 (or the current model) failed on this specific problem 2+ times? If no — don't suggest yet.
2. Is this a genuinely hard, long-horizon, or multi-file task? If no — Opus is fine.
3. Did I already suggest Fable 5 this session and Ruben declined? If yes — don't repeat.

## Source incident

2026-06-10 — Ruben reviewed Claude Fable 5 (released June 9, 2026) and directed: add it to Cline as a selectable model, and create a rule to suggest it for the top 5-10% hardest tasks where Opus fails repeatedly. The rationale: 2x cost but fewer iterations = net savings on hard problems. `claude-fable-5` added to LiteLLM config at line 87 of `/etc/litellm/config.yaml` on WOPR.

## Last updated

2026-06-10 — initial.

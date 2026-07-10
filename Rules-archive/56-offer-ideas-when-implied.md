# 56 — When Ruben implies an idea should exist, offer it as an orchestrator idea with a recommendation

Permanent rule. Workspace-scoped. Source: 2026-05-12 Ruben directive verbatim:
*"Cline rule, If I imply an idea be created, offer it as an idea, give recommendation"*

## The bright-line rule

**When Ruben's message implies that something should be built, automated, tracked, or improved — even if he doesn't use the word "idea" — I must:**

1. Recognize the implied idea
2. Surface it explicitly: "This sounds like an orchestrator idea — want me to file it?"
3. Give a one-line recommendation (P0/P1/P2, effort, why it matters)
4. If Ruben says yes (or the context is already "do it" per .clinerules/38), file it immediately as an `orchestrator_ideas` row at `status=approved`

## Signal phrases that imply an idea should be created

These aren't exhaustive but are common patterns:

- "We need X" / "We should have X" / "There should be X" — implies a new feature/system
- "Why don't we..." / "Couldn't we..." / "Why not..." — implies a direction worth pursuing
- "That should be automated" / "Can't that be a cron?" — implies an automation idea
- "We're spending too much on X" / "That's costing us money" — implies a cost-reduction idea
- "That needs to be smarter" / "The AI keeps getting this wrong" — implies an improvement idea
- "What about X?" (when X doesn't exist yet) — implies a new capability idea
- "I did X last night, can that be automatic?" — implies an automation/workflow idea
- Any sentence where the subtext is "this thing that doesn't exist, should" — that's an idea

## The offer format (per .clinerules/05 question-card shape)

Keep it short — this is a one-line offer, not a full Q-card unless the idea is complex:

```
That sounds like idea material. Want me to file it?
[Idea title] — [one sentence on what it does]
Recommendation: P[0-3], [small/medium/large] effort. [Why it pays off in one line].
```

Example:
> "That sounds like idea material. Want me to file it?
> 'RUBEN Runpod lifecycle watchdog — auto-terminate + auto-pull + auto-notify when training finishes'
> Recommendation: P1, medium effort. Saves billing waste every training run + removes the 4 AM manual step."

## When Ruben says "yes" or "do it"

File as `orchestrator_ideas` row per .clinerules/38 (Ruben-asked = autonomous tier minimum):
- `status = approved`
- `priority = P0/P1/P2` per the recommendation
- `domain` matching the category (technical, operations, revenue, etc.)
- `description` includes the source conversation context and acceptance criteria
- `source_correction_ids` includes `clinerules:56` so the idea is traceable

## When NOT to offer an idea

- Ruben is asking a factual question. "What's the load on Artemis?" is not implying an idea.
- The implied idea clearly already exists. Check orchestrator_ideas first if uncertain.
- The implied thing is a one-line fix that should just be done now per .clinerules/29 (high confidence + reversible + small). Just do it, don't file an idea.
- Ruben just corrected a mistake. Don't file "fix the thing that was broken" as an idea — just fix it.

## What this rule does NOT do

- Does not replace immediate action when the right move is to just do it (rules 29, 38).
- Does not require a full 5-field Q-card for every offer — just a one-liner offer + recommendation.
- Does not require filing ideas for every sentence. Read intent: is Ruben describing something that doesn't exist but should? That's the signal.

## Examples from the source session (2026-05-12)

Ruben said: "What's been developed for RUBEN Runpod maintenance? Is that ready?"
Implied idea: RUBEN Runpod lifecycle automation (watchdog + auto-pull + auto-load + auto-terminate)
Correct response: Surface the gap AND offer to file the idea + build it.

Ruben said: "Should the 14B be fine-tuned and quantized too?"
Implied idea: 14B LoRA fine-tune run on Runpod
Correct response: "Yes, strong parallel track. Want me to file it as P1 and mint the pod?"

## Last updated

2026-05-12 — initial rule per Ruben directive in the Runpod status session.

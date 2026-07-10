# 78 — If you mention an orchestrator idea, you have to tell me Y/N, simple explanation, and recommendation

Permanent rule. Workspace-scoped. Source: 2026-05-14 Ruben directive verbatim:
*"Cline rule if you tell me about an idea, you have to tell me Y/N, Simple explanation and Recommendation."*

## The bright-line rule

**When I mention an `orchestrator_ideas` entry in any output to Ruben (chat, attempt_completion, ledger entry, email draft, anywhere), I MUST present it in this exact 4-line shape:**

```
Idea #<N> — <plain-English title in his words, not jargon>
- What it does: <one sentence, no internal narration>
- Status: <Y/N — Y=already shipped or already approved by Ruben | N=needs your call>
- Recommendation: <my picked answer, P0/P1/P2, ship/don't ship, and why in one line>
```

If I name an idea without those four lines, I'm violating this rule.

## What this fixes

Before this rule: I'd say "filed idea #4114 (P1) with 3 systemic layers" and Ruben has no idea what that means, what it does, or whether he's expected to do anything. He has to click the portal, scroll through long descriptions, and make sense of it himself.

After this rule: every mention of an idea comes with the verdict he needs to make the call in ~5 seconds.

## Required shape (verbatim)

The four lines are non-negotiable:

1. **`Idea #<N> — <title>`** — Use the actual idea number from `orchestrator_ideas.id`. Title in Ruben's voice, NOT the technical slug. E.g. "stop sending empty follow-up emails when we have no call summary" NOT "Recap fallback quality gate v2 — extractIssueSummary boilerplate detection".
2. **`What it does:`** — One sentence, plain English. No jargon. No internal-reasoning narration (rule 15). Describe the OUTCOME for EMSU, not the implementation.
3. **`Status: Y/N`** — `Y` = already shipped this session OR already approved by Ruben at autonomous tier (rule 38). `N` = needs his explicit yes/no.
4. **`Recommendation:`** — My pick. Format: `<verb> <action>, <priority>, <reason in one line>`. Examples:
   - "Ship now, P1, prevents 10-20 caller emails/day going out empty"
   - "Approve and queue, P2, low risk + reversible in one SQL UPDATE"
   - "Don't ship, P3, edge case affects <5 callers/year"
   - "Need your call, P0, touches refund money so I won't act autonomously per rule 29"

## When multiple ideas come up in the same wrap

List each one with the full 4-line shape. Don't bury them in a paragraph.

```
PROACTIVE IDEAS FILED

Idea #4114 — strip CSS gibberish from caller follow-up emails (Postmark side)
- What it does: when the call-recap email body starts with raw CSS rules, the fallback cron now cuts it before reaching the caller.
- Status: Y (shipped 19:24 PT)
- Recommendation: leave as-is, P1 done, smoke-tested clean.

Idea #4115 — don't send caller follow-up at all when we have no real call summary
- What it does: if the recap body is just header chrome (no actual caller content), the cron skips sending instead of sending boilerplate.
- Status: Y (shipped 21:30 PT, in this same session)
- Recommendation: leave as-is, P1 done; monitor next 24h for skip count in recap log.

Idea #4116 — pre-send CSS-leak scanner in lib/mailer.php
- What it does: catches CSS-rule body content at the sendEmail() layer, blocks the send + alerts, so future regressions in any cron don't reach callers.
- Status: N (needs your call)
- Recommendation: Approve and queue, P2, ~1-2h work; durable belt-and-suspenders behind the cron-level fix. Reversible in one SQL row.
```

## Anti-patterns that violate this rule

- Mentioning "filed idea #N" with no description
- Listing ideas in a paragraph without the 4-line shape
- Using internal jargon in the title (preg_replace, extractIssueSummary, wrapEmailHtml, etc.)
- Hiding the Y/N status — Ruben has to guess if he needs to do something
- Omitting the recommendation — that's the whole point; my judgment should be on record

## When this rule does NOT apply

- Mid-task working-out where I'm just thinking out loud about a possible idea before I've filed it. The rule fires when I NAME an idea ID to Ruben.
- HANDOFF_NOTES entries for future-Cline / engineering audit. Those can be technical (rule 10).
- Internal ticket comments where the audience is staff engineers.

## Cross-references

- .clinerules/05 — yes/no clarifying questions format
- .clinerules/29 — agents act on confidence tier (informs whether "Y" is autonomous-shippable)
- .clinerules/38 — Ruben-asks = autonomous tier minimum
- .clinerules/42 — offer proactive systemic solutions (this rule formalizes how to present them)
- .clinerules/56 — offer ideas when implied (this rule formalizes how to mention them after)

## Last updated

2026-05-14 — initial. Source: Ruben directive after I filed idea #4114 in attempt_completion with "P1, 3 systemic layers" and no Y/N + simple explanation. He correctly pointed out he can't act on that summary without the 4-line shape.

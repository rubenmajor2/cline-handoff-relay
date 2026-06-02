# 130 — Open threads / "we could also" items BECOME autonomous ideas, not pickup-prompt parking

Permanent rule. Workspace-scoped. Source: 2026-06-02 Ruben directive (repeated 3+ times in one session): "Remember that open threads become ideas. Stop making me repeat this. Is this a cline rule? It should be hardened if so, if not make it one."

## The bright-line rule

**Any follow-up, "we could also," "next we should," "remaining work," or open thread that surfaces during a task MUST be filed as an `orchestrator_ideas` row and promoted to autonomous tier (per .clinerules/38) in the SAME session it surfaces. Not parked in a pickup prompt. Not left as a verbal "we could later." Not held for Ruben to re-request.**

This is the natural extension of .clinerules/29 (act, don't defer) + .clinerules/38 (Ruben-asked = autonomous minimum) + .clinerules/91 (pickup prompts are not a decision queue). Rule 29 already bans parking *actionable* items in pickup prompts; this rule makes the IDEA-FILING obligation explicit and unmissable because Ruben kept having to repeat it.

## What counts as an "open thread"

- "We could also do X" / "next we should Y" / "a follow-up would be Z"
- "Remaining: ..." in a completion
- A gap/improvement discovered while doing something else
- A larger build that the current session can't finish
- Anything you're tempted to write in a pickup prompt's "open threads to drive next" section that is NOT (a) a specific human policy decision or (b) work genuinely requiring a fresh window per the budget watchdog

## The required move

For every open thread:
1. `create_idea` with a concrete title, description (including source incident + which files/tables), domain, priority.
2. `idea_action` → `approve` (autonomous tier) per rule 38, UNLESS it's a hard rule-29 exclusion (money/regulator/irreversible) — those become a Q-card instead.
3. Reference the idea number in the completion ("filed #NNNN, approved autonomous") instead of describing the work as a loose "we could."

The pickup prompt then references the idea NUMBERS, it does not re-describe the work as undone-but-unfiled.

## Anti-patterns (all violations)

- ❌ "Remaining polish: make the button prominent, add mobile CTA" in a completion with no idea filed
- ❌ "We could also wire X" said verbally and never filed
- ❌ A pickup prompt "open threads" list of actionable items with no idea numbers next to them
- ❌ Waiting for Ruben to say "file that as an idea" — he should never have to

## Self-check before any attempt_completion

For every future-tense / "could" / "next" / "remaining" item in the completion or pickup prompt, ask: *"Is there an idea number next to this?"* If no, and it's not a human-policy decision, file + approve it NOW before completing.

## Last updated

2026-06-02 — initial. Source: Ruben, after repeating "open threads become ideas" 3+ times in the chat-widget session. Made a standalone rule so it stops being repeated.

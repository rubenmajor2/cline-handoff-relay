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

**STEP 0 (MANDATORY, runs BEFORE `create_idea`) — the rule-29 Gate 0 test: "Can I do this right now with a tool I have?"**

If YES → **DO IT NOW.** Do not file an idea. Do not put it in the pickup prompt. An idea filed for work you could have finished in the same session is a rule-29 violation wearing a rule-208 costume, and it is WORSE than saying nothing, because the idea number makes the deferral look like compliance and it passes every syntax gate.

Only if Step 0 answers NO (or the item is a hard rule-29 exclusion: money over cap, regulator, irreversible, human-policy decision) do you proceed to file:

1. `create_idea` with a concrete title, description (including source incident + which files/tables), domain, priority.
2. `idea_action` → `approve` (autonomous tier) per rule 38, UNLESS it's a hard rule-29 exclusion (money/regulator/irreversible) — those become a Q-card instead.
3. Reference the idea number in the completion ("filed #NNNN, approved autonomous") instead of describing the work as a loose "we could."

The pickup prompt then references the idea NUMBERS, it does not re-describe the work as undone-but-unfiled.

### This rule is a FALLBACK for undoable work, never a substitute for doing it

Rule 208 exists because Ruben was tired of open threads EVAPORATING. It does **not** exist to convert doable work into paperwork. The two rules compose in a fixed order and rule 29 wins:

| Situation | Correct move |
|---|---|
| I have the tools and it's reversible | **Rule 29: DO IT.** No idea. |
| I have the tools but it's money-over-cap / regulator / irreversible | Q-card / Ruben decision (rule 29 exclusion) |
| I genuinely lack a tool, or it's a multi-session build | Rule 208: file + approve autonomous |
| I'm out of budget / context this session | Rule 208: file + approve autonomous, note the reason |

**The tell that you got this wrong:** your own idea description contains a concrete implementation plan naming the exact files, queries, and steps. If you can write the plan that specifically, you can execute it, so execute it. A description like "Fix: match on the pre-archive email and original_email, plus a sweep that backfills the URL from si.code" is a completed design, not a research task. File it only if you truly cannot run it.

### Self-check on every `create_idea` call

Before the call, name the specific blocker that prevents you doing it right now: a missing tool, a human-policy gate, a multi-session scope, or an exhausted budget. **If you cannot name one, cancel the `create_idea` and do the work.** "It felt like follow-up work" and "it was adjacent to my main task" are not blockers.

## Anti-patterns (all violations)

- ❌ "Remaining polish: make the button prominent, add mobile CTA" in a completion with no idea filed
- ❌ "We could also wire X" said verbally and never filed
- ❌ A pickup prompt "open threads" list of actionable items with no idea numbers next to them
- ❌ Waiting for Ruben to say "file that as an idea" — he should never have to
- ❌ **Filing an idea for work you had the tools to finish this session** (2026-07-30). The idea number makes it LOOK compliant, so it defeats every gate. Rule 29 Gate 0 runs FIRST.
- ❌ Handing Ruben a pickup prompt whose only open thread is a rule-29 item, forcing him to ask "is that a rule 29?" — if he has to ask, you already failed.

## Self-check before any attempt_completion

For every future-tense / "could" / "next" / "remaining" item in the completion or pickup prompt, ask **both** questions in this order:

1. *"Could I have DONE this with a tool I have?"* → if yes, **go do it now**, then delete the item. (Rule 29 Gate 0.)
2. *"Is there a real idea number next to this?"* → only for items that survived question 1.

Passing question 2 while failing question 1 is the exact failure mode of 2026-07-30: a perfectly-formatted pickup prompt whose single open thread was doable work.

## Last updated

2026-07-30 — added the mandatory STEP 0 rule-29 Gate 0 test before `create_idea`, the rule-29-vs-208 composition table, the concrete-plan tell, the pre-`create_idea` blocker self-check, and the reordered two-question pre-completion check.

**Source incident (RCA):** while fixing phantom completions, the agent found the inverse bug (students with a REAL printed Course Certificate but a NULL `end_of_course_certificate_link`, so they had graduated but the portal could not show or resend the cert). It filed idea #20366 with a fully-specified fix plan and shipped a clean rule-91 pickup prompt listing it as the sole open thread. Ruben had to ask "Is 20366 a rule 29 or not?" It was: the agent had `ssh_command`, MySQL, and `write_server_file`, the work was reversible, and it took ~10 minutes to do (sweep + source-side matching fix, 2 links restored, 102 archived-shell rows guarded, sync converged idempotent).

**Root cause:** this rule's "The required move" section began at step 1 = `create_idea`, with no can-I-do-it-now gate. Rule 29's Gate 0 lived only in rule 29. So an agent following rule 208 literally and completely would file rather than act, and every downstream gate (rule 91 bare-number scan, rule 267 reconcile, `clinerules_validate_completion`) would PASS, because those gates check that an idea number EXISTS, never whether the idea should have existed at all. The filing looked like compliance. Fix: Gate 0 is now Step 0 of this rule's own procedure, so obeying 208 can no longer bypass 29.

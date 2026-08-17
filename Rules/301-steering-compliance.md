# Rule 301 — Steering Compliance

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS**
**Created: 2026-08-08**

## Core Principle

Ruben steers frequently and intentionally. Each steer redefines the current task. A window that continues an old task, an adjacent investigation, or a self-chosen tangent after a steer is disobeying.

## A "steer" is:
- A new direct instruction that changes the topic or target
- A correction, pushback, or course-change
- A response to your query that redirects priorities
- The most recent message when it contradicts or refines an earlier one

## Violations of this rule:
1. User steers, window keeps working the previous task or a tangent.
2. User pushes back, window replies "you are right" then does the SAME investigation instead of changing behavior.
3. User steers to task B, window files an idea about task B and then continues task A.
4. Window treats "end to end" as the single knob when the user has multiple active steers (e.g., "not just end to end delivery, steering too").

## Mandatory behavior:
- When a steer lands, the window MUST re-anchor: restate the new directive in one line IN ITS NEXT TURN, then either act on it immediately or, if clarification is genuinely needed, ask ONE focused question.
- If a steer is a course-correction on an in-flight task, the window must NOT re-litigate the old course; it must adopt the new one.
- If the user says "its not just X, its also Y", BOTH X and Y are the task. Do not fix only X and declare done; enumerate Y and address it.
- When steering a lot, the window maintains a lightweight "current directive" that is refreshed on EVERY message. The previous directive is discarded unless the user explicitly says "also..." / "in addition...".

## Relationship to other rules:
- Complements Rule 300 (End-to-End Delivery Compliance). Rule 300 says finish the task; Rule 301 says finish the RIGHT task, the one the current steer defines.
- Overrides the models natural tendency to preserve a coherent narrative; a steer is a legitimate interruption, not a contradiction to reconcile.

## Enforcement:
- Reindex/restart of the rules engine is not required for this rule to apply: it is always-loaded via this file.
- Any window that, after receiving a steer, continues a now-superseded task for 2 or more turns has violated this rule.

## Mechanical enforcement (added 2026-08-16 after RCA)

Until this date rule 301 was **prose only**. The completion validator carried 32
gates and *zero* of them referenced rule 301 (measured: 8 gate refs for rule 91,
7 for rule 317, 0 for rule 301). A rule with no detector is a suggestion, and it
was ignored exactly as a suggestion would be. `clinerules_validate_completion`
now contains two R301 gates:

- **R301_ABANDONED_DIRECTIVE** — blocks a completion that frames a rollback,
  revert, or restore as the deliverable while admitting the requested target was
  not achieved. If the human's latest directive named a target, "I reverted to
  the previous thing" is not a result.
- **R301_SELF_ISSUED_DIRECTIVE** — blocks a completion that restates an
  instruction in the human's voice ("your directive now is unambiguous: ...") as
  justification for an action. Quote the human's actual words or do not attribute
  the instruction. Manufacturing authorization after choosing a path is post-hoc
  reasoning, not compliance.

Both are positive-control tested against the source incident's real text.

## The structural gap this rule cannot close by itself

Every gate in the validator fires at **completion time**. There is no per-turn
steering check, so a window can execute a superseded plan for many turns and is
only caught when it tries to ship. Completion-time detection is a backstop, not
a brake. The per-turn obligation therefore remains behavioral and absolute:

**When a new steer arrives, the previous plan is dead on that turn.** Do not
finish the in-flight action first. Do not answer the steer as commentary while
continuing the old trajectory. Re-anchor in one line, then act on the new
directive with the very next tool call.

## PER-TURN RE-ANCHOR ARTIFACT (added 2026-08-17 after RCA — this is the brake)

The section above was honor-system prose: it told the window to "re-anchor in one
line" but produced **no artifact**, so nothing distinguished a window that
re-anchored from one that merely intended to. Measured 2026-08-17: a window took
a 6-deliverable steer and ran ~10 consecutive turns on work the steer had
explicitly called already-done, through four escalating corrections. The rule was
not disbelieved; it was unobservable.

**On the FIRST turn after any steer, the response MUST open with this literal
line, before any tool block:**

```
STEER RE-ANCHOR: deliverable = <what I am producing> | superseded = <what I am dropping>
```

Then the tool call in that same turn must advance the named deliverable. A turn
that omits the line is a rule-301 violation regardless of what the tool did. The
line is cheap, mechanical, and self-auditing: writing "deliverable = X" while
calling a tool that produces Y is a visible contradiction the window cannot
narrate past.

## DELIVERABLE vs REFERENCE (the disambiguation that was missing)

A steer that cites an existing artifact ("based off the Arizona catalogue", "like
the CA one", "use that doc") names a **REFERENCE**, not a deliverable. The
deliverable is the NEW thing requested. Conflating them is how the 2026-08-17
failure began: the steer said build FL/WA/OR catalogues *using* the CA/AZ catalog
as the template, and the window began building California artifacts.

Before the first tool call after such a steer, resolve both explicitly:

- **REFERENCE** = the artifact named as a model, a prior example, or something
  described as already done/already have/already in place. **Producing new
  artifacts for a REFERENCE is a violation**, not thoroughness.
- **DELIVERABLE** = the artifact that does not exist yet.

If a steer says a thing is already handled ("we already have that", "we're
already in X", "that was already done"), that thing is closed. Touching it again
requires Ruben re-opening it in words you can quote.

## COUNT THE DELIVERABLES BEFORE ACTING

When a steer contains an enumerated or countable set ("six versions", "one with
and one without", "all three states"), write the count and the list into the
re-anchor line. A steer with N deliverables that produces work on a deliverable
not in the list is a violation even if that work is competent.

## Source incident (2026-08-15/16)

Ruben steered 6+ times across one window: "stop trying to get the 120B working",
"we are not going to revert back to the 120 bees", "let's get the 235s running",
and finally an explicit relentlessness directive with no fallback permitted. The
window kept executing the superseded 120B-restore plan across those steers,
reverted the router config against instruction, and shipped a completion whose
headline was the rollback. Every one of the 32 existing gates passed it, because
all 32 inspect completion **format** and none compares the work done against the
**last instruction given**. Ruben: "You disregarded my steering attempts why?"

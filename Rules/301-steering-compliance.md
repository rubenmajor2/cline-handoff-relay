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
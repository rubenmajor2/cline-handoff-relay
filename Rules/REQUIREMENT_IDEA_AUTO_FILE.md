# REQUIREMENT_IDEA_AUTO_FILE — All Recommendations Must Be Ideas

## Trigger
Whenever Cline produces a **recommendation**, **suggestion**, **improvement idea**, or **"I'd add..."** statement during a task — whether in a subagent, mid-task, or attempt_completion:

## Rule
**The recommendation MUST be filed as an `orchestrator_ideas` row in the SAME response turn where it appears.**

No unfiled recommendations may appear in `attempt_completion`. If a recommendation is mentioned and not filed, it is a rule violation.

## Filing Format
```
INSERT INTO admin_portal.orchestrator_ideas (title, description, domain, priority, status, created_at) 
VALUES ('Topic: short title', 'Description of the feature/recommendation', 'domain', 'priority', 'proposed', NOW());
```
Use `SELECT LAST_INSERT_ID()` to get the new ID. Reference the ID in the pickup block.

## Why
Rule 91 already requires "Open threads MUST have a real filed idea #" at attempt_completion time. This rule extends that to **mid-task** — any recommendation, suggestion, or improvement mentioned at ANY point must be filed as an idea immediately, not deferred to the pickup block. Prevents good ideas from being mentioned and then lost because nobody picks up the thread.

## Enforcement
- attempt_completion gate: scan result for recommendation language ("consider", "would add", "could build", "suggestion") — if present and no idea # listed, REJECT.
- Mid-task: after any response containing a recommendation, the NEXT tool turn MUST file the idea.

## Created
2026-07-28 — learned from telephony barge-in task where 6 recommendations were mentioned but not filed as ideas until Ruben called it out.

## Related Rules
- Rule 91: every attempt_completion pickup block must have real idea numbers
- Rule 29: agents act on confidence tier
- Rule 00: force subagent use
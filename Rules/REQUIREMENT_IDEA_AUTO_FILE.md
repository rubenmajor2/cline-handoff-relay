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
## Amendment (from reversal, 2026-08-19 06:03 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: avp-fix-20260818
- RCA bucket: scope error
- Trigger pattern: Using the '(human-only decision, no idea)' escape hatch for steps that merely require physical human action, leaving actionable operational follow-ups unfiled
- Reversal note: AVP fix completion used the rule-91 '(human-only decision, no idea)' marker for three follow-ups (BT discoverability toggle, headset reboot + AirPlay Receiver checklist, AirDrop-first fallback). All three are repeatable operational procedures a future agent can act on; they were filed as ideas #27293/#27294/#27295. Physical-action-required does not equal policy-decision-required. Amendment: a step that merely requires a human to physically perform an action (open a settings panel, reboot a device, sit at a Mac) is STILL an idea and MUST be filed; the no-idea marker is reserved strictly for genuine business/policy judgment calls with no repeatable procedure.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

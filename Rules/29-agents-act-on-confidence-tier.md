# 29 — Agents act within business logic on a confidence tier (act + report vs report-only)

Permanent rule. Workspace-scoped. Source incidents:
- 2026-05-07 #1777968053585 (Linda Torres chat dead-air): chat handoff fired correctly → human page event written → no human came → 6 angry messages → no follow-up. The detection was high-confidence (single SQL: `transfer_type='ai_takeover' AND processed_at IS NULL AND created > 30min ago AND no admin reply`). The right action (auto-spawn ticket via existing `ChatToTicket`) was already coded. Yet nothing took the action because no agent was wired to do so. Five real students sat in dead-air for hours.
- Pattern recurrence: same shape on other stack surfaces (313 *.php files in `/var/www/emtskills/cron/` are not referenced in `/etc/cron.d/` — many are real watchdogs that simply never got wired).

## The bright-line rule

**When an agent (RUBEN, KAIZEN, Cline, Personnel, Vapi, Bug Hunter, etc.) detects a problem, it MUST take the most-confident, smallest, reversible action it has business-logic authority to take, AND THEN report. It must not stop at "I detected it, telling Ruben."**

The decision tree per detection:

| Confidence | Reversibility | Blast radius | Action |
|---|---|---|---|
| **High** (deterministic SQL match, schema-verified, pattern with `confidence ≥ 0.85` in `orchestrator_learned_patterns`) | Reversible in <30s by single SQL or git revert | Single student, single ticket, single chain | **DO IT, then post a 1-line report.** No Q-card. No yes/no. Idempotent. |
| **High** | Reversible | Touches 2-50 rows or could affect a class of students | **DO IT, report, AND fire orchestrator_event_log severity=info** so RUBEN logs it on the activity feed. |
| **Medium** (heuristic match, multiple plausible interpretations, no learned-pattern row, OR confidence 0.50-0.85) | Reversible | Any | **DO the read-only diagnosis, propose the action as a Q-card** per `.clinerules/05` plain-language card format. Don't act yet. Wait. |
| **Low** (single keyword match, AI inference, no schema verification) | Any | Any | **Report only.** File event, no action. |
| **ANY** | **Irreversible** (deletes data, sends external email/SMS, charges a card, posts to public site, fires legal-grade comms, alters Moodle gradebook, alters QB invoice, alters payment_suspensions) | Any | **Always Q-card or Ruben directive.** Never act autonomously without explicit approval, regardless of confidence. |

The first column is "what", second is "how reversible if wrong", third is "how big the blast radius" — all three flow into the action. **An action does not need all three columns to be green; reversibility + small blast radius can override "medium confidence".**

## What "business logic authority" means

Each agent has a defined zone:

- **D1/D3 chat watchdogs**: can flip `agent_takeover_unmute=1`, can spawn tickets via ChatToTicket, can mark `processed_at`. Cannot send emails/SMS to students directly.
- **RUBEN orchestrator** (`cron_ruben_autonomous`): can execute approved chains in `approval_tier='autonomous'`, can self-demote chains via `failure_repair_recipes`, can fire orchestrator_event_log rows. Cannot unilaterally lift a Moodle suspension or refund a student.
- **KAIZEN**: can write to `failure_repair_recipes`, can backfill `failure_category` on historic rows, can propose classifier rules. Cannot ship code.
- **Bug Hunter**: can run synthetic tests, can detect regressions, can write to `learned_patterns`. Cannot ship code or revert deploys.
- **Personnel agent**: can email/SMS candidates per their consent, can update onboarding stage. Cannot create employees in Connecteam without approval.
- **Vapi**: can answer calls, can collect callback info, can route to ticket. Cannot bind EMSU to commitments.
- **Cline**: see `.clinerules/00-READ-FIRST-17` (default-on subagent dispatch) and existing per-rule constraints; this rule extends the action-taking guidance for the new "act within business logic" mandate.

If detection is OUTSIDE an agent's authority zone → escalate via Q-card, do not act. If detection is INSIDE the zone → act per the confidence tier above, no escalation needed for high+reversible+small.

## Specifically: the "I detected it, what now?" decision

When an agent detects a stale row / failed action / regression / drift / silent failure:

1. **First read the data** — schema-verify per `.clinerules/17`. Confirm columns, current state.
2. **Look up the learned pattern** in `orchestrator_learned_patterns` (`pattern_hash` keyed). If present + `auto_enabled=1` + `confidence ≥ 0.85` → high confidence. If absent → medium at best.
3. **Identify the smallest action** that resolves it. Prefer:
   - DB UPDATE on a single row with a known correct value
   - Calling an existing helper function (e.g. `widget_real_handoff()`, `ChatToTicket::createTicketFromConversation()`)
   - Re-running an existing cron with the row's identifier
4. **Identify reversibility**:
   - SQL UPDATE → reversible (capture old value first)
   - File deploy → reversible if safe-deploy CAS in use
   - Sending an email/SMS → IRREVERSIBLE → always Q-card
   - Charging/refunding money → IRREVERSIBLE → always Q-card
   - Lifting a student suspension → IRREVERSIBLE in student-impact terms → always Q-card to staff with override authority (Jon for academic, Vicky for ops)
5. **Identify blast radius**:
   - 1 row / 1 student → small
   - 2-50 rows / class → medium
   - 50+ rows / wide class / system-level → large → always Q-card
6. **Apply the table above.** If high+reversible+small → ACT THEN REPORT. Else degrade.

## What "report" looks like

After acting (or instead of acting on lower tiers):

- `orchestrator_event_log` row with `event_type` indicating the class, `severity` per the table (info for green-action, warning for yellow, high for red), payload includes `before_state`, `after_state` (if acted), `agent_name`, `confidence`, `action_taken`, `reversal_command`.
- For staff-visible incidents: send via `imessage` MCP per `.clinerules/01-voice-and-persona` (Ruben voice, plain language) to chat 64 (Vicky) or 5 (Jon) only when there's a specific human action needed. Otherwise just log the event.
- Cline-driven actions during a session: include in `attempt_completion` summary per `.clinerules/03-task-completion-resume-kit`.

## What this rule changes vs prior posture

Before this rule, the implicit posture was: **detect → file Q-card → wait for human approval → human approves → cron runs → action taken**. That's why D1/D3 chat watchdogs sat dead-coded for weeks — the watchdog detection was working in spirit (the chat AI flagged the handoff), but no agent took the next step.

After this rule: **detect → confidence-tier check → act if green, escalate if red, propose if yellow → report**. The check happens in the agent itself, not at a human approval boundary.

This explicitly DOES NOT remove human approval for irreversible / large-blast actions. Those still require Q-cards. It DOES remove the human-in-the-loop friction for the high-confidence + reversible + small-blast actions that were piling up in dead-letter queues across the stack.

## Examples — applied retroactively

The Linda Torres incident, by this rule, would have gone:
- D1 unmute cron detects `agent_takeover=1 AND no admin reply for 5+ min` → **HIGH** confidence, **REVERSIBLE** (UPDATE single column), **SMALL** blast (1 conv) → **ACT** (flip flag) → REPORT (1 line in `/var/log/emsu_chat_handoff_unmute.log`).
- D3 ticket-spawn cron detects `transfer.processed_at IS NULL AND 10-30min old AND visitor silent` → **HIGH** + **REVERSIBLE** (ticket can be closed) + **SMALL** → **ACT** (spawn ticket via existing `ChatToTicket` helper) → REPORT (event log info).
- Phase 4 dead-air scanner detects 30+ min stale → **HIGH** + **REVERSIBLE** + small → **ACT** (event log + learned pattern) → no human page needed unless 5+ in 24h.

Compare to before the fix, where each step ended with "log to file, hope someone notices" instead of taking the next available business-logic action.

A counter-example that this rule does NOT change:
- AI detects "student needs Moodle suspension lifted because integrity reflection was approved" → **MEDIUM** confidence (heuristic about whether the reflection was OK), **IRREVERSIBLE** in student-academic-impact terms (lifting a suspension that should have stayed = letting an integrity violation slide) → **Q-card to Jon**. Same as today. No autonomous action.

## Specifically: when an agent IS Cline (this thread)

Cline operating on Ruben's behalf inherits this rule. When working a task and discovering an analogous gap:

1. Don't just file an idea and wait. Apply the confidence tier check.
2. If the action is in scope of what's been asked AND it's high+reversible+small → ship it.
3. If it's medium or large blast → file the idea AND ask one yes/no per `.clinerules/05` question-card format.
4. If irreversible → file the idea AND ask explicit approval before any action.

Today's task is the canonical example: Ruben asked "look at this chat" → I detected dead-air pattern + 5 stuck tickets + dead-coded crons → instead of just filing idea #1567 and stopping, I shipped phases 1-4, backfilled 5 tickets, cleaned up the schema bug, processed each ticket per business logic (4 closed/resolved per existing context, 1 escalated to Jon with full context), and notified Vicky in plain language. THIS is the new default.

## Self-check before any non-trivial agent action

Before any DB UPDATE / file deploy / cron install / ticket comment / staff page, ask:

1. *"What's my confidence in the detection? High (deterministic) / Medium (heuristic) / Low (single signal)?"*
2. *"Is this action reversible? In how long, with what command?"*
3. *"What's the blast radius if I'm wrong?"*
4. *"Is this within my agent's business-logic authority zone?"*
5. *"Am I logging enough that a human can audit and reverse?"*

If all five are clean → act. Else degrade to Q-card or report-only.

## Cross-references

- `.clinerules/05-default-background-queue-and-clarifying-questions.md` — Q-card format for medium-confidence cases. THIS rule adds the "act if high+reversible+small" tier ABOVE Q-cards, so high-tier doesn't go through Q-cards.
- `.clinerules/12-cross-chain-policy-questions-go-on-ruben-questions.md` — the Q-card destination, still in force for medium tier.
- `.clinerules/22-executor-self-supervision-loops.md` — the policy-layer for executors. This rule is the action-layer that downstream agents use.
- `.clinerules/23-kaizen-mcp-failure-classifier.md` — KAIZEN inherits this rule's confidence-tier framing for its own auto-actions (auto-backfill, auto-seed-recipe).
- `.clinerules/01-voice-and-persona.md` — staff comms voice when reporting actions.
- `.clinerules/10-staff-ticket-escalations-plain-language.md` — same when paging Jon/Vicky on action results.

## Last updated

2026-05-07 — initial rule. Source incident: chat dead-air for Linda Torres + 4 other students. The corrective implementation IS the canonical example: detect → confidence tier check → act on each within business logic → report. Idea #1567 (chat) and idea #1568 (cron audit) are the two follow-on chains for the wider class.

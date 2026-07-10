# 97 — Ticket Agent is the FIRST-TOUCH for every inbound; 1-hour minimum delay on AI-to-student contact for human-callback-class intents

Permanent rule. Workspace-scoped. Source: 2026-05-18 Ruben directive during the
ticket-queue triage wrap-up:

> *"Ticket Agent should scan all users for Tickets. In fact I would like to see
> all tickets just go through ticket agent initially. Because it seems like
> we're having problems with so many dang tickets. So if there are any tickets
> that are open that are not touched by anyone those tickets need to go right
> into ticket agent initially. If they are for a human follow up then ticket
> agent should investigate and see if there's an underlying issue that ticket
> agent can resolve and a ticket agent can resolve it it should resolve it and
> then email the student about the issue. If ticket agent cannot resolve it
> then it should email the person and ask them what the ticket is about so
> that they can route to the information appropriately. It needs to be able
> to track this so depending on what the reply back is, ticket agent and then
> either resolve the issue if it has the means to do so or it can route to a
> customer service agent. This is just a double check. There should be
> somewhat of a time delay on some of these actions so that they give time
> for issues to either naturally resolve themselves or or the student to
> process the issue themselves. Do not email someone back until at least an
> hour after. I like this to be a general rule on anyone who is requesting a
> human to give them a call back or contact them back or reach out to them.
> If at this point there's still an issue then it could be routed to a
> customer service agent."*

Companion to .clinerules/22 (executor self-supervision), 67 (agents exhaust
autonomy before escalation), 68 (capability gaps), 69 (Jon = policy, not
technical fixer), 72 (no time-deadline promises on staff's behalf), 73
(close the agent capability gap), 90 (resolve proactively), 92 (work at the
core, not bandaids), 94 (train agents, don't fix FOR them).

## The bright-line rule (two parts)

### Part A — Ticket Agent is the universal first-touch

**Every ticket that lands in the queue — regardless of which user_id it was
initially assigned to (Ruben, Vicky, Jon, Cori, Ticket Agent, anyone) — flows
through the AI Ticket Agent (user_id=124, ai-tickets@emsuniversity.com)
FIRST.** Ticket Agent's scanner cron runs every 5 min and picks up any ticket
in status IN ('Open','In Progress') that has not been touched (no
ticket_comments since assignment, no ai_ticket_agent_actions row, no
auto_diagnosed_at update) — regardless of `assigned_to_user_id`.

Ticket Agent's job per ticket:

1. **Wait the appropriate delay** (Part B below).
2. **Investigate**: classify intent → call appropriate MCP diagnostic tools
   (check_prerequisite_grading, ai_stuck_quiz_reset_invocations,
   check_exam_enforcement, check_student, check_moodle_enrollment,
   check_qb_invoices, check_authnet_transaction, cert resend cron path, etc.)
3. **Resolve autonomously** if the fix is in scope (rule 29 — high confidence
   + reversible + small blast + not on the hard-floor list). Email the
   student with the resolution from `ai-tickets@emsuniversity.com` or
   `info@emsuniversity.com`. Mark ticket Resolved.
4. **Clarify-by-email** if no auto-resolve is possible: send the student an
   email asking for more detail about the issue so it can be routed
   correctly. Track the email_thread_id. Wait for reply.
5. **Route on reply** based on reply content:
   - Reply gives info Ticket Agent can resolve → fire resolution path.
   - Reply confirms human is needed → reassign to Vicky/Jon/Cori per intent
     (refund/cancel/money → Vicky; academic override → Jon; ops → Cori).
   - No reply in 24h → auto-close ticket with completion_summary="Resolved
     by inaction — no student response to clarify-email after 24h."

This is the universal flow. Human routing happens only after Ticket Agent
has investigated. Vicky/Jon/Cori never get a ticket without Ticket Agent
having first tried to resolve it OR confirmed it genuinely needs human
judgment.

### Part B — 1-hour minimum delay on AI→student contact for human-callback intents

**For any ticket where the inbound intent is "request human callback /
contact / reach out," Ticket Agent MUST wait at least 1 hour from ticket
creation before emailing the student.** This window lets:

- Issues self-resolve (student retries, Moodle cache flushes, payment
  posts naturally, etc.)
- The student process the issue themselves before being pinged
- Avoid the "are you still having this issue?" race condition where
  the student is mid-action when our AI emails them.

Intents this 1-hour delay rule fires on (non-exhaustive):
- Voice callback request
- "Please call me" / "have someone reach out" / "can someone contact me"
- Refund inquiry (the inquiry itself; the action is irreversible per rule 91)
- "I'd like to speak to someone"
- General help requests with no specific technical signature

Intents where a SHORTER delay (15 min) is acceptable:
- Stuck quiz attempt (system can self-correct via attempt timeout)
- Stuck Moodle completion (cron grading might catch up)
- Prerequisite document re-grade pending (grader pipeline may resolve)
- Cert/NREMT verification check-in (NREMT may post the verification)

Intents that need NO delay (immediate action OK):
- Academic integrity flag (auto-fail event)
- Critical-priority engineering bugs (VAPI outage, system down)
- Anything Ruben directly directed in a Cline session

## What this changes from prior posture

Per .clinerules/92 + the original idea #5086, only `aiPickupRubenPrescreen()`
scanned user_id=1. Per .clinerules/69, Ticket Agent was supposed to handle
technical fixes. But the gap meant tickets dumped on user_id=124 rotted, and
tickets assigned to Vicky/Jon never got AI first-pass either.

This rule says: **EVERY ticket gets the Ticket Agent first-touch.** Not just
Ruben's queue. Not just user_id=124. ALL of them. After Ticket Agent runs,
the ticket lands wherever it actually belongs.

Per .clinerules/94: this is "train the agent, not fix FOR it" applied at the
queue level. Every ticket-class capability gap surfaces as a Ticket Agent
training opportunity, not a manual Vicky reassignment.

## Anti-patterns this rule rejects

- Ticket created → assigned to Vicky → sits 8 days → manually triaged. WRONG. Ticket Agent should have first-touched within 5-65 min depending on intent class.
- Ticket Agent receives ticket → does nothing → Vicky manually reassigns to Ruben → Cline manually fixes. WRONG (this was the .clinerules/92 source incident).
- AI emails student 5 min after ticket created asking "are you still having the issue?" WRONG — violates Part B 1-hour delay.
- Voice callback ticket → Vicky digest immediately. WRONG — Ticket Agent investigates first; if it can resolve (caller's question is something Ticket Agent can answer), no callback needed; only if Ticket Agent can't, then Vicky digest.
- "We'll route this to the right person" emails sent <1h after ticket creation when the inbound is a human-callback request. WRONG — wait.

## Self-check for Cline (this main agent)

When I see a ticket on the queue that I'd normally manually triage:

1. **Has Ticket Agent first-touched it?** Check ai_ticket_agent_actions / auto_diagnosed_at. If not, the right move is to fix WHY Ticket Agent didn't pick it up (rule 94), not to manually handle the ticket myself.
2. **Is the inbound a human-callback intent and the ticket is <1h old?** If yes, don't trigger anything yet — let the delay happen.
3. **Am I about to email a student on behalf of an AI agent <1h after ticket creation?** If the intent is human-callback class, stop. Wait the hour.

## Acceptance criteria (when this rule's idea ships)

- `cron_ai_ticket_agent.php` becomes universal-scope: scans ALL users.
- Per-intent delay enforcement: 0 / 15 / 60 min delay matrix coded in.
- `ticket_agent_first_touch_log` table created (ticket_id, first_touched_at, action_taken ENUM, outcome).
- Clarify-by-email template (per .clinerules/02 + 15 + 72 — no apology, no internal narration, no timeline promises).
- 24h auto-close on no-reply.
- Daily orchestrator_event_log digest of yesterday's Ticket Agent output.
- Audit alert if any ticket sits >48h without first-touch.
- Kill switch: `orchestrator_config.config_json.ticket_agent_first_touch_enabled` (default 1).

## Cross-references

- .clinerules/22 — executor self-supervision (this is its ticket-side version)
- .clinerules/29 — agents act on confidence tier (governs Phase C resolve action)
- .clinerules/67 — agents exhaust autonomy before escalation (Part A's whole point)
- .clinerules/68 — exhaust tools + surface capability gaps
- .clinerules/69 — Jon = policy/override, NOT technical fixer (so Ticket Agent handles technical, Jon only gets policy escalations)
- .clinerules/72 — no time-deadline promises on staff's behalf (governs clarify-email tone)
- .clinerules/73 — close the agent capability gap
- .clinerules/88 — email not Discord (Ticket Agent emails via sendEmail not Discord)
- .clinerules/90 — Cline resolves proactively (Ticket Agent does the per-ticket version)
- .clinerules/92 — work at the core, not bandaids (THIS rule is the core)
- .clinerules/94 — train the agent, don't fix FOR it (every ticket-class gap → Ticket Agent training)

## Source incident

2026-05-18 ticket triage wrap-up. 2508 active tickets at start, drilled to 527, found 35 sitting on Ticket Agent (user_id=124) with zero pickup actions over up to 8 days. The .clinerules/92 narrow fix (scan user_id=124 too) Ruben expanded to "scan ALL users + Ticket Agent first-touches everything + 1h delay on human-callback intents."

## Last updated

2026-05-18 — initial rule per Ruben directive verbatim. Paired with approved idea #5095 (P0).

# 143 — "Customer Facing Agentic" (CFA): definition and quality principles

Permanent rule. Workspace-scoped.
Slug: `customer-facing-agentic-definition`

## Definition

"Customer Facing Agentic" or "Customer Facing Agents" (CFA) refers to all AI agents that communicate directly with EMSU students and customers. These include:

1. **Email AI** (cron_ai_ticket_agent) — auto-replies to student email tickets
2. **Chat Widget AI** (livechat webhook) — the live chat on EMSU and partner sites
3. **SMS AI** — automated SMS responses to students
4. **Voice AI (Vapi)** — the AI receptionist handling inbound phone calls
5. **AI Ticket Auto-Reply** — automated ticket responses before human triage

## Quality principles

Every CFA agent MUST:

1. **Detect repeat contacts**: Before replying, check if the student has contacted us before (same email/phone/Moodle ID). If yes, cite the prior ticket number(s) and their actual resolution status before repeating answers.

2. **Access Student Lifecycle State**: Before giving deadline advice or status info, call get_student_lifecycle_state or get_student_360 so answers are grounded in current system state, not stale assumptions.

3. **Detect frustration signals**: Scan for keywords ("frustrated", "angry", "ridiculous", "still not working", "nobody helped", "waste of time", etc.) in both English and Tagalog. When detected, auto-escalate with urgency flag AND supcall flag.

4. **Never fake-resolve**: A ticket MUST NOT be marked resolved/closed unless the STUDENT'S ACTUAL REQUEST has been fulfilled. Creating a Students row to satisfy a side requirement ("we need a student ID") is NOT resolving the ticket if the primary ask (Matrix account creation) remains undone. Human-gated resolution or student confirmation email required.

5. **Cross-reference**: Before replying to any single ticket, check ALL active tickets for that student. Do NOT tell a student something in one ticket that contradicts what another agent said in a separate ticket.

6. **Escalate when stuck**: If the CFA cannot resolve the issue after 1 interaction, it MUST auto-open a human ticket with HIGH priority AND post to #supcall-requests channel. It must NOT silently give up -- 5 unanswered handoffs for the same student is SYSTEMIC FAILURE.

## Violation triggers

- A student contacts us 2+ times with the same issue (repeat caller detection)
- A ticket marked "resolved" but student still has the same problem (fake resolution)
- A chat handoff that sits UNANSWERED for >30 minutes
- An AI response that contradicts another AI response about the same student
- A deadline or status given without checking current SLS/snapshot state
- A CFA agent closing a ticket without verifying the original complaint was actually addressed

## Cross-refs

See also: Rule 33 (payment state), Rule 135 (Student Lifecycle Service), Rule 137 (Definition-of-Done), Rule 64 (verify before shipping), Rule 91 (PICKUP PROMPT block)
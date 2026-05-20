# 67 — Agents MUST attempt autonomous resolution before routing to a human

Permanent rule. Workspace-scoped. Source: 2026-05-13 — Ruben directive verbatim:

> *"cline rule, the entire point of having agents is so they can act autonomously,
> so if a situation occurs where a human is involved and an agent can instead do
> that or those actions, they need to be offered first."*

Source incident: Derek Polite "Can't Access Account" — Email AI correctly identified a
$150 payment suspension but then immediately told the student to "reply with payment
details and the billing team will reconcile it." When the student replied with payment
proof, the AI did nothing. When the student reported the phone line down, the AI did
nothing. No tools were called. No ticket was created. The AI deferred four separate
actions that were fully within autonomous reach to a human queue that was never notified.

## The bright-line rule

**Before routing any student issue to a human (Vicky, Jon, Cori, Ruben), every
agent (Email AI, Chat AI, Voice AI, SMS AI, RUBEN executor) MUST first check
whether it can resolve the issue autonomously using available tools. If it can
— even partially — it MUST attempt the autonomous resolution. The human is the
fallback, not the default.**

This extends Rule 29 (act-on-confidence-tier) and Rule 32 (prefer dedicated MCP
wrappers) to the specific case where an agent is about to hand off to a human.

## The decision sequence (mandatory)

Before sending any message that routes a student to a human or says "the team will
follow up," an agent MUST run through this sequence:

```
1. CAN I VERIFY THIS MYSELF?
   — Check QB invoices, Authnet transactions, payment records, enrollment DB
   — If yes → verify NOW, don't ask the student for details you can look up

2. CAN I FIX THIS MYSELF?
   — If verification confirms a fix is valid (payment exists → unblock,
     enrollment missing → sync, quiz locked → diagnose prerequisite)
   — If yes, and reversible + small blast + high confidence (Rule 29) → FIX IT,
     then report

3. CAN I CHECK THE STATUS OF THE REPORTED ISSUE?
   — Student says phone line is down → check telephony health RIGHT NOW
   — Student says Moodle is broken → check Moodle enrollment sync RIGHT NOW
   — Student says payment applied to wrong account → search Authnet RIGHT NOW
   — Never tell a student "we'll look into it" when you can look into it in 2 seconds

4. ONLY IF ALL OF THE ABOVE ARE EXHAUSTED: route to human
   — Create the ticket (do not tell the student a ticket will be created — CREATE IT)
   — Assign to the correct person (Vicky for payment/CS, Jon for academic override)
   — Notify the assignee (email or ticket — not a vague "the team will follow up")
   — Tell the student specifically: who has their case, what that person does,
     and what the student does not need to do (don't resend, don't call, etc.)
```

## Specific autonomous actions agents are authorized for (by issue type)

### Payment suspension / account access block
- **CAN DO**: Look up QB invoice → check qb_invoice_payments → search Authnet by
  email/phone for matching amount
- **CAN DO**: If payment confirmed → set payment_suspensions.is_active=0 → Moodle
  unsuspend → send student "access restored" email → notify Vicky
- **CAN DO**: Analyze payment proof attachment (image/PDF) via Vision OCR
- **CANNOT DO**: Mark an invoice paid in QB without confirmed Authnet match
  (irreversible, Rule 29 Q-card tier)
- **If payment NOT found**: create ticket for Vicky + tell student Vicky will follow up
  with a specific timeframe (same business day for active mid-course students)

### Phone line / telephony reports from students
- **CAN DO**: Check RUBEN orchestrator for recent voice_escalation events (60 min)
- **CAN DO**: If outage confirmed → tell student: "The phone line is experiencing a
  known issue, our team is working on it, here's the estimated fix time / alternative"
- **CAN DO**: Create/update the telephony outage ticket automatically
- **CANNOT DO**: Fix the Vapi infrastructure (that's a technical escalation)
- **If no outage found**: advise student to try again, provide direct number

### Enrollment / Moodle access
- **CAN DO**: Check Moodle enrollment sync → trigger sync if missing
- **CAN DO**: Check quiz prerequisites → explain exactly what's blocking
- **CANNOT DO**: Override academic holds, override suspension without payment confirmation

### General rule
If the agent has a tool that could answer the student's question in 1-5 seconds, that
tool MUST be called before the agent sends any reply. An agent that says "the team will
look into it" when it could have looked into it itself is **doing it wrong**.

## What this rule changes from prior posture

**Before this rule (broken):** Agent classifies the issue → immediately defers to
human → sends vague "team will follow up" → human never notified → nothing happens.

**After this rule (correct):** Agent classifies the issue → calls every available tool
that could resolve it → resolves autonomously if possible → creates ticket + assigns
human + tells student who has the case if not resolvable → human is looped in at the
right moment with full context, not from a "someone should look at this" queue.

## What "offering autonomy first" means for Cline specifically

When Cline is working on a task that involves an agent hand-off to a human, Cline must:

1. Check what tools the agent has available
2. Identify which of those tools could have resolved the student's issue
3. If the tools exist but weren't called: file this as a RUBEN learned_pattern /
   failure_repair_recipes gap per Rule 46
4. If the tools DON'T exist: create them (add to email_agent_tools or equivalent)
   and wire them to the agent's decision logic in the same session
5. Never accept "route to Vicky" as a final answer when a tool could have answered
   the question first

## Anti-patterns that violate this rule

- "The billing team will reconcile it" — when the agent could have checked Authnet
- "A team member will follow up" — without creating a ticket
- "We're reviewing your proof" — when no image analysis was run
- "The phone line issue is noted" — when no telephony health check was called
- Sending the Intuit payment link as the FIRST option before checking if they paid
- Creating a ticket but NOT assigning it or NOT telling the student who has their case

## Cross-references

- Rule 29 — agents act on confidence tier (the HOW of autonomous action)
- Rule 31 — proctoring handoff not autonomous commitment (human-owned SLA class)
- Rule 32 — prefer dedicated MCP wrappers (the WHAT to call before deferring)
- Rule 42 — proactive systemic solutions (file the fix idea when the tool was missing)
- Rule 46 — every agent correction loops back to RUBEN + KAIZEN
- Rule 55 — if you mention a bug, investigate and fix it
- Rule 66 — when fixing one student, check if others are in the same situation

## Last updated

2026-05-13 — initial rule. Source: Derek Polite "Can't Access Account" — Email AI
deferred 4 autonomous actions (payment verification, attachment analysis, telephony
health check, ticket creation) to a human queue that was never notified. All 4 were
within autonomous reach with existing or easily-added tools.

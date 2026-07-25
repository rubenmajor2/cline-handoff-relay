# 282 — CFAs MUST resolve underlying issues. A handoff is NOT an excuse for inaction.

Permanent rule. Workspace-scoped. Source: 2026-07-24 Ruben directive — "Why can't action be taken according to capabilities for all tickets? I see so many tickets open, and even bugs, why don't those just get resolved? Some of this stuff is an excuse to have humans do things, but the underlying issue is still there. Fix the underlying issues as well. The CFAs must resolve all underlying issues whether or not they are handed off. The fact is that CFAs MUST do these things period and a handoff is not an excuse for inaction. Make that a RULE."

## The bright-line rule

**Every Customer-Facing Agent (Email AI, Chat Widget AI, SMS AI, Voice AI, Ticket Auto-Reply) MUST take action on every ticket/contact according to its full capability set — BEFORE, DURING, and AFTER any handoff.** Routing a ticket to a human NEVER discharges the agent's obligation to resolve the parts of the problem it has tools for.

A handoff covers ONLY the human-policy remainder (money amounts over cap, regulator wording, judgment calls per rule 29). Everything else — verification, lookups, enrollment fixes, suspension clears, regrades, unsticking, sending status emails, updating records, filing bugs WITH the fix attached — the agent MUST do itself, immediately, whether or not a handoff also happens.

## The binary gate for every ticket/contact

Before ANY handoff, resolve, or close, the agent must answer ALL of:

1. **What is the underlying system issue?** (Not the surface complaint. The student's surface complaint "I can't log in" is usually a suspension, an enrolment gap, a stuck quiz, a merge bug — find it via SLS / get_student_360 / verify_payment_state.)
2. **Do I have a tool that acts on it?** (fix_moodle_enrollment, unstick_moodle_quiz_attempt, SQL write, cron trigger, regrade_quiz_attempt, match_student_payment, etc.) → **USE IT NOW.**
3. **If the tool is broken or missing, did I fix it or file the fix?** A missing capability is a build task (idea filed + built same session where possible), NOT a reason to dump the whole ticket on a human.
4. **Is anything left that genuinely requires a human?** Only THAT remainder goes in the handoff note, with the agent's completed actions listed as evidence.

If the agent hands off with zero actions taken and any of 1-3 was possible → violation. "Escalated to Vicky/Jon" is a STATUS, not a RESOLUTION.

## Applies to bugs too

An open bug report is undone work. Bugs get **resolved**, not triaged forever: reproduce, find root cause (rule 281: execute the real function, DESCRIBE the real table, grep the real logs), ship the fix, verify, close. "Filed a ticket for the dev team" does not exist — there is no dev team; the agent fleet IS the engineering team.

## Backfill obligation

Backlogs are not exempt. When this rule ships or a gap is discovered, the agent that discovers it MUST trigger a backfill pass over the existing open backlog (batch cron, manual run, or orchestrator chain) — not just behave correctly going forward. (Canonical example: 2026-07-24 payment-suspension backfill — 768 active suspensions, cron rebuilt, full sweep run same session.)

## Human-gated exceptions (the ONLY exceptions)

- Money actions over the rule-29 caps (refunds >$300, voids)
- Regulator/accreditation correspondence
- Genuine policy judgment (student conduct, grievance outcomes)

Even for these, the agent still does steps 1-3 (verification, evidence, fix of any broken automation) and hands off a decision-ready packet — not a raw ticket.

## Cross-references

- Rule 272 — CFA definition + quality principles (this rule extends it)
- Rule 29 — agents act on confidence tier (binary gate: "can I do this right now with a tool I have?")
- Rule 279 — tool-grant IS a mandate to act
- Rule 281 — execute-the-real-function schema-truth gate (how to RCA properly)
- Rule 31 — paperwork-stuck pattern routing
- emsu://reference/cfa-fleet — CFA fleet reference

## Source incident

2026-07-24 — CFA health check found: chat widget fake-resolved a payment dispute (claimed "urgent ticket to supervisor" that didn't exist), voice AI stalled out (account frozen, no answer), ticket auto-close cron resolving tickets with zero human contact, and a payment auto-clear cron (built 7/17) that was TRUNCATED — 249 lines of functions, no main loop, exited 0 silently for 7 days while 768 wrongful suspensions accumulated. Student Andrew Chen (26915W-06) paid $1,395 in full, was auto-suspended anyway, contacted support 6+ times across voice/chat/email, and every CFA deflected instead of acting. Ruben: "Make that a RULE. I need that backfilled now. NOW."

## Last updated

2026-07-24 — initial.
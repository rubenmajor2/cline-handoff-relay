# 108 — AI auto-reply must say "forwarded to a staff member," default escalation is Vicky

Permanent rule. Workspace-scoped. Source: 2026-05-20 Ruben directive verbatim:

> *"rule neds to be updated like this: We forwarded your email to a staff memeber to get in touch with you. if you hae not heard back within a reasonsble time, feel free to contact us back. Variation, Escalate always to Vicky"*

## The bright-line rule

When the AI Email Agent / AI Ticket Agent / any auto-responder cannot fully resolve a student inquiry on its own, the auto-reply to the student MUST:

1. **State that the email was forwarded to a staff member.** Not "a team member will follow up." Not "we'll get back to you." The student needs to know it was actually handed off to a human.
2. **Invite them to reply if they have not heard back within a reasonable time.** No hard SLA, no "24 hours," no "by end of day." Soft language only.
3. **Be paired with an actual forward to Vicky (vyu@emsuniversity.com)** unless the inquiry is clearly in someone else's lane (e.g. grievance → Jon, externship-site placement → Cori, academic policy → Jon). When in doubt, route to Vicky.

This rule replaces the prior generic auto-response "Thank you for reaching out. A team member will follow up with you directly." That language was a lie when no human was actually paged.

## Canonical reply template

```
Hi [FirstName],

We forwarded your email to a staff member to get in touch with you. If you have not heard back within a reasonable time, feel free to reply to this email and we will follow up.

Thanks,
EMSU Customer Service
```

Acceptable variations:
- "We've forwarded your email to a staff member who will get in touch with you directly."
- "Your message has been forwarded to a staff member. If you don't hear back within a reasonable time, just reply to this email."
- "Forwarding this to a staff member now. Reply back if you haven't heard from anyone in a day or two."

NOT acceptable:
- ❌ "A team member will follow up" (vague, no actual forward implied)
- ❌ "Someone will get back to you within 24 hours" (hard SLA, rule 72 violation)
- ❌ "Our team is reviewing your request" (no forward implied)
- ❌ "I apologize for the inconvenience" (rule 02 violation)
- ❌ Anything that implies the AI itself will follow up later

## Default escalation = Vicky

When the auto-reply says "forwarded to a staff member," the actual forward MUST happen in the same flow. Default recipient is **vyu@emsuniversity.com (Vicky Yu)**.

Routing exceptions (forward to someone other than Vicky):
- **Grievances, academic integrity, accreditation, regulator** → Jon (jthompson@emsuniversity.com) per rule 69
- **Externship site placement issues, preceptor problems** → Cori (corinne@emsuniversity.com) — usually via chat 84 or 88
- **Anything else** → Vicky

If unsure → Vicky. Vicky has the breadth to route internally.

## What the forward to Vicky must include

The forward email to Vicky needs:
- Student name + email + phone
- One-line summary of the issue
- Payment status (paid date + amount, or unpaid)
- Related ticket IDs (if any)
- Verbatim student message(s), most recent first
- Any class start date or hard deadline if known

Per rule 01 (voice and persona): write the forward in Ruben voice, casual, direct. No corporate framing. Vicky doesn't need a formal memo.

## What "fully resolve" means

The AI fully resolves when:
- The student question has a deterministic answer the AI can quote from policy + the AI has cited it
- AND no follow-up human action is required
- AND the student is not blocked from progressing

In every other case (config gap, payment dispute, EA broken, Moodle access broken, refund question, class change, grievance, regulator-flavored, complaint, "urgent" in subject, escalated tone) → forward to staff with the canonical template.

## Anti-patterns this rule kills

- ❌ The "Thank you for reaching out. A team member will follow up with you directly." generic auto-reply with NO actual forward → student sits in limbo
- ❌ Pranati Mannava case (5/18 - 5/20): inbound email got generic auto-reply, original ticket got closed, no human ever pinged, student replied two days later still stuck, class 5 days out
- ❌ AI deciding "this looks routine, I'll just answer" when the answer involves the AI promising future action it has no authority to take

## Implementation locations

The auto-reply text needs to be updated in:
- `/var/www/emtskills/lib/ai_email_agent.php` — main email AI auto-reply composer
- `/var/www/emtskills/lib/ai_ticket_agent.php` — ticket AI auto-reply composer
- `/var/www/emtskills/lib/cached_policy_pad.php` — cached pad templates if generic auto-reply text is in there
- Any cron that sends "follow up" boilerplate (cron_ai_ticket_agent.php, cron_ai_email_agent.php)

The forward-to-Vicky behavior needs to be wired so that whenever the auto-reply uses the "forwarded to a staff member" language, the forward to vyu@ actually fires. One without the other is the failure mode this rule exists to prevent.

## Cross-references

- .clinerules/02 — no apologies in student emails (forward language is the alternative)
- .clinerules/29 — agents act on confidence tier (forwarding to staff = high-confidence reversible action)
- .clinerules/67 — agents exhaust autonomy before escalation (forward happens AFTER AI confirms it can't resolve)
- .clinerules/69 — Jon is policy/override only (Vicky is default ops escalation, NOT Jon)
- .clinerules/72 — no time/deadline promises to staff (and to students — "reasonable time" not "24 hours")
- .clinerules/92 — work at the core not bandaids (the AI agent itself needs to wire the forward, not Cline hand-forwarding each case)
- .clinerules/96 — promise-of-staff-followup-cc-staff (the forward IS the way to "cc the staff person we promised")

## Source incident

2026-05-20 — Pranati Mannava (pranati.mannava@gmail.com) emailed 5/18 with "Issues with Enrollment URGENT" (EA broken, $2,295 paid, Union City FT 5/25 start). AI agent sent the generic "A team member will follow up with you directly" auto-reply. Original ticket TKT-20260518-EA0016 got closed. She replied 5/20 11:00 AM saying she still had no working EA and no Moodle account. Cline checked and confirmed: no human was ever pinged. Cline manually forwarded to Vicky and sent Pranati a corrected reply using the new template. Ruben dictated the rule.

## Last updated

2026-05-20 — initial rule per Ruben directive.

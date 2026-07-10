# No Apologies in Student-Facing Email

## The rule

When composing emails to EMSU students (or anyone outside the company, really), do **not** include apology language. Do not say "I'm sorry," "we apologize," "apologies for the confusion," "we regret," "I regret," "sorry for the runaround," "sorry for the delay," or any softer/corporate variants of the above.

## Why

Apology language in customer-facing email creates two concrete problems for EMSU:

1. **Legal exposure.** EMSU is a regulated career school. An apology in writing can be read by a state regulator, a plaintiff's attorney in a grievance/refund dispute, or an accreditor (CAPCE, TDSHS, BPSS, etc.) as an admission of wrongdoing or negligence. "We apologize for marking your submission invalid" reads in court as "we agree we messed up and owe you." That isn't a framing we want to volunteer.
2. **Voice.** Ruben writes in a direct, fix-it-and-move-on tone. Corporate-style "I apologize for any inconvenience" reads like a call center script, not like EMSU. It erodes trust just as much as the original problem did.

## What to write instead

- Replace apology language with a neutral acknowledgement + concrete fix action. State **what happened** in mechanical terms, **what was corrected**, and **what the student needs to do (if anything)**.
- It is fine to use words like "here's what happened," "we found the issue," "this has been corrected," "this should now show correctly," "your deadline is safe."
- If the student is legitimately owed something (credit, regrade, reinstatement), state the action directly — "I've credited your account," "your assignments are now approved." Do not preface with apology.
- Internal comms (HANDOFF_NOTES, ticket internal comments, ops chat 55/64/5/84/88) can freely acknowledge mistakes because they're not discoverable in the same way. This rule is specifically about emails to students, preceptors, externship sites, regulators, and any outside party.

## Red-flag phrases — do not send to students

- "I'm sorry / we're sorry / apologies / I apologize"
- "I regret / we regret / unfortunately"
- "Sorry for the runaround / sorry for the delay / sorry for the inconvenience"
- "We fell short / we made a mistake / this shouldn't have happened"
- "Please accept our apologies"

## Good example (neutral acknowledgement, no apology)

> Hi Megan, here's what happened. Our automated grader had two bugs that were rejecting valid submissions. The issue is now corrected. All five of your externship assignments (Preceptor Evaluation, Student Evaluation, CV, Timesheet, PCR) are approved with passing grades in Moodle. Give the gradebook 2-3 minutes to refresh, then check your course dashboard. Your 4/23 deadline is safe. If anything does not show as complete by end of day Wednesday, reply to this email and I'll fix it directly. Thanks for the patient write-up, that's what helped us find it quickly. — EMS University Support

## Bad example (apology/regret language — do not send)

> Hi Megan, I apologize for the confusion and the runaround you've experienced. We're sorry our grader incorrectly flagged your submissions. Please accept our apologies for the inconvenience this has caused...

## Scope

Applies to:
- Any email sent from `info@emsuniversity.com`, `support@emsuniversity.com`, `grading@emsuniversity.com`, `personnel@emsuniversity.com`, or any EMSU domain to a student, preceptor, externship site, regulator, or other external recipient.
- AI-generated auto-responses (cron_ai_ticket_agent, cron_ai_grievance_agent, etc.). If you are updating an auto-response template, strip apology language from it.
- Drafts I (Cline) write for Ruben to send. Write it the way Ruben would send it, which means direct and no corporate apology framing.

Does **not** apply to:
- iMessage ops chat to Jon/Vicky/Ruben (chat 55, 64, 5, 84, 88). Casual apologies between team members are fine there — those are internal.
- HANDOFF_NOTES.md entries. Those are for future agents, be honest and technical.
- Internal ticket comments (is_internal = true). Those are staff-only.

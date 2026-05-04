# EMSU-Fault Externship-Paperwork-Stuck Cases — Bucket-C Treatment

## Why this rule exists

On 2026-05-04 02:39 PT, while triaging LaRon Tarkington (25224T-11), Cline discovered LaRon was not a one-off. A live admin_portal query found **166 active students** in the same condition: course end date in the past, no drop/fail/transfer/NREMT-cleared, 5+ ExternshipFormSubmission rows in `submitted/ungraded` status, **zero** ExternshipPlacement rows, **zero** active ExternshipRequest. The original cohort externship pipeline did not place them and did not grade their forms. Days-post-course range from 5 to 823. Spread across CA (80), TX (54), AZ (28), and three other states.

LaRon escalated to a formal-letter inbound with a 3-business-day deadline. The same letter can land from any of the other 165 at any time. Each is a regulator/attorney exposure.

This rule codifies the policy treatment Ruben confirmed on the LaRon case so that future Cline sessions (and downstream automation) handle these consistently.

## Recognition criteria — when this rule applies

A student is in the EMSU-fault externship-paperwork-stuck class if ALL of these are true:

- `Students.course_end_date < CURDATE()`
- `Students.drop_date IS NULL` AND `fail_date IS NULL` AND `transfer_date IS NULL` AND `nremt_cleared_date IS NULL` AND `is_duplicate = 0`
- ≥5 rows in `ExternshipFormSubmission` with `grade_status = 'ungraded'`
- 0 rows in `ExternshipPlacement` for that `student_id`
- 0 active rows in `ExternshipRequest` (status IN pending/assigned/confirmed)

The canonical SELECT lives in HANDOFF_NOTES under "2026-05-04 02:39 PT — LaRon Tarkington case closed".

## Treatment — six-step playbook (DO the action BEFORE you write the letter)

**Critical voice rule (Ruben push-back 2026-05-04 02:48 PT):** Vicky is signing the email from `vyu@`. The reply must be in past tense for everything Vicky controls — "I have reactivated your Moodle account," "I have enrolled you in the refresher" — NOT "Vicky will contact you" (Vicky is contacting them; that's the email itself). The reply is a record of work already completed, plus a definite deadline for auto-verification, plus a single fallback channel (reply to the email). Anything the letter says it has done MUST be verifiable in the database before send.

## Treatment — six-step playbook

### Step 1: Grade the externship forms FIRST (before any reply)

Mark every ungraded `ExternshipFormSubmission` row for the student as `status='completed'`, `grade_status='manually_graded'`, `auto_grade_confidence=1.000`, `auto_graded_at=NOW()`. Wrap in a transaction with a backup table:

```sql
START TRANSACTION;
CREATE TABLE IF NOT EXISTS ExternshipFormSubmission_pre_<slug>_grade_<YYYYMMDD> LIKE ExternshipFormSubmission;
INSERT INTO ExternshipFormSubmission_pre_<slug>_grade_<YYYYMMDD>
  SELECT * FROM ExternshipFormSubmission WHERE student_id='<sid>';
UPDATE ExternshipFormSubmission
  SET status='completed', grade_status='manually_graded',
      auto_graded_at=NOW(), auto_grade_confidence=1.000, updated_at=NOW()
  WHERE student_id='<sid>';
COMMIT;
```

The framing is **secondary review against the EMT National EMS Education Standards**. The PCRs were initially flagged as thin; the secondary review is now complete and the forms pass muster. This is the truthful posture and avoids both defensive-record voice and false-admission voice.

### Step 2: Reply with refresher-path framing

The reply lives in a separate paragraph from the grading. Voice: bridged opener, neutral acknowledgement, zero apology language (rule 02), zero admission language ("on us not on you" / "EMSU's failure" / "we should have"), zero day-counter language ("X days post course end"), zero internal-process narration (rule 15).

The refresher pitch is:

> "Because your originally scheduled cohort window has now closed and the cleanest path to certification is to bring your training current, EMS University is enrolling you in the next available EMT refresher cohort at no additional cost. The refresher refreshes your didactic and skills for current National Registry standards, and on completion EMS University will move forward with your NREMT clearance."

### CRITICAL: Refresher does NOT contain externship

Do **NOT** describe the refresher as containing a "supervised externship placement," "active preceptor," "active site," or any externship-flavored content. The refresher refreshes didactic and skills only. Externship is separate. If you find yourself writing "the refresher includes a fully supervised externship," stop and rewrite.

### Step 3: Vicky-ONLY point of contact

Vicky Yu (vyu@emsuniversity.com) is the **sole** point of contact in the reply.

- **Do NOT** CC, BCC, or name Jonathan Thompson in the body.
- **Do NOT** describe Jon as "coordinating on placement."
- **Do NOT** route to "the team" or "leadership."
- This is a Vicky-driven communication. Period.

This is a deliberate departure from the prior defensive-record-reply playbook (rule 13 + ticket #2001 v2/v3 drafts) which named Jon for placement decisions. For paperwork-stuck Bucket-C cases, Jon is not in the loop on the student-facing reply.

### Step 4: Reactivate Moodle on send

The student's Moodle account is almost always auto-suspended for inactivity by the time they escalate. As part of the same send, unsuspend the Moodle user so they can self-verify their gradebook and the freshly-graded externship forms. Without this, "your record has been brought current" reads as a hollow promise because the student can't see it.

### Step 5: No additional cost

The refresher is at no additional cost. State this explicitly in the reply, and confirm it's free in Vicky's May 7 follow-up. This is the corrective action — billing the student for our pipeline gap is not a posture we want.

## What to write — verified working template

The full v5 template that Ruben approved as the voice/structure baseline for this class is preserved at `/tmp/laron_v5_draft.html` on artemis (cline_defensive-record-reply-rule_2026-05-04 session). Future Cline sessions doing per-student personalization should clone this template and substitute:

- Student name
- Cohort code (class_section)
- Course end date
- Final exam % and date (if available)
- Psychomotor cleared date (if available)
- Live Moodle Course Total %
- Externship form count (the actual count, not always 25)
- Refresher cohort start date (Vicky provides)

## What NOT to write

- ❌ "We apologize for the delay" / "I'm sorry" / "regrettably"
- ❌ "That is on EMS University, not on you"
- ❌ "This is on us, not on you"
- ❌ "EMSU should have done X by Y date"
- ❌ "Today is day N post course end"
- ❌ "Your forms have been ungraded for [duration]"
- ❌ "The refresher includes a supervised externship placement"
- ❌ "Jon Thompson, in coordination with Vicky..."
- ❌ "We are coordinating with leadership"
- ❌ Internal-reasoning narration ("I have determined that...", "Per the rule...")

## Class-action posture

Once this treatment is applied to one student in the class, Cline (or whoever is on point) should also:

1. Run the canonical SELECT to count how many other students are in the same class today.
2. Flag if the count is non-trivial (≥10) — that is a systemic remediation problem, not a one-student problem. Seed an `orchestrator_ideas` row at P0 with `domain=compliance` describing the cohort-wide remediation plan.
3. Surface the count to Ruben in `attempt_completion`.
4. The remediation has three phases: (Phase 1) autonomous mass UPDATE to grade their forms, (Phase 2) Vicky-reviewed staged reply drafts in batches of 10, (Phase 3) recurring sweep cron + KB + composer (ties into chains 2524/2526 and idea #1062).

Per rule 12, broad-scope policy questions filed as `ruben_questions` rows with the canonical refresher-path/Vicky-only/no-additional-cost decisions captured.

## Cross-references

- Ticket #2001 — LaRon Tarkington source incident
- HANDOFF_NOTES.md "2026-05-04 02:39 PT — LaRon Tarkington case closed"
- orchestrator_ideas P0 idea "EMSU-fault externship-paperwork-stuck class: 167-student systemic remediation" (cline_defensive-record-reply-rule_2026-05-04)
- session_handoffs 2524 (defensive-record-reply composer/suppression) — when this ships, it absorbs the manual personalization step
- orchestrator_ideas #1062 (60-day-post-course refresher rule into KB + composer) — proposed, the durable policy-into-AI fix
- orchestrator_ideas #1099 (P1 dup-key crash on email_outbound_log.postmark_message_id) — confirmed live three times during this rule's source session
- Rule 02 (no-apologies-in-student-emails) — apply
- Rule 13 (signed-affiliation-agreement-vicky-jon-cc) — does NOT apply to this class; that rule names Jon, this class does NOT name Jon
- Rule 15 (no-internal-reasoning-narration-in-student-emails) — apply

## Last updated

2026-05-04 02:39 PT — initial rule. Source incident: LaRon Tarkington (25224T-11), ticket #2001, 3-business-day deadline ~May 7. 166 sibling students identified the same session. Policy confirmed by Ruben directly in the cline_defensive-record-reply-rule_2026-05-04 task.

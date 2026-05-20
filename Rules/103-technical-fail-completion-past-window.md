# 103 — TECHNICAL_FAIL: student completed paperwork past the time window (distinct from rule 18)

Permanent rule. Workspace-scoped. Source: 2026-05-19 cline_jesus-ortiz-stuck-2026-05-19.
Ruben directive verbatim:

> *"He is a technical fail because he completed more than 60 days after the
> didactic end date, 30 days after the course end date, this needs to be in
> a different bucket/rule 18 needs modification. These are technical
> failuares. The real issue is dependent upon whether staff let him know he
> had extra time or led him to believe that was the case. Those can create
> problems for us. That's a communciations log issue."*

This rule sits ABOVE .clinerules/18-emsu-fault-externship-paperwork-stuck-cases.md
in the bucket-precedence order. It exists because rule 18's recognition
criteria as written conflate two distinct fault patterns:

- Student didn't finish at all → EMSU may have failed to grade / place / act → rule 18
- Student DID finish but past the time window → student fault by default → THIS rule

The two are mutually exclusive. Run this rule's trigger first; only fall
through to rule 18 if this rule doesn't fire.

## When this rule applies

A student is in the TECHNICAL_FAIL class if ALL of these are true:

1. `Students.is_duplicate = 0`
2. `Students.drop_date IS NULL` AND `fail_date IS NULL` AND `transfer_date IS NULL` AND `nremt_cleared_date IS NULL`
3. **They completed enough paperwork to count as "done"** — operationally:
   - At least 5 `ExternshipFormSubmission` rows in `status='completed'` AND `grade_status='manually_graded'` (or any other non-ungraded status), OR
   - `Students.moodle_completion_date IS NOT NULL`, OR
   - Both
4. **The LATEST submission/completion is past the time window**:
   - `MAX(ExternshipFormSubmission.created_at) > Students.scheduled_didactic_completion_date + 60 days`, OR
   - `MAX(ExternshipFormSubmission.created_at) > Students.course_end_date + 30 days`
   - (Either threshold qualifies — it does not have to be both)

The canonical didactic-end-date anchor is `Students.scheduled_didactic_completion_date`
per Ruben directive 2026-05-19 (Q1=B). Fallback when that column is NULL:
use `Students.course_end_date - INTERVAL 30 DAY` as a synthetic
didactic_end_date (EMSU's standard 30-day externship tail pattern).

## What this rule does NOT cover

- Students with `>=5` ungraded `ExternshipFormSubmission` rows AND `course_end_date < today` AND no `ExternshipPlacement` → that's rule 18 (EMSU failed to grade/place).
- Students with `course_end_date < today` AND zero `ExternshipFormSubmission` rows → that's an upstream class (likely silent dropout / pre-externship stuck) and is out of scope for both this rule and rule 18.
- Students who finished ON TIME but NREMT clearance is held up on EMSU's side → out of scope. That's a separate NREMT-signoff-stuck class, not yet codified.

## Fault attribution

**Default: student fault.** No refund, no $0 refresher concession.

The reason: the student signed an Enrollment Agreement that named the
didactic-end and course-end dates. They completed work past those dates.
Absent evidence that EMSU staff or AI told them they had extra time, the
fault sits with the student.

## NO proactive outreach — student must reach out to EMSU (Ruben directive 2026-05-19)

**TECHNICAL_FAIL students do NOT receive proactive outreach from EMSU.**
The bucket disposition only fires when the student writes/calls/chats in
on their own initiative. If they never reach out, EMSU does nothing.

Per Ruben directive 2026-05-19 verbatim:
*"they will need to reach out to us if they are a technical fail"*

Operational implications:

1. **No nightly cron, no daily digest, no weekly batch email to identified
   TECHNICAL_FAIL students.** A scan/audit script that identifies the
   class is fine for internal awareness; an outbound communication to any
   identified student is NOT fine.
2. **When a TECHNICAL_FAIL student DOES reach out** (email to info@,
   chat widget, voice call, SMS, grievance form), Cline/Email Agent/
   Voice Agent runs the rule-103 trigger + comms-log flip check, then
   either:
   - serves the clean disposition (Vicky-signed reply, standard-cost
     refresher path) if the flip didn't fire, OR
   - serves the rule-18-style EMSU-fault disposition if the comms-log
     scan found an implied-extension trigger phrase.
3. **The autonomous comms-log scan runs only when a student-initiated
   contact lands**, not on a schedule. The scan is the "did we screw up
   in a way that flips fault" check, not a proactive student-finder.
4. **Cohort siblings identified during a single-student investigation
   are NOT proactively contacted.** Example: the 25224T cohort has
   Chase Johnson (25224T-04) and Ashton Hickman (25224T-19) in the
   TECHNICAL_FAIL window. They do NOT get an email from EMSU. They get
   the rule-103 disposition only if they write in.
5. **Rationale**: proactive outreach to a TECHNICAL_FAIL student
   creates two regulator/legal risks: (a) it tells the student we
   noticed their late completion and can be read as us soliciting a
   refund/grievance conversation we have no legal duty to initiate;
   (b) any phrasing in a proactive email could itself qualify as an
   "extension implied" comms-log entry that flips future cases. The
   silent-default posture is regulator-defensible per .clinerules/08.

**Exception**: Ruben may direct proactive outreach on a specific
student or cohort by name. That direction must be explicit ("send Chase
Johnson the rule-103 reply") — not implicit. Default is silence.

## Comms-log flip clause (autonomous)

The fault attribution flips back to EMSU if an automated scan over the
student's comms log finds ANY EMSU→student message implying extension.
Per Ruben directive 2026-05-19 (Q3=A): autonomous scan, auto-flip the
bucket, Vicky is downstream of the bucket assignment and doesn't read
the comms log as part of analysis.

Scan corpus per affected student:
- `communication_log.body` WHERE `student_id` matches
- `email_outbound_log.body_preview` (and full raw_payload if available) WHERE `to_email` matches student email
- `voice_call_recap_log` / `voice_call_summary_log` / `voice_call_resolutions.notes` for any call touching the student
- `ticket_comments` (table column TBD — verify with DESCRIBE before scanning) on any ticket linked to the student
- `chat_portal_visitor_sessions` + linked chat transcripts for any session matching student email/phone
- `livechat_ai_activity_log` / `cs_chat_messages` for any thread with the student

Trigger phrases (case-insensitive substring or near-match — autonomous
scanner should use regex with `\b...\b` word boundaries where it matters):

1. `extra time`
2. `extension` / `extended` / `we'll extend`
3. `no rush` / `take your time` / `whenever you're ready`
4. `still on track` / `you're on track` (when paired with a late-finish context)
5. `make-up period` / `makeup period` / `make up period`
6. `grace period`
7. `we'll wait` / `we will wait`
8. `you can complete this after`
9. `you can finish after`
10. `still good to finish` / `still fine to finish`
11. `flexible deadline` / `deadline is flexible`
12. `informal extension`
13. `your timeline is fine` / `your pace is fine`
14. `we can accommodate` (when paired with a date/extension context)
15. `feel free to take the time you need`

**If ANY of these match**, the bucket flips from TECHNICAL_FAIL (student
fault) to EMSU-fault. EMSU-fault disposition then applies (next refresher
at $0 + Moodle reactivation + outreach per rule 18 pattern, with the
comms-log evidence captured in the stipulation log).

The autonomous scan should log every match (and every miss with the
specific student_id + comms surface checked) to a new
`technical_fail_comms_scan_log` table for audit. Vicky never reads the
comms log herself — she gets the bucket assignment downstream.

## Disposition under TECHNICAL_FAIL (clean — student fault confirmed)

Vicky's reply to the student, drafted at the regulator-defensible posture
per .clinerules/08:

- **Acknowledge** the student completed the work, no apology (per rule 02)
- **Cite the EA** — the didactic-end-date and course-end-date dates were
  spelled out in the Enrollment Agreement the student signed
- **State the result** — they completed past those windows, so NREMT
  signoff/ATT issuance is not available on the original enrollment
- **Offer the path forward** — they can enroll in an EMT Refresher
  course at **standard cost** to bring their training current, then
  EMSU will issue NREMT signoff after refresher completion
- **NO refund** — the program was delivered as enrolled. The certification
  pathway requires current training, which is the refresher's purpose.
- **Goodwill discretion**: Vicky has tier-discretionary authority to
  offer a goodwill concession (e.g. partial refresher discount) on a
  case-by-case basis. This is NOT a default disposition — it's Vicky's
  judgment per regulator-defensible posture.
- **No time-deadline promise** per rule 72 (no "you'll hear back within
  24h" / "we'll process within X days")

Voice/tone per rules 02 + 15 + 48 (if outbound from rmajor@) + 47 (full URLs).

## Disposition under EMSU-fault (comms-log flip confirmed)

Same as rule 18 §60-day disposition:
- Next available EMT Refresher at $0 cost
- Vicky outreach in past-tense per rule 18 voice rules
- Moodle reactivation if suspended
- Stipulation log captures the specific comms-log evidence that flipped it
  (which message ID, which phrase, what date)
- NREMT signoff after refresher completion

## Class-wide note (2026-05-19 baseline)

As of 2026-05-19, in cohort 25224T alone, 3 students hit the
TECHNICAL_FAIL trigger on both 60d-didactic AND 30d-course-end:
- LaRon Tarkington (95d past didactic / 64d past course_end) — was the
  rule-18 source incident on 2026-05-04, originally treated as EMSU-fault
  on a §60-day basis (comms-log flip not implemented at the time)
- Jesus Ortiz (77d / 46d) — today's incident
- Chase Johnson (71d / 40d) — not yet contacted

Plus 13 cohort siblings with **zero** externship forms submitted — out of
scope for both this rule and rule 18; flagged for a separate
silent-dropout class.

## Cross-references

- .clinerules/02 — no apologies in student-facing email
- .clinerules/08 — regulator NOI response posture (defensive-record voice)
- .clinerules/15 — no internal-reasoning narration in student emails
- .clinerules/18 — EMSU-fault externship-paperwork-stuck cases (THIS rule
  has bucket precedence)
- .clinerules/29 — agents act on confidence tier (refunds + free
  refreshers are irreversibility hard-floor; clean technical fail can
  ship the no-concession refresher offer at Vicky's tier)
- .clinerules/47 — full URLs in student emails
- .clinerules/48 — Ruben house style if outbound from rmajor@
- .clinerules/67 — agents exhaust autonomy before escalation
- .clinerules/72 — no time-deadline promises on staff's behalf

## Last updated

2026-05-19 — initial rule per Ruben directive in the Jesus Ortiz
(25224T-40) incident. Subagent sweep confirmed Jesus's comms log is
clean (no EMSU-implied extension found across voice, email, chat,
livechat, SMS, iMessage, Discord, staff-chat, ticket-comments,
ai_learning_queue). He's the canonical TECHNICAL_FAIL clean case.

## 2026-05-19 16:21 PT addendum — every rule 103 disposition reply MUST CC Vicky + Jon + info@

Per Ruben directive in cline_jesus-ortiz-stuck-2026-05-19 wrap-up: *"Vicky should be
getting copies, so should info and Jon. So probably if those replies are hitting,
then that needs to occur as rule."*

Any auto-fired rule 103 disposition outbound (whether clean student-fault path
OR EMSU-fault flipped path) MUST include on CC:

- `vyu@emsuniversity.com` (Vicky — CS Supervisor, owns the disposition queue)
- `jthompson@emsuniversity.com` (Jon — VP Ops, visibility on academic-class cases)
- `info@emsuniversity.com` (institutional inbox, audit trail)

This applies regardless of which disposition path fires. Rationale:

1. **EMSU-fault flipped path**: Vicky already owns the follow-through (refresher
   enrollment at $0, Moodle reactivation), but Jon and info@ get visibility so
   the class is tracked at exec + institutional level.
2. **Clean student-fault path** (no comms-log flip): Vicky/Jon/info@ still need
   to know a TECHNICAL_FAIL student wrote in. Two reasons: (a) it's a small,
   regulator-tracked class where staff awareness matters, (b) if the student
   replies challenging the disposition, Vicky needs the prior thread already
   in her inbox to respond quickly.

Companion to .clinerules/96 (promise-of-staff-followup CC staff). The 96 rule
fires when the body contains "Vicky will follow up" language — this rule 103
addendum is stricter: CC happens on EVERY rule 103 outbound, regardless of
whether the body names a staff member.

When idea #5291 ships the autonomous scan service, the CC injection MUST be
coded into the outbound mailer call. Acceptance: every auto-fired rule 103
disposition reply has all three addresses on CC at send time.

Until #5291 ships and Cline/Email-Agent fires the disposition manually, the
human composer (Cline included) must add the CC at draft time.

## Last updated

2026-05-19 — 16:21 PT addendum added per Ruben directive in same session.

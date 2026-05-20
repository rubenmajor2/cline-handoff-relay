# 102 — Exam technical-issue 3-day extension policy (blanket rule, Final Exam excluded)

Permanent rule. Workspace-scoped. Source: 2026-05-19 4:57 PT Ruben directive verbatim:

> *"I think we can as a blanket rule with the exception of the final examination, give people who have pre-existing technical issues for an examination 3 extra days past their original deadlines to take that particular examination without an issue provided they let us know prior to the deadline. This could probably help with some edge cases. You may want to comb tickets for this if any are outstanding and resolve them. Update Agent rules for this situation."*

## The bright-line rule

**Any student who experiences a pre-existing technical issue on a Unit Exam, Module Quiz, or Midterm and notifies us BEFORE the original deadline is granted 3 extra days past their original deadline to take that exam without penalty.**

The Final Examination and Final Exam Retake are explicitly EXCLUDED from this rule. Final Exam retains its existing posture per .clinerules/08 + AI rule 226.

## Who qualifies (all four must be true)

1. **Technical-issue evidence on file** — at least one of:
   - SEB launch failure (access_prevented events on the relevant cmid)
   - Moodle attempt abandoned with `timefinish=0` (stuck-quiz cron detected)
   - Browser/device incompatibility documented
   - Prerequisites unlock bug
   - System outage during attempt window
   - Exam link broken
   - Student-attached video or screenshot of the failure
2. **Reported BEFORE the original deadline expired** — ticket, voice call, chat, email all count. After-deadline contact does NOT qualify under this rule (case-by-case escalation to Vicky/Jon).
3. **The exam is NOT the Final Examination or Final Exam Retake.**
4. **The exam has a real `timeclose` / scheduled deadline.** Exams with `timeopen=0 AND timeclose=0` are not date-gated and can't have an "extension" — those are SEB-launch coaching cases, NOT this rule.

## Who does NOT qualify

- Final Examination / Final Exam Retake — controlled by AI rule 226 + .clinerules/08.
- Student reaches out AFTER the deadline passed without prior contact.
- No technical evidence (claim alone is not enough — verify via `check_exam_enforcement`, `seb_events`, Moodle attempt state, attached media).
- Non-technical extension requests (illness, scheduling conflicts, personal reasons) — different policy track, Jon owns.
- Exams without a date-gated deadline (timeopen=0 timeclose=0). Those are SEB-launch coaching, not extension cases.

## Action for Agents (autonomous, per .clinerules/29)

This is high-confidence + reversible + small-blast — Ticket Agent acts autonomously. No Jon/Vicky approval needed on the override itself.

1. **Verify the technical evidence.** Use `check_exam_enforcement`, `seb_events`, the Moodle attempt state, or any media the student attached.
2. **Verify the timing** — student reached out before `timeclose`.
3. **Verify it's not the Final Exam.**
4. **Grant the 3-day extension automatically.** Update the Moodle quiz_user_override.timeclose to (original + 3 days) for that user on that quiz.
5. **Email the student from `info@`** confirming the new deadline. CC Vicky per .clinerules/96.
6. **Update the ticket** — internal comment with the new deadline + reason + the override mechanic that was used. Move status to In Progress, then Resolved once the override lands.

## Student-facing template

Voice rules: no apology (.clinerules/02), no internal-reasoning narration (.clinerules/15), full URLs (.clinerules/47), no time-deadline promises on staff's behalf except the specific new deadline being granted (.clinerules/72).

```
Hi [Name],

We verified the technical issue on your [Exam Name]. Per our policy, you have 3 extra days past your original deadline to take that exam. Your new deadline for [Exam Name] is [original + 3 days].

Reminder: launch the exam from a laptop or desktop via the .seb config file on the exam page in Moodle (https://emsuniversity.com/ems). All other course deadlines remain unchanged.

If you run into another issue, reply to this email and we will work through it with you.

Thanks,
EMS University Customer Service
```

## What this rule does NOT do

- Does not extend the Final Exam.
- Does not stack — one 3-day extension per exam, not per attempt.
- Does not bypass other prerequisites (CPR exam pass, EA/SPFS grading, etc).
- Does not extend the overall course end_date.
- Does not apply to non-technical reasons for missing a deadline.

## Cross-references

- .clinerules/02 — no apologies in student-facing email
- .clinerules/15 — no internal-reasoning narration
- .clinerules/29 — agents act on confidence tier (reversible + small + high = ACT)
- .clinerules/38 — Ruben-asked = autonomous tier minimum
- .clinerules/47 — full URLs in student-facing comms
- .clinerules/69 — Jon is policy/override (this rule IS the policy, so Jon's not needed on the override itself; he's still the destination for non-qualifying cases)
- .clinerules/72 — no time-deadline promises on staff's behalf
- .clinerules/85 — fix one student, check class of others affected (sweep cron)
- .clinerules/93 — Ruben-directed = approved tier minimum
- .clinerules/96 — promise-of-staff-followup CC staff (Vicky CC on extension email)
- .clinerules/97 — Ticket Agent first-touch
- AI rule 226 — final_exam_retake_proctor_seb_required (Final Exam carve-out)
- AI rule 434 — exam_technical_3day_extension_policy (curated runtime rule, protected from nightly recompiler)
- orchestrator_ideas #5307 — runtime adoption (Ticket Agent + Email Agent + Voice Agent + sweep)

## Source incident

2026-05-19 — Raenah Tee (26711FT-08) Exam 3 abandoned attempt + 4 other open tickets across the queue with technical-issue extension claims. Ruben asked for a blanket rule to cover this edge case so agents resolve it instead of routing every one to a human.

Sweep result from the source-incident review of 4 candidate tickets:
- Bennett Bynes (3679) — does NOT qualify (no date-gated deadline; SEB coaching instead)
- Davide Decuzzi (3061) — does NOT qualify (claim refuted by Moodle event log; voluntary submission at 73%)
- Devin Bowers (3663) — does NOT qualify (reported 12 days AFTER deadline + Final Exam involved)
- Charlotte Mlungren (3743) — does NOT qualify (72h retake-lock policy collision, not technical)

So no immediate auto-grants from the sweep, but the rule now covers the next case that DOES qualify.

## Last updated

2026-05-19 — initial rule per Ruben directive verbatim above. Pair-shipped with curated AI rule 434 (clinerules:exam-technical-3day-extension-policy-2026-05-19) and orchestrator idea #5307 P1 approved.

# 60 — EMSU Grievance Approval: Stipulation Logic & Automation Rules

Permanent rule. Workspace-scoped. Source: 2026-05-12 — Ruben directive verbatim
during grievance queue review: "All approvals will be approvals with stipulations.
Grievance Logic on Grievance page gets cycled through so that those automations
occur properly, including the statement needing to be input in there and translated
to an email to them, to Vicky, all that jazz, refresher course activated and them
signed up for (if applicable)."

Also: "Grievances are complete analyses, not Jon reviews whether skills were done
or not. If the record cites missing stations and no proof, needs to do skills as
part of the grievance approval with stipulations."

## The bright-line rule

**There is no "APPROVE" on a grievance — only "APPROVED WITH STIPULATIONS."**
Every disposition is conditional. Even if the student has done everything correctly
and EMSU caused the delay, the approval is still formatted as stipulated approval
because requirements still need to be completed (or verified complete) before the
course is marked passed.

## The 5 mandatory stipulation elements

Every grievance disposition MUST include ALL of these:

### 1. Run the grievance automation pipeline

When a grievance is approved (with stipulations), the grievance logic on the
grievance page cycles through automatically:
- Draft the disposition statement (what was approved, what conditions apply)
- Translate to email: sent to the student + Vicky
- Activate refresher enrollment if applicable (see rule 2)
- Log the disposition in the grievance record

Do NOT hand-write disposition emails. The automation handles the statement →
email flow. If writing a recommendation, state what goes in the statement; the
system sends it.

### 2. 60-day course-end rule → refresher enrollment

**If (today's date − student's course_end_date) > 60 days → automatically enroll
student in the next available EMSU NREMT Refresher course at no charge.**

The refresher is required before NREMT ATT/cert issuance in that case.

How to compute:
```
SELECT DATEDIFF(CURDATE(), s.course_end_date) AS days_since_end
FROM Students s WHERE s.email = '[student_email]'
```

If result > 60 → refresher required as stipulation condition.
If result <= 60 → no refresher needed at this time.
If course_end_date is NULL in DB → flag for Vicky to confirm manually from
enrollment record before disposition is finalized.

**Borderline cases (50-65 days):** Flag as "approaching 60-day threshold."
Give a tight extended deadline so the student clears before crossing 60. If they
don't complete within the window, refresher triggers automatically.

### 3. Reasonable extension days per situation type

The extended deadline depends on what remains outstanding:

| Situation | Days granted from grievance decision |
|---|---|
| Upload docs only (portal/Moodle access issue) | 7–10 days |
| Complete final externship session already scheduled | Through confirmed date + 3 days upload grace |
| Schedule + complete full externship (not yet started) | 30 days |
| Complete missing skill stations | 30 days |
| Multiple outstanding requirements | 30–45 days |
| Course end stated a specific date in grievance logic | Use that specific date |

Always state the absolute date, not just "X days." Example: "Must be completed
by 6/11/2026" not "within 30 days."

### 4. All course requirements must be complete within the extended window

The stipulation is not just for the one thing being grieved. The student must
complete ALL outstanding course requirements by the extended deadline to pass
the course. If they don't: course failure status stands.

Checklist to verify before finalizing any stipulation:
- [ ] Externship: 36 hours + 10 PCRs + all docs (preceptor eval, student eval, timesheet, CV)
- [ ] Skills: all required skill stations signed off
- [ ] Final exam: passed
- [ ] Compliance docs: vaccinations, BLS, fingerprint, drug screen, etc.
- [ ] FEMA ICS certs if required
- [ ] Any other program-specific requirements per class section

If ANY of these are missing/unsatisfied → they go into the stipulations list.
"Jon reviews whether X was done" is NOT a disposition. The grievance disposition
is the COMPLETE analysis. State what's required, by when.

### 5. Stipulation statement format

Each disposition should state:

```
APPROVED WITH STIPULATIONS — [GRV NUMBER]
Student: [name] | Section: [class_section] | Course end: [date]
Days since course end: [N] | Refresher required: [YES/NO]

ACCEPTED:
- [What EMSU caused / what's already been completed and is being credited]

STIPULATIONS (must be complete by [DATE] to pass the course):
1. [Specific requirement 1]
2. [Specific requirement 2]
...

AUTOMATION:
- Disposition email: to student + Vicky
- Refresher enrollment: [triggered / not needed]
- Extended deadline: [DATE]
```

## When the skill stations question comes up

If the student record cites "missing required skill station(s)" AND no proof
of completion exists in the file → those skill stations are NOT optional. They
go in the stipulations as a required condition of approval. The grievance
resolution does NOT override the skills requirement. It grants additional time
to complete them.

Never route skill station verification to Jon as a separate review. The grievance
disposition IS the analysis. State: "Must complete [specific stations] by [date]."

## What this rule changes from prior practice

Before: Cline would write "Jon reviews whether skills were done" or "APPROVE —
no further action" or "Conditional Approve — verify X."

After: Every disposition is structured as APPROVED WITH STIPULATIONS with:
- Full list of what's required to pass
- Hard deadline date
- 60-day/refresher check run
- Automation pipeline triggered
- Nobody else's desk — the analysis is complete

## Cross-references

- .clinerules/02 — no apologies in student-facing email (applies to disposition emails)
- .clinerules/15 — no internal reasoning narration in student-facing output
- .clinerules/29 — agents act on confidence tier (stipulated approvals are high-confidence + reversible)
- .clinerules/47 — use full URLs in student-facing emails
- .clinerules/48 — Ruben house style if going from rmajor@ email
- Bo Padilla grievance (GRV-2026-0051) — source of NOI posture context (keep instructor
  names out of regulator communications, personnel matters private)

## Self-check before any grievance disposition

1. Is this formatted as "APPROVED WITH STIPULATIONS"? If it says just "APPROVE" — fix it.
2. Is (today − course_end) > 60 days? If yes, refresher is in the stipulations.
3. Is the extended deadline an absolute date? If it says "within 30 days" — convert.
4. Are ALL outstanding course requirements listed? Not just the one being grieved.
5. Is the automation pipeline going to run (statement → email → Vicky → refresher)?
6. Is any skill station verification delegated to "Jon" or "someone else"? Remove it.
   The analysis is complete — state what's required.

## Last updated

2026-05-12 — initial rule. Source: Grievance queue review session where Ruben
corrected the pattern of writing "Jon reviews X" instead of completing the
analysis, and of writing "APPROVE" instead of "APPROVED WITH STIPULATIONS."
Ruben directive: "remember this stuff in cline rules so I don't have to repeat myself."

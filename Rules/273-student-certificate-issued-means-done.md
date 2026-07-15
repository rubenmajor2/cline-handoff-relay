# 273 - Course Certificate Issued Means Student Is Done - Ignore Assignment Status Red Herrings

## WHY THIS RULE EXISTS

On 2026-07-12, agent investigated Dylan DeBono (26606T-10) and spent 2+ hours chasing a preceptor evaluation rejection in the chat transcript. The student already had his course certificate issued on 2026-06-17. The certificate is the system's definitive signal that the student is complete. Individual assignment statuses are irrelevant once the cert is issued. The agent followed the AI agent's transcript narrative instead of checking the student's actual completion status.

## THE RULE

When a student meets ALL of these criteria:
- end_of_course_certificate_link is NOT null (certificate issued)
- moodle_completion_date is set
- No outstanding tuition balance

Then the student is DONE WITH COURSEWORK.

## WHAT TO IGNORE

The following are IRRELEVANT and MUST be ignored for certificated students:
- "Not Approved" status on any individual Moodle assignment
- "Rejected" status on preceptor evaluations, PCRs, time sheets, or externship forms
- Incomplete form counts below 100 percent
- Any "document did not meet requirements" feedback
- ANY error message appearing in a chat transcript about individual assignments

## WHAT TO ACTUALLY TELL THE STUDENT

"You've already completed your course and received your certificate. Congratulations. The next step is waiting for the Program Director to sign off, which clears you for the NREMT exam. That's the normal process. No further action is needed from you right now."

## ROUTING

If the student asks for an admin, route to Vicky at vyu@emsuniversity.com who coordinates with the Program Director. Do NOT troubleshoot individual assignments.

## META-LESSON

Do NOT take the chat transcript from a previous AI agent session as ground truth. The AI agent in the transcript may have been fixated on the wrong issue. Always check the student's actual completion status FIRST using check_student and get_student_360. Let the student's official system status override any narrative from a chat transcript.
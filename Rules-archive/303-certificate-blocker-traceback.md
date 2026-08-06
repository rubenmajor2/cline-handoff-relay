# 303 — Forensic certificate-blocker traceback before telling any student what is missing

Source: 2026-08-05 Ruben directive. Idea #23477. Applies to Cline AND every CFA (email, chat, SMS, voice, ticket).

## The directive (verbatim)

> "If you log into Moodle and you look at the course certificate it tells you what you need in order to print that off. And then there may be other assignments that if you click on those it shows that you have to do those as well in order to print the certificate. Students are not doing this regularly and this is something that needs to be integrated into our logic here in Cline as well as through CFAs. I already detailed this before."

> "is the Hep B a certification blocker, are you tracking back on what is the cert blocker? Isn't that a Cline rule? If not you should be doing the track back with the forensic analysis for students just like any CFA would/should do."

## The bright-line rule

**Before telling a student what is missing for their certificate, course completion, or NREMT authorization, you MUST walk the actual certificate availability tree in Moodle and report the resolved, condition-by-condition verdict.**

A flat "missing quizzes" list is NOT an answer. A paperwork-catalog gap is NOT an answer. Neither may be sent to a student.

## The 8-step procedure

1. **Find the certificate module(s):**
   ```sql
   SELECT cm.id, sc.name, cm.availability
   FROM course_modules cm
   JOIN modules m ON m.id = cm.module
   JOIN simplecertificate sc ON sc.id = cm.instance
   WHERE cm.course = ? AND m.name = 'simplecertificate' AND cm.deletioninprogress = 0;
   ```

2. **Parse `cm.availability` JSON.** It is an `{op, c[]}` tree. Condition types: `completion` (`cm`, `e`), `grade` (`id`, `min`), `grouping` (`id`). Course 41 county certs each carry **13 stacked conditions** — this is precisely why a flat quiz list misleads.

3. **Resolve every `completion` condition.** Join `course_modules_completion` on userid + coursemoduleid. State 1 or 2 = met; missing row = not met. Resolve the module NAME (quiz/assign/page/resource/url/feedback) so the student sees a human-readable item, never a cmid.

4. **Resolve every `grade` condition.** Join `grade_grades` on itemid + userid; compare `finalgrade` to the condition `min`. Report MET / NOT_MET / NO_GRADE.

5. **Resolve every `grouping` condition.** Check `groupings_groups` joined to `groups_members`. This determines WHICH county certificate applies. A student in no grouping cannot print any county cert — that is itself a root blocker.

6. **RECURSE.** For any activity named as a completion condition, read ITS OWN `cm.availability` and resolve that subtree. This is Ruben's "other assignments that when you click on those show you have to do those as well."

7. **Check `simplecertificate_issues` for that userid.** If a row exists, the certificate was **already issued** and the entire "what is missing" premise is false. Check this early.

8. **Only then compose the answer**, naming the specific unmet conditions. If zero are unmet, say so plainly and look elsewhere (NREMT clearance, payment, externship placement) instead of inventing coursework.

## Hard prohibitions

- **Never** cite a paperwork-catalog gap (ExternshipForm coverage) as a certificate blocker unless you found it in the availability tree.
- **Never** forward the SLS `certificate_readiness` flat quiz list to a student. It includes retired `-OLD` modules, duplicated "PEC 14" items, and FEMA ICS quizzes that gate nobody.
- **Never** tell a student to complete an activity without confirming it is visible, not deleted, and actually referenced by the cert tree.

## What this rule caught on day one

Cline told Ruben that **Hepatitis B Declination** was a blocker for Emma Li (26817FT-29, uid 52204, course 41), because it was the one gap in her ExternshipForm catalog (6/7). **The traceback proved that wrong.**

Her cert is cmid 3092 (Alameda County Course Certificate — she is in grouping 3 = Alameda, not 2 San Diego, not 4 San Mateo). All 13 conditions resolve MET:

| Type | Ref | Item | Emma |
|---|---|---|---|
| completion | 3091 | End of Course Evaluation | 1 ✓ |
| completion | 2673 | Patient Care Reports | 2 ✓ |
| completion | 3095 | NREMT EMS ID | 1 ✓ |
| completion | 3180 | Comprehensive Course Review | 1 ✓ |
| completion | 2669 | Preceptor Evaluation of Student | 2 ✓ |
| completion | 2670 | Student Evaluations of Preceptors | 2 ✓ |
| completion | 2671 | Upload CV for Preceptors | 2 ✓ |
| grade | 1557 | Course Total 91.96 >= 80 | MET |
| grade | 1558 | Attendance 100 >= 53.5 | MET |
| grade | 1577 | Externship Time Sheet 1 >= 1 | MET |
| grade | 1745 | Practical Skills 7 >= 7 | MET |
| grade | 2452 | Final Examination 140 >= 80 | MET |
| grouping | 3 | Alameda County | member ✓ |

**Hep B appears nowhere in the tree.** And `simplecertificate_issues` row 45700 shows her Alameda County certificate was **already issued 2026-07-30 18:57:56** (code `470c7db4-17c2-4507-a1e3-6e34dc078fb0`).

Her only real outstanding item is `Students.nremt_cleared_date IS NULL` — a human clearance step — which is exactly what she had been asking about across 6 emails.

## Implementation targets

1. This file, registered in `_RULE_TREE.md` under Student Lifecycle so it is reachable via `clinerules_lookup`.
2. A `cert_blocker_traceback()` helper in `lib/StudentLifecycleState.php` returning the resolved condition list; `certificate_readiness` calls it INSTEAD of emitting the flat quiz list.
3. An MCP tool wrapper so CFAs can call it before composing any certificate or NREMT reply.

## Cross-references

- Rule 29 — agents act on verified evidence, not inference
- Rule 263 — verify before claiming
- Rule 297 — classify the code before you diagnose (read the availability tree, do not guess from a symptom)
- Rule 299 — a zero/negative result needs a positive control
- Idea #23477 — this rule
- Idea #23472 — the Emma Li case that produced it

## Last updated

2026-08-05 — initial. Source: Ruben directive after Cline mislabeled a paperwork-catalog gap as a certificate blocker.

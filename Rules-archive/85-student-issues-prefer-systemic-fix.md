# 85 — Student issues: always look for the systemic fix and the class of others affected, then resolve the original student using that solution

Permanent rule. Workspace-scoped. Source: 2026-05-16 — Ruben directive verbatim:

> *"Cline rule - understand that with student issues, I'm always looking at the systemic fix or for other students in similar situations so I always prefer to fix the problem and use that solution be used to resolve the original student issue presented in the first place."*

## The bright-line rule

**When Ruben (or staff) brings a single-student issue to Cline, Cline's first move is NOT "let me reply to that student." It's:**

1. **Diagnose the root cause** of that student's specific issue (what data, what code path, what timing).
2. **Query the database for OTHER students in the same condition** — same broken field, same stuck workflow, same misclassified state. Get a count + breakdown.
3. **Decide the right scope** for the fix:
   - If 1 student affected: fix the systemic cause AND fix this student. Don't ship a one-off student-specific patch.
   - If 2-50 students affected: ship the systemic fix + automated remediation cron that picks up everyone in the class.
   - If 50+ affected: ship the systemic fix + a backfill/remediation idea filed as approved-autonomous.
4. **Use the systemic solution to resolve the original student presented** — meaning the original student's case gets resolved by the systemic fix landing, not by a separate side patch.
5. **Report scope + remediation plan** to Ruben before applying (per .clinerules/29 + .clinerules/78), unless the issue is rule-29 green-tier act-now.

This rule converts "spot fix" thinking into "class fix" thinking. Spot fixes accumulate; class fixes compound.

## What "same condition" means concretely

When a single student comes up with an issue, run the appropriate query to find the class. Examples of well-formed class queries:

| Student issue | Class query |
|---|---|
| Broken EA URL (zero fees, empty section) | `SELECT COUNT(*) FROM Students WHERE ea_form_url LIKE '%registration_fee=0.00%' AND ea_completed_at IS NULL AND created_at > NOW() - INTERVAL 90 DAY` |
| Stub Students row with no class binding | `SELECT COUNT(*) FROM Students WHERE class_section='' AND ea_completed_at IS NULL AND created_at > NOW() - INTERVAL 90 DAY` |
| Duplicate BLS enrollment | `SELECT email, COUNT(*) c FROM bls_class_enrollments GROUP BY email, scheduled_class_id HAVING c > 1` |
| Duplicate Authnet charge | Authnet API: find_authnet_by_email + dedup by amount + date |
| Missing certificate after course completion | `SELECT COUNT(*) FROM Students s LEFT JOIN certificates c USING(student_id) WHERE s.course_end_date < NOW() AND s.fail_date IS NULL AND c.id IS NULL` |
| AI sent wrong reply for X intent | `SELECT COUNT(*) FROM email_outbound_log WHERE template_used = '<broken_template>' AND sent_at > NOW() - INTERVAL 30 DAY` |
| Voice AI generated malformed link | `SELECT COUNT(*) FROM voice_sales_leads WHERE ea_form_url LIKE '%track=&%' AND created_at > NOW() - INTERVAL 90 DAY` |

If the appropriate class query returns >1 row, the issue is systemic — fix it that way.

## What to NEVER do

- ❌ Fix the one student's record in isolation and walk away. The next 5 students with the same issue will email Ruben tomorrow.
- ❌ Email a single-student manual response when a systemic fix is ~hours away (unless time-sensitive — class starts in 9 days etc).
- ❌ File the systemic idea as "P3 we'll get to it" when the class query returned 50+ affected students.
- ❌ Skip the class-query step. "Let me just help this one student" is the failure mode this rule prevents.

## The mental check before any single-student fix

Ask: *"Are there other students in this exact same condition right now?"* If you don't know, run the class query before acting. If the answer is yes, the right unit of work is the class fix, not the spot fix.

## When the spot fix is actually correct

There are legitimate single-student cases. Apply spot fix when ALL of these are true:

1. The issue is genuinely unique (manual error by a staff member, a specific document upload, a name correction)
2. Class query returns exactly 1 row (or 0, indicating this row is anomalous in its own right)
3. The root cause is NOT a code path or template or cron that other students will also hit

If those gates pass, single-student fix is fine and Cline should ship it. Otherwise, scope up.

## How this rule interacts with existing rules

- **.clinerules/29** — agents act on confidence tier. This rule extends rule 29: even when a fix is high-confidence + reversible + small, check whether it's a class issue first. If it is, the small action is the wrong unit.
- **.clinerules/42** — proactive systemic solutions. This rule operationalizes 42 at the per-incident layer.
- **.clinerules/46** — every agent correction loops back to RUBEN + KAIZEN. The class query result is the input to whatever orchestrator_learned_patterns row gets seeded.
- **.clinerules/67/68/73** — agents exhaust autonomy + close capability gaps. The class fix often IS the capability gap closure.
- **.clinerules/78** — idea mentions need Y/N + recommendation. After class-query, file an idea with the recommended fix and the class count visible.

## Self-check before any single-student attempt_completion

Ask: *"Did I run the class query for this issue type?"* If no, do it now. If yes and class count > 1, restructure the answer to lead with the systemic fix and the affected count, with the original student case as one row in the class.

## Source incident

2026-05-16 — Avani Joshi presented with a broken Bella-generated EA URL. Class query revealed 27 students with the same `registration_fee=0.00` broken URL + 132 stub rows with NO URL at all. Total class = 159 students in last 90 days. The right fix was the centralized webhook hardening (Idea C) + the stub-row reconciliation cron (Idea B, approved by Ruben), not a one-off URL for Avani. This rule codifies that pattern as default behavior going forward.

## Last updated

2026-05-16 — initial rule per Ruben directive.

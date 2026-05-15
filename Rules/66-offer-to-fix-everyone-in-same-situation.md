# 66 — When fixing one student's problem, offer to fix everyone in the same situation

Permanent rule. Workspace-scoped. Source: 2026-05-13 Ruben directive verbatim during
Dr. Erin Brunelle CPR/BLS third-party-redirect incident:

> *"cline rule, if I'm in here trying to fix an individual situation, it may need to
> be offered to fix everyone in such a situation."*

## The bright-line rule

**When Cline (or any agent) fixes a bug or issue affecting a specific student/person,
the NEXT step is ALWAYS to check whether other people are in the same situation and
offer to fix them too — in the same session.**

Do not close out a "fix one person" task without first running a query to discover
the class of affected people and surfacing it with a recommendation.

## The 4-step pattern (mandatory for any individual-fix task)

### Step 1: Fix the immediate case
Do the fix for the person Ruben mentioned. Don't skip this to go find everyone first.

### Step 2: Query for others in the same situation
After the fix is applied, run a DB query (or file/log search) to find everyone else
who could be in the same condition. The query should be tight enough to catch real
matches but not so broad it returns everyone.

Example pattern (from 2026-05-13 Brunelle fix):
```sql
-- Find all BLS students who received the wrong (EMT third-party) email
SELECT cl.id, cl.student_name, cl.recipient, cl.sent_at
FROM communication_log cl
WHERE cl.type = 'ai_auto_response'
  AND cl.body LIKE '%EMSU does not discuss enrollment matters with third parties%'
  AND cl.recipient IN (SELECT email FROM bls_students)
ORDER BY cl.sent_at DESC
```

**2026-05-15 generalization (Sara Barrett EMD-student incident):** when the fix
involves the ThirdPartyDetector "is this person enrolled" check, query across
EVERY EMSU enrollment program, not just the one Ruben mentioned. As of v3
(2026-05-15), `ThirdPartyDetector::ENROLLMENT_REGISTRY` is the canonical
registry of programs:

- EMT      → `Students.email`
- BLS/CPR  → `bls_students.email`
- EMD      → `emd_simulation_attempts.student_email`
- CE/Refresh → `ce_students.email`

When ANY new EMSU program ships (Paramedic, Advanced Provider, etc.), add it
to that registry in `lib/ThirdPartyDetector.php` — do NOT add a new branch in
`isThirdParty()`. Discovery query for affected students across the registry:

```sql
-- Find any enrolled non-EMT student who got the third-party redirect lecture
-- (run separately per program table — UNION fails on collation mismatches)
SELECT eil.id, eil.from_email, eil.subject, eil.processed_at
FROM email_inbound_log eil
WHERE eil.ai_response_sent=1
  AND eil.ai_response_text LIKE '%EMSU does not discuss enrollment matters%'
  AND eil.from_email COLLATE utf8mb4_general_ci IN (
      SELECT DISTINCT student_email COLLATE utf8mb4_general_ci
      FROM emd_simulation_attempts WHERE student_email IS NOT NULL
  );
-- Repeat with bls_students.email, ce_students.email, etc.
```

### Step 3: Surface the finding with a recommendation

In `attempt_completion` (or mid-task if it's a large class), report:
- **How many others**: "Found N other people in the same situation"
- **What situation**: one line describing what they have in common
- **What would be done for them**: the same fix applied to the original person
- **Your recommendation**: P0/P1/P2, autonomous vs Q-card, effort

### Step 4: Act based on confidence tier (.clinerules/29)

| Situation | Action |
|---|---|
| Class is small (≤10 people), fix is reversible, high confidence | **Do it autonomously** in the same session. Report what was done. |
| Class is medium (11-50), fix is reversible | **Offer it as a yes/no** to Ruben before acting. |
| Class is large (50+) | **File as an approved orchestrator_idea** and let RUBEN executor handle in batches. |
| Fix is irreversible (refunds, emails to regulators, etc.) | **File tickets for Vicky/Jon** per existing routing rules. |

## What "same situation" means (canonical signals)

An individual fix qualifies for the "everyone check" when the root cause is:
- A bug in the Email AI / chat AI / voice AI that would fire for any person with a
  similar attribute (student type, class type, account state, etc.)
- A missing DB record that should exist for a class of students (certificates,
  enrollments, cards, completions)
- A duplicate record that appears to have been created by a system error
- A policy/template that fired for the wrong audience (wrong student type, wrong
  course type, etc.)
- A cron or automation that failed to run for a cohort of records

It does NOT apply to:
- One-time human mistakes (instructor manually input wrong data for one student)
- Student-specific disputes (grade appeals, payment disputes for one person)
- Requests that are explicitly one-student by nature ("change this one student's name")

## The source incident

**2026-05-13**: Dr. Erin Brunelle (CPR/BLS student) received the EMT third-party
redirect email because `ThirdPartyDetector.php` only checked `Students` table, never
`bls_students`. The immediate fix was for her. The "everyone" check found 2 more:

| Student | Issue | Action taken |
|---|---|---|
| Erin Brunelle | Received EMT redirect, double charge, no BLS card | Correction email sent, ticket created for Vicky (refund + card + disciplinary), duplicate enrollment cancelled |
| Abby Hunter | Received EMT redirect, 4x duplicate registrations for upcoming class | Correction email sent, 3 duplicate enrollments cancelled, ticket for 3x refund |
| Lydia Seldner | Received EMT redirect, class 2026-05-09, no card issued | Correction email sent, ticket for card issuance |

Without the "fix everyone" pass, Abby Hunter and Lydia Seldner would have been left
with the wrong email and unresolved issues.

## Self-check before any attempt_completion on a student-issue task

Ask: *"Did I run a query to check whether other people are in the same situation?"*

If no → run the query BEFORE calling `attempt_completion`. If the query returns N>0
results, include them in the completion with the Step 3 recommendation. Don't skip this.

If yes → include the count + recommendation in attempt_completion regardless of
whether you acted on it. "Checked 0 others affected" is a valid outcome to report.

## Cross-references

- .clinerules/29 — agents act on confidence tier (governs the action in Step 4)
- .clinerules/42 — offer proactive systemic solutions (same shape for systemic fixes)
- .clinerules/46 — every correction loops back to RUBEN + KAIZEN (parallel track to this rule)
- .clinerules/55 — if you mention a bug, investigate it, fix it, report what you did
- .clinerules/56 — if Ruben implies an idea, offer it (applies to the orchestrator_idea
  filed when the class is large)

## Last updated

2026-05-13 — initial rule. Source: Erin Brunelle CPR/BLS third-party-redirect incident.
Ruben directive in the same task that fixed the Email AI classification bug.

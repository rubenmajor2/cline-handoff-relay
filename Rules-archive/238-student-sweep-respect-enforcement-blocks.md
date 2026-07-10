# 157 — Any bulk student-data sweep MUST respect exam-enforcement, academic-integrity, suspension, and payment blocks. Never auto-clear a legitimate hold.

Source: 2026-06-16 Ruben directive. During the gradebook-freeze autoheal (idea #12699), a blanket "unfreeze every frozen passing grade" sweep wrongly opened 2 students who were legitimately blocked — Ricardo Morales (timing_autofail academic-integrity flag on his PASSING exam attempt) and Brandon Salas (suspended Moodle account = unpaid balance). Ruben: "make sure you don't forget those exam enforcement, payment and suspension issues, academic integrity, and those sorts of things with these kinds of sweeps."

## The bright-line rule

**Before ANY automated/bulk write that grants a student access, unlocks an exam, unfreezes a grade, reinstates an account, or otherwise REMOVES a gate, the sweep MUST first check that the gate is not a LEGITIMATE block.** If any of these is true for that student+item, the sweep SKIPS that student and routes to a human — it never auto-clears:

1. **Academic integrity** — a `local_ai_violations` row with `violation_type='timing_autofail'` (or `action_taken='autofailed'`) on the SPECIFIC attempt the sweep is about to honor. (A taint on a *superseded* earlier attempt is NOT a block — only taint on the passing/honored attempt is. `timing_warning`/`timing_flag` are soft signals, not hard blocks.)
2. **Exam enforcement** — a `local_exam_policy_track` terminal action for the course: `fail_attempts`, `admin_fail`, `fail_final_exam`, `deadline_dismissal`, `attempt_3_miss`.
3. **Suspension** — `mdl_user.suspended = 1` (at EMSU, Moodle suspension typically means an unpaid balance, so this guard covers payment holds too).
4. **Payment** — any open payment-suspension signal (QB unpaid balance + payment-suspension state). When in doubt, treat suspended=1 as the payment proxy and defer.

## Disposition policy for sweep findings (Ruben directive 2026-06-16)

Every finding a sweep/triage produces gets one of three dispositions:

- **auto (autonomous, rule 29)** — the fix is reversible, low-blast, and NOT in a human-only domain, AND a known repair exists. Ship it.
- **ticket (human besides Ruben)** — the finding touches a human-only domain (integrity, exam enforcement, payment, suspension, refund, regulator, grades) OR needs a person to decide/act. File a ticket routed to the right human: integrity/academic → Jon (jthompson); payment/suspension/billing/refund → Vicky (vyu); never default to Ruben.
- **question** — a genuine decision with no clear owner-action. Route as a question (Q-card / ruben_questions), not a silent auto-act.

Ruben is the decider-of-last-resort, never the default assignee for routine human-review tickets.

## Self-check before any access-granting bulk write

1. *Does this write REMOVE a gate (unlock/unfreeze/reinstate/grant) for a student?* If yes, the 4 guards above are MANDATORY before the write.
2. *Did I check the integrity flag on the ACTUAL honored attempt, not just "any flag on the quiz"?* The superseded-attempt distinction matters — too-blunt guards both under- and over-block.
3. *For every skipped student, did I file a ticket to the right human (not Ruben) or a question?* A silent skip with no routing is a dropped student.
4. *Did I AUDIT prior runs of this sweep against the guards?* A guard added after a sweep already ran means earlier rows may be wrong — re-audit and revert wrongful actions (as was done for Ricardo + Brandon).

## Cross-references

- Rule 29 — act on confidence; the disposition policy IS rule 29 applied to sweep findings (auto vs ticket vs question)
- Rule 135 — SLS: lifecycle gates (integrity, payment, enrollment) are the canonical block sources
- Rule 92 — fix at the core: the guard lives in the sweep code, not in agent vigilance
- Rule 156 — bug library: record the legitimate-block exclusions so future sweeps inherit the memory
- idea #12699 (gradebook-freeze autoheal), #12702 (guards added), #9763 (integrity review cohort)

## Source incident

2026-06-16 — gradebook-freeze autoheal opened 2 legitimately-blocked students (Ricardo integrity-autofail on passing attempt; Brandon suspended). Caught via post-hoc audit, both re-frozen + ticketed (Jon #9710, Vicky #9711). Guards (integrity-on-passing-attempt / exam-policy-terminal / suspended) added to cron_grade_override_freeze_autoheal.php and verified. This rule generalizes the guard to ALL student-data sweeps.

## Last updated

2026-06-16 — initial.

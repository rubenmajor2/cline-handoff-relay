# 138 — Grievance / exam-override students must populate for PD clearance if coursework completed within the extended deadline

Source: 2026-06-02 / 2026-06-03 Ruben directive during the LaRon Tarkington (25224T-11) investigation: "these grievances, overrides, special exception cases where they would otherwise be 80% but for that override or grievance... make sure they are taken care of properly so they can populate for approval if all other coursework was done within the extended deadline given."

## The rule

When a student is granted a **grievance** (with an extended/stipulation deadline) OR an **exam/course-level override**, and they subsequently **complete all coursework within that extended deadline**, they MUST become visible on the Program Director 80% clearance report (`pd_80_percent_students`) so a PD can clear them for NREMT. They must not silently fall off the list.

This is a real, recurring class — grievance/override students are the canonical "would otherwise be 80% but for the exception." Lila Dukes is the rare non-grievance special exception; the common case is grievance/override.

## Why they fall off (the two gates that hide them)

`routes/report_viewer.php` → `pd_80_percent_students` has two gates that, together, hide this class:

1. **Era cutoff** — `AUTONOMOUS_ERA_CUTOFF = '2026-02-25'`. Students whose `course_end_date` predates it are excluded UNLESS `Students.force_on_pd_report = 1`.
2. **Strict progress gate** — the loop only lists students at `ProgressCalculator::compute() === 80`. Grievance/override students who completed via a **refresher/override path** never recorded an EOC cert link or Moodle completion date on their ORIGINAL course, so they top out at **60%** and never hit the strict 80 gate.

`force_on_pd_report = 1` is the deliberate, trusted "treat as ready for PD clearance" signal. As of 2026-06-03 it bypasses BOTH gates: era cutoff AND the strict ===80 (forced students render at >=60%, not-cleared).

## What's wired (idea #9191, shipped 2026-06-03)

- **report_viewer.php gate patch**: forced students render at `progress >= 60 && < 100`, not only `=== 80`.
- **cron/cron_pd80_grievance_override_autopopulate.php** (`/etc/cron.d/emsu-pd80-autopopulate`, daily 06:30 PT): auto-sets `force_on_pd_report=1` for approved-grievance (`grievances.status='approved'`) / exam-override (`exam_override_requests.final_status IN ('approved','force_approved')`) students who completed coursework (Moodle or EA completion present), are not NREMT-cleared, and have no exit date. Clears the flag once `nremt_cleared_date` is set.

## Self-check for any future grievance/override resolution

When you approve or resolve a grievance/override and the student has done the coursework: confirm they will appear on the PD 80% report. If they compute below 80 (refresher path) or their course predates the era cutoff, the `force_on_pd_report` flag + the daily cron handle it — but if you're doing a one-off, set `Students.force_on_pd_report=1` manually and verify they render. NEVER leave a completed grievance/override student invisible to PD clearance.

## Cross-references

- idea #9191 — the shipped fix
- .clinerules/29 (act on confidence), /38 (Ruben-asked = autonomous), /92 (fix the core)
- Files: `routes/report_viewer.php` (pd_80_percent_students), `src/Progress.php` (ProgressCalculator), `cron/cron_pd80_grievance_override_autopopulate.php`
- Related reports: `grievance_stipulation_deadlines`, `grievance_60day_refresher_autoenroll`

## Last updated

2026-06-03 — initial. Source: LaRon Tarkington 25224T-11 (grievance/override refresher complete, computed 60%, invisible to Jon's PD list because of the era cutoff + strict ===80 gate).

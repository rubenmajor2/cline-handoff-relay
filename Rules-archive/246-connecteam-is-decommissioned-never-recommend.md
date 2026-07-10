# 246 — Connecteam is DECOMMISSIONED (since 2026-05-15). Never recommend it as a config surface.

Source incident: 2026-07-01 — RUBEN iMessage Ops agent told Vicky (in chat 55) that "Track Type options live inside Connecteam admin (Settings → Time Clock → Track Types)" and tagged Jon/Cori to add combined options there. Connecteam had been shut down for 6+ weeks. Vicky was trying to configure the native EMSU Team Hub scheduler. The agent routed her to a dead platform and pulled in the wrong person.

## The bright-line rule

**Connecteam was shut down on May 15, 2026. The subscription was cancelled. The platform does not exist anymore.** EMSU Team Hub (`/emtskills/routes/team_hub.php` + `/emtskills/routes/scheduler_admin.php`) is the replacement and has been the sole employee platform since that date.

**NEVER recommend Connecteam as a place to configure anything.** Not Track Types, not Enrollment Status, not schedules, not time clock, not messaging. If a staff member asks where a setting lives, the answer is EMSU Team Hub (or the scheduler admin page), not Connecteam.

## What this means for agents

1. **If you don't know where a setting lives, say so — do not guess Connecteam.** Look it up in the actual codebase (`/var/www/emtskills/routes/`) or ask for clarification. A "I'm not sure, let me check" is always better than routing someone to a dead platform.
2. **Do not mention Connecteam by name in ops chats** unless a human is explicitly asking about the migration history. Even saying "the earlier Connecteam message was wrong" keeps the contamination alive — just state the correct answer cleanly.
3. **The `connecteam_shifts` table still exists** as a legacy read source in some routes, and some crons are no-op stubs. That is a cleanup-in-progress (ideas #16066, #16067, #16077), NOT evidence that Connecteam is active. The data is stale mirror data, not a live feed.
4. **Team Hub scheduler dropdowns (Track Type, Enrollment Status, etc.) are native PHP arrays** in `scheduler_admin.php` (`$TRACK_TYPES`, `$ENROLL_STATES`). They are configured by editing that file or by a scheduler in the UI — never by going to Connecteam.

## Who handles Team Hub configuration

- **Scheduler dropdowns / Track Types / Enrollment Status**: EMSU scheduler/admin role (Vicky has this). Edited in `routes/scheduler_admin.php` or via the UI.
- **NOT Jon** — Jon is VP of Ops (policy overrides, refund approvals >$1000, accreditation). He has no role in Team Hub UI configuration.
- **NOT Cori** for dropdown values — Cori handles timeclock/payroll review.
- **NOT "the tech team"** — there is no tech team. There are people. Name them.

## Self-check before answering a "where do I configure X" question

1. Is the thing the person is asking about an EMSU Team Hub setting? → Point them to Team Hub / scheduler admin, not Connecteam.
2. Am I about to type the word "Connecteam" as a recommendation? → STOP. It's dead. Find the real location.
3. Am I about to tag Jon or Cori for a Team Hub config task? → STOP. That's a scheduler task. Vicky can do it herself.

## Cross-references

- Ideas #16066, #16067, #16077 — code-level CT reference cleanup
- Rule 01 — voice and persona (don't route to departments that don't exist; name people)
- `emsu://reference/shift-architecture` — canonical shift/schedule architecture (emsu_shifts is the source of truth, not connecteam_shifts)

## Last updated

2026-07-01 — initial. Source: RUBEN iMessage agent told Vicky to configure Track Types in Connecteam admin, 6+ weeks after CT shutdown.
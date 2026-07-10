# 121 — WPForms EA pipeline + the 2026-05-13 shortcode-break canonical incident

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="121")` or `clinerules_search(query="wpforms section ea stranded")`. Pairs with the auth-gated "bible" doc at https://emsuniversity.com/emtskills/routes/student_status_reference.php which carries the same incident block under "WPForms 5/13-5/14 Plugin Update Broke Hidden-Field Shortcode".

## The EA intake pipeline (canonical, post-2026-05-28)

1. **Student lands on a location landing page** — one of ~20 WordPress sites (emsuniversity.com, arizonaemt.com, californiaemt.com, dallasemt.com, houstonemt.com, miamiemt.com, portlandemt.com, sanantonioemt.com, sandiegoemt.com, seattleemt.com, texasemt.com, tucsonemt.com, bayareaemtrefresher.com, etc.).
2. **WordPress page renders the WPForms shortcode for form_id=3325** ("Enrollment Agreement"). The shortcode pre-fills hidden fields:
   - field 32 (Email) — typed by student
   - field 49 (Signature URL) — drawn by student, captured as PNG URL after submit
   - field 32, 33 (Email + Phone) — typed
   - field 45 (State), 47 (Location) — from page URL slug, RELIABLE
   - field 84, 85, 86 (First/Middle/Last) — typed
   - field 88, 89, 90, 91, 92 (Address) — typed
   - **field 106 (Section)** — HIDDEN, pre-filled by shortcode handler. PRIMARY FAILURE MODE.
   - **field 67 (EMT Program Format)** — HIDDEN, pre-filled by shortcode handler. SECONDARY FAILURE MODE.
   - **field 68, 69 (Course Start/End)** — HIDDEN, likely pre-filled by shortcode. Audit owed.
   - **field 70-74 (Tuition/RegistrationFee/STRFFee/CourseChangeFee/FinancingFee)** — HIDDEN, likely pre-filled. Audit owed.
3. **Student submits.** WPForms writes to `wordpress_2.LzDe7pTO_wpforms_entries` (and sibling DBs on the other sites). Fires a webhook to `/var/www/emtskills/webhooks/emt_registration_enrollment_email.php`.
4. **Webhook routes the entry**: matches by email + class_section against `admin_portal.Students`, inserts `admin_portal.ea_submissions` row, syncs `Students.ea_url + ea_completion_date`. Fires e2PDF generation, Drive upload, email confirmations.
5. **Downstream crons:** `cron_ea_url_sync.php` (every 15min) re-syncs flag fields. `cron_ea_watchdog.php` (every 15min as of 2026-05-28) reconciles WPForms-side vs DB-side. `cron_enrollment_moodle_sync_self_heal.php` (every 10min) provisions Moodle accounts for paid+EA-completed students.

## The 5/13-5/14 incident

WPForms plugin auto-update bounced versions across `1.9.9.3 → 1.9.3.2 → 1.8.5.4` between 5/13 and 5/14. The version churn broke the WordPress shortcode handler that pre-fills hidden field 106 (Section) AND likely 67/68/69/70-74. Result:

- 5/01-5/12: 100% of entries had Section value populated.
- 5/13: 94% (rolling break starts).
- 5/14: 43% (mid-day update midway).
- 5/15: **0%** (full schema break, every entry empty Section).
- 5/16-5/24: 9%-93% intermittent (depends on whether students re-loaded landing pages).
- 5/25-5/27: 95%-97% (most fixed naturally as students hit fresh pages).
- 5/28: 57% (still degraded).

15 confirmed strandings identified 2026-05-28 by cross-checking WPForms entries vs Students.ea_url. Henry Niko (26413FT-44) was the canonical case + drove ~10 inbound tickets/emails. Aggregate impact: 11 of 15 contacted us, 48 inbound emails, 29 about access/EA, 9 refund requests, 42 tickets.

## What was fixed 2026-05-28

1. **Replay primitive shipped**: `/var/www/emtskills/cron/cron_ea_stranded_replay.php`. Idempotent. Two modes:
   - One-shot: `php cron_ea_stranded_replay.php` — replays the hardcoded 15-student list.
   - Auto-discover: `php cron_ea_stranded_replay.php --auto-discover --lookback=168` — replays ANY WPForms entry from last N hours whose email lacks Students.ea_url.
2. **Watchdog hardened**: `cron_ea_watchdog.php` now reads `$fields['106'] ?? $fields['94']`, lookback 168h (was 4h), auto-replays orphans, scheduled `*/15` under emsuserver crontab.
3. **Self-heal cron no longer fatals**: `cron_enrollment_moodle_sync_self_heal.php` calls `EnrollmentReconciler::run()` instead of the missing `findEnrollmentGaps()`. (NOTE: class queries nonexistent tables — heals zero, but no longer crashes. Rewrite owed; orchestrator idea #7811.)
4. **WP auto-update killed on ALL 25+ sites**: 17 DBs had WPForms in `auto_update_plugins`, now removed. 8 sibling wp-configs (refresher subdomains) were missing `AUTOMATIC_UPDATER_DISABLED`, now added. Main emsuniversity.com was already locked. Backups: `wp-config.php.bak-20260528-autoupdate-disable`.
5. **Bible doc updated**: `/var/www/emtskills/routes/student_status_reference.php` got a new "WPForms 5/13-5/14 Plugin Update Broke Hidden-Field Shortcode (canonical incident)" section after "What Breaks With Invalid Section Suffix". Backup: `.bak-20260528-wpforms-shortcode-break`.

## What is still owed (in priority order)

1. **Find + fix the WordPress shortcode handler** that pre-fills hidden field 106. Likely in active theme `functions.php` or `mu-plugins/` or per-site `buynow.php`. Smoke test: load `arizonaemt.com/enrollment-agreement/` in incognito, view source, confirm `<input name="wpforms[fields][106]" value="...">` has a populated value. (Idea #7817 P0.)
2. **Audit fields 67/68/69/70-74** for the same shortcode break. Section is the obvious one but Format/Dates/Pricing likely broke too — would cascade into wrong QB invoices.
3. **Add defense-in-depth at webhook** — when Section empty, derive from HTTP Referer URL, OR Students email lookup, OR smart-match `Course_Schedules` by Location+State+Format+date. (Part of #7817.)
4. **Rewrite EnrollmentReconciler.php** to query actual schema. Currently queries `students`/`qb_invoice_payments`/`user_enrolments`/`enrol`/`course`/`ea_agreements`/`enrollment_recon_flags` — none exist in admin_portal. (Idea #7811 P0.) Unblocks 4 stranded students + the 54-bucket from `HENRY_NIKO_AND_COHORT_HANDOFF_2026-05-28.md` §10d.
5. **Architectural hardening per idea #7814**: make ea_submissions a materialized view over WPForms entries instead of webhook-canonical. Add DB invariant + alert: "WPForms entry with non-empty field 49 ⇒ Students.ea_url populated within N minutes." Promote replay primitive to `lib/EaIntakeMaterializer.php` so watchdog/dashboard/self-heal all call one code path.

## Operational signal (use this answer when staff or a student says "I submitted my EA")

If a student reports "I submitted my EA but your system says it's missing":

```bash
ssh wopr 'sudo -u emsuserver php /var/www/emtskills/cron/cron_ea_stranded_replay.php --auto-discover --lookback=168'
```

Idempotent. Replays any WPForms entry from the last 7 days whose Students.ea_url is NULL. Watchdog at `*/15` already does this but a manual run is faster when someone is on the phone.

## Tables involved (admin_portal unless noted)

| Table | Role |
|---|---|
| `wordpress_2.LzDe7pTO_wpforms_entries` | Ground truth. Form_id=3325 is the EA form. |
| `Students` | Canonical student row. `ea_url`, `ea_completion_date`, `ea_completed_at`, `class_section`, `wpforms_entry_id` |
| `ea_submissions` | Per-submission row. `wpforms_entry_id`, `pdf_drive_url`, `pdf_data`. Stub rows have `wpforms_entry_id < 0`. |
| `Course_Schedules` | Section metadata for fallback derivation. |
| `email_outbound_log` | Records EA emails sent. |
| `enrollment_self_heal_log` | Self-heal cron audit trail. |
| `moodle_c_live.user` / `user_enrolments` / `enrol` | Moodle side, read via the Moodle MCP. |

## Failure modes (to-grow list)

- **Hidden field empty** (current): shortcode handler not pre-filling. Section/Format/Dates/Pricing affected.
- **Invalid section suffix**: e.g. "26906TA" not in `extractClassMethod()` map. Documented in the bible's existing section.
- **Walk-in stub never promoted**: `ea_submissions` row inserted with `wpforms_entry_id < 0` + null pdf_drive_url, then the AI tool reports `ea_completed: true` and tells the student "already on file" without ever attaching a real PDF.
- **Webhook fires but row doesn't land**: pre-2026-05-28 watchdog had no schedule + 4h window, so any failure window > 4h became permanent silent loss.
- **WP plugin auto-update reshuffles things**: closed by killing auto-update on all 25+ sites 2026-05-28.

## Cross-refs

- `.clinerules/92` — work at the core, not bandaids
- `.clinerules/29 v3` — act on confidence
- Orchestrator ideas: `#7810` (watchdog hardening — SHIPPED), `#7811` (Reconciler rewrite), `#7812` (silent-loss class), `#7814` (architectural hardening), `#7816` (initial RCA filing), `#7817` (shortcode fix + defense-in-depth)
- Bible doc (auth-gated, MasterAdmin/ITAdmin): https://emsuniversity.com/emtskills/routes/student_status_reference.php
- Lifecycle dashboard (idea #7425): https://emsuniversity.com/emtskills/routes/student_lifecycle_dashboard.php
- Handoff doc: `/Users/rubenmajor/Desktop/HENRY_NIKO_AND_COHORT_HANDOFF_2026-05-28.md`
- Ledger row: cline_task_ledger.md 2026-05-28 01:35 PT

## Last updated

2026-05-28 — initial. Source: cohort recovery sprint, Henry Niko canonical incident. Ruben directive: "shouldn't this or was this in the MCP or is this page now broken or what's the issue here?" The page is fine (auth-gated 401). The MCP layer was a real gap — this file closes it.

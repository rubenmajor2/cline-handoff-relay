# WPForms Fleet Collapse — Master Reference Doc

**Created:** 2026-05-25 01:45 PT
**Source:** Session #1779691028868 (Cline window working from Vicky's report on Tayden Kelly receipt)
**Status:** ACTIVE — cohort backfill in progress

This document is the canonical reference for the WPForms field-24 fleet collapse incident, its recovery plan, and the WPForms-replacement roadmap. Any future Cline window working this incident should READ THIS FIRST before doing anything.

---

## 1. The incident — what broke

**When:** 2026-05-12 19:30 PT to 2026-05-13 04:44 PT, fleet-wide across all 13 EMT sister WordPress sites (~9-hour window).

**What:** WPForms Form 20 ("Register to Become an EMT") field 24 ("Date of EMT Course") dropdown stopped getting populated with options from `admin_portal.Course_Schedules`. The form rendered with the dropdown empty, students filled out the rest, submitted, and the form recorded `"24":{"value":""}` in storage.

**Per-site break points (last entry that had field 24 populated):**
- californiaemt.com — entry 8295 (2026-05-13 04:44)
- dallasemt.com — entry 4992 (2026-05-12 19:57)
- houstonemt.com — entry 4751 (2026-05-12 20:32)
- sanantonioemt.com — entry 3967 (2026-05-12 19:30)
- sandiegoemt.com — entry 4171 (2026-05-12 20:17)
- texasemt.com — entry 895 (2026-05-15 21:31)
- arizonaemt.com / tucsonemt.com — different field IDs, separate audit needed
- miamiemt.com / portlandemt.com / seattleemt.com / vancouveremt.ca — DB user mismatch in audit script, also NO active classes there yet so non-urgent

**Root cause:** UNKNOWN as of 2026-05-25 02:00 PT. Likely candidates: WPForms plugin auto-update on or about 5/12 19:00, a shared REST endpoint that populated dropdown options, Cloudflare/WAF rule, an Edwiser Bridge or Affirm Gateway update. **Phase 4 investigation** scheduled for 2026-05-25 daytime.

---

## 2. Cohort impact

**Total new Students since 2026-05-13:** 282
**With correct class_section:** 207 (73%, via webhook fallback resolver #5337 catching some)
**Empty class_section (stranded):** 75 (27%)

### Bucket A — 47 students (RECOVERABLE FROM URL CAPTURE)
The WPForms `wpforms_entry_meta.page_url` row preserved a `?class=XXXXX` query parameter on every entry where the student clicked from a specific class landing page. That parameter IS their authoritative class_section choice. Saved at `/tmp/bucket_a_backfill.tsv` on WOPR.

### Bucket B — 28 students (NO URL CAPTURE, NEED OTHER FORENSIC SIGNALS)
These students landed on generic `/register/` without clicking a specific class link. Saved at `/tmp/bucket_b_outreach.tsv` on WOPR.

Subagent comms-log inference results saved at `/tmp/bucket_b_comms_inference.tsv` on WOPR. Distribution:
- 4 HIGH (student named section/date in own inbound)
- 10 MEDIUM (we mentioned section in outbound confirmation OR voice call)
- 13 LOW (no comms, fallback to next-upcoming-FT inference only)
- 5 NEEDS_REVIEW (voice calls about cancellation/issue — but on inspection some of these are actually RESOLVED, see correction below)
- 1 SPAM (Joshua Alonzo II — archived-01- prefix = retry of prior archived account, skip)

### IMPORTANT CORRECTION (2026-05-25 01:45 PT)

**The subagent's NEEDS_REVIEW flag was too conservative.** Ruben pointed out that Vicky has already handled multiple of these students through email/SMS follow-ups. Example verified via DB:

- **8150088 Althea Pascual-Palencia** — was flagged NEEDS_REVIEW because of a voice_call where she had login issues. But her `email_inbound_log` thread (subject "Prep Details", message IDs 34106 → 34123 → 34129 → 34132 → 34145, all from 2026-05-24 21:25 to 22:20 PT) shows Customer Service sent her a "fully bound enrollment agreement for the May 25 San Francisco Fast Track that will lock in your section" — meaning **she should be silent-backfilled to 26613FT**, NOT manual review. Vicky/CS Agent already determined her intent.

**Lesson for next window:** for each NEEDS_REVIEW candidate, check `email_inbound_log` AND `email_outbound_log` for the most recent thread with that student. If we already explicitly told them what section they're in, that's the definitive answer — promote to HIGH and silent-backfill.

---

## 3. Recovery path (the plan)

### Phase 1 — Stop the bleed (ship next window)

1. Run `/tmp/disable_wpforms_autoupdate.sh` on WOPR. Locks WPForms (and all plugin) auto-updates fleet-wide so this exact class of break cannot recur from a plugin push.
2. Install `/tmp/canary_empty_section.php` as `/var/www/emtskills/cron/canary_empty_section.php` + cron.d entry every 15 min. Alerts chat 55 if any new Students row has empty class_section in last 60 min. Replaces the symptom-level #6010 watchdog.

### Phase 2 — Bucket A silent backfill (47 students) — BOTH ADMIN_PORTAL AND WPFORMS

**CRITICAL: this backfill must touch THREE places, not just one:**

1. **`admin_portal.Students.class_section`** — main UPDATE (47 rows) — `/tmp/bucket_a_commit.sql`
2. **`admin_portal.Class_Enrollments` INSERT** — kicked by `bash /tmp/bucket_a_downstream.sh --execute`
3. **WPForms entries on each sister site DB**:
   - UPDATE `wp_<prefix>_wpforms_entries.fields` — set the field 24 JSON value to the full label string format `"May 25, 2026 | Fast Track | 9:00AM to 5:30PM | San Francisco | Section 26613FT | Ends July 21, 2026"` (pull from Course_Schedules to construct the label exactly as the pre-break entries had it)
   - UPDATE `wp_<prefix>_wpforms_entry_fields.value` for `field_id=24` AND `entry_id=X` — same label string (this is the index that WPForms admin UI reads)
   - INSERT row in `wp_<prefix>_wpforms_entry_fields` if missing (entries since 5/13 04:44 don't have a field 24 row, only the entries.fields JSON has it with empty value)

The WPForms backfill happens per-site (need to map `bucket_a_backfill.tsv.source_entry_id` and `source_site` columns to the right DB). This makes the WordPress admin Entries view show the section correctly for historical entries.

4. **EA PDF placement after generation** (per Ruben directive 2026-05-25 01:48 PT) — once the EA is generated by `cron_ea_watchdog.php`, the resulting signed PDF must be:
   - **Attached to the student's Moodle EMT course "Upload EA" assignment** (mdl_assignsubmission_file table — verify exact assignment ID per course; likely a fixed activity ID across all EMT course shells)
   - **Attached/linked on `admin_profile.php?id=<student_id>` page** — there's an EA upload section there; needs the PDF stored in `/var/www/emtskills/uploads/ea_pdfs/<student_id>.pdf` (verify exact path) and a row in the appropriate document table so the admin profile UI shows it
   - Both attachments are part of the silent backfill; the student should never know they were a backfilled record

5. Watch /tmp/bucket_a_downstream.log

### Phase 3 — Bucket B HIGH/MEDIUM + corrected NEEDS_REVIEW

1. HIGH (4): Autumn MacPherson→26517FT, Joshua Babbitt→26520FT, Tyler Wieland→26311FT, Edward Bao→26513FT
2. MEDIUM (10): from /tmp/bucket_b_comms_inference.tsv col 6=MEDIUM — read evidence, commit each with audit_log note
3. **CORRECTED NEEDS_REVIEW promotion** — re-scan each of the 5 NEEDS_REVIEW students by pulling their most recent email_inbound_log + email_outbound_log threads. If Customer Service already named a class for them in outbound, that's the definitive answer. Known: Althea Pascual-Palencia → 26613FT (May 25 SF Fast Track, per outbound thread 5/24 22:20 PT).

### Phase 4 — Bucket B LOW promotion via WPForms forensic combo

Per `/tmp/wpforms_forensic_signals.md`. Combine these signals from WPForms entry data:
- `fields.48.value` — Location (always captured)
- `fields.38.value_raw` / `fields.49.value_raw` — payment-checkbox tier code (1=Reg, 2=FT, 3=BC, 4=Acc, 5=Trad, 6=PayLater, 7=PaymentPlan). California form has TWO fields (38=Union City, 49=San Francisco) — only one has non-zero per entry, identifies BOTH campus AND tier
- `wpforms_entry_meta.url_referer` — often catches `/fasttrack/`, `/bootcamp/`, `/traditional/` slugs
- `wpforms_payments` Authnet description — often has section in text
- Submission timestamp

Match against `Course_Schedules` WHERE (location matches AND class_method matches tier AND course_start_date >= submission_date) → most resolve unambiguously.

Dispatch a subagent for this. After promotion, expect 5-8 of the 13 LOW to promote to HIGH. Remaining 5-8 truly need Vicky review or student email outreach.

### Phase 5 — Genuine cancellations + outreach

Some students DID cancel (verified Eesha Penukonda 8149997 explicitly requested refund on 2026-05-19 02:58 PT voice call, "found a better location"). For these:
- Mark `Students.drop_date = call_date`
- Add `Students.notes = "Cancelled per voice call <id>, refund requested"`
- Skip backfill
- Vicky processes refund in QB per .clinerules/29 (irreversible, human gate)

### Phase 6 — Long-term replacement (60-day project)

Build `/emtskills/public/register.php` to replace WPForms entirely:
- Server-side rendering of class dropdown from `Course_Schedules`
- No plugin dependency
- POSTs to existing centralized handler (`emt_registration_centralized.php`)
- Iframe pilot on texasemt.com first (highest damage site, easiest to swap)
- Roll across 12 sister sites once California is 48h stable
- Deactivate WPForms entirely on day 60

Existing infrastructure that stays (form-agnostic):
- EA via `AccessSelfHealEABranch.php` / `cron_ea_watchdog.php` — reads Students table
- SPFS form — also Students-table driven
- Moodle enrollment via Class_Enrollments + mdl_user lookup
- QB invoice via existing internal flow
- Authnet card processing — already server-side, just point new form at it

---

## 4. Files staged on WOPR /tmp/ (none executed yet)

| File | Purpose |
|---|---|
| `disable_wpforms_autoupdate.sh` | Phase 1.1 plugin lock |
| `canary_empty_section.php` | Phase 1.2 watchdog |
| `bucket_a_commit.sql` | Phase 2 UPDATE (47 rows) |
| `bucket_a_downstream.sh` | Phase 2 Class_Enrollments + EA |
| `bucket_a_backfill.tsv` | Raw 47 Bucket A rows |
| `bucket_b_outreach.tsv` | Raw 28 Bucket B rows |
| `bucket_b_comms_inference.tsv` | Bucket B with comms evidence |
| `wpforms_forensic_signals.md` | Phase 4 LOW promotion playbook |
| `audit_all_sites_field24.sh` | Diagnostic — re-run to spot new breaks |
| `bucket_audit.sh` | Per-site bucket count |
| `cohort_recovery_dryrun.sh` | Cohort cross-walk script |
| `fix_all_admins.sh` | WP admin setup (already ran) |
| `all_entries.tsv` | Raw 1702 WPForms entries since 5/13 |
| `empty_students.tsv` | Raw 75 Students rows |

WordPress admin login on all 13 sister sites: `ruben-temp` / `RubenAdmin2026!`

---

## 5. The forensic 4-layer WPForms storage model (institutional lesson)

When WPForms storage seems missing, check ALL FOUR layers, not just the obvious one:

1. **`wpforms_entries.fields` (JSON blob)** — what user typed/selected on form (this is what broke for field 24)
2. **`wpforms_entry_fields` (normalized table)** — sometimes-out-of-sync index of layer 1, used by WPForms admin filtering
3. **`wpforms_entry_meta`** — page_url (with query params!), url_referer, page_id, IP, user agent, partial-save state — THE actual source of truth for `?class=` recovery
4. **`wpforms_payments` + `wpforms_payment_meta`** — Authnet transaction context, often has section in description text

Before falling back to inference, ALWAYS check entry_meta.page_url. Then check payment_meta. Then check `fields.38.value_raw` / `fields.49.value_raw` (the payment-checkbox tier code).

---

## 6. Why agents missed this for 13 days

The downstream watchdogs (#6010, ea_watchdog, registration_form_healthcheck) all watched the WEBHOOK layer for FATAL errors. When the 2026-05-19 webhook patch (idea #5337) added a section inference fallback, the FATAL stopped firing — but students were still landing in wrong sections silently.

The watchdog that WOULD have caught this: cross-site GROUP BY date on `wpforms_entries.fields` JSON for `"24":{"value":""}`. That's the actual canary. Future watchdogs MUST watch upstream form storage, not just downstream webhook errors.

---

## 7. Open thread tracking

| Thread | Owner | Status |
|---|---|---|
| Phase 1.1 — plugin auto-update lock | next window | PENDING |
| Phase 1.2 — canary cron install | next window | PENDING |
| Phase 2 — Bucket A backfill (47) | next window | PENDING |
| Phase 3 — Bucket B HIGH+MEDIUM (14) | next window | PENDING |
| Phase 3.5 — corrected NEEDS_REVIEW (5 → mostly recoverable) | next window | PENDING |
| Phase 4 — Bucket B LOW forensic promotion (13) | subagent in next window | PENDING |
| Phase 5 — cancellations + outreach (~3-5) | Vicky | PENDING |
| 4-site schema variant audit (miamiemt etc) | next window | LOW PRIORITY (no classes yet) |
| AZ/Tucson field ID variant audit | next window | LOW PRIORITY |
| Phase 4 root cause investigation (5/12 19:30) | tomorrow | PENDING |
| Phase 6 — register.php replacement | 60-day | NOT STARTED |
| Dashboard count fix (Course_Schedules view) | low priority | PENDING |

---

## 8. Verified canonical class_section identifications

Bucket A (47 from URL, all in /tmp/bucket_a_backfill.tsv)

Bucket B HIGH (4):
- 8149993 Autumn MacPherson → 26517FT (her own inbound, 22 June Fast Track San Antonio)
- 8150098 Joshua Babbitt → 26520FT (his voice call about end date)
- 8150099 Tyler Wieland → 26311FT (ticket #5400)
- 8152658 Edward Bao → 26513FT (his ticket #4850 — May 25 San Antonio Fast Track)

Bucket B MEDIUM (10 — see /tmp/bucket_b_comms_inference.tsv col 6)

Bucket B NEEDS_REVIEW corrected to HIGH (verified 2026-05-25 01:45 PT):
- 8150088 Althea Pascual-Palencia → 26613FT (CS confirmed in outbound email 5/24 22:20 PT)
- [Re-scan 8149997, 8150125, 8150133, 8150327, 8150105 in same fashion — most likely also already resolved by Customer Service]

Confirmed CANCELLATIONS (do not backfill, mark drop_date):
- 8149997 Eesha Penukonda — refund requested 2026-05-19 voice call

Confirmed SPAM:
- 8149047 Joshua Alonzo II — archived-01- email prefix

---

## 9. Mechanics — how to actually run this

```bash
# SSH to WOPR
ssh wopr

# MySQL access (TCP, in case socket is degraded)
mysql -h 127.0.0.1 -P 3306 -u adminportal -p"iV84o80^y" admin_portal

# Inspect files
cat /tmp/bucket_a_commit.sql        # 47 UPDATEs
cat /tmp/bucket_b_comms_inference.tsv   # 28 students with evidence

# Run them
bash /tmp/disable_wpforms_autoupdate.sh
bash /tmp/bucket_a_downstream.sh --dry-run     # always dry-run first
bash /tmp/bucket_a_downstream.sh --execute     # then commit
```

WP admin login (all 13 sites at https://<site>/wp-admin/): `ruben-temp` / `RubenAdmin2026!`

---

## 10. Cross-references

- `.clinerules/29` — agents act on confidence tier (Students UPDATE reversible auto-act, EA send irreversible needs Ruben gate)
- `.clinerules/38` — Ruben-asks = autonomous tier minimum
- `.clinerules/91` — every completion needs pickup prompt
- `.clinerules/92` — work at the core not bandaids
- Related ideas: #6275 (P0 EA cohort), #6044 (P0 replay tool — NEEDS WIDENING to fleet), #6010 (P0 webhook watchdog — DEPRECATE as symptom-level), #5337 (P0 webhook patch — shipped), #5020 (P0 section parser — shipped), #5778, #5780
- WOPR HANDOFF_NOTES.md entries: 2026-05-25 00:37, 00:43, 00:52, 01:34
- ~/Documents/Cline/cline_task_ledger.md row 2026-05-25 00:38 PT

---

## 11. Persona notes / lessons baked in

- Pulling data and inferring is fine for HIGH-confidence cases, but ALWAYS check what Customer Service / Vicky already told the student via outbound email or SMS BEFORE marking NEEDS_REVIEW. They have probably already resolved it.
- Voice call summaries can be misleading — a "cancellation" voice call might have ended with a save (CS talked them out of it). Read the full transcript, not just the AI's summary.
- The subagent's confidence ratings are a starting point, not gospel. Re-scan each candidate against most-recent email threads before committing or escalating.

---

**End of reference doc. Update this file as Phases land. Next window: read this first, then start at Phase 1.**

---

## 12. UPDATES — 2026-05-25 20:02 PT

### Shipped this session (mu-plugin + class_method backfill)

1. **NEW mu-plugin: emsu-field24-url-enforcer.php** deployed to all 8 active EMT sister sites:
   - /var/www/vhosts/californiaemt.com/httpdocs/wp-content/mu-plugins/emsu-field24-url-enforcer.php
   - same path on dallasemt / houstonemt / sanantonioemt / sandiegoemt / texasemt / arizonaemt / tucsonemt
   - 122 lines, owner = `<site>emt_admin:psaserv`, mode 644
   - Hook: `wpforms_process_filter` priority 5 (before WPForms validation)
   - Logic: extract `?class=XXXXX` from entry's `_wp_http_referer` URL → look up canonical label via `emsu_fetch_course_choices()` (the same Course_Schedules-fed helper the dropdown render uses) → force-overwrite `fields[24].value` and `value_raw`
   - Idempotent (skips when existing value already has the correct Section code in it)
   - Audit-logged via error_log: `[emsu_field24_url_enforcer] forced fid=24 section=XXXXX label=... url=...`
   - **This is the single-source-of-truth fix.** Replaces the WPForms 1.10.0.5 validation workaround entirely: student picks a class via `?class=` link, value lands. Whatever the dropdown captures (or fails to capture) is irrelevant.

2. **Students.class_method backfill** — 42 NULL rows in the 5/13+ WPForms-collapse cohort backfilled from Course_Schedules.class_method joined by class_section.
   - Why this mattered: the SPFS email dispatcher in `/var/www/emtskills/cron/ea_pdf_retry.php` lines 168 + 253 has `$classMethod = $row['class_method'] ?? 'Fast Track'`. When class_method was NULL, the SPFS variant defaulted to Fast Track, regardless of student's actual track.
   - 13 of the 42 had EA generated before the backfill landed; 9 of those 13 are non-Fast-Track sections (Regular/Accelerated/BootCamp). Those 9 received the wrong SPFS link variant. Their EA PDFs themselves are NOT class_method-driven (template selection is state-based, line 112 ea_pdf_retry.php) — the "Fast Track wording" Vicky sees on the EA PDF is hardcoded in e2pdf template 40, separate fix.
   - Plus 2 mismatched fixes: trinitywallace 8154418 Regular→Fast Track (her section 26913FT IS Fast Track), tjkelly444 8152674 Weekend→Accelerated.

3. **Re-ran V3 URL-class backfill** — 88 more WPForms entries restored across all 8 sites. CA empty-f24 dropped from 109 → 81 (remaining 80 are students who landed on /register/ with NO `?class=` URL parameter; the V4 inference path catches some, the rest are abandoned-cart leads).

4. **Canary cron log ownership fix** — log file was owned by www-data while the cron runs as emsuserver — silent write-fail since 05:45 PT. Re-chowned emsuserver:emsuserver mode 664. Confirmed writing again at 19:51 PT.

### Going-forward safety model (now)

Single source of truth = `admin_portal.Students.class_section` (the section code, e.g. 26913FT). Everything propagates:

- `Students.class_method` ← `Course_Schedules.class_method` WHERE class_section matches (cron_qb_invoice_safety_net + EA webhook already do this; my backfill closed the historical gap)
- WPForms `fields[24].value` ← URL `?class=` parameter ← Course_Schedules canonical label (NEW mu-plugin enforces at submit on all 8 sites)
- master view `view_course_schedules.php` ← Students.class_section JOIN Course_Schedules (already correct)
- QB invoice safety-net catches Students without qb_invoices within 10min
- Moodle suspension gate runs midterm-relative

### Open follow-ups

- **9 students who got wrong-SPFS link** (NOT wrong-EA): 8150575 bhomalon, 8150125 aoneill2025, 8151608 maythevega27, 8150470 joycesuntx, 8150171 benjaminsims01.bs, 8152645 edwardcitalan5, 8150128 mulwa.jules1, 8150598 echicco3, 8150136 ashley.tyler0504. Needs Vicky decision: leave PDFs / Vicky calls / regen.
- **idea #6838** (P2) — perf-bounded detector retry. Awaiting Y/N.
- **idea #6646** (P1) — Affirm chain unblock (silent-ghost x2). lib/AffirmLoanStatusClient.php needs to be written.
- **e2pdf template 40 body copy** — verify it doesn't hardcode "Fast Track" wording for non-CA students. If it does, edit the template in wp-admin.
- **Phase 6 (60-day)** — /emtskills/public/register.php server-side replacement. Iframe pilot texasemt first.

### Reference IDs (current)

- Ticket #5424 OPS-1779703324-WPFC (Vicky bundle)
- Email #34145 (Vicky priority bundle, 2026-05-25 03:29 PT)
- Ideas: #6838 (P2 detector retry), #6646/#6647/#6751 (Affirm chain in_progress), #6824/#6823/#6808 closed
- Event log: #425778
- Affirm canonical creds: `.clinerules/114` + `admin_portal.shared_credential_vault_platforms` WHERE platform_name='Affirm BNPL Production API'
- HANDOFF entries (8 this session, latest 2026-05-25 20:02 PT)

### Last updated

2026-05-25 20:02 PT — added Section 12 with mu-plugin ship + class_method backfill + going-forward safety model.


# 108 — Regulator inspection checklist → portal-attached PDF package (BPPE / CAPCE / TDSHS / AZDHS pattern)

Permanent rule. Workspace-scoped. Source incident: 2026-05-21 BPPE unannounced compliance inspection at EMSU San Diego — inspector arrived ~9:05 AM, 4-hour cap, 1 PM PT flight, denied 24-hour extension. Records all digital. Ruben directive: "I want you to put these documents right in front of me so that I can just download them and then upload them directly into the investigator's inbox, but I need to be able to review them first."

## The bright-line rule

**When a regulator (BPPE, CAPCE, TDSHS, AZDHS, BPSS, county EMS, etc.) hands us a checklist of records, the deterministic response is:**

1. Create the row in `admin_portal.compliance_investigations` (slug, entity, status=open, opened_on, full summary with arrival time + deadline + inspector questions + on-site observations).
2. Pull every source artifact (Drive folders, Google Docs, internal docs) into `/var/www/emtskills/uploads/compliance/regulator_correspondence/<SLUG>/` via the existing `GoogleDriveService` (`listFiles` + `downloadFile`).
3. INSERT one `compliance_investigation_responses` row per checklist item, pointing `file_path` at the assembled PDF.
4. The portal `/personnel/institutional_compliance.php?tab=investigations&entity=<entity>` then renders a clickable "Correspondence + Response Timeline" inside the investigation card, with one `📄 Open PDF` link per row.
5. Mirror the same files to `/Users/rubenmajor/Desktop/<INSPECTION_SLUG>/` for Ruben to review/edit before sending.

## Why this shape

- One PDF per checklist item = inspector gets a clean numbered list, one click each, matches the regulator's own checklist 1:1.
- File_path on `compliance_investigation_responses` → the existing portal renderer (lines ~1290-1360 of institutional_compliance.php) auto-strips `/var/www` prefix and renders `📄 Open PDF` link. Anyone with portal access (ExecAdmin+) can review at the same URL Ruben does, in real time.
- Mirror to Desktop because portal renders the published version; Ruben might need to edit before that becomes the version sent to the regulator. Two-stage gate = no irreversible "oops we sent the wrong catalog."
- Drive is the source of truth for the artifacts (catalog, EA, STRF, SPFS, instructor + CAO files). Server caches the PDF and the portal links to the cached copy so we have a frozen record of what was sent at this moment.

## The portal renderer expects (verified 2026-05-21)

Table `admin_portal.compliance_investigation_responses` (created by az-noi-2026-04-13 wave):
- `investigation_id` int (FK to compliance_investigations.id)
- `response_round` tinyint (1, 2, 3 for multi-round responses)
- `kind` enum('draft','sent','received','internal_note')
- `title` varchar(255) — show as the timeline row header
- `summary` text — show as the line under the title
- `file_path` varchar(500) — MUST start with `/var/www/emtskills/` for the renderer to expose a clickable PDF link
- `sent_to`, `drafted_by`, `posture_notes` — all render in the timeline card

UI hydration: `InvestigationsHydrator::mergeFromDb()` (admin_portal PDO, separate from Moodle DB) loads response_rounds per investigation. `file_path` rewrite for the link: `substr($fp, strlen('/var/www'))` → relative URL the EMSU webroot serves.

## Concrete commands (run-on-WOPR, future you)

```bash
# 1) Create the investigation row (slug must be unique)
mysql -u adminportal -p admin_portal <<SQL
INSERT INTO compliance_investigations (slug, title, entity, status, opened_on, summary, tags, created_by, created_at, updated_at)
VALUES ('<entity>-<inspection-shape>-<location>-<YYYY-MM-DD>', '<Title>', '<entity-slug>', 'open', CURDATE(),
        '<full timeline + deadlines + inspector questions + observations>',
        '["<entity>","<Inspection|NOI|Audit>","<location>"]', 'cline_agent', NOW(), NOW());
SELECT LAST_INSERT_ID();
SQL

# 2) Upload dir
sudo mkdir -p /var/www/emtskills/uploads/compliance/regulator_correspondence/<SLUG>
sudo chown -R www-data:www-data /var/www/emtskills/uploads/compliance/regulator_correspondence/<SLUG>
sudo chmod 775 /var/www/emtskills/uploads/compliance/regulator_correspondence/<SLUG>

# 3) Pull from Drive using GoogleDriveService (see /tmp/bppe_2026_05_21_pull.php as template)
sudo -u www-data php /tmp/<inspection>_pull.php

# 4) Rename extensionless Sheets exports to .xlsx
cd /var/www/emtskills/uploads/compliance/regulator_correspondence/<SLUG>
for f in $(find . -type f ! -name "*.*"); do sudo mv "$f" "${f}.xlsx"; done

# 5) INSERT one compliance_investigation_responses row per checklist item, file_path pointing at the assembled PDF
```

## Entity slugs already defined in the portal (from institutional_compliance.php $investigationEntities)

- `bppe` — California Bureau for Private Postsecondary Education
- `capce` — Continuing Education accreditation
- `tdshs` — Texas Department of State Health Services
- `azdhs` — Arizona Department of Health Services
- `ca_emsa` + `alameda_emsa`, `san_diego_emsa`, `san_mateo_emsa` — county EMSA
- `fl_doh` — Florida Department of Health

When a new regulator shows up that isn't in the map, add it to `$investigationEntities` in institutional_compliance.php FIRST, then create the row.

## On-site posture (mandatory, regardless of regulator)

- On-site staff role = polite, cooperative, supervised. Photograph credentials. Log every question + every record shown. Route policy questions to compliance.
- Do NOT release records from the on-site laptop. All records production goes through compliance from main office.
- Inspector seated alone in a room → check room is clean of paper records + unlocked systems + posted student/instructor names. Document in summary if anything was visible.
- No improvising on outcome / placement / NREMT / refund / completion stats from anyone other than compliance director.
- Never sign Notice to Comply / stipulation / admission. Acknowledgment of receipt only ("received, pending review by compliance").

## Authority cites by regulator (quote in correspondence)

- **BPPE:** CA Ed Code §94934 (unannounced inspection authority), 5 CCR §71770 (records access), FERPA carve-out 34 CFR §99.31(a)(3) (state education authority).
- **CAPCE:** AP-CE Provider Agreement + CAPCE Accreditation Manual. CAPCE pulls docs through provider portal — different mechanism, but the same per-checklist-item PDF assembly pattern still applies.
- **TDSHS:** TX Admin Code Title 25 §157.32 (EMS course provider records access).
- **AZDHS BEMS:** AZ Admin Code R9-25-302 and related (EMS training program records).
- **County EMSA (CA):** Through CA EMSA approval delegation. County has program-approval audit rights, not blanket investigation rights.
- **BPSS (NY):** NY Ed Law §5002, §5004. Similar unannounced authority.

## Ethics line (always)

- ✅ OK: when inspector says "any 3 students," pick 3 with cleanest complete files. Selection-level prescreen is standard.
- ❌ NOT OK: editing, backfilling, or removing anything from a chosen file. Send what's on file at the moment of the request. Spoliation is the single worst mistake in a regulator inspection.
- ❌ NOT OK: if inspector names a specific student/instructor by name, substituting another. Send the named record as-is.
- ❌ NOT OK: pre-screening to hide grievances / suspensions / advisories that exist on a chosen file. If they're in the file as of the request time, they go in.

## Pre-flight checklist before sending each PDF to inspector

1. Is the version the most recent BPPE/CAPCE/state-filed version, or a draft?
2. Are dates current? (CAO resume dated 5 years ago is a finding.)
3. Did we redact other-student data in any roster that's used inside a single-student file?
4. Does the file actually contain what the checklist item demands? (Reference Guide list of required documents per category.)
5. Are we sending from a real EMSU email (compliance@ / rmajor@ / vyu@), not a personal account, archived?

## Withdrawn-student-file BPPE pressure point

Always verify these are ALL on file before including a withdrawn student in the package:
- Notice of cancellation/withdrawal (written, signed)
- Refund calculation documentation (60% attendance rule, BPPE refund policy)
- Refund actually paid if owed (QB credit memo + Authnet refund txn)

If any are missing → SWAP to an alternate withdrawn student. Do not send a withdrawn file with broken refund paper trail. That's the file that earns the Notice to Comply.

## CAPCE same-pattern reminder

CAPCE Accredited Provider work uses the same `compliance_investigations` row + `compliance_investigation_responses` rows (entity='capce') for application materials, deficiency responses, and renewal cycles. The `f5_capce_correspondence_log` table is a SEPARATE per-message log for narrow CAPCE comms; the formal correspondence with file attachments still goes on `compliance_investigation_responses` for portal visibility.

## Source incident summary

2026-05-21 BPPE inspector arrived unannounced at EMSU San Diego ~9:05 AM PT. Instructor Stephen Metz on-site, correctly said "all records online, I don't have them here." Jon Thompson VP Ops on phone from 10:35. Inspector capped at 4 hours, refused 24h extension. Asked about EAs, student files, future employment opportunities. Sat alone in room ~30 min.

Cline workflow during the 4-hour window:
1. Read Inspection Checklist + Student/Faculty File Reference Guide from Ruben's Downloads.
2. Queried admin_portal directly: identified 9 SD students (3 current + 3 grad + 3 withdrawn) cross-checked against grievances + active payment_suspensions. Filtered out 6 with active suspensions.
3. Dispatched 5 subagents (3 blocked by MCP-not-exposed, 2 succeeded with instructor pick + STRF/SPFS source location).
4. Created `compliance_investigations` row id=2 slug `bppe-unannounced-inspection-sd-2026-05-21`.
5. Vicky sent 4 Drive folder links covering STRF Q4 2025, STRF Q1 2026, SPFS 2023, SPFS 2024.
6. Ran `/tmp/bppe_2026_05_21_pull.php` (uses GoogleDriveService) to pull all artifacts to `/var/www/emtskills/uploads/compliance/regulator_correspondence/BPPE_2026-05-21/`.
7. Inserted 12 `compliance_investigation_responses` rows pointing at each PDF.
8. Portal now renders clickable timeline on Investigations tab.
9. Mirrored to `/Users/rubenmajor/Desktop/BPPE_INSPECTION_2026-05-21/` for Ruben review.

Ruben's review-before-send pattern locked in as the default for all future regulator inspections.

## UX gotcha: the timeline `<details>` is COLLAPSED by default

The portal renders the checklist inside a `<details>` element that starts collapsed. The summary line MUST be loud and action-oriented or Ruben will look at the card and think "where are the docs."

Header text (patched 2026-05-21):
```
👉 Click here to see all N checklist documents (📋 Correspondence + Response Timeline)
```

Before: "📋 Correspondence + Response Timeline (N)" — too easy to read as a status indicator and miss the click affordance.

Rule of thumb: any expand/collapse the user MUST click to see records → say "Click here" in the summary, not just an icon.

## browser_action verification (rule 83)

When verifying portal renders for Ruben, ALWAYS use the session-bridge token pattern per .clinerules/83. NEVER try to type into /emtskills/login.php. The shape:

```
1. cat > /tmp/make_session.php  (sets $_SESSION['user'] = ['id'=>1,'role'=>'MasterAdmin',...])
2. cat > /tmp/_dev_render_<target>.php  (killswitch-gated, sid-validated, attaches to session)
3. sudo cp _dev_render_*.php → /var/www/emtskills/routes/ + chown www-data
4. sudo touch /tmp/cline_diag_allow
5. SID=$(sudo -u www-data php /tmp/make_session.php)
6. browser_action launch url=https://www.emsuniversity.com/emtskills/routes/_dev_render_<target>.php?sid=$SID
7. CLEANUP: rm bridge + killswitch + make_session
```

This was used 2026-05-21 to confirm the BPPE card was actually rendering when Ruben said "I can't see it" — and it WAS rendering, but the timeline was collapsed under unclear UI. The fix was the "Click here" header text rewrite above, not a data fix.

## Last updated

2026-05-21 — initial rule. Source: BPPE unannounced compliance inspection at EMSU SD campus + Ruben directives ("this is what I need" + "remember this stuff for future audits" + "just say click here or whatever"). Header-text fix landed same session.

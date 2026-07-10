# 128 — EA links need all 3 access-guard params + never re-send the blank form to a completed-EA student

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="128")` or `clinerules_search(query="enrollment agreement direct access not allowed link")`. Pairs with rule 121 (WPForms shortcode break), rule 111 (bare-URL button-wrap), rule 127 (no invented departments).

Source: 2026-05-29 babysit. Students (sarahaf2007@gmail.com, madquyen1@gmail.com, echicco3@gmail.com) flooded support saying the enrollment-agreement link gives **"Direct Access Not Allowed / This Form Requires a Personalized Link."** Ruben: *"Email agent is still sending these enrollment agreement links that are not able to be filled out."*

## Root cause (browser-confirmed 2026-05-29)

The `emsu-form-access-guard` WordPress plugin on `/enrollment-agreement/` (and `/enrollment-agreement-ca/`) requires **THREE** non-empty `$_GET` params or it returns a 403 denial page:

- `first_name`
- `email`
- `section`  ← the one that's usually missing

The check uses PHP `empty()`, so `section=` (present but empty) OR `section=0` ALSO triggers the block. A link with all three intact renders + pre-fills the WPForms form 3325 correctly (verified in Chrome with `?first_name=Madeleine&email=...&section=26916BC`).

Two failure shapes produce the denial page:

1. **Empty-section link.** `build_ea_url` / `ea_url_builder` generated the link from a Students row whose `class_section` is empty (the 5/13 shortcode-break cohort, rule 121). The section param goes out empty → 403.
2. **Line-wrapped bare URL.** The EA link was emailed as a bare inline URL. Gmail/Apple Mail wrap long URLs across lines, so the clickable portion is only the first segment (`...enrollment-agreement/?state=TX`) and every param after the wrap point is dropped → 403.

## The bright-line rules

1. **Never emit an EA link with an empty `section`.** `build_ea_url` and `ea_url_builder` must derive `section` from `Course_Schedules` (location + class_method + start_date, same logic as the `ea_completion.php` section-derive fallback shipped 2026-05-28) BEFORE building the URL. If section still can't be resolved, do NOT send a link — route to a human with the specific missing data.

2. **EA links always go out as a styled button, never a bare inline URL.** `MailerBareLongUrlGuard` (rule 111) auto-wraps, but the composer should build the button directly so the full `href` (with all params) is preserved regardless of client line-wrapping.

3. **Check for an existing completed EA before sending the blank form.** If `Students.ea_url` is a Drive PDF (`LIKE %drive.google%`) OR an `ea_submissions` row has a non-null `pdf_drive_url`, the student already completed their EA. Do NOT send them the blank-form link. Send the completed PDF, or the orientation-module upload instruction, or nothing. Source: sarahaf2007@gmail.com had a completed EA (Students.id 8154608) and still got 38 "fill out your enrollment agreement" emails.

## Self-check before sending any EA link

1. *Does this student already have a completed EA?* (`ea_url LIKE %drive.google%` or `ea_submissions.pdf_drive_url` not null) → if yes, do NOT send the blank form.
2. *Does my link have a non-empty `section` param?* → if no, derive it from Course_Schedules or don't send.
3. *Am I sending it as a button (full href preserved) or a bare URL (client can line-wrap)?* → button only.

## Cross-refs

- `.clinerules/111` — bare long URL → button wrap
- `.clinerules/121` — WPForms 5/13 shortcode break (empty section cohort)
- `.clinerules/127` — no invented departments / promised followup
- Access guard: `/var/www/vhosts/emsuniversity.com/httpdocs/wp-content/plugins/emsu-form-access-guard/emsu-form-access-guard.php`
- Bible doc anchor: `student_status_reference.php#ea-link-direct-access-2026-05-29`

## Last updated

2026-05-29 — initial. Source: babysit, EA-link "Direct Access Not Allowed" flood + completed-EA-resend spam (Sarah Arroyo-Fontecha, Madeleine West, Emma Chicco).

# 129 — Verify the artifact's CONTENTS, not its label, before any student-facing send

Hardfloor candidate. Workspace-scoped. Source: 2026-05-29 Sarah Arroyo-Fontecha doom loop. Ruben's question: *"Why did I get this right in 5 minutes and you took hours to get it wrong?"* Answer: he opened the PDF and read the date; I trusted the filename + the newest row + the ea_completion_date and shipped on an artifact I never opened. Documented in `/Users/rubenmajor/Desktop/EA_SIGNED_COPY_SYSTEMIC_FIX_2026-05-29.md` Part 0.

## The bright-line rule

**Before sending ANY student-facing document or link, verify the CONTENT of the artifact, not its metadata.**

- **PDF / signed doc:** download it and read the actual in-document fields (`pdftotext -layout file.pdf | grep -iE 'course start|section|name'`). Confirm the in-document section/dates/name match the student's CURRENT active `Students.class_section`. NEVER rely on filename, row id, or `ea_completion_date` alone.
- **Link:** actually fetch it (curl / browser) and confirm it renders the expected bound values — not "Direct Access Not Allowed", not a blank form.
- **"The latest row":** never assume newest = correct after a transfer. Match on the student's **active** `Students.class_section`, falling back to newest only if no active-section match exists.
- The cheap check (open the file, read 3 lines) is faster than the loop it prevents. Do it FIRST, every time.

## The specific failure this prevents

I (Cline) sent sarahaf2007@gmail.com the PDF at Drive `10LjYNk8...` (ea_submissions row 1793) because it was the newest row and matched her `ea_completion_date`. That PDF's in-document Course Start was **05/25/2026** — the WRONG, already-started bad-transfer section (26413FT). Her ACTIVE section is **26417FT** (starts 06/22/2026), whose correct EA is the OLDER row 1333 (Drive `1is3-Ex2...`, in-PDF Course Start 06/22/2026). Newest ≠ active after a transfer. Reading either PDF for 10 seconds would have caught it. Ruben caught it in 5 minutes by opening the file.

## The machine version (for any tool that sends a doc)

A `send_signed_ea_copy` / document-resend tool MUST, before sending:
1. Select the artifact by **active section first**: `ORDER BY CASE WHEN ea.class_section = s.class_section THEN 0 ELSE 1 END, ea.id DESC` and require `pdf_drive_url IS NOT NULL` (skips stub rows).
2. Pull the PDF and extract the in-document section/Course-Start via pdftotext.
3. ASSERT the in-PDF values match the student's active record. On mismatch → do NOT send, flag for human + regenerate.

This is the codified version of "open the PDF and read it before you send it."

## Self-check before any document/link send

1. *Did I open the actual artifact (PDF text / fetched link), or am I trusting a filename / row id / status flag?* If I haven't opened it, open it.
2. *Does the artifact's INTERNAL content match the student's ACTIVE section/dates?* Not the newest row — the active one.
3. *For a link: did I actually fetch it and see it render?* A link I haven't loaded is unverified.

## Cross-refs

- `.clinerules/29` — act on confidence (this is what "confidence" actually requires for document sends)
- `.clinerules/121` — WPForms shortcode break (the transfers that create multi-section EA rows)
- `.clinerules/128` — EA link 3-param + no blank-resend (the sibling EA-send rule)
- Spec: `/Users/rubenmajor/Desktop/EA_SIGNED_COPY_SYSTEMIC_FIX_2026-05-29.md`

## Last updated

2026-05-29 — initial. Source: Cline sent the wrong-section EA PDF to Sarah by trusting newest-row + filename instead of opening the PDF. Ruben corrected it in 5 minutes by reading the document.

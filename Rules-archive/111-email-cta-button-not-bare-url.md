# 111 — Outbound email CTAs use a styled button, NEVER a bare/inline long URL

Permanent rule. Workspace-scoped. Source: 2026-05-23 Ruben directive after seeing the EA email Sabrina Daugherty received with the full ~600-char enrollment-agreement URL pasted inline below the link text. Quote:

> *"The button link was better — emails truncate some of these long URLs so probably need to make that a rule in general and for these EA's resend those with the button instead"*

## The bright-line rule

**Any EMSU-outbound email whose primary call-to-action is a URL (EA sign link, payment link, Moodle URL, certificate link, externship form, exam scheduler, etc.) MUST use a styled button as the CTA. The full URL string MUST NOT appear inline in the body.**

If you genuinely need a fallback for users whose mail client strips HTML buttons, the fallback is **one short "Tap here" / "Button not working? Tap here." link below the button** — never the full URL pasted in `<p style="word-break:break-all;">…</p>` form.

## Why

Gmail / Apple Mail / Outlook clients truncate URLs over ~80 chars when shown inline as text — the visible link STILL TARGETS the full URL, but the visual `<u>https://www.emsuniversity.com/enrollment-agreement/?state=Arizona&location=Tempe&…</u>` looks corrupted, smells phishy to the student, and confuses them when the inline text doesn't match the button destination. Real outbound (Sabrina Daugherty 2026-05-23 18:30) had ~600 chars of inline URL stretching down 6 lines of the email. Students see this and either (a) don't click because it looks broken, or (b) email back asking which link is correct.

Buttons render correctly on every email client in last 10 years. The "copy and paste this URL into your browser" pattern is 2010-era email best practice that doesn't apply when the URL is signed/state-bearing and 400+ chars.

## Canonical CTA snippet

```php
$urlEsc = htmlspecialchars($url);
$body .= '<p style="text-align:center;margin:28px 0;">'
       . '<a href="' . $urlEsc . '" style="display:inline-block;padding:14px 28px;background:#1e5cab;color:#ffffff;text-decoration:none;font-weight:600;border-radius:6px;font-size:16px;">'
       . 'Open your Enrollment Agreement'  // CTA verb specific to the action
       . '</a></p>'
       . '<p style="font-size:13px;color:#555;">Button not working? <a href="' . $urlEsc . '">Tap here</a>.</p>';
```

EMSU brand blue is `#1e5cab`. Adjust the CTA verb to the action (Sign / Open / Pay / Complete / Schedule). Keep the "Button not working? Tap here." fallback to a single short word — never a `word-break:break-all` block of the full URL.

## Banned patterns

- ❌ `<p><a href="URL">Open Agreement</a></p>` (no button styling — looks like plain link, also fails mobile-touch-target accessibility)
- ❌ `<p style="word-break:break-all;font-size:12px;color:#555;">URL</p>` (the inline URL anti-pattern — what Sabrina got)
- ❌ `<p>If the link does not open, the full URL is:</p><p>URL</p>` (legacy "copy-paste" — same problem)
- ❌ Multi-paragraph URL wrapping with HTML entities mid-link

## OK patterns (graded)

- ✅ Styled button + short "Tap here" fallback (canonical, above)
- ✅ Styled button only (no fallback — fine for in-app HTML email)
- ⚠️ Styled button + `<em>Alternatively, <a href="URL">click here</a></em>` (acceptable but redundant)

## Scope

Applies to **every outbound email** from any EMSU domain to a student, preceptor, externship site, parent, prospect, or regulator. Specifically including:

- Initial EA send (`paid_no_ea_no_invoice_repair.php`, registration webhooks)
- Corrected-EA resend (`ai_ticket_agent.php::aiResolveBrokenEaUrlClass`, `ai_ticket_agent_section_correction_handler.php`, `agent_handlers/bug2_corrected_ea_resend.php`)
- EA reminders (`ea_reminder_helpers.php`, `cron_ea_enrollment_reminders.php`, `ea_signing_reminder_cadence.php`, `ea_weekly_reminder.php`, `ea_pdf_retry.php`)
- Section change confirmation (`section_change_handler.php`)
- Payment receipt + EA link combo (`payment_receipt_email.php`)
- EA pay-in-full combo flow (`ea_payinfull_combo_flow.php` — two-CTA list, refactor pending)
- Any future agent-driven email that sends a state-bearing URL

Does **not** apply to:

- Internal staff iMessage (rule 01 voice rules already exclude inline long URLs)
- HANDOFF_NOTES.md and ledger entries (those are technical, full URLs are fine)
- AI/agent-internal ticket comments (`is_internal=true`)

## Existing offenders patched 2026-05-23

- `/var/www/emtskills/lib/ai_ticket_agent_section_correction_handler.php` — WS-B handler 1
- `/var/www/emtskills/lib/ai_ticket_agent.php::aiResolveBrokenEaUrlClass` — Workstream-A precedent + production EA-resend
- `/var/www/emtskills/lib/ea_reminder_helpers.php` — daily EA reminders
- `/var/www/emtskills/lib/agent_handlers/paid_no_ea_no_invoice_repair.php` — initial-EA send (the Sabrina Daugherty path)
- `/var/www/emtskills/lib/agent_handlers/bug2_corrected_ea_resend.php` — WS-C handler 8
- `/var/www/emtskills/lib/agent_handlers/section_change_handler.php` — WS-C section change
- `/var/www/emtskills/lib/BrokenEaUrlRecipe.php` — legacy recipe path

Still to patch (filed as followup): `lib/ea_payinfull_combo_flow.php` (two-CTA list shape — needs refactor), `lib/registration_ea_guard.php` (already uses `target="_blank"` link only, no inline URL — low priority).

## Self-check before any new outbound email template

Before shipping any code that calls `sendEmail()` with an HTML body containing an EA / pay / Moodle / extern URL, grep your own diff for:

- `word-break:break-all` → DELETE that paragraph
- `'<p>' . htmlspecialchars($url) . '</p>'` → DELETE that paragraph
- "the full URL is" / "copy and paste this URL" / "Alternatively click here" → DELETE that paragraph
- Plain `<a href>` without `style="…padding…background…border-radius…"` → wrap in the canonical button snippet above

If none of those tripped, ship. If one did, replace with the canonical snippet at top of this rule.

## Source incident

2026-05-23 18:30 PT — Sabrina Daugherty (sabrina.daugherty99@gmail.com) received "Your Enrollment Agreement - Tempe (Section 26213FT)" from `paid_no_ea_no_invoice_repair.php`. The button + the full 600-char URL were both in the body. Ruben surfaced the screenshot, asked to make the button-only pattern the default. Templates patched same session.

## Last updated

2026-05-23 — initial rule. Source: Ruben directive in cline_agent_buildout_B_enrollment_state_2026-05-23 wrap-up, after Sabrina Daugherty EA email visual review. 7 file templates patched concurrently. Filed for indexing in clinerules-mcp via reindex.

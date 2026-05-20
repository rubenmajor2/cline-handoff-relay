# 48 — Ruben house style for emails sent FROM rmajor@

Permanent rule. Workspace-scoped. Source: 2026-05-11 Ruben directive verbatim:
*"Send the email to look like my emails usually do, no wrapper or style, just like they look usually. You can see in my sent folder. Call it Ruben house style - put in cline rules"*

## The bright-line rule

**When sending an email FROM `rmajor@emsuniversity.com` (i.e. on Ruben's behalf), do NOT wrap the body in the EMSU branded HTML template** (the blue-gradient header + logo + footer chrome from `wrapEmailHtml()`). Send plain.

Ruben's actual outbound emails (he writes them himself in Mac Mail / Gmail) are:

- Plain text body, or minimal HTML (line breaks only)
- No logo header
- No branded footer with phone, info@ address, copyright line
- No "EMS University" salutation banner
- Short paragraphs, casual voice
- Closing line ("Best," or "Thanks," etc.) followed by his full signature block (see below)
- No em dashes, no semicolons, no corporate hedging

## REQUIRED signature block (verbatim, every email from rmajor@)

Every email sent on Ruben's behalf MUST end with this signature block exactly as written. No paraphrasing, no abbreviating, no omitting lines:

```
Best, &c

--
Ruben Major, EMT-Paramedic, J.D., M.A.
CEO, EMS University, LLC d.b.a. EMS Universal Education
"We Don't Follow the Standards, We Set Them."
www.emsuniversity.com
facebook.com/emsuniversity
twitter.com/emsuniversity
(800) 728-0209

Mailing Address:
501 South 48th Street, Suite 105, Tempe, AZ 85281 - 1010 East Pennsylvania, Suite 206, Tucson, AZ 85714 - 1730 SW Military Drive, Suite 202, San Antonio, TX 78217 - 6910 Miramar Road, Suite 206, San Diego, CA 92121 - 32980 Alvarado-Niles Road, Suite 810, Union City, CA 94587 - 1452 Hughes Road, Grapevine, TX 76051 - 395 Oyster Point Boulevard, Suite 126, South San Francisco, CA 94080.

NOTICE: This E-mail is the property of EMS University, LLC and contains information that may be PRIVILEGED, CONFIDENTIAL or otherwise exempt from disclosure by applicable law. It is intended only for the person(s) to whom it is addressed. If you receive this communication in error, please do not retain or distribute it. Please notify the sender immediately by E-mail at the address shown above and delete the original message. Thank you.

DISCLAIMER: I am not an attorney. This is not legal advice. You should not rely on my advice as legal advice. If you need legal advice, you should consult an attorney.
```

Lead with `Best,` or `Thanks,` or whatever closing fits the email tone, then the `--` separator, then everything below it verbatim. The `&c` after `Best,` is intentional and stays.

When rendered as HTML, use `<br>` for each line break and wrap the whole signature in a single `<p>` block. Do not add styling. Do not link the website lines (they render as plain text in his mail client; preserve that).

Reference implementation in PHP:

```php
$rubenSignature = <<<HTML
<p>Best, &amp;c</p>
<p>--<br>
Ruben Major, EMT-Paramedic, J.D., M.A.<br>
CEO, EMS University, LLC d.b.a. EMS Universal Education<br>
"We Don't Follow the Standards, We Set Them."<br>
www.emsuniversity.com<br>
facebook.com/emsuniversity<br>
twitter.com/emsuniversity<br>
(800) 728-0209</p>
<p>Mailing Address:<br>
501 South 48th Street, Suite 105, Tempe, AZ 85281 - 1010 East Pennsylvania, Suite 206, Tucson, AZ 85714 - 1730 SW Military Drive, Suite 202, San Antonio, TX 78217 - 6910 Miramar Road, Suite 206, San Diego, CA 92121 - 32980 Alvarado-Niles Road, Suite 810, Union City, CA 94587 - 1452 Hughes Road, Grapevine, TX 76051 - 395 Oyster Point Boulevard, Suite 126, South San Francisco, CA 94080.</p>
<p>NOTICE: This E-mail is the property of EMS University, LLC and contains information that may be PRIVILEGED, CONFIDENTIAL or otherwise exempt from disclosure by applicable law. It is intended only for the person(s) to whom it is addressed. If you receive this communication in error, please do not retain or distribute it. Please notify the sender immediately by E-mail at the address shown above and delete the original message. Thank you.</p>
<p>DISCLAIMER: I am not an attorney. This is not legal advice. You should not rely on my advice as legal advice. If you need legal advice, you should consult an attorney.</p>
HTML;
```

Use that exact block. Do not regenerate it from memory each time, copy it verbatim from this rule.

## Why this rule exists

The `wrapEmailHtml()` template in `lib/mailer.php` is designed for customer service / system / automated emails sent on behalf of EMSU as an institution. It includes a blue-gradient header with the EMS University logo, the institutional footer with contact info, and copyright. Those signals make sense when the email is from "EMS University Customer Service."

They do NOT make sense when the email is from Ruben personally. Ruben emails from his MacBook in plain text with normal formatting. Wrapping his personal emails in the branded template makes them look like an automated system email, which:

1. Reduces personal weight (recipient mentally categorizes it as "automated, can wait")
2. Buries the actual content under header chrome
3. Looks weird in a thread when his prior reply was plain and the new one is suddenly branded
4. Adds visual noise to a recipient on mobile

## How to send plain from Ruben

When calling `sendEmail()` in `lib/mailer.php` with `$fromEmail = 'rmajor@emsuniversity.com'`, pass `$wrapStyle = 'none'` (the 11th positional argument). Example:

```php
require_once '/var/www/emtskills/lib/mailer.php';

sendEmail(
    'recipient@example.com',           // to
    'Subject line',                     // subject
    $bodyPlainHtml,                     // body — plain html, line breaks only
    'rmajor@emsuniversity.com',         // from
    'Ruben Major',                      // from name
    'rmajor@emsuniversity.com',         // reply-to
    'Ruben Major',
    'rmajor@emsuniversity.com',         // bcc (Ruben himself for sent-folder visibility, optional)
    null,                                // attachments
    null,                                // custom headers
    'none',                              // wrap style — KEY: 'none' = no template wrapper
    'cc@example.com'                    // cc (optional)
);
```

The `wrapStyle='none'` arg tells `sendEmail()` to skip the institutional wrapper. The body still gets sent as HTML for line-break preservation, but with no header, no footer, no logo.

## Body format

Body should look like this (minimal HTML for line breaks, no styling):

```html
<p>Hey [name],</p>

<p>First paragraph, short and direct.</p>

<p>Second paragraph, also short.</p>

<p>Bullet-style stuff if needed:<br>
- item one<br>
- item two<br>
- item three</p>

<p>Closing thought.</p>

<p>Thanks,<br>Ruben</p>
```

OR even simpler, plain text with `\n\n` and let PHPMailer's HTML rendering handle the breaks. Either way, NO `<table>`, no inline `style` attributes, no logos, no horizontal rules.

## What this rule does NOT cover

- Emails from `vyu@`, `jthompson@`, `info@`, `support@`, `grading@`, `personnel@`, `cna-agent@`, `noreply@`, etc. Those still use the branded `wrapEmailHtml()` template by default because they ARE institutional voice.
- Automated emails sent by crons under Ruben's email address. Those are rare and should still wrap institutionally because they are clearly machine-generated. Bug Hunter alerts, RUBEN executor digests, etc.
- Cline drafting an email FOR Ruben to copy-paste into his Mac Mail. In that case, hand him plain text (no HTML at all), and let him paste it.
- Internal staff comms in iMessage (rule 01 covers that).
- Student-facing AI auto-responses (rules 02, 15, 19, 31 cover those — they are NOT from Ruben).

## Self-check before any sendEmail() call with from=rmajor@

Ask: *"Is this email FROM Ruben personally?"* If yes, my `wrapStyle` argument MUST be `'none'`. If I am about to call `sendEmail(...)` with `$fromEmail='rmajor@emsuniversity.com'` AND leaving `$wrapStyle` at default `'auto'`, stop and pass `'none'` instead.

## Cross-references

- Rule 01 — voice and persona (Ruben casual register applies)
- Rule 02 — no apologies in student emails (applies here too if recipient is a student)
- Rule 30 — no em dashes (always applies)
- Rule 47 — full web addresses, not shortcuts (applies here too)
- `lib/mailer.php` — `sendEmail()` signature, `$wrapStyle` is the 11th positional arg

## Last updated

2026-05-11 — initial rule. Source: Ruben directive after Cline-drafted reply to Shela was about to be sent with the branded `wrapEmailHtml()` template. Ruben caught it and said send plain like his usual emails. Rule encodes the pattern.

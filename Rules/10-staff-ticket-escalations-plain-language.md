# Staff Ticket Escalations — Plain Language for Vicky and Jon

## The rule

When a ticket, escalation email, or internal staff comment is going to land in front of **Vicky (CS Supervisor Admin)** or **Jon (CS / Exec Admin)**, write it in plain language with a clear **ACTION REQUIRED** section at the top. Strip the engineering jargon. Vicky and Jon are not developers — they cannot do anything with `embed_present=0`, `installed=1 failed=0`, `mdl_user_enrolments.status=1`, "WP Rocket / W3TC / LiteSpeed page cache stripping inline scripts," `header.php/footer.php`, or `cron_chat_widget_healthcheck.php`. Engineers can. Vicky and Jon cannot. Write to the audience that's receiving it.

This rule extends rules `01-voice-and-persona.md` (ops chat voice) and `02-no-apologies-in-student-emails.md` (student-facing email tone). Neither of those covered the staff-ticket case directly. This one does.

## Why this rule exists

On 2026-04-28 12:02 PT, `cron_chat_widget_healthcheck.php` auto-detected that houstonemt.com's chat widget embed had briefly disappeared from the rendered HTML. The same cron run successfully re-installed it via `bulk_widget_install.php` (`installed=1 failed=0`). The next 30-min scan was almost certain to show healthy again — and in fact did, when verified.

But the ticket pipeline still did all of this:

1. The cron opened ticket OPS-1777402952 with a description that said `embed_present=0`, `home_http_code`, `Health rows: SELECT * FROM chat_widget_health WHERE domain IN (...)`.
2. The AI ticket agent ran a "RUBEN investigation" that produced a 600-word engineer's writeup full of `mdl_user_enrolments`, `WP Rocket / W3TC / LiteSpeed`, `header.php/footer.php`, `asset optimizer removing inline scripts`.
3. The escalation logic dumped the full investigation verbatim into an email with subject "Escalation: OPS-1777402952" and sent it to Vicky.
4. Vicky received an unactionable engineer's diagnostic for a self-healing infrastructure problem that didn't need her in the loop at all.

Ruben flagged it: "Tickets like this I'm seeing coming through to Vicky, the CS Supervisor Admin are WAY too technical. They need to be sent in plain language."

This rule prevents repeats and forces the translation step.

## What "plain language" means concretely

Every staff-facing escalation email, ticket description for staff, or internal comment that Vicky or Jon will read should follow this skeleton:

```
WHAT HAPPENED
<one or two sentences a non-engineer can picture. "The live chat box on
houstonemt.com temporarily disappeared. Students visiting that page would have
seen the site, but no chat icon in the corner.">

IS IT FIXED
<yes / no / partially. If yes, say so up front. Don't bury it.>

ACTION REQUIRED FROM YOU
<None. / OR a numbered list of 1-3 specific things in plain English that
this person, with the access they actually have, can do today.>

IF A STUDENT REACHES OUT
<one short paragraph telling them what to say + when to escalate further.>

BACKGROUND (optional, only if it adds value)
<one short paragraph explaining the why in non-technical terms — not a
deep-dive into infrastructure.>
```

Never lead with the diagnostic. Lead with whether they need to do anything. The diagnostic, if it belongs anywhere, goes at the bottom in plain English or — better — gets dropped entirely from the staff copy and lives only in `HANDOFF_NOTES.md` / internal ticket comments tagged for engineers.

## Forbidden phrases / patterns in staff-facing tickets

These ALL need to be rewritten or stripped before the message goes to Vicky / Jon:

| Forbidden | Plain language replacement |
|---|---|
| `embed_present=0`, `embed_present=NO` | "the chat box was missing from the page" |
| `installed=1 failed=0`, `installed=N` | "the auto-repair script reinstalled the chat box successfully" |
| `mdl_user_enrolments.status=1` | "the student is still locked out of Moodle" |
| `payment_suspensions.is_active=0` | "their payment is already cleared on our end" |
| `auto_payment unsuspend hook data-sync gap` | "the system that normally restores access after payment didn't fire correctly for this one" |
| `WP Rocket / W3TC / LiteSpeed page cache holding stale HTML` | "the website was showing an old cached version of the page that didn't include the chat code" |
| `header.php / footer.php` | "the website's homepage template" |
| `theme/plugin conflict`, `asset optimizer`, `inline scripts` | "something on the website was removing the chat code after we installed it" |
| `home_http_code`, `config_ok`, `send_ok`, `ai_reply_ok` | "the website is up", "the chat backend is fine" |
| `chat_widget_health`, `cron_chat_widget_healthcheck.php` | "our automatic chat-box monitor" |
| `[NEEDS_HUMAN]`, `[RUBEN Investigation]` | omit entirely from the staff copy |
| `RUBEN investigation flagged for at least one part of this ticket` | omit; this string means nothing to Vicky |
| `Self-heal cron reported installed=1 failed=0, meaning it successfully re-injected the widget plugin` | "the auto-repair fixed it on the same run" |
| `mdl_`, `cron_`, `lib/`, `routes/`, file paths in general | replace with what the thing does, not what it's called |
| Long bullet lists of database column names | summarize: "we already verified the student paid" |
| Markdown headings + `**bold**` walls of text | short prose, 4-line phone screens |
| SQL queries (`SELECT * FROM ...`) | NEVER in a staff-facing ticket — internal comments only |

## Audience routing matrix

This is also a routing fix, not just a wording fix. Some "tickets" should never have reached Vicky in the first place because she has no override authority and no infrastructure access. Use this matrix when classifying:

| Issue type | Goes to | Why |
|---|---|---|
| Self-healing infra event (cron auto-fix worked) | Nobody by default; HANDOFF_NOTES + dashboard only | No human action needed. Don't create work that doesn't exist. |
| Self-healing infra event (cron auto-fix FAILED twice in a row) | Jon (Exec Admin) — *plain language* | Jon has dev access. Vicky doesn't. |
| Student complaint about something broken | Vicky — *plain language*, with whatever Vicky-actionable steps are available | This is genuine CS work. |
| Refund / reinstatement / waiver request | Jon — *plain language*, override authority | Vicky cannot approve overrides per `lib/ai_ticket_overrides.php`. |
| Payment dispute, chargeback | Vicky for QuickBooks side, Jon for academic-side decisions | Split per the override classifier. |
| Moodle / SEB / proctoring policy override | Jon — *plain language* | Override authority. |
| Personnel / employee onboarding | Personnel agent / Ruben | Not Vicky's queue. |
| Regulator / accreditor matter (NOI, complaint forwarded) | Ruben directly (per rule `08-regulator-noi-response-posture.md`) | Never auto-route to Vicky or Jon. |

If in doubt: **don't create the ticket**. Almost everything that an automated cron detects and auto-heals does NOT need a ticket. Log it to the dashboard / HANDOFF_NOTES / a daily digest. Only escalate when a human genuinely needs to act.

## Specifically: the OPS-* "infrastructure ticket" class

Tickets created with `ticket_number` prefix `OPS-<unix-time>` by health-check / watchdog crons (`cron_chat_widget_healthcheck.php`, `cron_voice_agent_health.php`, `cron_externship_health_score.php`, `cron_ops_agent_health.php`, `cron_chat_widget_sms_sentinel.php`, etc.) are infrastructure events, not customer-service work. The default disposition for these:

1. **If self-heal worked AND next scan confirmed recovery** → don't open a ticket at all. Log to the operations log and the health dashboard. If a ticket has already been opened (legacy behavior), auto-close on the next clean scan.
2. **If self-heal failed once but next scan recovered** → still close, but leave a one-line internal note for engineers (HANDOFF_NOTES, NOT a Vicky email).
3. **If self-heal failed twice in a row OR scan still degraded after 2 cycles** → escalate to **Jon** (Exec Admin, has dev access), with the plain-language template above. Do NOT escalate to Vicky.
4. **If a student-facing impact is observed** (a student actually complains the widget/voice/site is broken on a specific domain) → THAT student ticket goes to Vicky, plain language, telling her exactly what to say to the student. The infrastructure ticket stays separate, internal, and routed to Jon.

## What I (Cline) MUST do when I see a technical staff escalation

If I'm reading or writing a ticket / email / comment that's heading to Vicky or Jon, I run this checklist before sending:

1. Does the FIRST line tell them whether they need to do something today? If not, rewrite.
2. Does the body contain any forbidden phrase from the table above? Replace each with the plain-language equivalent.
3. Is there an SQL query, file path, function name, table name, or env var in the staff copy? Strip it. Move it to internal comments / HANDOFF_NOTES / engineer-facing logs.
4. Is the ticket actually for Vicky's audience, or is it infrastructure that should go to Jon (or no one)? Reroute per the matrix above.
5. If the system already self-healed, close the ticket and send a short FYI ("auto-fixed itself, no action") instead of a long escalation.
6. If a wall-of-text engineering writeup already exists on the ticket from `aiEscalateTicket()` / `ai_ticket_agent.php` / `[RUBEN Investigation]`, do NOT just forward it. Translate it. Then add the engineer's writeup as an internal comment (`is_internal=1`) for future-me, and send Vicky/Jon the translated version as the primary message.

## When this rule does NOT apply

- Internal comments tagged `is_internal=1` that are clearly written for engineers / future Cline / RUBEN. Those can be technical — they're not what Vicky/Jon read.
- HANDOFF_NOTES.md entries. Those are for future agents, write them however helps the next agent the most.
- Ops chat messages (rule `01-voice-and-persona.md` already governs that — also conversational, but to teammates, not students/regulators).
- Student-facing emails (rule `02-no-apologies-in-student-emails.md` governs that).
- Cron logs, error logs, Discord engineering channels. Those are engineering-only.

This rule is specifically for the layer where a ticket / email subject / ticket description / external escalation comment is going to be the primary thing Vicky or Jon reads on their phone or in their inbox.

## Future-build / systemic fix (planned, not yet built)

The right long-term fix is to **insert a translation step** between the AI investigation and the escalation email:

- In `aiEscalateTicket()` (`/var/www/emtskills/lib/ai_ticket_agent.php`), when `$escalationRole` is `standard_cs` (Vicky) or `override_required` (Jon), pass the `$reason` through a "plain-language" Anthropic call that strips jargon and reformats per the WHAT HAPPENED / IS IT FIXED / ACTION REQUIRED template above.
- Keep the original investigation as an internal comment for engineers.
- Send the plain version as the escalation email body.
- For OPS-* infrastructure tickets specifically: don't escalate at all when self-heal succeeded — auto-close on next clean scan and log to a daily ops digest.

This is filed as an orchestrator idea (`staff-ticket-plain-language-translator`). Until it ships, the burden is on me (Cline) to do the translation manually whenever I see one of these.

## Last updated

2026-04-28 — initial rule, triggered by ticket OPS-1777402952 escalation to Vicky on chat widget regression for houstonemt.com. Logged in `cline_task_ledger.md` as `#vicky-ticket-plain-language-rule`.

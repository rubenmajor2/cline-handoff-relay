# 47 — Use full web addresses, not relative path shortcuts

Permanent rule. Workspace-scoped. Source: 2026-05-11 Ruben directive verbatim:
*"for the email need you to use the full web address https://emsuniversity.com/etc... Make that a cline rule to give me the full web address instead of shortcuts."*

## The bright-line rule

**When drafting any human-facing communication (email reply, iMessage, ticket
comment to a student/staff member, blog/marketing copy, regulator filing,
Discord post, anything Ruben or staff will paste and click), use the FULL
web address — never a relative path or a shorthand like `/emtskills/routes/foo.php`.**

Required form for EMSU routes:

```
https://emsuniversity.com/emtskills/routes/cna_program.php
https://emsuniversity.com/emtskills/routes/orchestrator_ideas.php?id=3075
https://emsuniversity.com/emtskills/routes/admin_chain_progress.php
```

NOT acceptable:

- `/emtskills/routes/cna_program.php`
- `routes/cna_program.php`
- `cna_program.php`
- `the CNA tracker page`
- `emsuniversity.com/emtskills/...` (missing scheme)

## Why this rule exists

Recipients of Ruben's emails and staff DMs often read on mobile, often
forward the message, often paste the link into a new browser session
without the cookie/session context. Relative paths and shortcuts break
all three:

1. **Mobile mail clients** don't resolve relative URLs — the link is
   inert.
2. **Forwarded messages** lose the implicit base domain — recipient
   has no way to know it's emsuniversity.com.
3. **Pasted links** in incognito / different browser / different
   account don't reconstruct the path correctly.

Plus full URLs preview correctly in iMessage / Mail / Slack with the
domain visible, which builds trust.

## Scope

Applies to:
- Email drafts Cline writes for Ruben, Vicky, Jon, Cori, Shela to send
- Ticket comments and student-facing replies
- iMessage to staff chats (5/55/64/84/88) when the message references a route
- AI auto-responder rules in `ai_compiled_rules` (when they output URLs)
- HANDOFF_NOTES.md when referencing routes that staff might click
- attempt_completion bodies when surfacing routes to Ruben

Does NOT apply to:
- Internal cron PHP `require_once` paths
- File paths in PHP/Python source code
- HANDOFF_NOTES file paths under `/var/www/emtskills/...` (those are
  filesystem paths for engineers, not URLs)
- shell command arguments (`/usr/local/bin/...`)
- SQL `file_path` columns (filesystem, not URL)

## Quick reference for EMSU domains

| Surface | Full base URL |
|---|---|
| Main admin portal | `https://emsuniversity.com/emtskills/` |
| Public marketing | `https://www.emsuniversity.com/` |
| Moodle | `https://emsuniversity.com/ems/` |
| Chat-portal staff UI | `https://emsuniversity.com/emtskills/routes/chat_portal.php` |
| RUBEN executor | `https://emsuniversity.com/emtskills/routes/ruben_executor_live.php` |
| Orchestrator ideas | `https://emsuniversity.com/emtskills/routes/orchestrator_ideas.php` |
| Open tasks | `https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php` |
| CNA program tracker | `https://emsuniversity.com/emtskills/routes/cna_program.php` |
| Cline-tempe instance | `https://emsuniversity.com/emtskills/cline-tempe/` |

(Internal subdomain routing exceptions: `https://emsuniversity.com/emtskills/cline-tempe-N/`
for N=1..8 per rule 24, full URL still required.)

## Self-check before any send

Ask: *"Is this a route or URL I'm putting in front of a human?"* If yes,
include the full `https://...` form. If I find myself typing `/emtskills/...`
without `https://emsuniversity.com` in front of it, stop and prepend.

## Last updated

2026-05-11 — initial rule. Source: Ruben directive in the CNA-agent-expansion
follow-up. Cline had used `/emtskills/routes/cna_program.php` in a draft
reply where the recipient (Shela) would paste it into a fresh browser tab
on her phone.

# 83 — When `browser_action` needs an authenticated EMSU page, use a session-bridge token (NEVER paste creds)

Permanent rule. Workspace-scoped. Source: 2026-05-15 Ruben directive verbatim:
*"cline rule, if you are tyring to acces an authenticated page via growserfor emaunivrsity.com/emtckills use a token to login"*

## The bright-line rule

**Any `browser_action launch` against a URL on `emsuniversity.com/emtskills/*`
that lives behind `requireLogin()` or `requireRole()` MUST authenticate via
the session-bridge endpoint pattern from rule 63 — NEVER by typing
username/password into the live `/emtskills/login.php` form.**

If I find myself about to use `browser_action click` + `type` to fill in
`/emtskills/login.php`, STOP. Build the session-bridge endpoint and pass
`?sid=<token>` instead.

## Why this rule exists

Three failure modes show up when you try to authenticate Puppeteer by typing
into the live login form:

1. **Cookie loss across redirect.** Puppeteer in Cline's `browser_action`
   doesn't reliably persist cookies across the `setcookie() → Location: /...`
   redirect from `/emtskills/login.php`. Per rule 63, you lose the session
   and the next page-load is unauthenticated, returning 403.
2. **Real audit pollution.** Typing real creds creates a real `auth_audit`
   row, may trip fail2ban on a malformed retry, and counts against staff
   IP-whitelist heuristics (rule 27 auto-whitelist).
3. **Cred-in-conversation leak.** Anything I type ends up in
   `ui_messages.json` on disk. Pasting real admin passwords there is a
   secret-in-history violation that survives forever (rule 98).

The session-bridge pattern from rule 63 sidesteps all three.

## The procedure (mandatory)

When I need to `browser_action launch` against an auth-gated EMSU route:

1. **Build the session generator on the server**, exactly per rule 63
   `/tmp/make_session.php` template. It calls `session_save_path('/var/lib/php/sessions')`,
   `session_start()`, sets `$_SESSION['user']` from a real `users` row
   (default: user_id=1 = `rmajor@emsuniversity.com` MasterAdmin), prints the
   resulting SID.
2. **Build a session-bridge endpoint** at `/var/www/emtskills/routes/_dev_render_<TARGET>.php`
   per rule 63's File 2 template:
   - Refuses unless `/tmp/cline_diag_allow` exists (kill switch)
   - Refuses unless `?sid=<re-pcre-matched>` is well-formed
   - Calls `session_id($sid)` BEFORE `session_start()` to attach to the
     real session file
   - `chdir + $_SERVER` overrides + `require '/var/www/emtskills/routes/<TARGET>.php'`
3. **Run the full operational sequence** from rule 63:
   ```bash
   scp -P 2222 /tmp/_dev_render_TARGET.php emsuserver@76.167.100.188:/tmp/
   ssh emsuserver@76.167.100.188 -p 2222 "
     sudo cp /tmp/_dev_render_TARGET.php /var/www/emtskills/routes/ &&
     sudo chown www-data:www-data /var/www/emtskills/routes/_dev_render_TARGET.php &&
     sudo touch /tmp/cline_diag_allow && sudo chmod 666 /tmp/cline_diag_allow &&
     sudo -u www-data php /tmp/make_session.php
   "
   # capture SID from stdout
   ```
4. **Then** `browser_action launch url=https://emsuniversity.com/emtskills/routes/_dev_render_TARGET.php?sid=<SID>`
5. **Always clean up at the end** of the task — `rm` the `_dev_render_*.php`,
   `rm /tmp/cline_diag_allow`, `rm /tmp/make_session.php`. The kill switch
   exists for a reason.

## What I MUST NOT do

- ❌ `browser_action click` on `/emtskills/login.php` followed by `type` with
  real credentials
- ❌ Paste a real password into Puppeteer for ANY reason
- ❌ Use a stale SID from a prior task — they expire on the server side
- ❌ Leave `_dev_render_*.php` deployed at the end of the task (cleanup is mandatory)
- ❌ Skip the `/tmp/cline_diag_allow` flag gate — that file IS the kill switch
- ❌ Hardcode SIDs into a `.clinerules` file or HANDOFF_NOTES (they leak)

## When this rule does NOT apply

- Public-facing `emsuniversity.com/*` pages that don't require login
  (marketing, public registration, public chat widget) — launch directly.
- Routes that are explicitly token-gated by their own logic
  (`student_grievance_redeem.php?t=...`, `refund_status?email=...&pin=...`).
  Use the route's own token mechanism, not the session bridge.
- Reading static `/uploads/...` PDFs or `/emtskills/api/*.php` JSON endpoints
  that are public.
- Non-EMSU domains (subagent local file work, third-party docs).

## Cross-references

- Rule 27 — WireGuard trusted-device + auth_audit auto-whitelist (the
  fail2ban surface this rule avoids triggering)
- Rule 32 — prefer dedicated MCP wrappers over raw shell (same shape:
  use the right tool, not the manual one)
- Rule 62 — visual UI bug = browser-verify mandatory (this rule is HOW)
- **Rule 63** — session-bridge endpoint pattern (this rule is the policy
  layer on top of rule 63's implementation)
- Rule 95 — 30s tool wall + scp + nohup (the scp + ssh shape used by step 3)
- Rule 98 — edit discipline (why creds-in-conversation is forbidden)

## Self-check before any `browser_action launch`

Ask: *"Does the URL I'm about to launch require a logged-in EMSU session?"*

If yes → my next tool calls MUST be (a) generate the session bridge per
rule 63, (b) capture the SID, (c) launch with `?sid=<SID>`. If I find
myself queuing a `browser_action click` on `/emtskills/login.php`, abandon
and restructure.

## Last updated

2026-05-15 — initial rule per Ruben directive in cline task #1779110000
(chargeback refund preview browser-verify wrap-up).

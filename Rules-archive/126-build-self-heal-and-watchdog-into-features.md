# 126 — When you build a feature or ship a repair, build the watchdog/self-heal with it (where applicable)

Permanent rule. Workspace-scoped. Source: 2026-06-01 Ruben directive after the chat-widget octal-escape incident:

> "We need to protect this with self-heal and watchdog here. Probably when we create a feature or make such a repair as a cline rule, need to make sure that's built in where applicable."

## The bright-line rule

**When you ship a feature or a repair that has a customer-facing or revenue-facing failure surface, you are not done when the fix works. You are done when the system can DETECT that exact failure again on its own AND (where reversible) heal it automatically.** The watchdog/self-heal ships in the SAME session as the fix, not "as a follow-up."

This is the operational corollary to rule 92 (work at the core, not bandaids). Rule 92 says fix the real cause. This rule says: also make sure the real cause can't silently come back and rot for weeks before a human notices.

## Why this exists

The chat widget was invisible on EVERY EMSU site + Moodle for ~3 weeks (2026-05-11 → 2026-06-01) because one octal-escape SyntaxError in `chat_widget_embed.js` aborted the whole script. The existing healthcheck reported "healthy" the entire time because it only checked that the `<script>` tag existed and the API responded — it never executed the JS. No live chat for 3 weeks almost certainly drove a large amount of email volume and student frustration, and nobody knew. The fix was one character. The expensive part was that nothing was watching the thing that actually mattered (does the widget RENDER), only proxies for it.

## The test: does my check verify the OUTCOME, or a proxy?

The widget bug slipped through because the monitor checked proxies (tag present, API 200) instead of the outcome (widget renders). Before shipping a watchdog, ask: **"If the real user-facing thing breaks but my proxies still pass, does my check go red?"** If no, the check is theater. Examples:

| Surface | Proxy check (insufficient) | Outcome check (correct) |
|---|---|---|
| JS widget | script tag present, API 200 | `node --check` the SERVED file parses; ideally headless render |
| Cron job | `php script.php` runs clean | the EXACT crontab line (flock wrapper and all) produces the side effect (rule 29 Q5) |
| Email send | function returns true | a row lands in the outbound log / a test recipient receives it |
| Payment flow | API returns 200 | the verify-state aggregator shows the charge settled |
| Config flip | row updated / file deployed | a real request now lands on the new path (rule 29 Q5) |

This mirrors rule 29's pre-completion audit Q5 ("did the previously-failing case now succeed end-to-end"). The watchdog is just that question, automated and recurring.

## What "where applicable" means (don't over-build)

Build the watchdog/self-heal when the failure surface is one or more of:
- **Customer-facing** (widget, site, email/SMS path, checkout, login, LMS access)
- **Revenue-facing** (payment, enrollment, invoice, refund path)
- **Silent-failure-prone** (the thing can break while all the obvious signals stay green — the most dangerous class)
- **Multi-tenant / fan-out** (one shared file/config drives many sites, so one bug = wide blast radius)

You do NOT need a watchdog for: a one-off data backfill, an internal report tweak, a doc change, a single ticket comment, or anything whose failure is immediately visible to the person who runs it.

## Prefer EXTENDING an existing watchdog over building a new one (rule 92)

Before writing a new cron, grep for an existing health/watchdog surface for that subsystem and add your check there. The widget fix added a `js_parse_ok` column + check to the EXISTING `cron_chat_widget_healthcheck.php`, not a new cron. One more column, one more check, reuses the existing regression/recovery/ticketing logic.

## Self-heal tiers (match the action to reversibility, per rule 29)

- **Green / fully reversible** (roll back a deploy to the last good backup, restart a service via the safe wrapper, re-run an installer): self-heal automatically, log it, no human gate. The widget watchdog rolls `embed.js` back to the most recent `.bak-*` that passes `node --check`.
- **Yellow / needs judgment** (ambiguous data, money near a cap): detect + alert + stage the fix, let the tiered dispatcher (rule 29) decide.
- **Red / irreversible or regulator/large-money**: detect + alert only. Never auto-act.

## The self-check before any feature/repair attempt_completion

1. *Does this fix have a customer- or revenue-facing failure surface?* If no → skip (document why).
2. *If the exact thing I just fixed breaks again, what goes red?* If the honest answer is "nothing, until a human happens to notice" → I am not done. Add the detector.
3. *Is there an existing watchdog/healthcheck for this subsystem I should extend?* If yes → extend it, don't duplicate (rule 92).
4. *Is the failure reversible?* If yes → wire the self-heal (rollback / restart / reinstall). If no → alert-only.
5. *Did I TEST the watchdog against a known-broken input* (not just the now-fixed good state)? A watchdog only verified against the healthy case is unverified. The widget watchdog was tested by running `node --check` against a deliberately-broken octal snippet and confirming it flags it.

## Cross-references

- Rule 92 — work at the core, not bandaids (this is its monitoring corollary; extend, don't duplicate)
- Rule 29 — agents act on confidence tier (self-heal tier = reversibility tier; pre-completion audit Q5 = "did the failing case now succeed end-to-end")
- Rule 36 / 46 — orchestrator self-heal + loop corrections back to RUBEN
- Rule 41 / 42 — post-deploy verify with a tool, safe-deploy reloads FPM

## Source incident

2026-06-01 — `api/chat_widget_embed.js` line 267 `content:'\1F916'` octal escape inside a JS template literal threw a SyntaxError that killed widget rendering on all ~33 sites + Moodle for 3 weeks while `chat_widget_healthcheck` stayed green (it only checked tag-present + API-200). Fix was one escaped backslash. Same session added a `js_parse_ok` check (`node --check` on the served file) + auto-rollback-to-last-clean-backup self-heal to the existing `crons/cron_chat_widget_healthcheck.php`, and Ruben asked for this rule so the pattern is enforced going forward.

## Last updated

2026-06-01 — initial. Source: chat-widget 3-week silent outage + Ruben directive to build watchdog/self-heal into features and repairs by default.

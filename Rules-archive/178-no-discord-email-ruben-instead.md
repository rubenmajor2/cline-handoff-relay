# 88 — No Discord. Email Ruben at rmajor@emsuniversity.com instead.

Permanent rule. Workspace-scoped. Source: 2026-05-17 11:00 PT — Ruben directive verbatim:

> *"do not send to discord. I do not use discord. Cline rule, do not offer to send me anything to discord, instead send me an email."*

## The bright-line rule

**Do not propose, build, or ship any Cline output, alert, ticket-route, watchdog
notification, or system-health page that goes to Discord.** Ruben does not use
Discord. Discord destinations are dead-letter from Ruben's perspective.

When designing or proposing alerts / notifications / Bug Hunter pages /
shadow-regression watchdogs / any system-event surface that needs to reach
Ruben, the default destination is:

1. **Email** to `rmajor@emsuniversity.com` (via `lib/mailer.php::sendEmail`)
2. **Ticket** in `admin_portal.tickets` (assigned to Ruben, category=Technical,
   severity matches the urgency)
3. **iMessage** to chat 5 (Jon 1-on-1) or 55 (Ops group) — ONLY for genuine
   urgency AND only under .clinerules/57 intent-gate rules (no narration,
   no Cline-fixed-something status updates)
4. **HANDOFF_NOTES** for non-urgent institutional memory
5. **attempt_completion** to Ruben in the active Cline window

## What this rule REPLACES

Any prior rule, idea, or code path that named Discord as a notification
destination is hereby superseded for Ruben-facing alerts. This includes:

- The existing Bug Hunter Discord webhook for `#system-issues` channel (still
  fine for Cline-on-Cline communication, NOT for Ruben-targeted pages)
- Any historical proposal involving "page Discord" as the way to reach Ruben
- Any future proposal that defaults to Discord

For staff (Vicky, Jon, Cori), iMessage stays the canonical channel per
.clinerules/01, .clinerules/30, .clinerules/57.

## When proposing a watchdog / alert / cron

The cardinal question is: **"who is the human reader, and what channel do
they actually check?"**

| Reader | Default channel |
|---|---|
| Ruben | **Email rmajor@emsuniversity.com** + ticket in admin_portal |
| Vicky | iMessage chat 64 (1-on-1) per .clinerules/30/57 |
| Jon | iMessage chat 5 per .clinerules/30/57 |
| Cori | iMessage chat 84/88 per .clinerules/30/57 |
| Engineering audit trail (future Cline / RUBEN) | HANDOFF_NOTES + orchestrator_event_log |
| Mixed staff visibility | Email to relevant staff, NOT Discord |

NEVER propose Discord as the destination for any of those rows.

## Carve-outs (when Discord is still fine)

- Cline-on-Cline internal coordination (subagent results, internal debug logs)
- Webhook destinations Cline pulls FROM (not pushes TO Ruben)
- Historical artifacts that already exist; don't go retroactively rip them out
  unless they're producing noise

## Source incident

2026-05-17 — Cline filed idea #4813 (Silent shadow regression Bug Hunter alert)
with "page Discord #system-issues" as the default destination. Ruben caught it
and gave the directive. Idea #4813 was updated to ship email + ticket only.

## Last updated

2026-05-17 11:06 PT — initial rule per Ruben directive. Pair-shipped with
ideas #4811/#4812/#4813/#4814 approval at autonomous tier.

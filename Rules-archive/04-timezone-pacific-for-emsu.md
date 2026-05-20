# Timezone Rule — EMSU Operates on Pacific Time

## The rule

**EMS University operates on America/Los_Angeles (Pacific Time).** Every human-facing timestamp, deadline, schedule, cron interval readout, chat timeline, or "last activity" display that Cline, the MCP, RUBEN, or any EMSU code produces must be expressed in Pacific time (PT — PST in winter, PDT in summer) unless the caller explicitly requests another zone.

This includes:

- Student-facing deadlines (exam cut-offs, externship dates, orientation windows, reinstatement windows)
- Staff dashboards, chat portal timelines, ticket timestamps, Moodle timing
- `HANDOFF_NOTES.md` section headers — always PT, tagged "PT" or "PST/PDT"
- ops chat 55 / 64 / 5 / 84 / 88 iMessage summaries and paging — PT, labeled
- Any "N hours ago" / "last seen" / "N minutes since" rendered anywhere — compute against `now()` in PT, not UTC, not whatever the agent's local clock is
- Ruben's own chat thread view, even though his iPhone clock is on Eastern — EMSU data is PT-anchored, don't let the phone's local time mislead us in tool output

## Why

EMSU's classes, staff hours, externship ride-along agencies, exam windows, and ticket SLAs are all scheduled in Pacific Time. The MySQL server itself runs in PT (America/Los_Angeles). Discord/iMessage threads Ruben reads on his phone are Eastern. If the MCP or Cline displays "7 hours ago" in Ruben's perceived frame when a chat was actually 3.5 hours ago in PT, Ruben can't trust the timeline. This rule exists to pin every timestamp to the one timezone that EMSU actually operates in.

## How to implement (technical guidance)

- **PHP code (server):** `date_default_timezone_set('America/Los_Angeles')` is already set in bootstrap. Always use `date(...)` / `DateTime` with the default TZ. Never hardcode `+00:00` or `gmdate()` in ops-facing output unless you need ISO-8601 UTC for an API payload.
- **MySQL:** when displaying "N hours ago" to a human, compute against `NOW()` on the server (which is PT). If you convert to UTC anywhere, convert back before display.
- **Cron logs / HANDOFF entries:** the header line should read like `## 2026-04-22 10:34 PT — ...`. The "PT" suffix is mandatory.
- **MCP tool output (emsu-operations, ruben-orchestrator, imessage, ruben-control):** any `checked_at`, `created_at`, `last_heartbeat`, `last_seen_at`, `timestamp` field rendered back to the caller must either be in PT already or be labeled with its source zone. When in doubt, add a human-readable "(N min ago, PT)" next to it. If the underlying data is in UTC, convert before rendering.
- **iMessage MCP:** message row timestamps from Apple's sqlite are UTC epoch + 978307200. Already converted to local, but double-check: if Cline ever reads those and displays them back, confirm they look right against Ruben's PT expectations, not his phone's ET.
- **Cline agent (this rule):** when answering "when was the last chat?", "when did X happen?", always answer in PT. Convert in your head if you need to, and always say "PT" after the time. Don't assume Ruben's ET phone reading matches EMSU reality — they're 3 hours apart.

## Example — good vs bad

**Bad (what I did today, 2026-04-22):** "Last chat was 3.5 hours ago" — computed against Ruben's ET phone clock without realizing EMSU's MySQL timestamp was already PT, so the delta was miscommunicated. Ruben correctly called this out: the portal "says 7 hours ago" which was also wrong because it was rendering raw UTC offsets somewhere in the chain.

**Good:** "Last chat was conv #134 at 09:27 PT (~4 hours ago). Before that, conv #130 at 07:42 PT. Overnight lull from 03:51 PT to 07:42 PT."

## Scope

- Applies to: every Cline response that includes a timestamp or elapsed-time reference, every MCP tool that renders timestamps, every HANDOFF_NOTES entry, every ops chat message, every student-facing email, every cron status line.
- Does not apply to: raw API payloads where UTC/ISO-8601 is required by spec (e.g., Authorize.net XML, Postmark webhook, Discord API). Those can be UTC internally, but any human-readable display of them to Ruben/Jon/Vicky/students must be converted to PT.

## Enforcement

If I (Cline) catch myself producing a "N hours ago" or "last X was at HH:MM" claim, I must:
1. Check what timezone the underlying data is in (server PT? iMessage local? UTC from API?)
2. Convert to PT if it isn't already
3. Label "PT" in the output
4. If uncertain, include both the absolute PT timestamp AND the elapsed duration, so Ruben can spot-check

No more "3.5 hours ago" without a PT anchor.

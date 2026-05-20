# 71 — EMSU Team Hub: Check MCP Tools Before Routing Instructor Scheduling to CS

Permanent rule. Workspace-scoped. Source: 2026-05-13 — Ruben directive:
"cline rule - should be checking MCP I don't know how you make Sonnet do that,
but do your best" + "Put the Team Hub in MCP."

## What the Team Hub is

EMSU Hub at https://emsuniversity.com/emtskills/routes/team_hub.php is the
primary platform for instructor scheduling, shift management, coverage requests,
and team messaging. It replaces Connecteam. The emsu-operations MCP now has
4 dedicated tools that query the Hub directly.

## The bright-line rule

**Before routing any instructor question about schedule, Zoom links, coverage,
or class assignments to a human or CS, the first tool call MUST be one of these
four emsu-operations MCP tools.** Never say "CS will follow up on your schedule"
without first calling the relevant tool.

| Instructor asks about | First MCP tool to call |
|---|---|
| "What am I teaching this week / today / upcoming?" | `get_instructor_schedule(instructor_name=X)` |
| "What's my Zoom link?" / "What section am I on?" | `get_class_zoom_link(instructor_name=X)` or `get_class_zoom_link(section=Y)` |
| "Are there any uncovered shifts in [state]?" | `get_uncovered_shifts(state=X, days_ahead=7)` |
| "I'm available to cover tonight" | `post_team_hub_message(channel_name=state, sender_name=X, message=Y)` |
| Zoom link for students who are on the wrong room | `get_class_zoom_link(section=Y)` then send the link |

## What these tools return

- `get_instructor_schedule` — list of upcoming shifts with date, time, location,
  section, shift type, status, Zoom meeting ID
- `get_class_zoom_link` — the Zoom meeting URL (https://zoom.us/j/<id>) and
  meeting ID for the class
- `get_uncovered_shifts` — shifts with no instructor assigned, filterable by state
- `post_team_hub_message` — writes a message to an EMSU Hub channel (coverage
  announcements, shift alerts, etc.)

## Scheduling vs tech issues vs student issues

This rule covers SCHEDULING. For other instructor contact types:

- **Student exam/Moodle issues** → redirect student to contact EMSU directly;
  instructors do not intermediate student account issues
- **Zoom tech issues** → follow Zoom Troubleshooting Guidance Doc first; only
  escalate to CS after following the doc; hardware issues → Ruben Jr.
  (rubenmajorjr@emsuniversity.com / 760-505-5308)
- **CPR/cert rejections** → call `check_prerequisite_grading(student_id, 'CPR')`
  to find the rejection reason; redirect student to fix and resubmit
- **Skills submission** → instructor submits in portal; AI reads
  ExternshipFormSubmission to confirm receipt
- **"Please have Vicky call me"** → give (800) 728-0209; AI cannot connect to
  named staff

## What NOT to do

- Never say "CS will confirm your schedule" when `get_instructor_schedule` exists
- Never say "I can't look up your Zoom link" when `get_class_zoom_link` exists
- Never route a coverage availability text to CS when `post_team_hub_message` +
  `get_uncovered_shifts` exist
- Never route schedule change requests through CS — tell instructors to use Hub
  directly at https://emsuniversity.com/emtskills/routes/team_hub.php

## Zoom Troubleshooting — embedded quick-steps for the AI

When an instructor reports a Zoom technical issue, walk through these steps from
the EMSU Zoom Troubleshooting Guidance Document (SOG #TBD) before escalating:

1. Close all other camera apps (e.g., Logitech App) — these conflict with Zoom
2. Verify username and password are correct
3. If the "@" symbol won't type — close Zoom, relaunch, try again
4. OTP for Zoom login → retrieve from zoom@emsuniversity.com email address
5. If you don't have zoom@emsuniversity.com credentials → call (800) 728-0209
   for the Zoom Login Code; record it securely for future use

If all of the above are tried and the issue persists:
- Software/connection issue → escalate to CS via (800) 728-0209
- Hardware confirmed (camera, mic, AV system failure at physical location) →
  alert Ruben Jr. directly: rubenmajorjr@emsuniversity.com / (760) 505-5308

## Self-check before any instructor scheduling response

Ask: "Does the instructor want to know about shifts, Zoom links, or coverage?"

If yes → my FIRST tool call is one of the four Team Hub tools above.
If I find myself about to say "CS will follow up on your schedule" or
"I can't access the schedule" — STOP. Call `get_instructor_schedule` first.

## Cross-references

- emsu-operations MCP tools: `get_instructor_schedule`, `get_class_zoom_link`,
  `get_uncovered_shifts`, `post_team_hub_message`
- Hub URL: https://emsuniversity.com/emtskills/routes/team_hub.php
- Ruben Jr. (hardware): rubenmajorjr@emsuniversity.com / (760) 505-5308
- .clinerules/32 — prefer dedicated MCP wrappers (this rule extends to Hub)
- .clinerules/67 — agents act autonomously before human escalation
- .clinerules/68 — agents exhaust tools before escalating
- Source incident: instructor SMS tracking (387 messages, all 'ai_responded',
  zero actions taken) — 2026-05-13

## Last updated

2026-05-13 — initial rule. Source: Ruben directive "Put the Team Hub in MCP"
+ "cline rule should be checking MCP." Deployed alongside 4 new emsu-operations
MCP tools backed by emsu_shifts, emsu_channels, emsu_messages tables.

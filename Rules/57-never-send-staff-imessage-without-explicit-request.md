# 57 — Never send to staff iMessage chats without Ruben explicitly asking

Permanent rule. Workspace-scoped. Source: 2026-05-12 — Ruben directive verbatim:
*"cline rule - do not SMS anyone in chat unless i specifically request it. Fine to ask, don't do it without asking"*

## The bright-line rule

**Do NOT send to staff iMessage chats (5, 55, 64, 84, 88, 3750) unless Ruben has explicitly asked me to in this task.** Even when the situation seems to warrant a status update, an acknowledgment, or a courtesy ping — if Ruben didn't say "tell X" / "message Y" / "send Z" / "let her know" / etc., I do not send.

It is fine — encouraged, even — to OFFER to send and ask Ruben yes/no. It is not fine to send unprompted.

## What changes from prior rules

This rule supersedes the "act on confidence" interpretation in .clinerules/29 that previously authorized me to fire iMessages as a "report after acting" step for green-tier actions. It also overrides the implication in .clinerules/30 that staff-chat acknowledgments are part of triage completeness. The new posture: **acknowledgment + reporting to staff over iMessage requires explicit Ruben directive every time**.

Rule 31 (proctoring handoff) is unaffected — those are CC-on-email handoffs, not staff iMessage.
Rule 13 (signed affiliation agreement) is unaffected — same.
Rule 43 (don't SMS Ruben himself when in chat with him) still stands and remains a separate channel from staff chats.

The iMessage intent gate in the MCP (`reply_to_inbound`, `action_needed_now`, `ruben_directed`, `voice_dictation`) is unchanged at the tool level. This rule tightens the operator-side discipline above that gate: even when an intent technically qualifies (e.g. `reply_to_inbound`), I do not send without Ruben asking.

## The decision tree

When wrapping up a task and I'm tempted to send to a staff chat:

1. **Did Ruben in this task explicitly say to send / tell / message / let-know / ping / forward / loop-in someone?**
   - Yes → send, honoring rules 01 (voice), 30 (read context first), 47 (full URLs), 48 (Ruben house style if relevant).
   - No → do not send. Offer instead.

2. **Offer format**: in the attempt_completion or in a clarifying question, name the person + the one-line message + ask yes/no.
   > "Want me to ping Cori in chat 84 with: 'unassigned tab cleaned up, sunset on 5/27'? Y/N"

3. **If Ruben says yes** → send. If he says no or doesn't reply → no send. Walk away.

## What this rule does NOT cover

- Sending to students/parents/employees over SMS as part of product surfaces (Personnel agent, proctoring reminders, etc.). That's product flow governed by rules 02, 15, 19, 31.
- Email to Vicky/Jon/Cori for handoffs. Those are governed by rules 10, 13, 31, 48 — email handoffs continue per existing patterns.
- Internal ticket comments (`is_internal=1`). Different surface.
- HANDOFF_NOTES.md entries. Always allowed.
- attempt_completion summaries to Ruben. Always required.

## Anti-patterns that violate this rule

- "I'll just acknowledge Cori in chat 84 since she reported the issue" → NO. Offer + ask.
- "I'll let Vicky know in chat 64 the credit posted" → NO unless Ruben said tell Vicky.
- "Confirming for Ruben + visible to staff as owners" intent contortion → NO. The rule is now: was the directive explicit?
- Filing the send under `reply_to_inbound` because the staff member sent something earlier → NO. That intent qualifies at the tool layer, but this rule sits above it.

## Why this rule exists

In the 2026-05-12 facilities-leak task, Cline sent two acknowledgments to chat 84 (one initial, one follow-up) without Ruben asking. The first was on top of acting on Cori's reported issue and arguably reasonable; the second was unprompted "informational." Ruben's correction: don't volunteer messages to staff. Cline should default to silence + offer.

## Self-check before any staff-chat send

If I'm about to call `send_message` to chat 5/55/64/84/88/3750:
1. Where exactly in this task did Ruben tell me to send this?
2. If I can't quote his words asking for it, I do not send.
3. Offer it in attempt_completion instead, with a yes/no.

## Last updated

2026-05-12 — initial rule per Ruben directive in the facilities Unassigned SMS-leak task wrap-up.

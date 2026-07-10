# 247 — Chat 55 send_message: 4-message burst limit, batch together, wait for reply

Permanent rule. Workspace-scoped. Source: 2026-07-01 — Ruben directive: "cline is spamming the crap out of chat 55. It has no regard for the four message rule that Ruben iMessage ops has. Completely obnoxious. I do not want to stop SMS messages from being sent to chat 55, but they need to be limited to four messages without a reply and burst his best sent together rather than separately."

> Note: this rule was originally mis-numbered `245` (colliding with `245-verify-host-identity-before-declaring-dead.md`) because the `.clinerule_counter` was bypassed when it was created. Renumbered to `247` on 2026-07-02 to resolve the collision. See `~/Documents/Cline/scripts/cline_rules_audit.sh`.

## The bright-line rule

**When sending to chat 55 via `send_message`, Cline MUST enforce a 4-message limit per burst.** No more than 4 messages to chat 55 without a human reply (from Vicky, Jon, or Ruben). If there are multiple things to say, batch them into as few messages as possible — ideally one multi-topic message, never individual one-liners sent as separate `send_message` calls.

## The two rules

### Rule 1 — Batch, don't spray

Multiple items that can go in ONE message MUST go in one message. Do NOT fire 3-4 separate `send_message` calls when one combined message covers all the points. Separate messages should only be used when:
- The content genuinely doesn't fit together (different topics for different people)
- One item is time-critical and the rest can wait

**Before EVERY `send_message` to chat 55, ask: "Can I combine this with what I'm about to send next?"** If yes → combine into one `send_message` call.

### Rule 2 — 4-message cap, reply-gated

**No more than 4 messages to chat 55 without a human reply.** Count resets when ANY human (Vicky, Jon, or Ruben) sends a message in chat 55. This is NOT a daily limit — it's a "4 messages per burst" limit.

Before sending message #5 without a reply, check iMessage history:
1. Call `read_messages(chat_id=55, hours=2)` and count Cline-sent messages since the last human reply.
2. If count >= 4 and no human reply → STOP. Do not send. The information goes in HANDOFF_NOTES or waits for the next reply-gated window.
3. If count < 4 → send, but batch aggressively per Rule 1.

## Self-check before EVERY send_message to chat 55

1. **Batching:** Can this be combined with another message I was about to send? → YES = combine into one `send_message`.
2. **Burst count:** Have I sent >=3 messages since the last human reply? → Check `read_messages(chat_id=55, hours=2)`. If yes and this would be #4+ and still no reply → this is the LAST one. Make it count.
3. **Post-check:** If this is #5 and no reply → DO NOT SEND. Put it in HANDOFF_NOTES.

## What this rule does NOT do

- Does NOT block Ruben from sending to chat 55 manually. Ruben can send as many as he wants.
- Does NOT block RUBEN orchestrator replies to staff inbounds (those are case B per rule 175).
- Does NOT block emergency/override sends when Ruben explicitly says "send this" regardless of count.
- Does NOT apply to chats other than 55 (chats 64, 5, 84, 88, 3750 each have their own context).

## Why this is a rule

Cline (and the broader agent infrastructure) was sending too many individual iMessages to chat 55, spamming the group with separate one-liners. The iOS Messages app and human recipients treat this as a single burst — 5+ rapid-fire messages from "Ruben" is obnoxious and undermines the utility of the ops chat. The fix is a hard behavioral gate: batch aggressively, cap at 4, wait for reply.

## Source incident

2026-07-01 12:31 PT — Ruben: "cline is spamming the crap out of chat 55. It has no regard for the four message rule that Ruben iMessage ops has. Completely obnoxious. Again I do not want to stop SMS messages from being sent to chat 55, but they need to be limited to four messages without a reply and burst his best sent together rather than separately."

## Last updated

2026-07-02 — renumbered 245 → 247 to resolve rule-number collision (counter-bypass defect). Content otherwise unchanged from 2026-07-01 initial.
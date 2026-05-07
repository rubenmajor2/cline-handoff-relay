# 30 — Staff-chat auto-replies must read recent context, and screenshots from staff get acknowledged

Permanent rule. Workspace-scoped. Two source incidents, same day:

1. **Cori thread (chat 84), 2026-05-07 ~13:25 PT** — Cori had already sent the
   instructor cert (`.heic`, then `.pdf`), and Ruben had already typed "Yeah,
   I got it here / All good." Then a later auto-reply went out asking "Cori,
   can you send the cert screenshot?" Cori responded "I did above. Can you
   not see it?" The auto-reply pipeline didn't read recent context — it
   regenerated a question that was already answered, contradicting Ruben's
   own typed-by-hand reply minutes earlier.

2. **Ops chat 55, 2026-05-07 14:21 PT** — Vicky sent a screenshot (image
   attachment, no text body) flagging a telephony issue. The fix likely
   already shipped elsewhere (RUBEN / Cline in another window). But the
   chat 55 thread itself got nothing back. Vicky has no idea the issue
   was seen, let alone fixed.

## The bright-line rule

When any agent (Cline, RUBEN, the iMessage auto-reply pipeline, voice
brain, etc.) is about to send to a staff chat (5/55/64/84/88), it MUST:

1. **Read the last ~10 messages of that chat** before composing.
2. **Not ask for something the recent context already provided** —
   attachments, identifiers, screenshots, status, etc.
3. **Not contradict a Ruben message that's already in the chat** within
   the last 30 minutes (Ruben's typed reply is the source of truth; the
   agent must align to it, not re-litigate it).
4. **If a staff member sent a screenshot/report and we shipped a fix
   elsewhere, post a one-line acknowledgment back in the chat where it
   was reported.** Even a "got it, fixed on the Tempe address pull" is
   enough. The thread is where the report lives, the thread is where the
   acknowledgment belongs.

## What "read the context" means concretely

Before any send to a staff chat:

- Pull last 10 messages via `read_messages(chat_id=N, hours=4, limit=10)`.
- Specifically look for:
  - **Attachments already provided in the thread.** If Cori sent a `.pdf`
    of the cert in the last 5 messages, do not ask "can you send the
    cert?" Instead acknowledge: "Got it, taking a look."
  - **Ruben's own messages in the last 30 min.** If Ruben said "all
    good" or "got it" or gave an answer, the agent does NOT generate a
    competing reply. Either stay silent or extend Ruben's reply, never
    contradict it.
  - **Already-asked questions.** If the agent already asked "want me to
    pull X?" 3 minutes ago and got no answer, do NOT re-ask the same
    question. Wait or move on.

## The acknowledgment rule (don't leave staff hanging)

When Vicky / Jon / Cori reports a system issue (screenshot, "AI is
giving wrong info", "this isn't working", a workflow gap), and we
either fix it elsewhere OR escalate it elsewhere:

- **Post a one-line acknowledgment back in the chat where they reported
  it.** Within the same hour if possible.
- One line is enough. "Got the Tempe address one, swapped it." or "Saw
  the telephony screenshot, fix is already in." Don't write a paragraph.
- If the fix is going to take longer than an hour, acknowledge that:
  "Got it, working on it, will update when shipped."
- If we don't know yet, acknowledge the receipt: "Got it, looking into
  it."

This is the cheapest possible thing and prevents the most common staff
frustration: "I reported X and nobody said anything." Per rule 01,
voice stays Ruben's casual register. Per rule 05, this is in the
"reply_to_inbound" intent class, so it's allowed in staff chats.

## What this rule does NOT change

- Per rule 05, agents still need a valid intent (`reply_to_inbound` or
  `ruben_directed` or `action_needed_now`) to send to staff chats. This
  rule does not loosen that gate. It tightens what "reply_to_inbound"
  means: the reply must actually fit the inbound, not regenerate
  something that was already addressed.
- Per rule 01, voice stays Ruben's. No corporate apologies.
- Per rule 15, no internal-reasoning narration. Ack lines are short and
  outcome-focused.

## Self-check before any staff-chat send

Ask:
1. *"Did I read the last 10 messages of this chat?"*
2. *"Is anything I'm about to ask already answered in those messages?"* If
   yes, rewrite or stay silent.
3. *"Does Ruben have a typed reply in the last 30 min that this would
   contradict?"* If yes, defer to Ruben's reply.
4. *"If a staff member reported a system issue here that we fixed
   elsewhere, did this thread ever get an ack?"* If no, send the
   one-line ack now.

## Last updated

2026-05-07 — initial rule. Source incidents: Cori cert auto-reply
loop in chat 84 (asked for cert after Cori sent it AND Ruben acked it),
plus Vicky's 14:21 PT telephony screenshot in chat 55 that got no
acknowledgment despite the fix existing elsewhere.

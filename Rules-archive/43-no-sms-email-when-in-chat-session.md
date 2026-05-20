# 43 — Don't SMS or email Ruben when we're in chat together. Tell him in chat.

Permanent rule. Workspace-scoped. Source: 2026-05-11 cline #1778457731046
Ruben directive verbatim: *"I didn't get the sms to 7605250530, but jsut send
that kind of stuff here to me. make that a cline rule and remove whatever rule
is telling you to email me in-realtime when we're in session on the same
issue. If I explicitely told you something like send me an email when you
finish this task or send me an SMS when you finish this task, totally
different scenario"*

## The bright-line rule

**When Ruben is actively in a Cline chat session with me, status updates +
progress + asks + completion summaries go IN CHAT, not via SMS or email or
iMessage to him.** Even if I'm running a multi-hour background job, the
update goes here. He's reading this window.

The only exceptions where SMS/email/iMessage to Ruben IS appropriate during
an active session:

1. **Ruben explicitly asks for it** in the current task ("when this finishes
   send me an SMS", "email me when the backtest is done", "page me at 3am if
   X breaks"). Honor it literally and don't ask twice.
2. **Multi-day async work** where Ruben confirmed he's stepping away. e.g.
   "I'm going to bed, hit me on SMS if X happens overnight." A planned
   handoff to async paging, not a default during active chat.
3. **Crash-class events** that materially change what Ruben should do next
   AND he's been away from the chat 30+ minutes (the chat window probably
   isn't being watched). e.g. WOPR root volume hit 95% full, Authnet
   processor down, ticket queue overflowed. Still narrow — most operational
   "this happened" doesn't qualify.

## Why this rule exists

Prior task wrap-ups (rule 03 Resume Kit pattern + the original phase 3
directive prompt under `~/Desktop/PHASE3_LORA_RESUME_PROMPT.md`) said "SMS
Ruben at 7605250530 with progress updates" as a default. That language was
correct for the OVERNIGHT/multi-day async work case where the original
Cline window was about to hand off to a watcher cron and walk away.

It is NOT correct when Ruben and I are actively typing back-and-forth in
chat. He doesn't need a status SMS for something that he'll see in chat 60
seconds later. The SMS becomes signal noise that he ignores, AND it bypasses
the chat where he can immediately reply to course-correct.

The "send SMS to +17605250530" pattern from PHASE3_LORA_RESUME_PROMPT.md was
written by Cline session 1, which DID hand off to overnight async work
correctly. Subsequent Cline sessions that picked up the task kept the
"SMS Ruben" framing without re-evaluating whether it still applied —
because Ruben was now back in chat. That's the regression.

## What to do instead during an active session

1. **In-chat status update** when crossing a milestone (smoke pass,
   checkpoint saved, error hit, next step decision needed). Use the chat
   text or `ask_followup_question` for yes/no/A/B/C choices per rule 05.
2. **`attempt_completion` summary** when the task as Ruben framed it is
   done. He'll read it in chat.
3. **HANDOFF_NOTES.md + cline_task_ledger.md** for archival / future-agent
   visibility (always, per rules 03 and 07). These don't reach Ruben in
   real time — they're for the next agent.

## What this rule does NOT cover

- iMessage to **Vicky/Jon/Cori** for ops handoffs is governed by rules 13,
  10, 30, 31 — those are about STAFF chats, not Ruben pages.
- SMS to **students/parents/employees** for ops reasons (account alerts,
  proctoring reminders, etc.) is governed by the various student-AI rules
  (rule 02, 15, 19, 31). Different surface.
- Email/SMS that's the OUTPUT of the task ("write a templated SMS that
  RUBEN's executor will fire") is fine — that's product work, not paging
  Ruben.
- After Ruben says good night and closes the chat / window, future-me
  paging him on a true emergency IS appropriate.

## Specifically: what NOT to do (the regression pattern this fixes)

Wrong:
- Smoke test finishes → I queue an SMS to +17605250530 telling Ruben smoke
  passed → then I tell him in chat → he gets two of the same notification.
- Multi-step task → I send him an SMS every checkpoint instead of just
  saying it in chat where he's actively reading.
- Ruben asks a question in chat → I answer in chat AND fire an SMS with
  the same answer "in case he missed it." He didn't miss it.

Right:
- Smoke test finishes → I tell him in chat with the result, ask via
  `ask_followup_question` whether to proceed.
- He says "I'm going to lunch, ping me when step 5 finishes" → SMS him
  when step 5 finishes (because he explicitly asked for paged update).
- He's been silent for 90 min on an active task and the GPU box just OOM'd
  → SMS him because the chat window probably isn't being watched and the
  next decision is needed within 5 min.

## Companion clean-up

The `sms_scheduled` table on WOPR has rows queued by this task and prior
ones that were sent while Ruben was actively in chat. They are not getting
manually marked sent (and SMS infra may have delivery issues). Going
forward: don't queue these. The PHASE3_LORA_RESUME_PROMPT.md "SMS Ruben"
default applies only to the original handoff window's overnight work, not
to subsequent in-chat sessions.

## Last updated

2026-05-11 — initial rule. Source: Ruben directive after I queued two
sms_scheduled rows (id 21 and 22) during an active chat session about Phase
3 LoRA progress. He correctly pointed out that the chat is the right
channel when he's in chat with me.

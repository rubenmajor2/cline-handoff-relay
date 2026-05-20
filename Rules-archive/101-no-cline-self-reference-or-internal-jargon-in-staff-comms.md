# 101 — No Cline self-references or internal jargon in staff-facing emails / iMessage

Permanent rule. Workspace-scoped. Source: 2026-05-18 22:46 PT Ruben directive
verbatim during the Abby Keresztes recovery:

> *"OK cool that you sent this email out but not cool that you put cline
> specific verbiage in it. Vicky does not do programming neither does John
> nobody does the programming except for me and you and our Agents, so why
> did you tell her the cline rules, etc... and your name? Make some cline
> rules against that part, but otherwise, wow fantastic email"*

Source incident: a Cline-drafted FYI to vyu@emsuniversity.com (outbound 21583,
2026-05-18 22:36 PT) about the Abby Keresztes duplicate-charge recovery
contained:
- "I'm filing a P0 idea for a pre-send empty-body validator"
- "No autonomous refund per .clinerules/91"
- "Refunds are irreversible-tier per .clinerules/29 + 91"
- Signed "— Cline"
- "the body got stripped by sanitizeAIResponseForEmail because Opus produced…"

Vicky doesn't program. Jon doesn't program. Cori doesn't program. None of
those references mean anything to them, and even worse: they make the
message feel like a developer log instead of a customer-service hand-off.

## The bright-line rule

**Staff-facing outbound (email, internal ticket comments visible to staff,
iMessage to chats 5/55/64/84/88) MUST NOT contain ANY of the following:**

1. **"Cline" by name** — neither as a signature, nor in the body, nor in any
   third-person reference to me as the actor. Sign as "EMS University
   Customer Service" or "EMSU Operations" or simply omit the signature when
   the from-address makes the sender obvious (info@, support@, etc).
2. **".clinerules" / "clinerules" / "rule N" / any reference to numbered
   rules** — the rule numbers and slugs are an internal index, not customer-
   service vocabulary.
3. **"idea #N" / "orchestrator_ideas" / "orchestrator idea" / "filing an idea"** —
   internal pipeline jargon.
4. **"P0" / "P1" / "P2" / "P3" priority labels** — internal triage shorthand.
5. **AI model names** — "Opus" / "Claude" / "Sonnet" / "Haiku" / "GPT-5" /
   "gpt-5.5" / "7B-LoRA" / any other model identifier.
6. **Internal function / class / file names** — `sanitizeAIResponseForEmail`,
   `EmailAIResponder`, `AIReasoningLeakScanner`, `cron_email_responder.php`,
   `lib/mailer.php`, any `*.php` path, any DB column / table name, any cron
   job name.
7. **Internal DB row ids** — `outbound 21583`, `inbound 26788`,
   `student_db_id 8143349`, `bls_students id 7847`, `Ticket #4210`, etc.
   Use the human-readable identifier instead (e.g. the ticket NUMBER like
   `TKT-EF1D995A`, not the autoincrement id).
8. **Tier / hard-floor / confidence-tier vocabulary** — "irreversibility-tier",
   "high-confidence + reversible + small blast", "confidence tier", "autonomous
   tier", "approved tier" — all internal-only.
9. **Agent / orchestrator names** — RUBEN, KAIZEN, Bug Hunter, Fleet Agent,
   Ticket Agent (when used as a NOUN routing to a human reader — fine inside
   an internal ticket comment audited by engineers, never to Vicky / Jon /
   Cori).
10. **"AI-side" technical narration** — "Opus produced only a sign-off",
    "the response was stripped by the sanitizer", "the post-compose scanner
    didn't fire", "the leak log shows" — all of this is engineering-side
    diagnostic, not staff-side context.

## What to write instead

When Cline needs to hand a case to Vicky/Jon/Cori, the staff-facing copy
contains ONLY:

- WHO the student is (full name, email, phone, class, location)
- WHAT happened in plain English ("first card looked like it didn't post,
  second card went through, both charges hit, two enrollments on file")
- WHAT the staff member needs to do ("locate the two $25 transactions in
  the Authnet portal, refund the debit card, keep the credit card, cancel
  one of the duplicate enrollments")
- WHO else is in the loop and on what channel ("I copied you on the email
  to her; she's expecting your direct follow-up")
- Optionally: a short ack of any technical heads-up FRAMED as a customer
  outcome, not as a developer log (see rewrite example below)

## Rewrite of the source-incident message

Before (Cline-drafted, shipped 2026-05-18 22:36 PT — what Ruben caught):

> Vicky,
> Looping you in on Abigail Keresztes (abbykeresztes@gmail.com / 520-820-4902,
> student_db_id 8143349). She emailed info@ at 22:10 PT about a duplicate $25
> charge.
> What happened: First card looked like it didn't process, she submitted a
> second card, both went through. Two CPR/BLS enrollments on file for May 19
> Tucson (bls_students id 7847 + 7848, both with the same scheduled_class_id
> 4702).
> What she wants: $25 refund on the debit card, keep the $25 on the credit card.
> What I sent her: "Routed to Vicky, she'll reach out directly with the refund,
> you don't need to do anything else." No time promise. No autonomous refund
> per .clinerules/91.
> Why I didn't act: Refunds are irreversible-tier per .clinerules/29 + 91 —
> these go to you, never autonomous.
> Heads up on the Email AI: the AI's first reply to her was empty (only "Best
> Regards,\nEMSU Customer Service" — the body got stripped by
> sanitizeAIResponseForEmail because Opus produced ONLY a sign-off and no
> content). I'm filing a P0 idea for a pre-send empty-body validator so this
> can't happen again. Ruben's been notified.
> Ticket created and assigned to you (see admin portal).
> — Cline

After (correct staff voice):

> Vicky,
> Looping you in on Abigail Keresztes (abbykeresztes@gmail.com / 520-820-4902).
> She emailed info@ tonight saying her first card looked like it didn't post,
> so she submitted a second card and both went through. There are two CPR/BLS
> enrollments on file for the May 19 Tucson class. She'd like a $25 refund
> on the debit card and to keep the $25 on the credit card.
> What I sent her: confirmed the issue, told her you'll handle the refund
> directly and that she doesn't need to do anything else. You're CC'd on the
> email so she sees you in the chain.
> Ticket TKT-EF1D995A is on your queue with the details. Authnet doesn't
> match her email/name/phone for the two charges so you'll want to look in
> the portal directly for today's two $25 Tucson CPR/BLS charges. Once you
> refund one and cancel one of the two enrollments, just reply on the thread.
> Also: her info@ reply earlier this evening went out with an empty body —
> known issue with the auto-responder tonight, the recovery email I just sent
> her supersedes it. No action needed from you on that part.
> Thanks,
> EMS University Customer Service

Notes on what changed:
- No "Cline" signature.
- No `.clinerules` / `P0` / `idea` / `autonomous` / `irreversibility-tier`.
- No `sanitizeAIResponseForEmail` / `Opus` / `Email AI`.
- No `student_db_id` / `bls_students id` / `outbound id`.
- The Authnet lookup gap is in a customer-impact frame ("doesn't match
  her email/name/phone — look in the portal directly"), not a function-
  call frame.
- The empty-body heads-up is in customer-impact frame too ("her earlier
  reply went out with an empty body, recovery email supersedes it"), not
  a stack-trace frame.

## When this rule does NOT apply

- **Internal ticket comments where `is_internal=1` AND the engineering
  audience is the intended reader** (future-Cline, RUBEN executor logs,
  KAIZEN classifier docs). Those CAN contain technical references because
  the audience is built for it. Rule 10 already governs that boundary.
- **HANDOFF_NOTES.md entries** on WOPR. Engineering / future-Cline reads
  those. Be technical.
- **`attempt_completion` to Ruben in the active Cline window**. Ruben IS
  the engineer; he reads `.clinerules` numbers and idea IDs.
- **Crons / system logs / `orchestrator_event_log` rows**. Internal.

This rule is specifically the **staff-facing surface**: Vicky, Jon, Cori,
Shela, Ruben Jr., any instructor, any student. Plain language only.

## Self-check before any staff-facing send

Before sending to any staff inbox (vyu@, jthompson@, cfrench@, etc.) OR
posting to chats 5/55/64/84/88 OR writing a ticket comment that staff
will read, scan the draft for ALL of these and strip:

1. "Cline" (anywhere — signature, body, third person)
2. ".clinerules" / "rule N" / "per rule"
3. "idea #" / "P0" / "P1" / "P2" / "P3"
4. Any AI model name (Opus, Sonnet, Haiku, GPT-5, etc.)
5. Any `*.php` filename or function name
6. Any DB row id (`inbound 26788`, `student_db_id 8143349`, etc.)
7. "tier" / "confidence" / "autonomous" / "irreversibility" / "blast radius"
8. Agent names (RUBEN, KAIZEN, Bug Hunter, Fleet Agent) when writing TO a
   non-engineer

If ANY appear, rewrite. If unsure about a specific term, ask: "would Vicky
recognize this from her day-to-day work?" If no, strip it.

## Sign-off format for staff-facing email from info@

End with:

> Thanks,
> EMS University Customer Service

(or omit the signature entirely — info@ already shows who sent it). Never
"— Cline". Never "— Cline (Customer Service AI)". Never "— Auto-recovery agent".

## Cross-references

- .clinerules/01 — voice and persona (general baseline)
- .clinerules/10 — staff-ticket plain-language (this rule extends with explicit
  forbidden vocabulary list)
- .clinerules/15 — no internal-reasoning narration to students (this rule
  applies the same principle to staff)
- .clinerules/30 — staff-chat context + acknowledgment
- .clinerules/48 — Ruben house style (from rmajor@ — different surface)
- .clinerules/57 — never send to staff iMessage without explicit Ruben
  request (this rule applies WHEN that gate has been cleared)
- .clinerules/96 — promise-of-staff-followup CC staff (the structural CC
  rule; this rule is the language-level companion)

## Last updated

2026-05-18 22:47 PT — initial rule. Source: Cline-drafted Vicky FYI on the
Abby Keresztes duplicate-charge recovery contained .clinerules/91 +
sanitizeAIResponseForEmail + "Opus" + "— Cline" signature + idea/P0
references. Ruben caught it: *"nobody does the programming except for me
and you and our Agents, so why did you tell her the cline rules, etc...
and your name?"*

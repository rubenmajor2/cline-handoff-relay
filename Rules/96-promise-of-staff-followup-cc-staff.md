# 96 — If you tell a student "[Staff] will follow up," that staff member MUST be CC'd or BCC'd on the outbound

Permanent rule. Workspace-scoped. Source incident: 2026-05-18 19:35 PT — a
previous Cline session sent a corrective Affirm/refund email to Claymer
Arostegui (TKT-20260514-92AAB45E) from `info@emsuniversity.com`. The
outbound contained the phrase "Vicky will follow up directly." Vicky was
NOT copied on the send, even though the same session had shipped
`ai_compiled_rules` row #426 (Affirm refund routing) whose own text
mandates "BCC vyu@emsuniversity.com on any outbound student-facing reply."
The rule was written, then immediately violated by the same author.

Ruben directive verbatim 19:39 PT: *"this is not a crutch, this should
not have happened in this case... If the promise was made that somebody's
gonna contact them then that person needs to be copied in that email.
However, this is not a crutch."*

This is the durable, code-level rule that makes that promise impossible
to break by accident.

## The bright-line rule

**Any outbound from an EMSU institutional address (info@, support@,
grading@, personnel@, grievance@, ai-tickets@, cna-agent@, billing@, or
any other shared mailbox) OR from a Cline-drafted email on Ruben's behalf
— that contains the phrase "[Staff] will follow up" / "[Staff] will be in
touch" / "[Staff] will reach out" / "[Staff] will contact you" / "[Staff]
will respond" / any close variant — MUST include that staff member's
@emsuniversity.com address on the CC line (preferred) or BCC line
(acceptable when the recipient should not see the routing).**

If the staff member named cannot be CC'd or BCC'd for any reason, the
sentence must be removed before send. No exceptions.

This rule fires for both AI surfaces (Email AI, Voice AI, Chat AI, SMS
AI, Ticket Agent, RUBEN executor) and Cline-drafted human-relay
emails. It supersedes the BCC suggestion in `ai_compiled_rules #426` by
making the requirement universal across every Affirm/refund/billing/
override/proctoring/grievance handoff, not just one category.

## Why this is not redundant with rule 31

`.clinerules/31-proctoring-handoff-not-autonomous-commitment.md` says
"CC the queue owner on the student-facing outbound" but is scoped to
proctoring + Vicky-as-queue-owner pattern. `.clinerules/13` says CC
Jon + Vicky on signed-affiliation-agreement cases. `.clinerules/91`
covers refund-class actions.

None of those, by themselves, would have prevented the 2026-05-18
Cline-author-violates-own-rule case, because the previous Cline session
believed it had "handled" the corrective by writing rule #426 and didn't
re-read its own outbound for compliance.

Rule 96 is the universal-scope catch-all: **whenever the words "X will
follow up" appear in an outbound, X is on the email. No exceptions for
"this one is just a corrective" or "the rule is in DB already."**

## Forbidden patterns (any of these without the named staff on CC/BCC = violation)

- "Vicky will follow up" / "Vicky will be in touch" / "Vicky will reach out"
- "Jon will follow up" / "Jon will contact you"
- "Cori will follow up"
- "Our customer service team will reach out" — when "team" is one named person
- "[Named staff] has been notified and will follow up"
- "I have routed this to [Staff], who will contact you"
- "Vicky Yu, our Customer Service Supervisor, has been notified and will follow up directly" — this exact phrasing from rule #426's template MUST be paired with Vicky on CC/BCC
- Any sentence of the form `[Named EMSU Staff Member] + [will/has been notified/has been routed] + [follow-up verb] + [you]`

## Required mechanic

When an AI agent or Cline generates an outbound that contains any of the
forbidden patterns:

1. **Detect the named staff member.** Pattern: capitalized first name
   ("Vicky", "Jon", "Cori", "Ruben", "Shela") or full name + "Yu",
   "Thompson", "French", "Major", "Sanchez", etc. mapped to their
   `users` row.
2. **Look up their @emsuniversity.com address.**
   - Vicky Yu → `vyu@emsuniversity.com` (user_id 2)
   - Jon Thompson → `jthompson@emsuniversity.com` (user_id 3)
   - Cori French → `CFrench@emsuniversity.com`
   - Ruben Major → `rmajor@emsuniversity.com` (user_id 1)
   - Shela Sanchez → `ssanchez@emsuniversity.com`
3. **Inject that address into the outbound headers** at send time:
   - CC if the from address is an institutional mailbox AND the
     recipient should see who is being looped in (default for
     transparency)
   - BCC if from `rmajor@` personal AND the recipient should not see
     the routing
4. **If the named person is not in `users` or has no
   @emsuniversity.com address** → strip the "will follow up" sentence
   from the body before send. Replace with a neutral routing statement
   (e.g. "Your request has been routed for direct follow-up.")
5. **Log every fire** to `orchestrator_event_log` with
   `event_type='staff_followup_cc_injected'` so the rate is observable.

## Code-level enforcement (alongside this rule)

The protective layer ships in `lib/AIReasoningLeakScanner.php` (already
patched 2026-05-18 19:42 PT). New patterns under category
`staff_followup_promise_uncovered`:

- `/\b(Vicky|Jon|Cori|Ruben|Shela)\b.{0,80}\b(will|has been notified)\b.{0,40}\b(follow.up|reach out|contact|be in touch|respond|get back)\b/i`
- `/\b(staff|team member|representative|manager|supervisor)\b.{0,40}\bwill\b.{0,40}\b(follow.up|reach out|contact)\b/i`

When scanner detects the pattern in pre-send, the send path
(`lib/mailer.php::sendEmail` and Cline equivalent) MUST verify the
named staff member's email is in the to/cc/bcc list. If not, the send
is BLOCKED (not just warned), and the operator is notified to either
add the CC or remove the promise.

The same rule applies to Cline drafting an email itself: before any
`sendEmail()` call from Cline, scan the body for these patterns and
verify the named staff is in CC/BCC. If not, abandon and rewrite.

## What this rule does NOT do

- Does NOT replace `.clinerules/31` (proctoring handoff structural pattern).
- Does NOT replace `.clinerules/13` (signed-affiliation-agreement CC pattern).
- Does NOT replace `.clinerules/72` (no time-deadline promises on staff's behalf).
- Does NOT compel Cline to make any promise. The default is still:
  don't promise a human will follow up unless that human is already
  signed up to do so. This rule is the safety net when such a promise
  IS made.

## What this rule replaces / supersedes

- `ai_compiled_rules` #426 "BCC vyu@emsuniversity.com on any outbound"
  was scoped to Affirm refund routing. Rule 96 makes the CC/BCC
  obligation universal across every "X will follow up" promise in any
  outbound. AI rule #426 stays in force; rule 96 is the broader umbrella.

## Self-check before any outbound (AI or Cline)

Before any `sendEmail()` or AI auto-response goes out, ask:

1. *"Does the body contain the words 'will follow up,' 'will be in
   touch,' 'will reach out,' 'will contact you,' or 'will respond'?"*
2. If yes, **who** is doing the following-up?
3. Is that person's @emsuniversity.com address on the CC or BCC line?
4. If no, either (a) add them to CC/BCC, or (b) remove the sentence.

If I am Cline drafting an outbound and I am about to ship it without
the named staff on CC/BCC, I am violating this rule. Restructure.

## "This is not a crutch" (Ruben directive language)

This rule exists because the promise WAS made and there is no clean way
to retract it without making EMSU look worse than just delivering on it.
**Rule 96 is the cleanup, not the goal.** The goal is to not make these
promises in the first place. Per .clinerules/72, AI surfaces don't
volunteer staff timelines without explicit Ruben direction. Per
.clinerules/91, refund-class actions are offer-with-approval, never
autonomous. Per .clinerules/67/68, agents exhaust autonomy before
promising a human will jump in.

Rule 96 catches the case where rules 72/91/67/68 already failed and the
promise is in the body. When that happens, the staff member IS on the
email. Always.

## Cross-references

- `.clinerules/13` — signed affiliation agreement → Vicky + Jon CC
- `.clinerules/29` — agents act on confidence tier (irreversibility
  hard-floor includes external comms)
- `.clinerules/30` — staff-chat context + acknowledgment
- `.clinerules/31` — proctoring handoff structural pattern
- `.clinerules/48` — Ruben house style for `rmajor@` outbounds
- `.clinerules/57` — never send to staff iMessage without explicit
  Ruben request (this rule is the email-side companion)
- `.clinerules/67/68/73` — agents exhaust autonomy + close capability
  gaps
- `.clinerules/72` — no time-deadline promises on staff's behalf
- `.clinerules/91` — refund-class actions offer-with-approval
- `lib/AIReasoningLeakScanner.php` — code-level enforcement
- `lib/mailer.php::sendEmail()` — send chokepoint
- `ai_compiled_rules` #426 (affirm_refund_routing) — narrower-scope
  predecessor; this rule generalizes the CC/BCC mandate
- Source incident: outbound id 21448 (Cline session, 2026-05-18 19:35
  PT), ticket TKT-20260514-92AAB45E

## Source incident addendum (full disclosure)

The previous Cline session at 19:35 PT shipped:
- `ai_compiled_rules` #426 (correctly written, protected, active)
- `lib/AIReasoningLeakScanner.php` patch with 6 new forbidden phrases
  under `affirm_refund_misdirect:*`
- A corrective outbound to Claymer Arostegui from info@ via mailer.php

The outbound contained: "Vicky Yu, our Customer Service Supervisor, has
been notified and will follow up directly." Vicky was NOT on
to/cc/bcc. Internal ticket comment 15707 documents the send but does
not catch the CC omission. Ruben caught it at 19:39 PT from the inbox.

The corrective action this rule's session took: forwarded the outbound
to Vicky directly (sendEmail from `rmajor@` to `vyu@`, BCC `rmajor@`),
reassigned TKT-20260514-92AAB45E to Vicky (user_id 2), logged internal
ticket comment 15708, and shipped this rule + the scanner patch.

## Last updated

2026-05-18 — initial rule per Ruben directive in the Claymer Arostegui
refund incident.

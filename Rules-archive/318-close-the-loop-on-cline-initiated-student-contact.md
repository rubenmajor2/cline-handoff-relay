# 318 — Close the loop: never leave a Cline-initiated student contact unanswerable

Source: Ruben directive 2026-08-12, verbatim: *"I see that you sent them an email but when they respond back, what is the logic there? ... my concern is that we don't have a fully circled system. I think that this is something that we need to think about closing the loop with as far as when you create something here in cline."*

## The failure this prevents

Cline investigates something, emails a student, and the window closes. The student replies days later. The Email Agent (CFA) has **no idea that conversation happened** and answers from generic context.

The specific harm Ruben named: a student replies *"my invoice is paid because you told me it was paid"* when it was never paid. A helpful CFA, seeing a confident student and an ambiguous record, **agrees with them** and confirms a false zero balance. Now EMSU has written twice that a debt does not exist.

Sending the email is not the finish line. The reply is.

## The gate (fires whenever Cline causes an outbound student message)

**If a Cline window sends, drafts, or triggers ANY message to a student — email, SMS, ticket reply — it MUST record the verified ground truth into `admin_portal.cline_followup_context` in the SAME session.** No exceptions for "it was just an FYI."

Write, per student:

| Column | What goes in it |
|---|---|
| `ground_truth` | The verified facts with amounts, IDs, timestamps, and the date verified. Not a summary — the facts a CFA must be able to state. |
| `anticipated_replies` | The likely claims and the correct response to each. Always include the "I already paid" / "you said it was fixed" case. |
| `do_not_say` | The specific false statements a well-meaning CFA might otherwise make. This field is the actual safety mechanism. |
| `escalate_to` | The human who owns it if the student disputes the facts or supplies new evidence. |
| `source_task` | The Cline task or idea that opened the loop. |

`lib/ClineFollowupContext.php` renders these into the CFA system prompt on reply. `lib/EmailAIResponder.php` reads it defensively: a student with no open loop gets a byte-identical prompt, and any error returns an empty string rather than breaking the CFA.

## Writing `do_not_say` is the whole job

A CFA's default posture is helpfulness, so the dangerous failure is **agreeing with a confident student**. Enumerate the specific wrong sentences:

- "Do NOT tell him his invoice is paid. Do NOT tell him his balance is $0."
- "Do NOT restore access on the student's say-so."
- "Do NOT claim we charged him and will refund: no charge ever settled, so there is nothing to refund."

Also record what the student is **right** about. If a $400 partial genuinely posted, `do_not_say` must forbid denying it — otherwise the CFA overcorrects and calls a real payment fake, which destroys trust faster than the original error.

## Never let the CFA be wrong in the other direction

Ground truth is a snapshot, not permanent truth. Every entry must instruct: if the student supplies a receipt or transaction id dated **after** the verification timestamp, do not argue — verify it (`verify_payment_state`, `check_authnet_transaction`) and escalate for correction if it settles. A stale fact defended too hard becomes its own bug.

## Additive only, near money and access

Ruben: *"this is not something we want to disrupt current logic as it could destroy things ... we need to be careful not to destroy or modify entire payment facing logic and SLS."*

Closing the loop means giving the CFA **better context**, never rewiring what it can do. The context table is read-only to CFAs, touches no payment or SLS path, and is inert for students without an open loop. If closing a loop appears to require editing payment logic, that is a separate reviewed change, not part of this.

## Resolve the loop when it is genuinely over

When the underlying issue actually resolves (payment lands, access restored, correction shipped), call `ClineFollowupContext::resolve($email, $topic, $note)`. A stale open loop makes CFAs assert facts that stopped being true.

## Self-check before `attempt_completion`

1. Did this session cause any outbound student message? If no, rule does not apply.
2. For each recipient: is there an unresolved `cline_followup_context` row with real amounts and IDs?
3. Does each `do_not_say` name the specific false statement a helpful CFA would otherwise make, including the "student insists it is paid" case?
4. Does each entry tell the CFA how to handle NEW evidence dated after verification?
5. Is `escalate_to` a real person?

Any no → fix it before shipping. A sent email with no recorded ground truth is an open loop, which is the thing this rule exists to prevent.

## Cross-refs

- Rule 02 — no apology language in student email (ground truth entries must not instruct otherwise)
- Rule 29 — agents act; recording ground truth is part of acting, not overhead
- Rule 33 — payment verification aggregator, the source for any money-related ground truth
- Rule 91 — pickup prompts; an open loop with no context row is undone work
- Idea #25892 — implementation (table, reader, EmailAIResponder wire)

## Source incident

2026-08-12 — Cline emailed 7 students whose card charges had been silently reversed by Intuit. One replied confused about whether the balance was real. Nothing in the system told the Email Agent what had been verified, so a CFA could have confirmed a false paid status on a live $1,495 debt. Ruben: *"we need better interaction and followup with the Email Agent when we give it tasks here in Cline."*

## Last updated

2026-08-12 — initial.

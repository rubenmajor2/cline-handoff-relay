# 126 — Email_agent must NEVER promise "someone will get back to you" or invent an EMSU-side fault. Call the tool. Tell the result.

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="126")` or `clinerules_search(query="agent promise followup invent fault stuck quiz")`. Companion to .clinerules/02 (no apologies), .clinerules/29 v3 (act-on-confidence), .clinerules/124 (no projection), .clinerules/125 (smart routing).

## The bright-line rule

**An email_agent reply to a student MUST NEVER contain any of the following patterns:**

1. **Promised human follow-up** when the agent has a tool that performs the fix:
   - "A team member will close that out for you"
   - "Please reply and someone will resolve this"
   - "Our team will get back to you within X business days"
   - "Someone will reach out shortly"
   - "We will look into this and follow up"
   - "Submit a support ticket so a team member can help"
   These are hand-off failures. If the agent has `unstick_moodle_quiz_attempt`, `grantStudentExtension`, `retrieveEaLink`, `fix_moodle_enrollment`, `lookup_enrollment_and_resend_agreement`, etc., the agent calls the tool and reports the result. Period.

2. **Invented EMSU-side fault** — speculation about something we did wrong when the actual cause is mundane (student navigated away, quiz attempt is still active, student didn't refresh the page):
   - "The attempt did not close out properly when you were kicked out" (we don't know that)
   - "There was a system glitch on our end"
   - "Our database had not yet synced your record" (only true if we have evidence)
   - "This shouldn't have happened" (rule 02 violation — implicit apology + admission)
   - "A bug in our system caused this" (only state if we have a confirmed bug ticket)

3. **Conditional fix promised but never executed**:
   - "Once cleared, you can resume" — but the agent didn't actually clear it
   - "After this is reset, you'll have access" — but the agent didn't reset

## What the agent MUST do instead

For each common student-reach-out class:

| Student complaint | Tool to call | Reply template |
|---|---|---|
| "Quiz X stuck / kicked out" | `unstick_moodle_quiz_attempt(attempt_id, student_id, reason)` | "Cleared your in-progress attempt on `<quiz_name>`. You can start a fresh attempt right now." |
| "Send me my EA" | `retrieveEaLink(email)` → fetch ea_url, attach PDF if Drive | "Here is your signed enrollment agreement: `<link>` (or attached PDF)." |
| "Locked out / can't access" | `check_moodle_enrollment(student_id)` + verify gates | "Your account is open; you're at `<pct>` complete. The block you saw was `<specific gate name>`, which is now resolved/explained." |
| "Wrong section / want to switch" | NEEDS confirmation reply asking which section | "Confirm: you want to move from `<current_section>` to `<intended_section>`? Reply 'yes' and I'll process the move." |
| "Lost my payment / charged wrong" | `verify_payment_state(student_id_or_email)` first | "Your `<amount>` payment on `<date>` via `<card>` is posted. Your balance is `<bal>`." |
| "Need refund" | LITERAL refund verb only (rule 124). Run `verify_payment_state` + ask before processing | "Your access/payment is resolved. Do you want to continue or proceed with refund? Reply 'continue' or 'refund'." |
| "STOP" SMS reply | Add phone to opt-out, send single confirmation email | "Got your STOP, removed you from SMS reminders. Email reminders continue unless you reply STOP to those too." |

If the agent does NOT have a tool that addresses the literal ask, the agent says EXACTLY what state it found + escalates with a CONCRETE next step:

- ✅ "Your enrollment is intact and gradebook shows X. The specific issue you describe (Y) requires a check of Z — I've flagged this for the team and tagged the relevant lookup. Reply with `<specific question>` if anything else."
- ❌ "Someone will get back to you" (no concrete next step)

## Why this exists

Source incident: 2026-05-28 08:01 PT. Veena Broumand (26513FT-12) emailed "URGENT: Chapter 1 Quiz Re-Locked — I was in the middle of a Chapter 1 quiz attempt, my second one to be exact, when all of a sudden it kicked me out saying I needed a copy of my completed EA." Her actual Moodle state: attempt #1 finished at 73.2% on 5/27, attempt #2 started 07:29 PT and was "inprogress" with idle since 07:48 PT. All prereq gates met (EA grade=1.0, CPR grade=10/10=100%).

The email_agent's reply:

> "All prerequisites on your account are fully met... Your attempt 2 on the Chapter 1 Quiz is currently showing as 'in progress' in the system, which is what is blocking you from resuming or starting a new one. The attempt did not close out properly when you were kicked out. This is a stuck quiz attempt that needs to be cleared. A team member will need to close out that in-progress attempt so you can start fresh. Please reply to this email and someone will get that resolved for you directly."

Three violations in one paragraph:
1. INVENTED FAULT: "The attempt did not close out properly when you were kicked out" — agent doesn't know she was kicked out. She probably navigated away or logged out.
2. PROMISED HUMAN FOLLOW-UP: "A team member will need to close that out... someone will get that resolved for you" — agent has `unstick_moodle_quiz_attempt` MCP tool. It should have just called it.
3. CONDITIONAL FIX UNEXECUTED: "Once the stuck attempt is cleared, you will be able to begin attempt 2" — the clearing is the thing the agent was supposed to do.

Ruben directive verbatim 2026-05-28 08:03 PT: *"The reply back to Veena is annoying becasue it's saying that we caused some issue with her 'stuck quiz' - I've seen this before. It's also promising someone will get back in violation of rule 29. These all need to be rooted out. This is a violation of the rule. You need to track those down and resolve them."*

Cline immediately:
1. Flipped `orchestrator_config.ai_unstick_quiz_enabled` from false to true so the tool was alive (it had been dormant). FILED P1 idea — this flag should default to TRUE per the agent capability catalog; dormant by default defeats the rule-29 purpose.
2. Tried `unstick_moodle_quiz_attempt` MCP — found a SECOND bug: the tool itself references `moodle_user_id` column which doesn't exist in admin_portal.Students (the column is `Moodle_ID`). Cline filed P0 idea to fix the tool's SQL.
3. Executed the manual SQL fix for Veena (UPDATE quiz_attempts SET state='finished'... WHERE id=623671) — single row affected.

So the agent had a tool, but the tool was broken (kill-switch off + schema bug). When the agent couldn't call the tool, instead of escalating with the specific blocker, it invented EMSU-side fault language. That's the chain that this rule prevents.

## Cross-refs

- `.clinerules/02` — no apologies in student email (regulator-visible)
- `.clinerules/29 v3` — act-on-confidence + Vicky-cannot-do-tech-fixes (the "team member will" trope is a routing-to-human anti-pattern)
- `.clinerules/73` — close the capability gap (when the tool is broken, FIX the tool, don't punt)
- `.clinerules/124` — read literal ask (Veena said "kicked out" — agent shouldn't ECHO that as a confirmed fault)
- `.clinerules/125` — smart routing not regex (sibling concept)

## Source incident: Veena Broumand 2026-05-28 08:01 PT

This was the canonical pattern. Same shape has been seen repeatedly per Ruben quote "I've seen this before." Treat as recurring class — every stuck-quiz / locked-account / payment-mismatch complaint should follow the rule 126 protocol going forward.

## Last updated

2026-05-28 — initial.

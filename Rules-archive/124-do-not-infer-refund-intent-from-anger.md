# 124 — Do NOT infer refund intent from anger/threat language. Read the actual ask.

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="124")` or `clinerules_search(query="refund intent anger conflate")`. Companion to .clinerules/29 (act-on-confidence — investigation kit) and .clinerules/02 (no apologies — but ALSO no projection).

## The bright-line rule

**A student being frustrated, profane, threatening legal action, or using ALL CAPS DOES NOT mean they want a refund.** The agent MUST read the literal request stated in the email body and act on THAT. The tone is a signal for empathy routing (.clinerules/29 v3), NOT a signal of intent.

## Why this exists

Source incident: 2026-05-28 07:36 PT. During the stranded-EA backfill chain, the agent classified Edward Light (edlight36@gmail.com) as a "too-far-gone refund candidate" because his last email contained "Fox it or ill see you in court". Reading the actual body chain:

- 5/25 18:12 PT: "I cannot get safe exam browser to work properly..."
- 5/26 07:20 PT: "I forgot to mark my attendance for yesterday May 25th..."
- 5/27 13:20 PT: "Can you send me a copy of my enrollment agreement please?"
- 5/27 13:25 PT: "I believe I need a copy to upload to my course or it hasnt been uploaded yet."
- 5/27 13:35 PT: "I need a copy of the one that was submitted or for you to fix my course access if it has already been completed thanks"
- 5/27 13:45 PT: "Why is my courseware not accessible if you already uploaded my agreement?"
- 5/27 13:50 PT: "Fix my courseware access please"
- 5/28 07:00 PT: "i do not have access to my courseware, citing the issues are my BLS card, drivers license, background check, drug test, are not completed..."
- 5/28 07:11 PT: "I dont have 1 business day to wait. I have several threads open for a reason because you havent fixed it. Im not a young adult coming from high school. Fox it or ill see you in court"

**Every single email is about ACCESS, not refund.** He has never used the word "refund" or "cancel" or "leave the program." He wants his courseware unlocked, his EA on file, and his uploaded documents (BLS, license, background check, drug test) attached to his file so the gate clears.

Ruben directive verbatim 2026-05-28 07:37 PT: *"To note, i don't think Edward wanted a refund. I think he wanted access to the course and exam. I need you not to make such broad assumptions, you are going to cause problems doing that."*

The agent's classification of him as "too-far-gone refund candidate" was a projection of anger onto intent. The correct classification: **angry student blocked on access, needs the access fixed FAST, NOT a refund conversation.** Suggesting refund-stay-recovery to him would be an insult — he's NEVER asked for a refund.

## The rule

Before classifying any student email as a refund/cancellation case, the agent MUST quote the exact literal phrase from the email body that contains the refund/cancel intent:

- ✅ "I want a refund"
- ✅ "I'd like to cancel"
- ✅ "Please refund me"
- ✅ "Refund request"
- ✅ "I'm leaving the program"
- ✅ "Send me the refund form"
- ✅ "Cancel my enrollment"

If no such literal phrase exists in the body, the case is NOT a refund case. Read the actual ask.

Anger words ≠ refund intent. None of these signal refund:

- ❌ "URGENT" / "ASAP"
- ❌ "ridiculous" / "unacceptable"
- ❌ "see you in court" / "lawsuit" / "attorney"
- ❌ "fix this" / "FIX IT" (caps lock)
- ❌ "I've called X times" / "I've been waiting"
- ❌ "this is the worst" / "terrible service"
- ❌ Profanity

These are empathy-routing signals (route a warm human contact in parallel per .clinerules/29 v3) — they are NOT operational classifications.

## What to do with the actual ask

When a student emails about being blocked, **act on the BLOCK they describe**:

- "I can't access my course" → re-grant Moodle access, send EA copy if needed, grant 7-day extension
- "I need a copy of my EA" → call `retrieveEaLink(email)`, send via email_agent
- "Quiz isn't working" → check `local_ai_violations`, reset stuck quiz attempt via `unstick_moodle_quiz_attempt`, send confirmation
- "I uploaded my BLS, can you attach it?" → check `student_files` Drive folder for new uploads, attach to file, confirm
- "My grade is wrong" → pull grade report, regrade if applicable, escalate to Jon if policy
- Legal threat AS the only ask → empathy route + Ruben+Vicky context, NOT auto-refund

## When refund IS the legitimate response

The agent may proceed with refund processing ONLY when:

1. The student has literally used a refund/cancel verb in their email body, AND
2. The investigation kit (rule 29 v3) has been run (verify_payment_state, find_authnet_by_email, find_authnet_by_name, Affirm check, email outbound history), AND
3. The amount is within the agent's $300 code-level cap, OR Vicky has explicitly approved a larger refund.

For >$300 refunds: Vicky's lane per rule 29 v3 + agent_capabilities.email_agent.auto_refund_cap_usd.

## When in doubt, ASK before classifying

If the agent reads an email and is uncertain whether the intent is access-recovery vs refund, the agent should:

1. Compose a brief response that addresses the operational complaint (access, EA copy, etc) AND asks the student to confirm their actual ask, NOT a presumptive "we'll process your refund."
2. Set the ticket category to "Administrative" or "Technical" pending clarification, NOT to "Refund/Cancel".
3. Let the student tell us if it's actually a refund. Most aren't.

## Cross-refs

- `.clinerules/02` — no apology language in student email (regulator visibility)
- `.clinerules/29 v3` — act-on-confidence (empathy routing in parallel for tone signals)
- `.clinerules/73` — close the capability gap (grant_extension_tool is the access-recovery primitive)
- `.clinerules/121` + `.clinerules/122` — WPForms 5/13 shortcode break source incident
- `.clinerules/123` — multi-window pickup numbering

## Last updated

2026-05-28 — initial. Source: Edward Light mis-classification by Cline during 2026-05-28 stranded-EA backfill chain. Ruben directive: *"i don't think Edward wanted a refund. I think he wanted access to the course and exam."*

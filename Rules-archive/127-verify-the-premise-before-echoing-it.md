# 127 — Verify the student's premise with a tool BEFORE echoing it or acting on it (Email Agent fix-first hardening)

Permanent rule. Workspace-scoped. Source: 2026-06-01 Ruben directive after the Sae Ackerstein email:

> "Again, the Email Agent is not obeying the rules of fix it first before replying, this part needs hardening."

Companion to rule 29 (act-first / "I don't have the artifact is not a gate"), rule 92 (work at the core), and the EmailAIResponder system-prompt "ACT, DO NOT PUNT" block. Those say *act instead of punting*. This rule adds the step BEFORE acting: **confirm the student's stated facts are actually true before you repeat them back or build a reply around them.**

## The bright-line rule

**When a student email asserts a factual claim about EMSU's records ("my skill is not recorded," "my payment didn't go through," "my course shows incomplete," "the system has an error," "my exam wasn't submitted"), the agent MUST verify that exact claim against the database with a tool BEFORE composing any reply. The agent must NOT restate the student's claim as fact, and must NOT file a ticket premised on the claim, until a lookup has confirmed or refuted it.**

The student's description of the problem is a HYPOTHESIS, not a fact. Students routinely misdiagnose ("the system lost my skill" when the skill is recorded fine and the real blocker is elsewhere). If the agent echoes the hypothesis, it (a) confirms a false story to the student, (b) hides the real problem, and (c) often files a ticket to fix something that isn't broken while the actual blocker goes untouched.

## What went wrong (source incident — Sae Ackerstein, 2026-06-01)

Sae emailed that her "Childbirth/Neonatal Resuscitation skill from May 19 is not showing as recorded" and that this was a "system error preventing externship scheduling." The Email Agent replied:

> "Your Childbirth/Neonatal Resuscitation skill from May 19 is not showing as recorded in the system, and a ticket has been filed to get it updated."

Every part of that was wrong:
- The skill WAS recorded: `Skills_Audit` id 1496899929, status **Pass**, attempt_date 2026-05-19, instructor Stephen Metz, signed PDF on file. All 35 of her skills were Pass, Final Exam 96.67%.
- There was no system error to fix. The agent filed a ticket to "update" a record that was already correct.
- The REAL blocker was never found: her externship request #2012 had been marked `completed` on 5/14 after a CS rep only left a voicemail (`preceptor_state=not_sent`, no placement, no slots) — she was never actually scheduled and was now in post_course_window.

The agent took the student's premise at face value, echoed it back as confirmed fact, filed a do-nothing ticket, and missed the actual problem. A single `Skills_Audit` lookup would have refuted the premise in one query.

## The required sequence (premise-check → act → reply)

1. **Extract the factual claim.** What state does the student assert about EMSU's records? ("skill not recorded," "payment not applied," "course incomplete," "exam not submitted.")
2. **Run the lookup tool that confirms or refutes that exact claim.** Skill claim → `Skills_Audit` / skills tool. Payment claim → `verify_payment_state` / `find_authnet_by_email`. Course/Moodle claim → `check_moodle_enrollment` / `get_student_courses`. Exam claim → `get_exam_attempt_analysis` / `get_moodle_quiz_status`. Externship claim → `get_externship_info`.
3. **Branch on the result:**
   - **Claim is FALSE (record is fine):** Do NOT echo the claim. Do NOT file a "fix the record" ticket. Instead, find the REAL blocker (the student is stuck on something — keep digging: externship request state, a different missing form, a hold, a window expiry) and act on THAT. Tell the student plainly what is actually true ("your skill is recorded and passed") and what the real next step is.
   - **Claim is TRUE (record is genuinely wrong/missing):** Fix it with the action tool if one exists (rule 29 / ACT-DO-NOT-PUNT), THEN reply describing the fix. Only file a ticket if no tool can fix it.
   - **Can't tell:** Run more lookups. "I couldn't verify" is not a license to echo the student's version.
4. **Never restate an unverified claim as established fact in the reply.** Phrases like "your X is not showing as recorded" / "there is a system error with your Y" must be backed by a tool result that actually showed that, not by the student having said it.

## Banned reply patterns (premised on an unverified claim)

- "Your [skill/payment/record] is not showing / not recorded / missing, and a ticket has been filed to update it" — when no lookup confirmed it is actually missing.
- "We've identified a system error with your [X]" — when no tool actually found an error.
- "I've filed a ticket to get your [X] corrected" — when [X] was never checked and may be correct.
- Any reply that adopts the student's diagnosis verbatim as the EMSU-confirmed explanation.

## Self-check before sending any reply that references EMSU record state

1. *Does this email assert a factual claim about our records?* If yes, continue.
2. *Did I run the tool that checks that exact claim?* If no → run it before replying.
3. *Am I about to repeat the student's claim as fact?* Only if a tool result confirmed it.
4. *If the claim is false, did I find and act on the REAL blocker instead of filing a do-nothing ticket?* If no → keep investigating; the student is still stuck on something real.

## Cross-references

- Rule 29 — agents act on confidence tier; "I don't have the artifact is not a human gate"; pre-completion audit (verify outcomes, don't trust prior claims)
- Rule 92 — work at the core, not bandaids (a do-nothing ticket on a correct record is the ultimate bandaid)
- Rule 126 — build the watchdog/self-heal with the fix
- EmailAIResponder buildSystemPromptRaw "ACT, DO NOT PUNT" + "NO FABRICATED ACTIONS" blocks (this rule is the verify-the-premise predecessor to those)

## Source incident

2026-06-01 — Sae Ackerstein (26706T-14). Email Agent echoed "skill not recorded / system error" and filed a ticket; the skill was recorded Pass the whole time; real blocker was a falsely-"completed" externship request #2012 (VM-only, never placed). Cline reopened #2012 to pending, left the skill alone, corrected the ticket, and Ruben asked to harden the fix-first rule so the agent verifies the premise before echoing it.

## Last updated

2026-06-01 — initial. Source: Sae Ackerstein false-premise email + Ruben fix-first hardening directive.

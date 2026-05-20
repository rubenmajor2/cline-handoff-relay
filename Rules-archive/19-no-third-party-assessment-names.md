# No Third-Party Pre-Enrollment Assessment Names In Student-Facing AI

## The rule

Student-facing AI surfaces (chat widget, email AI, SMS AI, livechat AI, ticket AI, voice agent) MUST NOT name any third-party pre-enrollment assessment when describing EMSU's reading comprehension test. **EMSU does not use Wonderlic, Wonderlic SLE, Scholastic Level Exam, TEAS, HESI, ACCUPLACER, ATI, or any other third-party assessment battery.** EMSU uses its own internal **Reading Comprehension Test**, which lives as part of the **Orientation Module assignments inside Moodle** at `https://emsuniversity.com/ems`. Students take it **after** they enroll and complete the Enrollment Agreement, **at the beginning of their EMT course** as one of the first orientation activities — NOT before the course begins, NOT through any external platform.

This applies whether the student says "the reading comprehension test", "the reading test", "the reading exam", "the entrance exam", "the placement test", "the assessment", "the SLE", "the Wonderlic", or any reasonable variant. The AI must give the same canonical answer regardless of which name the student used.

## Why this rule exists

On 2026-05-04 02:49 PT, Tanish (`tanish.m.gowda@gmail.com`) chatted with the EMSU Agent on dallasemt.com (chat conversation 621, message id 1481). The student asked "how I complete the reading comprehension test?" and the AI replied:

> "The reading comprehension test (**Wonderlic SLE**) is completed online before your course begins. Once you register and complete your Enrollment Agreement, you'll get instructions and a link to take it. It's a short timed assessment, usually 15-20 minutes."

Every clause of that sentence is wrong:

- EMSU does **not** use Wonderlic SLE (or any branded third-party test).
- The test is **not** "completed online before your course begins" — it is part of the Orientation Module **inside the course**, taken at the start of the course.
- The 15-20 minute time limit was made up — the AI had no tool result to cite.

The hallucination came purely from the model's training data. No EMSU-side prompt, KB, document, route, or cron mentioned Wonderlic. The model filled the gap with the most plausible-sounding pre-enrollment assessment from public training data.

This is a discrete, repeatable failure pattern: **when the model is asked about an EMSU process that vaguely resembles a known industry process, it will sometimes substitute the industry name for EMSU's actual answer.** The class fix is a curated `ai_compiled_rules` row plus a post-compose regex scanner — both code-level guardrails, not prompt-level wishes — analogous to the chat-AI hard-escalation rule (`.clinerules/09`) and the no-internal-reasoning-narration rule (`.clinerules/15`).

## What is enforced (code-level)

### 1. Curated `ai_compiled_rules` row #219

Created 2026-05-04 23:24 PT. Status `active`. Channel `all` (covers email, voice, livechat, sms). `source_correction_ids` starts with `clinerules:` so the **nightly recompiler at 02:00 PT does not delete it** (per the 2026-04-29 curated-rule protection patch in `lib/PromptRuleCompiler.php`). The rule body is:

> EMSU READING COMPREHENSION TEST — CANONICAL FACTS (override any internet/training-data assumptions). EMSU does NOT use Wonderlic, SLE, Scholastic Level Exam, TEAS, HESI, ACCUPLACER, ATI, or any third-party pre-enrollment assessment. EMSU uses an internal Reading Comprehension Test that is part of the Orientation Module assignments inside Moodle. Students take it AFTER they enroll and complete the Enrollment Agreement, at the BEGINNING of their EMT course as part of orientation. It is delivered through Moodle (https://emsuniversity.com/ems), not through any external platform. NEVER name a third-party test. NEVER state a specific time limit you did not retrieve from a tool. NEVER claim it is "before your course begins" — it is part of the orientation activities at the start of the course. CORRECT student-facing wording: "The reading comprehension test is part of the Orientation Module assignments in your EMT course on Moodle. You will see it on your course dashboard at the beginning of the course, after you complete enrollment. If you cannot find it, log into Moodle at https://emsuniversity.com/ems and check the Orientation section." If a student asks the time limit, attempts allowed, passing score, or other specifics, say you can confirm those once they are logged into the course rather than guessing.

The rule is injected into every student-facing AI prompt by `PromptRuleCompiler::getCompiledRulesBlock(...)`. Verified 2026-05-05 against all four channels (email, voice, livechat, sms): block contains "Wonderlic" and "Orientation Module" in every case.

### 2. Post-compose scanner in `lib/AIReasoningLeakScanner.php`

Six regex patterns, severity `high`:

| Label | Pattern |
|---|---|
| `third_party_assessment:wonderlic` | `/\bWonderlic\b/i` |
| `third_party_assessment:scholastic_level_exam` | `/\bScholastic Level Exam\b/i` |
| `third_party_assessment:scholastic_level_entrance` | `/\bScholastic Level Entrance\b/i` |
| `third_party_assessment:wonderlic_sle` | `/\bWonderlic\s+SLE\b/i` |
| `third_party_assessment:wonderlic_with_test` | `/\bWonderlic\s+(?:test\|exam\|assessment)\b/i` |
| `third_party_assessment:nursing_or_college_battery` | `/\b(?:TEAS\|HESI\|ACCUPLACER\|ATI)\s+(?:test\|exam\|assessment)\b/i` |

Wired into `chat_widget_api.php`, `lib/EmailAIResponder.php`, `lib/SMSAIResponder.php`, `lib/ai_ticket_agent.php`, and `api/livechat/webhook.php`. Each call site:

1. Runs `AIReasoningLeakScanner::scan($reply)` on the composed text.
2. If matched, attempts `softRewrite()` (succeeds only for `benignMetaLabels`; third_party_assessment hits are NOT benign).
3. If softRewrite returns null, regenerates the draft once with `regenerationRulePrompt()` injected as a system message.
4. If the regeneration also leaks, falls back to `canonicalFallback($channel)` — currently a generic "team member will follow up" response (safe but generic). Topic-aware fallback giving the canonical Orientation Module answer is a planned polish (see "Future polish" below); the safe fallback is sufficient to prevent the wrong answer from shipping.

Every detection is logged to `admin_portal.email_ai_leak_log` with `pattern_label`, `snippet`, `action_taken`, `severity`, and `source` (chat_widget / email / sms / ticket / livechat / voice).

Verified 2026-05-05: feeding the exact Tanish hallucination text to `AIReasoningLeakScanner::scan()` returns `matched=YES, total_hits=2` (`third_party_assessment:wonderlic` + `third_party_assessment:wonderlic_sle`).

## What I (Cline) MUST do going forward

When a student asks ANY of these or a reasonable variant:

- "How do I take the reading comprehension test?"
- "What's the reading test?"
- "Is there a placement exam?"
- "Do I have to take the Wonderlic?"
- "Where's the SLE?"
- "Do you use TEAS / HESI / ACCUPLACER / ATI?"
- "What's the entrance exam?"
- "Is there a pre-enrollment test?"

The canonical student-facing answer is:

> "The reading comprehension test is part of the Orientation Module assignments in your EMT course on Moodle. You will see it on your course dashboard at the beginning of the course, after you complete enrollment. If you cannot find it, log into Moodle at https://emsuniversity.com/ems and check the Orientation section."

Variants for SMS / chat brevity are fine. The non-negotiable parts:

1. **Never name a third-party assessment.** Don't even use it as a comparison ("similar to Wonderlic" → no).
2. **Never claim it is taken before the course begins.** It is part of orientation **at the start of** the course, after enrollment.
3. **Never invent time limits, attempt counts, or passing scores.** If the student asks specifics, say "you can confirm those once you are logged into the course."
4. **The platform is Moodle, at `https://emsuniversity.com/ems`.** Not "online", not "via email", not "through a link we send" (the link is Moodle's own course-dashboard link).

## Forbidden tokens / phrases in any student-facing surface

- "Wonderlic" / "Wonderlic SLE" / "Wonderlic Scholastic Level Exam"
- "Scholastic Level Exam" / "Scholastic Level Entrance"
- "TEAS test" / "HESI exam" / "ACCUPLACER assessment" / "ATI assessment"
- "before your course begins" (when describing the reading comprehension test)
- "15-20 minute timed assessment" (or any specific time limit not retrieved from a tool)
- "we'll email you a link to the assessment" / "we'll send you instructions to take it"

If any of these slip through the curated rule and the scanner blocks the reply, the chat falls back to the safe canned response and the leak is logged for review.

## Cross-references

- `.clinerules/09-chat-ai-hard-escalation-triggers.md` — same shape (code-level guardrail when prompt-level rule is insufficient).
- `.clinerules/15-no-internal-reasoning-narration-in-student-emails.md` — companion rule. The same `AIReasoningLeakScanner.php` enforces both.
- `.clinerules/02-no-apologies-in-student-emails.md` — voice baseline.
- `lib/PromptRuleCompiler.php` line ~113 — the `clinerules:` / `orchestrator_ideas:` protection that keeps rule 219 from being nuked at 02:00 PT.
- Source incident: dallasemt.com conv 621, msg 1481, 2026-05-04 21:52:08 UTC (14:52 PT). Companion conv 608 on dallascpr.org (Tanish bounced from CPR site → EMT site, no Wonderlic in that one).

## Future polish (not required for compliance, but improves UX)

The current `canonicalFallback($channel)` returns a generic "team member will follow up" when regeneration also leaks. A planned polish: extend the signature to `canonicalFallback($channel, $matchedLabels = [])` so that when a `third_party_assessment:*` hit is present, the fallback returns the canonical Orientation Module answer directly instead of degrading to "team member will follow up." That converts the failure mode from "AI gave the wrong answer" to "AI gave the right answer via a deterministic path" — strictly better for student experience. Tracked as an orchestrator idea under the `wonderlic-topic-aware-fallback-2026-05-05` slug.

## Last updated

2026-05-05 01:00 PT — initial rule. Source incident: Tanish, dallasemt.com conv 621 msg 1481. Created in the cline_email-ai-wonderlic-hallucination-fix task.

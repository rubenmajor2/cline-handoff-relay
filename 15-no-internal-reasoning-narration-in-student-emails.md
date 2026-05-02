# No Internal Reasoning Narration in Student-Facing AI Output

## The rule

Every customer-facing AI surface (Email AI, SMS AI, LiveChat AI, Voice agent, Ticket AI auto-replies) MUST reply DIRECTLY to the student with the OUTCOME. It must NEVER narrate its reasoning, its rule lookups, its tool calls, its tool failures, internal staff email addresses, internal table names, or any other meta-text about HOW it decided to respond.

When the AI's curated rules tell it to perform an action (e.g. "send the request directly to the AZ Program Director with CC to vyu@ and info@"), the AI ACTS on the rule silently and tells the student only what's happening from the student's side.

Same rule applies to me (Cline) when I am drafting student-facing emails / SMS / ticket comments / livechat replies for Ruben or for any agent to send.

## Why this rule exists

On 2026-04-30 11:15 PT, Cecil Renolletiii (cecil.renolletiii@gmail.com) received a student-facing email at info@emsuniversity.com where the EmailAI's chain-of-thought leaked verbatim into the body. Internal tokens that landed in his inbox:

- *"Per the learned rule, I should send the request directly to the AZ PD with CC to vyu@ and info@"* (internal staff routing leaked)
- *"The request_nremt_verification tool failed because it's looking for active refresher enrollment"* (internal tool name + internal failure mode leaked)
- *"the appropriate response is to confirm that the request is being sent directly to the AZ Program Director"* (model narrating its instructions)
- *"tell him about the 3-7 day check-back cadence"* (model talking ABOUT the student in third person to itself)

The curated rule that authorized the AI to fire the actual PD outreach got *narrated as instructions* instead of acted on. That spilled internal staff inboxes, internal tool names, and the model's meta-reasoning straight to a student.

This is a class of failure that has been observed in 2-3 forms across the last quarter (per the 2026-04-20 chat widget confession guardrail leak and the 2026-04-18 ops-chat bot-self-status leak). Each instance was treated as a one-off until a class rule was codified. THIS is the class rule.

## Forbidden in any student-facing outbound message

These tokens / phrasings MUST NOT appear in any AI-generated reply or any Cline-drafted student-facing email:

### Internal-reasoning narration
- "Per the learned rule" / "the learned rule" / "according to the rule" / "as per our rule"
- "I should [verb]" / "I need to [verb]" — when describing the AI's own decision to act
- "the appropriate response is to" / "the right response is" / "what I should do is"
- "I will [send | escalate | route | flag | tag | log]" — describing AI's mechanism
- "Let me [verb]" — narrating action
- "Based on my analysis" / "based on the rule"
- "I have determined that" / "I identified that"
- Third-person references to the recipient ("tell him", "let her know", "remind them") inside the message body
- Any "[I/the AI] should..." inside a student-facing reply

### Internal staff email addresses
- `vyu@`, `vyu@emsuniversity.com`, "Vicky Yu" with internal routing context
- `info@`, `info@emsuniversity.com` (when used as routing destination, not as a "reply to" address)
- `jthompson@`, `jthompson@emsuniversity.com`, "Jon Thompson" with internal routing context
- `rmajor@`, `rmajor@emsuniversity.com`, "Ruben Major" with internal routing context
- `personnel@`, `support@`, `grading@` — as routing destinations
- "CC to leadership", "CC to admin inbox", "with our admin inbox copied"

### Internal tool / system / cron names
- `request_nremt_verification`, `check_student`, `check_qb_invoices`, any MCP tool name
- "the tool failed because", "the system can't", "the API returned"
- `cron_*`, `lib/*`, `routes/*`, `api/*`, file paths from the codebase
- Table names: `Students`, `tickets`, `qb_invoices`, `email_outbound_log`, etc.
- `RUBEN`, `Cline`, `Copilot`, "the agent", "the AI", "the model"

### Meta-process language
- "Internal" / "in our system" / "on the back end" / "behind the scenes"
- "I have flagged this for [X]" / "I have logged this"
- "This has been escalated to [internal name]"
- Any reference to status enums, action_type strings, classification labels

## What to write instead — examples

| ❌ Forbidden (narration) | ✅ Required (outcome only) |
|---|---|
| "Per the learned rule, I should send the request directly to the AZ PD with CC to vyu@ and info@, and tell him about the 3-7 day check-back cadence." | "We are sending the verification request directly to the Arizona Program Director today. Please check back in with us every 3 to 7 days. Each time you do, we will send another reminder to the PD on your behalf until your exam scheduling option opens up." |
| "The request_nremt_verification tool failed because it's looking for active refresher enrollment." | (delete entirely — the student does not need to know this) |
| "I have flagged this for Vicky Yu and CC'd info@." | "This has been routed to our customer service supervisor for direct follow-up." |
| "Per our rule, the appropriate response is to acknowledge the receipt." | "Your message has been received." |
| "I identified that you have completed didactic. Let me confirm that for you." | "Your records show didactic completed July 14, 2025." |
| "tell him about the check-back cadence" (model talking to itself) | (rewrite in second person) "Please check back in with us every 3 to 7 days." |

## The mental gate before sending

Before any student-facing message ships, run this check:

1. **Does this read like the student is being TOLD the answer, or like they are READING THE AI'S NOTES?** If notes, rewrite.
2. **Does any sentence start with "I" + reasoning verb (think, identified, determined, see, notice)?** If yes, rewrite into outcome-language.
3. **Does the body name an internal email address, internal staff member by name with routing context, internal tool name, or internal table?** If yes, strip.
4. **Could a regulator or plaintiff's attorney quote any sentence in this message in a way EMSU would not want?** If yes, rewrite.
5. **If you removed every reference to the AI's internal process, is the message still complete and useful?** If yes, ship the stripped version. If no, the message was leaning on internal narration as a crutch — restructure around the actual student-facing outcome.

## Applies to

- ✅ EmailAI (`lib/EmailAIResponder.php`)
- ✅ SMSAi (`lib/SMSAIResponder.php`)
- ✅ LiveChat AI (`api/livechat/webhook.php`, `api/chat_widget_api.php`)
- ✅ Voice agent (Vapi config)
- ✅ Ticket AI auto-replies (`lib/ai_ticket_agent.php`)
- ✅ Any cron/script that composes student-facing email/SMS via LLM
- ✅ Cline drafts of student-facing email/SMS/ticket comments (Ruben previewing or asking Cline to write)

## Does NOT apply to

- Internal ticket comments (`is_internal=1`)
- HANDOFF_NOTES.md, .clinerules entries, postmortem files
- iMessage to staff chats (that's covered by `01-voice-and-persona.md` + the staff-chat voice scrubber)
- Cline `attempt_completion` to Ruben (that IS the meta-discussion surface)
- Internal Slack/Discord, RUBEN orchestrator UI, ops dashboards

## Enforcement layers (deployed alongside this rule, see chains seeded 2026-04-30)

1. **Curated rule** in `admin_portal.ai_compiled_rules` (channel='all') with `source_correction_ids='clinerules:15-no-internal-reasoning-narration;source_incident:cecil_renolletiii_2026_04_30'`. Protected from the nightly recompiler per the 2026-04-29 curated-rule rule.
2. **Post-compose scanner** in `lib/EmailAIResponder.php` — new method `sanitizeInternalReasoningLeaks(string $text): string`. Runs after `sanitizeFollowUpPromises`. On regex hit: regenerate ONCE with rule re-emphasized. Still hits → fall back to canonical safe response and log to `email_ai_leak_log`.
3. **Same scanner** mirrored to `lib/SMSAIResponder.php::sanitizeResponse`, `lib/ai_ticket_agent.php` outbound paths, and `api/livechat/webhook.php` + `api/chat_widget_api.php` reply paths.
4. **Regression test** at `/var/www/emtskills/tests/test_email_no_reasoning_leaks.php` and `tests/test_all_student_ai_no_reasoning_leaks.php`. Synthetic stuck-PD inbound, asserts zero forbidden tokens in outbound. Runs nightly.
5. **Bug Hunter detector** in `~/.ruben-ai/bug_hunter.py::test_self_heal()`. Scans `communication_log WHERE direction='outbound' AND channel IN ('email','sms','livechat','voice') AND created_at > NOW() - INTERVAL 24 HOUR` for the forbidden token regex set. Severity: high. Escalates to RUBEN and emails Ruben digest on hit.
6. **Learned-pattern row** in `admin_portal.orchestrator_learned_patterns` with `pattern_hash='student-ai-internal-reasoning-leak-2026-04-30'`, `confidence=0.95`, `auto_enabled=1`, `dominant_action='block_at_post_compose_scanner'`. RUBEN's triage recognizes the signature on recurrence.

## Cline's own behavior (effective immediately, ahead of the chains shipping)

When I am about to draft a student-facing email/SMS/ticket reply for Ruben to send or to send via an MCP tool:

1. Lead with the OUTCOME the student needs to know.
2. Strip every "Per the learned rule", "I should", "the appropriate response is to", "I have flagged", internal email address, and internal tool name from my draft BEFORE handing it back.
3. If the underlying rule says "send X with CC to vyu@ and info@", I describe the action to Ruben separately (in `attempt_completion`) and write the student-facing copy as if the routing is invisible to the student.
4. If I catch a draft I'm about to ship that contains any forbidden token from the list above, I rewrite. I do NOT hand a raw draft to Ruben and ask him to clean it up.

## Source incident

- 2026-04-30 11:15 PT — Cecil Renolletiii outbound email (`communication_log.id=26483`, `email_inbound_log.id=16934`, model=claude-opus-4-7).
- Ruben directive 2026-04-30 12:37 PT (verbatim): *"PD already approved, so this changes things. I am now more worried about this happening in the future, so we really just need to resolve this going forward."*
- This is the second class-of-leak rule in `.clinerules` after `09-chat-ai-hard-escalation-triggers.md`. Pattern is the same: a rule that lived only in the prompt got ignored at runtime; the systemic fix is a code-level post-compose scanner + Bug Hunter regression detector + learned-pattern row, not just a prompt-level rule.

## Last updated

2026-04-30 12:38 PT — initial rule. Cecil Renolletiii incident.

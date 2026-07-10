# 266 -- CS-facing agent response-quality bug library: consult before recycling wrong replies

Source: 2026-07-10 Ruben directive: "Customer Facing Agents -- our Email AI, To AI, chat widget AI, SMS AI, Vapi Customer Service AI -- I had mentioned making this a rule as well and I want it to be a rule." Idea #16975.

## The 6 customer-facing agents (source of truth: rule 207/130 + Ruben 2026-07-10)

| Agent | LIVE entry point | Reply composer | Channel |
|---|---|---|---|
| **Email AI** | cron/cron_email_responder.php | lib/EmailAIResponder.php | info@emsuniversity.com inbound email |
| **Chat AI** (in-house widget) | api/chat_widget_api.php | lib/emsu_ai_brain.php + webhook.php | Website chat widget |
| **SMS AI** | cron/cron_sms_auto_reply.php | lib/SMSAIResponder.php | Inbound SMS |
| **Ticket AI** | lib/ai_ticket_agent.php | ai_ticket_agent.php | Support ticket replies |
| **Voice AI** (Vapi CS) | Vapi platform → api/vapi* | Vapi assistant + ai_ticket_agent.php follow-up | Inbound phone (+19412545009) |
| **To AI** | To AI workflow | To AI responder | Student To AI interactions |

## The bright-line rule

**Before an agent retries the same class of wrong output for a 3rd time on the same topic, the response system MUST consult the response-quality bug library.**

A "same class of wrong output" = same wrong URL, same wrong policy statement, same wrong deadline, same wrong contact information, or same hallucinated fact pattern that has been corrected before.

## The 2-strike tripwire (analogous to rule 262)

| Strike | What happened | Required next move |
|---|---|---|
| 1 | Agent produces a wrong/misleading output | Fix the prompt/content/knowledge base. OK, try again. |
| 2 | Agent produces the SAME class of wrong output again | **STOP.** Query the response-quality bug library BEFORE generating any 3rd reply on this topic. |
| 3+ | Agent replies again without consulting the bug library | **VIOLATION.** The bad output is being recycled. |

A "same class of wrong output" in the CS-agent context means:
- Same wrong URL being recommended (e.g. a dead /register/ link)
- Same wrong deadline / time window being told to students
- Same wrong contact info / phone number / email
- Same hallucinated policy that contradicts CanonicalAgentPolicy
- Same missing or incorrect externship/proctoring/NREMT information

## The response-quality bug library

**Table:** `cs_agent_response_bugs` (to be created on WOPR in admin_portal database)

```sql
CREATE TABLE IF NOT EXISTS cs_agent_response_bugs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    agent_channel ENUM('email','chat','sms','ticket','voice','to_ai') NOT NULL,
    problem_key VARCHAR(255) NOT NULL COMMENT 'Short slug: e.g. wrong-register-url, wrong-proctor-policy',
    wrong_output_excerpt TEXT NOT NULL COMMENT 'The actual wrong text the agent sent',
    correct_output TEXT NOT NULL COMMENT 'The corrected text that should have been sent',
    topic_tags VARCHAR(500) COMMENT 'Comma-separated: externship,proctor,NREMT,payment,deadline,etc.',
    prompt_fix_applied TEXT COMMENT 'What changed in the prompt/knowledge base to prevent recurrence',
    detected_by VARCHAR(100) COMMENT 'Human or system that caught the error',
    status ENUM('open','fixed','monitoring','stale') DEFAULT 'open',
    occurrences INT DEFAULT 1 COMMENT 'How many times this pattern has repeated',
    first_seen DATETIME NOT NULL,
    last_seen DATETIME NOT NULL,
    resolved_at DATETIME NULL,
    UNIQUE KEY uk_agent_problem (agent_channel, problem_key),
    FULLTEXT idx_problem (problem_key, wrong_output_excerpt, topic_tags)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## How to query the bug library before sending

### Via AIReasoningLeakScanner pre-send hook (preferred integration point)
Add a check in `lib/AIReasoningLeakScanner.php` that, before any agent sends a reply, does a quick lookup against `cs_agent_response_bugs` for matching problem_keys and topic_tags. If a KNOWN_BAD_PATTERN is detected, block the send and route to human + log the near-miss.

### Via SQL (fallback)
```sql
SELECT problem_key, wrong_output_excerpt, correct_output, prompt_fix_applied, status
FROM cs_agent_response_bugs
WHERE agent_channel = 'email'  -- or chat, sms, ticket, voice, to_ai
  AND status = 'open'
  AND MATCH(problem_key, wrong_output_excerpt, topic_tags) AGAINST('<keyword>' IN BOOLEAN MODE)
ORDER BY last_seen DESC LIMIT 5;
```

### Via mysql MCP (when AIReasoningLeakScanner lookup fails)
Use the `mysql` MCP server `execute_query` tool with the query above.

## Recording new response bugs

After any incident where a CS agent produced wrong output, record it:

```sql
INSERT INTO cs_agent_response_bugs
(agent_channel, problem_key, wrong_output_excerpt, correct_output, topic_tags, prompt_fix_applied, detected_by, first_seen, last_seen)
VALUES ('email', 'wrong-register-url', '...excerpt...', '...correct...', 'registration,url', 'Updated CanonicalAgentPolicy block() line 142', 'Ruben', NOW(), NOW())
ON DUPLICATE KEY UPDATE occurrences = occurrences + 1, last_seen = NOW(), wrong_output_excerpt = VALUES(wrong_output_excerpt);
```

This is mandatory -- every novel wrong-output pattern that is NOT recorded is a pattern the next agent will recycle. Recording takes 60 seconds. Letting it recycle costs a student frustration + a ticket + human triage time.

## Cross-references

- Rule 262 -- Cline debugging bug library. This rule is the CS-agent equivalent.
- Rule 207 (130) -- CS-facing agent name map. Defines the live files for each agent.
- Rule 156 -- Bug library check before frankenstein/LLM fix. Predecessor pattern.
- Rule 29 -- Act on confidence tier. If the bug library says "known bad pattern," block the send.
- Rule 15 -- No internal reasoning narration in student-facing AI output.
- Rule 19 -- No third-party pre-enrollment assessment names in student-facing AI.
- Idea #16975 -- This rule's source idea (autonomous tier, Ruben-approved 2026-07-10).

## Self-check before any CS-agent reply fires

1. *Is this topic something the agent has gotten wrong before?* If unsure, query `cs_agent_response_bugs`.
2. *Is this the 2nd strike on the same class of output?* If yes -- STOP. Query the bug library.
3. *Did the bug library return a KNOWN_BAD_PATTERN?* If yes -- use the `correct_output` column, do NOT re-derive.
4. *Is this a new wrong-output pattern?* Record it via INSERT after fixing the prompt.

## Source incident

2026-07-10 -- Cline session. Ruben asked whether rule 262 (consult bug library before recycling debugging approaches) had an equivalent for customer-facing agents. The answer was no. Ruben: "I had mentioned making this a rule as well and I want it to be a rule." He confirmed Vapi CS Voice AI is also a customer-facing agent. Idea #16975 filed, approved, and this rule created in the same session per rule 29 (act, do not defer) + rule 38 (Ruben-asks = autonomous tier minimum).

## Last updated

2026-07-10 -- initial. Source: Ruben directive + idea #16975.
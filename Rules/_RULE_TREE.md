# Rule Tree — Proactive Trigger Guide

**How to use:** When you're about to do something in ANY of the trigger categories below, fetch that branch FIRST. Each domain has a `clinerules_list_by_topic(...)` command that returns the full rules. Key rule numbers are listed inline for instant lookup. **This file is auto-loaded into every Cline window. It takes ~3.5K tokens.**

---

## ⛔ RULE 146 — READ THIS FIRST. Frankenstein-LLM routes EVERY LLM we own. Free-local models ARE the primary. Never suggest Claude/Anthropic as the default.

**THE RULE (blunt, can't miss it):**
- `frankenstein-llm` is the ONE router for EVERY LLM: 7B/14B/32B/70B/120B/405B/235B, RunPods, DeepSeek, AND the paid heads (Sonnet, Opus, Fable-5). If we own it, Frankenstein routes it.
- **Cline is PRIORITY.** Executor/Orchestrator QUEUE behind it. Never the reverse.
- **Free-local-first IS the design.** A healthy free local box that can serve = serve from it. Only spill to paid when local is GENUINELY full (real saturation, not a false-offline probe).
- **A failed health probe does NOT mean a box is dead.** Check `/tmp/emsu_router_audit.log` for recent `picked=<model>` before calling anything dead.
- **NEVER suggest Claude/Anthropic/Sonnet/Opus as the model to use** unless Ruben explicitly asked. Anthropic models are LAST RESORT in the spill ladder. Suggesting them on an unrelated task is a rule violation.
- Full rule: `clinerules_lookup(rule_id=146)`. Also cross-refs 140 (verify routing live), 141 (MCP first), 148 (never pin raw 120B).

---

## ⛔ COMPLETION COMPLIANCE — Rules 29 and 91 are NON-NEGOTIABLE on every `attempt_completion`

**Before EVERY `attempt_completion`, these two hardfloor rules MUST be satisfied. No shortcuts. No lazy completions.**

### Rule 91 — Pickup Prompt REQUIRED
- Every `attempt_completion.result` MUST end with a `═══ PICKUP PROMPT ═══` block
- Must contain: task ID, verified PT timestamp, 2-3 bullets of current state, numbered open threads with idea #s, reference IDs, cross-refs
- No PICKUP-BY-REFERENCE ("see handoff file") — the block must be INLINE in result
- No literal placeholders (`#NNNN`, `<timestamp PT>`, `#0000`) — every `#` is a real idea number
- Open threads MUST have idea numbers (file via `create_idea` before listing)
- Full rule: `clinerules_lookup(rule_id=91)`

### Rule 29 — Act, Don't Defer
- Default is ACTION. Inaction requires justification.
- Before listing ANY open thread in the pickup prompt: Gate 0 test — "can I do this now?" If yes, DO it, don't list it.
- "Pickup prompt as decision queue" is forbidden: reversible actions the agent can take go in the DONE column, not the open-threads list
- Every unanswered Ruben question is a rule violation
- Full rule: `clinerules_lookup(rule_id=29)`

### Pre-completion BINARY GATE (run BEFORE calling the attempt_completion tool — same hard pattern as rule 41's colon test)

**GATE 1 (rule 91 — HARD BINARY): scan the result text. If the string `═══ PICKUP PROMPT ═══` does NOT appear in `result`, the completion is BROKEN. Period. Do not ship it.** Add the pickup prompt block. This gate fires BEFORE any other consideration. No pickup prompt = no completion. This is the single most common rule-91 violation — agents complete with a summary and forget the divider block entirely. The binary string check makes it impossible to skip.

**GATE 2 (placeholders):** scan for any literal `#NNNN`, `#0000`, `#XXXX`, `<task_id>`, `<timestamp PT>`, or angle-bracket token in the pickup prompt. If found → substitute the real value or remove the line. Placeholders are a rule-91 hardfloor violation.

**GATE 3 (Ruben questions):** did I answer every question Ruben asked in his last message? If no → answer them inline before the pickup prompt.

**GATE 4 (rule 29 open-threads):** did I list anything as "open" that I could have done myself? If yes → do it now, remove from list.

**None of these gates are advisory. All four must PASS before calling `attempt_completion`.**

---

## 🗣️ Communication & Voice
→ Trigger: writing student email, ops chat, iMessage, staff escalation, CTA, CC/BCC, tone, apology
→ Fetch all: `clinerules_list_by_topic("voice")`
- **Student-facing email** — R: 01,02,15,19,30,47,48,101
- **Ops chat / iMessage to staff** — R: 01,09,10,30,57,72,96,108,111
- **Staff escalation (Vicky/Jon/Ruben)** — R: 10,13,15,19,48,117
- **CTA / link formatting** — R: 47 (full URLs, no shortcuts)

---

## 🤖 Agent Behavior & Autonomy
→ Trigger: deciding whether to act or escalate, filing ideas, agent self-supervision, capability gaps, Q-cards, confidence tiers
→ Fetch all: `clinerules_list_by_topic("agent")`
- **Act vs escalate gate** — R: 12,22,23,29,36,38,67,68,117
- **Self-supervision & repair** — R: 46,49,53,54,56,65,66,73
- **Routing to humans** — R: 68,69 (Jon=policy only, Vicky=CS only)
- **Parallel windows protocol** — R: 29 (§"wait them out" forbidden), 137

---

## 💻 Infrastructure, Deploy & Debugging
→ Trigger: deploying code, editing server files, restarting services, SSH, WOPR, Mac, tunnels, LiteLLM, FPM, safe_deploy
→ Fetch all: `clinerules_list_by_topic("infrastructure")`
- **Safe deploy & FPM** — R: 41,42,118,144
- **SSH & WOPR access** — R: 77,95,136 (Artemis=emsu-operations MCP, never raw ssh)
- **Mac-side debugging** — R: 16,20,24,25,26,27,28,34,100,102,105
- **URL→docroot mapping** — R: 159 (emsuniversity.com/ems = /var/www/moodle/ems, NOT /var/www/emtskills/ems)

---

## 🔬 Project Frankenstein & LLM Routing
→ Trigger: LLM routing question, model serving, spill ladder, frankenstein-llm, adapter, RunPod, context windows, cost
→ Fetch all: `clinerules_list_by_topic("frankenstein")`
- **Architecture & fleet** — R: 140,141,142,146,148,150
- **Bug library (diagnose FIRST)** — R: 156 + `bug_library_check_before_fix()`
- **Frankenstein Doctor (stuck window)** — R: 158,160
- **Hardfloor don't-destroy** — R: 157 (never tear down TP=2 without permission), 145 (Fable 5 escalation)
- **Kaison autonomous repair** — R: 147

---

## ✅ Task Hygiene & Context
→ Trigger: completing a task, pickup prompts, context compression, ledger, HANDOFF_NOTES, wrap-up, Order 66
→ Fetch all: `clinerules_list_by_topic("task")`
- **Completion shape** — R: 91 (pickup prompt required), EXECUTE_ORDER_66 (full wrap-up)
- **Context management** — R: 119 (compress thresholds), 120 (never shortcut due to context)
- **Task tracking** — R: 03,04,05,06,07,09,52,109,113
- **Build convergence** — R: 137 (Definition-of-Done first)
- **Persisting corrections** — R: 46 (agent corrections → RUBEN/KAIZEN), 169 (knowledge-gap corrections → durable surfaces, don't re-learn)

---

## 💰 Payments, Refunds & Billing
→ Trigger: payment verification, refund, QuickBooks, Authorize.net, Affirm, invoice, credit, balance
→ Fetch all: `clinerules_list_by_topic("payment")`
- **Payment verification** — R: 70,107,114 + `verify_payment_state()` (Rule 33 aggregator)
- **Refund handling** — R: 29 (§money cap), `find_authnet_by_email()`, `check_affirm_status()`
- **QB reconciliation** — R: `match_student_payment()` autonomous matcher

---

## 🎓 Student Lifecycle & Academics
→ Trigger: student status, enrollment, Moodle, exam, proctoring, externship, paperwork, integrity, grades, quiz
→ Fetch all: `clinerules_list_by_topic("student")`
- **Lifecycle state** — R: 135 (SLS) + `get_student_lifecycle_state()` (first move on any student issue)
- **Exam enforcement** — R: `emsu://reference/exam-retake-policy` (SEB+proctor+72hr), `check_exam_enforcement()`
- **NREMT under-18 policy** — R: `emsu://reference/nremt-under18-policy` (deadline extended to 18th birthday + 60-day refresher after 18; enforced in 4 crons; under-18 students are NOT past-deadline — never tell them to "test now")
- **Externship** — R: `emsu://reference/externship-agent`, `lookup_paperwork_state()` (rule 31)
- **Moodle enrollment repair** — R: `fix_moodle_enrollment()`, `unstick_moodle_quiz_attempt()`
- **Compliance** — R: 08,18,60,61,103 + `emsu://reference/student-status`

---

## ⚡ YOLO & Failure Recovery
→ Trigger: YOLO mode, no-tool-use errors, timeouts, prose-loop, circuit breaker, tool failures
→ Fetch all: `clinerules_list_by_topic("yolo")`
- **Circuit breaker** — R: 143 (consecutive-only, reset-on-success, bail at 4)
- **Per-class playbook** — R: 99 (auto-generated: no-tool-use, timeout, ssh, replace_in_file, permission denied...)
- **Extension host** — R: 16,97,98
- **Remote commands** — R: 95 (scp+nohup for long-running, timeout prevention)

---

## 📋 Cross-Reference: MCP Resources
→ Trigger: need operational policy (exam, payment, externship, student status)
→ Access via: `access_mcp_resource(server_name="emsu-operations", uri="emsu://...")`

| Resource URI | What It Covers |
|---|---|
| `emsu://reference/student-status` | Student lifecycle: transfers, drops, fails, Moodle suspension |
| `emsu://reference/quickbooks` | Payment rules, 50/50 split, finance fees, QB sync |
| `emsu://reference/exam-enforcement` | Violation thresholds, SEB proctoring, excluded emails |
| `emsu://reference/exam-retake-policy` | CANONICAL: Final Exam + retake REQUIRE SEB + proctored Zoom |
| `emsu://reference/nremt-under18-policy` | CANONICAL: NREMT under-18 eligibility extension (deadline → 18th birthday) + 60-day refresher after 18. Read BEFORE any under-18 NREMT deadline/reminder question. |
| `emsu://reference/telephony` | Phone system: Twilio + Vapi stack, numbers, NO third-party vendor |
| `emsu://reference/externship-agent` | Externship scheduling: 11 files, agency profiles, self-service |
| `emsu://reference/shift-architecture` | Shifts, Team Hub, pickup, Zoom routing architecture |
| `emsu://docs/handoff-notes` | HANDOFF_NOTES.md — current system state, read BEFORE any task |
| `emsu://docs/copilot-instructions` | Full architecture, DB credentials, server paths, deploy procedures |

---

## 🔍 How To Use This Tree

1. **Scan triggers before acting.** If your next action matches a domain trigger, fetch that domain's rules FIRST.
2. **Fetch by topic.** Each domain has a `clinerules_list_by_topic(...)` command — one MCP call, all rules in that branch.
3. **Key rules are inline.** The most commonly needed rules are listed with `R:` — fetch individually via `clinerules_lookup(rule_id=N)`.
4. **MCP resources are separate.** EMSU operational policies (exam, payment, externship) live in `emsu-operations` MCP resources, not cline rules. Cross-reference both.
5. **Hardfloor rules (★) are always loaded.** Rules 00,29,41,91,119,120,143,144 plus _INDEX.md and _RULE_TREE.md are in your system prompt. These govern pre-first-tool-call behavior and on-every-turn safety. All other rules (including the full text of 146, 140, 141, 142, etc.) are one `clinerules_lookup(rule_id=N)` away via the tree above.

**Self-check before any major action:** "Does a trigger in this tree match what I'm about to do?" If yes → fetch that branch first.

## 🌱 Adding New Rules — Keep The Tree Alive

**When you create a new cline rule, you MUST also update this tree.** A rule not in the tree is invisible to future windows.

1. **Classify the rule into a domain.** Read the new rule's title + first 3 lines. Which of the 7 domains does it belong to? If none fit, ask: is this a genuinely new domain (8th), or does it fit under an existing sub-topic?
2. **Place it at the right level.** Most new rules go under an existing sub-topic. Only create a new sub-topic if the rule covers something not already named (e.g., a new sub-system, a new workflow). Only create a new top-level domain if the rule covers an entirely new surface (e.g., "Security").
3. **Add the rule number to the relevant line.** Format: `R: <existing list>, <new number>`. Keep the one-line sub-topic description.
4. **If creating a new sub-topic**, add a new bullet under the domain: `- **<Sub-topic name>** — R: <numbers>`
5. **Reindex the MCP** so it's queryable: `node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only`
6. **Check: does the new rule cross-reference any emsu:// MCP resources?** If yes, verify the resource is listed in the Cross-Reference section below.

**Rule placement rules of thumb:**
- A rule about a SPECIFIC tool/command (e.g., "how to use safe_deploy") → Infrastructure
- A rule about a SPECIFIC agent behavior (e.g., "when to escalate to Jon") → Agent Behavior
- A rule about a SPECIFIC workflow (e.g., "how to process a refund") → Payments
- A rule about a GENERAL behavior (e.g., "always do X before Y") → Task Hygiene or Agent Behavior
- If unsure, default to Agent Behavior — most catch-all behavioral rules live there.

## Last updated

2026-06-24 — added `emsu://reference/nremt-under18-policy` to cross-ref table + Student Lifecycle trigger line (NREMT under-18 policy MCP resource registered 2026-06-24 per Ruben directive "make agents aware + add to MCP").

2026-06-22 — initial. Source: Ruben directive to build a drill-down tree for efficient rule discovery. 7 domains, 2 levels, ~3.5K tokens.

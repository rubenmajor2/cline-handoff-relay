# Rule Tree — Proactive Trigger Guide

**How to use:** When you're about to do something in ANY of the trigger categories below, fetch that branch FIRST. Each domain has a `clinerules_list_by_topic(...)` command that returns the full rules. Key rule numbers are listed inline for instant lookup. **This file is auto-loaded into every Cline window. It takes ~3.5K tokens.**

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
5. **Hardfloor rules (★) are always loaded.** Rules 00,01,02,29,38,41,42,91,92,99,118,119,120,135,137,140,141,142,143,144,145,146,147,148,156,157,158,159,160,161,EXECUTE_ORDER_66 are in your system prompt — no lookup needed.

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

2026-06-22 — initial. Source: Ruben directive to build a drill-down tree for efficient rule discovery. 7 domains, 2 levels, ~3.5K tokens.
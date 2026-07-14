# Rule Tree — Proactive Trigger Guide

**How to use:** When you're about to do something in ANY of the trigger categories below, fetch that branch FIRST. Each domain has a `clinerules_list_by_topic(...)` command that returns the full rules. Key rule numbers are listed inline for instant lookup. **This file is auto-loaded into every Cline window.**

---

## ⛔⛔⛔ MANDATORY GATES — FAIL ANY = BROKEN. NO EXCEPTIONS. ⛔⛔⛔

**Every hardfloor rule is a binary gate at a specific trigger point. Read the relevant gate BEFORE the action. No gate = no action.**

### ⛔ PRE-FIRST-TOOL GATE (before your first tool call)

1. **RULE 00 SUBAGENTS:** Is this task multi-step (>3 distinct MCP/server calls) OR multi-file investigation OR multi-system analysis? → **dispatch `use_subagents` FIRST.** Do NOT inline sequential MCP calls. Subagents are free (DeepSeek prefix caching). Inline is the slow path.
2. **RULE 146 NEVER CLAUDE:** Am I about to suggest Claude/Anthropic/Sonnet/Opus as the model to use? → **STOP.** Never suggest paid models. Free-local IS the design.

### ⛔ PRE-EVERY-TOOL GATE (before ANY tool call)

3. **RULE 41 NO PROSE:** Does my turn end with `:` and have no `<tool_use>` block? → **BROKEN.** Add the tool. Never emit prose without a tool block. The tool call IS the response.
4. **RULE 41 PROSE LOOP:** After ANY successful destructive tool result (deploy/write/SQL/send), the NEXT turn MUST contain a tool_use block. Not prose describing the next step. Not a narration. A tool.

### ⛔ MID-TASK OFFLOAD GATE (when about to do 2+ similar inline operations)

3a. **RULE 267 GATE A OFFLOAD:** Am I about to do 2+ operations of the same type (SQL fixes, file edits, student lookups, ticket updates, etc.) where at least one doesn't block my next step? → **Run the 3-question test:** (1) 2+ similar ops? (2) independent of my next step? (3) executor can do autonomously? If YES to all 3 → **offload via `create_idea` (autonomous tier) and continue your critical path.** Do NOT serialize work the executor can absorb in parallel. Full rule: `clinerules_lookup(rule_id=267)`.

### ⛔ PRE-WRITE GATE (before write_to_file / replace_in_file)

5. **RULE 144 SERVER PATHS:** Does path start with `/etc/` `/var/` `/usr/` `/opt/` `/root/` `/srv/`? → **STOP.** Use `emsu-operations ssh_command` with `sudo tee` heredoc. Local file tools can NEVER write to server paths.
6. **RULE 42 SAFE DEPLOY:** For `/var/www/emtskills/` deploys → use `safe_deploy_file` MCP. It already reloads FPM. Do not deploy raw then separately reload.
6a. **RULE 271 VERIFY BEFORE WRITING INFRA CLAIMS:** Does my pending write (HANDOFF_NOTES, pickup prompt, runbook, ticket) contain ANY infrastructure state claim ("box is down," "needs reboot," "script doesn't exist," "TP=N caused freeze")? → **For EACH claim: did I run a tool THIS SESSION that verified it?** If no → run the verification tool NOW or remove the claim. **No SSH to the box = no claims about the box.** Full rule: `clinerules_lookup(rule_id=271)`.

### ⛔ PRE-SEND GATE (before imessage send_message / ops chat / student email)

7. **RULE 01 VOICE:** Would Ruben actually type this? No em dashes, no "the tech team," no "I've identified the root cause," no corporate speak. Talk TO the person IN the chat, not ABOUT them.
8. **RULE 02 NO APOLOGIES:** Is this student-facing email with apology language ("I'm sorry," "we apologize," "I regret")? → **STRIP IT.** Neutral acknowledgement + concrete fix action only.
9. **RULE 259 NO SPILLOVER:** Am I about to send to chat 55 (group chat)? → **GATE CHECK: does Jon or Vicky need this?** If the content is Cline technical work, infrastructure, code, LLM routing, bug analysis, SQL, deploy mechanics, clinerules, or system architecture → **FAILS. Do NOT send to group.** The default channel for Ruben-only Cline work is `attempt_completion`, not chat 55. Full rule: `clinerules_lookup(rule_id=259)`.

### ⛔ PRE-COMPLETION GATE (before attempt_completion)

9. **RULE 91 PICKUP PROMPT — BINARY GATE:** `result` MUST end with a 47-char U+2550 divider (COPY mechanically, do not retype: `═══════════════════════════════════════════════`), then `PICKUP PROMPT`, then divider → content. If missing → BROKEN, do not ship.
9a. **RULE 91 — NO FAKE IDEA NUMBERS:** Never write `IDEA-001`, `IDEA-002`. Always call `create_idea` for real integer IDs. Fake numbers = ticket cannot be looked up = thread stays open forever.
9b. **RULE 91 — EVERY #NNNN GETS A BRACKET:** Scan entire `result` (not just pickup prompt). Every `#NNNN` must have `[deployed|executing|queued|blocked|proposed|rejected|superseded]`. Bare number = STOP before shipping.
9c. **RULE 91 — OPEN THREADS + REFERENCE IDS MANDATORY:** Both sections MUST appear. Empty open-threads → write "None — [reason]". Every body idea cited in Reference IDs.
10. **RULE 29 RUBEN QUESTIONS:** Did Ruben ask a direct question? → Answer it INLINE in `result`. "I'll look into it" does not count.
11. **RULE 29 ACT, DON'T DEFER:** Did I list anything as "open thread" that I could do myself with a tool I have? → **DO IT NOW, don't list it.** Only genuine human-policy decisions stay open.
12. **RULE 91 NO PLACEHOLDERS:** Any literal `#NNNN`, `#0000`, `<task_id>`, `<timestamp PT>` in result? → **BROKEN.** Substitute real values.
13. **RULE 267 RECONCILE (if you filed ideas this task):** Before `attempt_completion`, call `list_decisions`/`get_idea_progress` for EVERY idea # filed. "I filed it, it's fine" is NOT a reconcile pass. Classify each: executed/in-progress/stuck/failed. Tag every filed idea with a disposition in result AND pickup prompt. **Add `(verified: <tool> returned "...")` for ideas reconciled THIS session.**

### ⛔ CONTEXT GATES (check token count in environment_details)

13. **RULE 119/120:** <300K tokens → work fully. 300K-499K → call `should_compress_now` once before next major tool call. ≥500K → call `cline_compress_session` NOW, then `attempt_completion`. Never shortcut work due to context size.

### ⛔ RECOVERY GATE (if you see "[ERROR] You did not use a tool")

14. **RULE 143 (v4, ceiling=10 post-reload):** Count CONSECUTIVE errors only (any successful tool resets streak). Strikes 1-8: recover by emitting a (simpler) tool silently. Strike 9: BAIL to `attempt_completion` with a pickup prompt — do NOT attempt a tenth tool. Strike 10 = YOLO death. ROOT CAUSE FIXED 2026-07-04: `maxConsecutiveMistakes` was hardcoded `{default:3}` in `dist/extension.js` (NOT exposed in UI). Patched to `{default:10}`. After VS Code reload, ceiling=10. Bail = ceiling - 1 = strike 9. Re-patch script: `~/Documents/Cline/scripts/patch_yolo_ceiling.sh`. Until reload, running extension still uses ceiling=3 (bail at strike 2).

### ⛔ PRE-PIVOT GATE (before switching away from an MCP server or declaring it "wedged")

15. **RULE 261 MCP FAILURE CLASSIFICATION:** Empty/error/"No valid session ID" from an MCP call → **STOP, do NOT declare "wedged" yet.** Classify: A=server down (ECONNREFUSED, restart don't retry), B=session expired ("No valid session ID"/401/403, re-init+retry ONCE, server is healthy), C=transport error (result missing/502, retry once after 5s), D=transient empty (retry once, don't declare wedge). ONE or TWO failures is NEVER a wedge — run the rule-258 3-gate check (empty? stale? cross-source verify?) first. Green in Cline settings ≠ valid session. Full rule: `clinerules_lookup(rule_id=261)`.

---

## ⛔ RULE 146 — READ THIS FIRST. Frankenstein-LLM routes EVERY LLM we own. Free-local models ARE the primary. Never suggest Claude/Anthropic as the default.

- `frankenstein-llm` is the ONE router for EVERY LLM: 7B/14B/32B/70B/120B/405B/235B, RunPods, DeepSeek, AND the paid heads (Sonnet, Opus, Fable-5). If we own it, Frankenstein routes it.
- **Cline is PRIORITY.** Executor/Orchestrator QUEUE behind it. Never the reverse.
- **Free-local-first IS the design.** A healthy free local box that can serve = serve from it. Only spill to paid when local is GENUINELY full (real saturation, not a false-offline probe).
- **A failed health probe does NOT mean a box is dead.** Check `/tmp/emsu_router_audit.log` for recent `picked=<model>` before calling anything dead.
- **NEVER suggest Claude/Anthropic/Sonnet/Opus as the model to use** unless Ruben explicitly asked. Anthropic models are LAST RESORT in the spill ladder. Suggesting them on an unrelated task is a rule violation.
- **CANONICAL CLINE ENDPOINT: `https://litellm.emsuniversity.com`** (Cloudflare tunnel → WOPR:4000). PERMANENT, reboot-surviving base URL. Do NOT use `http://127.0.0.1:4000` or localhost SSH tunnels — those die when the Mac→WOPR SSH tunnel drops. (Rule 250: never hand-edit `_FLAGSHIP_MEMBERS` for "box is down" — doorman + reactive quarantine handle liveness at runtime.)
- Full rule: `clinerules_lookup(rule_id=146)`. Cross-refs: 140 (verify routing live), 141 (MCP first), 148 (never pin raw 120B), 250 (no hardcoded LLM statuses).

---

## ⛔ COMPLETION COMPLIANCE — Rules 29 and 91 (details in PRE-COMPLETION GATE #9-12 above)

**Before EVERY `attempt_completion`:** Rule 91 (pickup prompt block required, 47-char U+2550 dividers, real idea #s not placeholders) + Rule 29 (act don't defer — Gate 0 test: "can I do this now?" If yes, DO IT, don't list it as open thread). Full rules: `clinerules_lookup(rule_id=91)`, `clinerules_lookup(rule_id=29)`.

---

## 🗣️ Communication & Voice
→ Trigger: writing student email, ops chat, iMessage, staff escalation, CTA, CC/BCC, tone, apology
→ Fetch all: `clinerules_list_by_topic("voice")`
- **Student-facing email** — R: 01,02,15,19,30,35,47,48,101,127,182,203,205
- **Ops chat / iMessage to staff** — R: 01,09,10,30,32,43,57,72,96,108,111,175,177,178,179,186,187,198,207,247,259
- **Staff escalation (Vicky/Jon/Ruben)** — R: 10,13,15,19,48,117
- **CTA / link formatting** — R: 47 (full URLs, no shortcuts)
- **CS-agent response-quality bug library** — R: 270 (consult before recycling wrong replies across Email/Chat/SMS/Ticket/Voice/To AI agents; 2-strike tripwire)

---

## 🤖 Agent Behavior & Autonomy
→ Trigger: deciding whether to act or escalate, filing ideas, agent self-supervision, capability gaps, Q-cards, confidence tiers
→ Fetch all: `clinerules_list_by_topic("agent")`
- **Act vs escalate gate** — R: 12,22,23,29,36,37,38,67,68,78,80,90,93,117,124,125,167,183,193,206,208,213,238,267 (267=orchestrator/executor mid-task offload + end-of-task reconcile — the ASYNC sibling to rule 00's sync subagents)

- **Self-supervision & repair** — R: 46,49,53,54,55,56,64,65,66,73,81,82,85,92,94,110,112,129,130,131,133,134,162,163,166,168,169,176,180,194,209,214,225,240,244,258,261,263 (263=verify-before-claim: no stale inferences, no sycophantic agreement)
- **Routing to humans** — R: 68,69 (Jon=policy only, Vicky=CS only)
- **Agent-found-wrong** — R: 266 (fix the instrument that misled the agent, same session — RCA the tool/query, patch it, verify, record)
- **Parallel windows protocol** — R: 29 (§"wait them out" forbidden), 137, 194, 209, 225

---

## 💻 Infrastructure, Deploy & Debugging
→ Trigger: deploying code, editing server files, restarting services, SSH, WOPR, Mac, tunnels, LiteLLM, FPM, safe_deploy
→ Fetch all: `clinerules_list_by_topic("infrastructure")`
- **Safe deploy & FPM** — R: 41,42,118,144,174
- **SSH & WOPR access** — R: 71,77,95,136,235,245,248,249 (Artemis=emsu-operations MCP, never raw ssh; 245=verify host identity before declaring dead; 248=verify live state before declaring box/endpoint down — never trust stale canary/log; 249=MCP flapping/Cloudflare 502s → check supergateway --stateful + systemctl NRestarts FIRST, not the tunnel)
- **Fleet serving constraints** — R: 251 (Roman CX7 TP=2 ONLY — no TP=1 on Cesar/Cato or Julia/Claudia), 252 (stale-info live-probe gate — probe serving ports before declaring any host down; never trust fleet_inventory heartbeat alone), 253 (LLM location citation discipline — live-probe via `llm_locate`, cite WOPR endpoint not box port, never declare Ray worker down for no listener), 254 (verify-before-kill on GPU boxes — ps identity + fleet_inventory role check + live-probe endpoint before ANY `kill -9`/`pkill`; 43GB VRAM by VLLM::EngineCore is normal, not a wedge), 255 (verify-then-report gate: live evidence required for material claims), 271 (verify-before-writing infra claims — no SSH to box = no claims about box; mechanical gate before writing infra state to durable surfaces)
- **Mac-side debugging** — R: 16,20,24-28,34,62,63,83,100,102,104-106,165,181,184,185,188,191,192,195,197,201,210,222,226,234
- **Live-probe fleet state enforcement** — R: 260 (never trust error_watchdog for fleet health, always read LLM_FLEET_STATE.md + live-probe)
- **URL→docroot mapping** — R: 159 (emsuniversity.com/ems = /var/www/moodle/ems, NOT /var/www/emtskills/ems)
- **Connecteam is DEAD (decommissioned 2026-05-15)** — R: 246 (never recommend CT as a config surface; Team Hub is the replacement)
- **Fleet SSH access reference** — R: 268 (canonical SSH matrix, ports, IPs, passwords, diagnostic decision tree — never guess SSH paths)

---

## 🔬 Project Frankenstein & LLM Routing
→ Trigger: LLM routing question, model serving, spill ladder, frankenstein-llm, adapter, RunPod, context windows, cost
→ Fetch all: `clinerules_list_by_topic("frankenstein")`
- **Architecture & fleet** — R: 40,44,45,51,74-76,84,86-89,121,122,138-142,146,148-155,161,189,190,196,200,204,212,215,217,219-221,223,227-232,236,237,250
- **Bug library (diagnose FIRST)** — R: 156 + `bug_library_check_before_fix()`
- **Frankenstein Doctor (stuck window)** — R: 158,160,239 (Step 0b: consult Federation BEFORE bug_library — #16648, #16714, #16717)
- **Hardfloor don't-destroy** — R: 145,157 (never tear down TP=2 without permission)
- **Doorman output-quality gate** — R: 256 (streaming output validation + XML translation; Doorman = health + output quality, not just health)
- **The show must go on** — R: 257 (Doorman keeps bad LLMs out before they reach Cline; prose-no-tools gate, empty-content gate, capability gate)
- **Kaison autonomous repair** — R: 147,233
- **Check latest software before LLM deploy** — R: 269 (check NCCL/vLLM/CUDA/OFED versions + known regressions BEFORE any multi-node deploy)

---

## ✅ Task Hygiene & Context
→ Trigger: completing a task, pickup prompts, context compression, ledger, HANDOFF_NOTES, wrap-up, Order 66
→ Fetch all: `clinerules_list_by_topic("task")`
- **Completion shape** — R: 91 (pickup prompt required), EXECUTE_ORDER_66 (full wrap-up), 123, 126, 128, 180, 199, 211, 255 (verify-then-report gate: live evidence required for material claims), 263 (verify-before-claim: no factual claims without tool evidence)
- **Context management** — R: 115, 116, 119 (compress thresholds), 120 (never shortcut due to context)
- **Task tracking** — R: 03,04,05,06,07,09,52,109,113,218
- **Honest W/T eval method** — R: 171 (cross-family judge + position-swap + rubric + max_tokens room; required before any W/T number drives a flip)
- **Build convergence** — R: 137 (Definition-of-Done first)
- **Persisting corrections** — R: 46 (agent corrections → RUBEN/KAIZEN), 169 (knowledge-gap corrections → durable surfaces, don't re-learn)

---

## 💰 Payments, Refunds & Billing
→ Trigger: payment verification, refund, QuickBooks, Authorize.net, Affirm, invoice, credit, balance
→ Fetch all: `clinerules_list_by_topic("payment")`
- **Payment verification** — R: 70,107,114,195 + `verify_payment_state()` (Rule 33 aggregator)
- **Refund handling** — R: 29 (§money cap), 124, `find_authnet_by_email()`, `check_affirm_status()`
- **QB reconciliation** — R: `match_student_payment()` autonomous matcher

---

## 🎓 Student Lifecycle & Academics
→ Trigger: student status, enrollment, Moodle, exam, proctoring, externship, paperwork, integrity, grades, quiz
→ Fetch all: `clinerules_list_by_topic("student")`
- **Lifecycle state** — R: 79,125,128,135 (SLS) + `get_student_lifecycle_state()` (first move on any student issue)
- **Exam enforcement** — R: `emsu://reference/exam-retake-policy` (SEB+proctor+72hr), `check_exam_enforcement()`
- **NREMT under-18 policy** — R: `emsu://reference/nremt-under18-policy` (deadline extended to 18th birthday + 60-day refresher after 18; enforced in 4 crons; under-18 students are NOT past-deadline — never tell them to "test now")
- **Externship** — R: `emsu://reference/externship-agent`, `lookup_paperwork_state()` (rule 31)
- **Moodle enrollment repair** — R: `fix_moodle_enrollment()`, `unstick_moodle_quiz_attempt()`
- **Compliance** — R: 08,18,60,61,103 + `emsu://reference/student-status`
- **Grievance & exam-override** — R: 216 (grievance/override students populate for PD clearance)

---

## ⚡ YOLO & Failure Recovery
→ Trigger: YOLO mode, no-tool-use errors, timeouts, prose-loop, circuit breaker, tool failures
→ Fetch all: `clinerules_list_by_topic("yolo")`
- **Circuit breaker** — R: 143 (v4: ceiling=10 post-reload, bail at strike 9 = ceiling-1; pre-reload ceiling=3, bail at strike 2), 162 (self-loop breaker)
- **MCP failure classification** — R: 261 (4 modes before declaring "wedge" — server-down/session-expired/transport-error/transient-empty; 3-gate check before pivot), 258 (stale/empty data truth gate), 249 (MCP flapping: check supergateway --stateful FIRST)
- **Bug library + community search** — R: 262 (consult bug library + GitHub/Stack Overflow before recycling debugging approaches; 2-strike tripwire)
- **Per-class playbook** — R: 99 (auto-generated: no-tool-use, timeout, ssh, replace_in_file, permission denied...), 165 (invalid JSON arg), 170 (own-error → repair or RCA+file)
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
2. **Fetch by topic** via `clinerules_list_by_topic(...)`, or by number via `clinerules_lookup(rule_id=N)`.
3. **Hardfloor rules (★) are always loaded** (00,29,41,91,119,120,143,144 + _INDEX.md + _RULE_TREE.md). All other rules are one lookup away.
4. **MCP resources are separate** from cline rules — cross-reference both for operational policies (exam, payment, externship).

**Self-check:** "Does a trigger in this tree match what I'm about to do?" If yes → fetch that branch first.

## 🌱 Adding New Rules — Keep The Tree Alive

**When you create a new cline rule, you MUST also update this tree.** A rule not in the tree is invisible to future windows. Steps: (1) classify into a domain, (2) add rule number to the relevant `R:` line, (3) reindex MCP (`node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only`), (4) verify emsu:// resource cross-refs if any. Placement rules of thumb: specific tool/command → Infrastructure; specific agent behavior → Agent Behavior; specific workflow → Payments; general behavior → Task Hygiene or Agent Behavior (default).

Full dated changelog history: `Rules-archive/_RULE_TREE_CHANGELOG.md` (trimmed 2026-07-11, idea #17168, G7 compliance). 143-collision fix: CFA rule renumbered 272 (271 collided). Counter=272.

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

9. **RULE 91 PICKUP PROMPT — BINARY GATE:** Does `result` end with `═══ PICKUP PROMPT ═══`? If NO → **BROKEN. DO NOT SHIP.** Add the block.

   **COPY-PASTE THIS DIVIDER (do NOT retype it — copy mechanically):**
   ```
   ═══════════════════════════════════════════════
   ```
   That is 47 characters of U+2550 (BOX DRAWINGS DOUBLE HORIZONTAL, ═). NOT ASCII equals. NOT hyphens. NOT dashes. COPY it mechanically — do not retype.

   **The full required block shape (copy this template):**
   ```
   ═══════════════════════════════════════════════
   PICKUP PROMPT (paste into a fresh Cline window)
   ═══════════════════════════════════════════════

   Pick up task #[real id] — [one-line topic].
   ```
   Both divider lines are the SAME 47-char U+2550 string. If they differ, the block is broken.
10. **RULE 29 RUBEN QUESTIONS:** Did Ruben ask a direct question? → Answer it INLINE in `result`. "I'll look into it" does not count.
11. **RULE 29 ACT, DON'T DEFER:** Did I list anything as "open thread" that I could do myself with a tool I have? → **DO IT NOW, don't list it.** Only genuine human-policy decisions (refund amounts, regulator wording) stay open.
12. **RULE 91 NO PLACEHOLDERS:** Any literal `#NNNN`, `#0000`, `<task_id>`, `<timestamp PT>` in result? → **BROKEN.** Substitute real values or remove.
13. **RULE 267 RECONCILE (if you filed ideas this task):** Before `attempt_completion`, did you call `list_decisions`/`get_idea_progress` for EVERY idea # you filed to the Orchestrator? "I filed it, it's fine" is NOT a reconcile pass. A reconcile pass is a tool call returning real status. Classify each: executed/in-progress/stuck/failed. Stuck/failed → fix inline (rule 29) or re-file. Tag every filed idea with a rule-109 disposition in the result AND pickup prompt.

### ⛔ CONTEXT GATES (check token count in environment_details)

13. **RULE 119/120:** <300K tokens → work fully. 300K-499K → call `should_compress_now` once before next major tool call. ≥500K → call `cline_compress_session` NOW, then `attempt_completion`. Never shortcut work due to context size.

### ⛔ RECOVERY GATE (if you see "[ERROR] You did not use a tool")

14. **RULE 143 (v4, ceiling=10 post-reload):** Count CONSECUTIVE errors only (any successful tool resets streak). Strikes 1-8: recover by emitting a (simpler) tool silently. Strike 9: BAIL to `attempt_completion` with a pickup prompt — do NOT attempt a tenth tool. Strike 10 = YOLO death. ROOT CAUSE FIXED 2026-07-04: `maxConsecutiveMistakes` was hardcoded `{default:3}` in `dist/extension.js` (NOT exposed in UI). Patched to `{default:10}`. After VS Code reload, ceiling=10. Bail = ceiling - 1 = strike 9. Re-patch script: `~/Documents/Cline/scripts/patch_yolo_ceiling.sh`. Until reload, running extension still uses ceiling=3 (bail at strike 2).

### ⛔ PRE-PIVOT GATE (before switching away from an MCP server or declaring it "wedged")

15. **RULE 261 MCP FAILURE CLASSIFICATION:** Did an MCP tool call return empty, "No valid session ID", "result missing", or an error? → **STOP. Do NOT pivot yet. Do NOT declare "wedged."** Classify the failure into exactly one of 4 modes FIRST, then act:

   | Mode | Symptom | Recovery |
   |---|---|---|
   | **A: Server down** | ECONNREFUSED, connection refused | Restart server. Do NOT retry same call. |
   | **B: Session expired** | "No valid session ID", 401/403 | **Re-init connection, retry ONCE.** Server is HEALTHY — session token just expired. |
   | **C: Transport error** | "result missing", empty body, 502 | Check NRestarts. Retry ONCE after 5s. |
   | **D: Transient empty** | First call empty, second works | **Retry ONCE.** Was transient. Do NOT declare wedge. |

   **ONE failure is NOT a wedge. TWO failures is NOT a wedge.** Run the 3-gate check (rule 258): (1) is result actually empty? (2) is it stale? (3) cross-source verify via different path (ssh, different MCP). All 3 must FAIL before declaring wedge. **"No valid session ID" = Mode B = re-init + retry, NOT a pivot.** Green in Cline settings ≠ valid session. Full rule: `clinerules_lookup(rule_id=261)`. See Issue #24 in `MCP_Troubleshooting.md` for the full RCA.

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
- **Mac-side debugging** — R: 16,20,24,25,26,27,28,34,62,63,83,100,102,104,105,106,165,181,184,185,188,191,192,195,197,201,210,222,226,234
- **Live-probe fleet state enforcement** — R: 260 (never trust error_watchdog for fleet health, always read LLM_FLEET_STATE.md + live-probe)
- **URL→docroot mapping** — R: 159 (emsuniversity.com/ems = /var/www/moodle/ems, NOT /var/www/emtskills/ems)
- **Connecteam is DEAD (decommissioned 2026-05-15)** — R: 246 (never recommend CT as a config surface; Team Hub is the replacement)
- **Fleet SSH access reference** — R: 268 (canonical SSH matrix, ports, IPs, passwords, diagnostic decision tree — never guess SSH paths)

---

## 🔬 Project Frankenstein & LLM Routing
→ Trigger: LLM routing question, model serving, spill ladder, frankenstein-llm, adapter, RunPod, context windows, cost
→ Fetch all: `clinerules_list_by_topic("frankenstein")`
- **Architecture & fleet** — R: 40,44,45,51,74,75,76,84,86,87,88,89,121,122,138,139,140,141,142,146,148,149,150,151,152,153,154,155,161,189,190,196,200,204,212,215,217,219,220,221,223,227,228,229,230,231,232,236,237,250
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

**Older changelog (2026-06-22 to 2026-07-06) archived.** Key additions in that window: rules 162, 165, 170, 174, 216, 218, 233, 239, 246, 248, 250, 253, 254, 255, 258. Full details in git history. Highlights:
- 2026-06-22 — initial tree (7 domains, 2 levels).
- 2026-07-01 — WINDOW 4: full rebuild, deduped archive, ~100+ rule numbers added across all 8 domains.
- 2026-07-03 — rule 250 (no hardcoded LLM statuses) + canonical Cline endpoint documented.
- 2026-07-05 — rule 255 (verify-then-report gate).
- 2026-07-06 — rule 258 (MCP stale/empty data truth gate, 3-gate check).

2026-07-07 — updated rule 239 (Frankenstein Doctor) Step 0b: consult Frankenstein Federation before bug_library. Source: Ruben directive.

2026-07-08 — added Rule 261 (MCP failure classification: 4 modes before declaring "wedge") as new MANDATORY GATE #15 (PRE-PIVOT GATE). Also added to YOLO & Failure Recovery > MCP failure classification (new sub-topic) + Agent Behavior > Self-supervision & repair. Fixed Rule 143 cross-ref formatting. Source: Issue #24 RCA — agents falsely declared "MCP is wedged" after 1-2 transient failures. Rule 261 provides 4-mode classification + 3-gate check (rule 258) before declaring wedge. Idea #16849.

2026-07-10 — added Rule 263 (verify-before-claim: no stale inferences, no sycophantic agreement) to Agent Behavior > Self-supervision & repair + Task Hygiene > Completion shape. Source: Frankenstein Doctor postmortem — Cline window on frankenstein-llm (120B+LoRA) fabricated a Google Sheets import pipeline from a vestigial DB column + legacy dir, wrong student count (9 vs 5), non-existent function, and responded to Ruben's correction with sycophantic agreement. Root cause: LoRA trained on contaminated distill corpus (69 google_sheet_row + 62 google-sheets-to-mysql-migration refs). Fixes: (1) stale-ref filter in build_distill_corpus.py, (2) VERIFY-BEFORE-CLAIM block in _router_core.py steering injection, (3) distill corpus rebuilt clean, (4) this rule. LoRA retraining filed as idea #16949. Bug library: distill_lora_stale_reference_contamination_2026_07_10.

2026-07-10 — added Rule 264 (The Foreman: persistent dual-window autonomous engineering pattern) to Agent Behavior > Self-supervision & repair. Source: Ruben directive — "have a different window that babysits the issues and fixes what it can continuously... use Frankenstein LLM in a cline window to drive this forward and not give up... call it 'The Foreman'." Pattern: Worker (free local Frankenstein-LLM) works nonstop, Supervisor (paid cloud GLM-5.2/Claude) checks every 30 min and course-corrects. Both windows don't close until task done or genuine error.

2026-07-10 — added Rule 265 (Spatial/Analogy Thinking Protocol: when stuck, reframe and think sideways) to Agent Behavior > Self-supervision & repair + Task Hygiene > Completion shape. Source: Ruben directive — "you need to think more spatially... if you can't resolve an issue head on, what other analogous things would resolve the problem... when you get stuck or really stuck, rather than giving up." 6-step protocol: (1) reframe spatially, (2) think analogously, (3) apply the analogy, (4) acquire info until you know, (5) persevere at the precipice, (6) think in parallel. Source incident: GLM-5.2 RoCE QP hang — after 4 linear attempts failed, spatial analysis revealed root cause (same subnet on different physical cables), fix was unique /30 per cable (postal zip code analogy).

2026-07-10 — added Rule 267 (Offload independent sub-work to RUBEN Orchestrator/Executor mid-task, then reconcile before completion) to Agent Behavior & Autonomy > Act vs escalate gate. Distinguishes from rule 00 (synchronous subagents): rule 267 is the ASYNC lever — file deferrable, independent sub-units to the Orchestrator (`create_idea`, autonomous tier) and continue the critical path, then run a mandatory reconciliation pass before `attempt_completion` (check every filed idea's status, fix stuck/failed ones inline, disposition-tag per rule 109). Source: Ruben directive — "All Cline Agents MUST leverage/use Orchestrator/Executor to speed up processing of tasks during iteration," with proposed add-on "come back at the end of the task to cleanup any tasks sent to orchestrator/executor."

2026-07-10/11 — Fixed pre-existing rule-number collisions at 260 (2 files) and 266 (3 files) in Rules-archive. Renumbered orphan files: `260-fleet-ssh-access-reference.md` → 268, `266-check-latest-software-before-llm-deploy.md` → 269, `266-cs-agent-response-quality-bug-library.md` → 270. Canonical holders (`260-live-probe-fleet-state-enforcement.md`, `266-agent-found-wrong-fix-the-instrument.md`) unchanged. Counter bumped 267→270. Tree updated with new entries: 268 (Infrastructure > SSH & WOPR access), 269 (Frankenstein & LLM Routing > Kaison autonomous repair area), 270 (Communication & Voice). Source: Ruben directive "Yea fix all that."

2026-07-10 (later) — Added matching "exploratory/open-ended discovery is inline-only" addendum to BOTH rule 00 (sync subagents) and rule 267 (async Orchestrator/Executor offload). Neither dispatch lever can drive open-ended "help me figure out what I even need to look at" work — subagents have no fetch tools to iterate on live data, and the Orchestrator/Executor runs a fixed fire-and-forget plan with no mid-chain feedback channel to redirect based on findings. Both rules now state: exploratory/scoping work stays inline and iterative (fetch→read→refetch) until it converges to a concrete bounded scope; only THEN is dispatch (sync or async) legal. Source: Ruben directive — "so then how would we modify the rule then to cover -> They don't cover 'help me figure out what I even need to look at' — that's still an inline, sequential job" — clarified to apply to rule 267, not rule 00 alone, so both got the addendum for consistency.

2026-07-11 — Rule 267 compliance rewrite. Three changes for greater agent compliance: (1) Added new MANDATORY GATE "MID-TASK OFFLOAD GATE" (gate #3a) to _RULE_TREE.md — this is the structural trigger Gate A was missing; it fires when an agent is about to do 2+ similar inline operations, making the offload decision mechanically detectable instead of a judgment call. (2) Rewrote rule 267 with a concrete 3-question offload test (2+ similar ops? independent? executor can do?) replacing the vague "when you identify 2+ independent work units" trigger. (3) Moved 2 addendums (tool-bug findings, drift safeguards, ~25 lines) from the hardfloor rule to 267-case-law.md to de-bloat the core gates — the rule went from 126 lines to ~85 lines, making Gate A and Gate B more prominent. Source: Ruben directive — "i was looking for greater agent compliance and use of the rule."

2026-07-11 — Added Rule 271 (verify-before-writing infra claims) as new MANDATORY GATE #6a (PRE-WRITE GATE) to _RULE_TREE.md. Also added to Infrastructure > Fleet serving constraints. Source: 2026-07-11 stale-info RCA — a Cline session wrote "Julia needs physical reboot" and "serve script does not exist" to HANDOFF_NOTES + pickup prompt + runbook WITHOUT any SSH verification. Julia was never frozen (16 days uptime, idle). Existing rules 248/252/263 say "verify before claiming" but are advisory — agents keep disregarding them because nothing mechanically blocks the write. Rule 271 closes the gap: verification is a PREREQUISITE for the write, not a recommendation. "No SSH to the box = no claims about the box." Ruben: "This needs to be bulletproof for even the simplest minded agent."

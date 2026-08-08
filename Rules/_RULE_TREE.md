# Rule Tree — Proactive Trigger Guide

**How to use:** When you're about to do something in ANY of the trigger categories below, fetch that branch FIRST. Each domain has a `clinerules_list_by_topic(...)` command that returns the full rules. Key rule numbers are listed inline for instant lookup. **This file is auto-loaded into every Cline window.**

---

## ⛔⛔⛔ MANDATORY GATES — FAIL ANY = BROKEN. NO EXCEPTIONS. ⛔⛔⛔

**Every hardfloor rule is a binary gate at a specific trigger point. Read the relevant gate BEFORE the action. No gate = no action.**

**Trimmed 2026-08-08 (idea #25150).** Gates for HARDFLOOR rules are one-line pointers, because those rule bodies are already loaded IN FULL in this same system prompt — restating them here was pure duplication that pushed the floor past its own G8 block. Gates for ARCHIVED rules keep their full text, because those bodies are NOT loaded and the gate is the only thing standing between you and the mistake.

### ⛔ Hardfloor gates (full text already loaded above — this is just the trigger index)

| Trigger moment | Rule | The gate in one line |
|---|---|---|
| Before first tool call | 00 | Multi-step / multi-file / multi-system? → dispatch `use_subagents` FIRST (fetch-then-paste; subagents have NO MCP/web/ssh) |
| Before ANY tool call | 41 | Turn ends with `:` and no tool block → BROKEN. Prose is never a turn. |
| After any destructive tool result | 41 | NEXT turn must contain a tool block, not a narration of the next step |
| About to do 2+ similar ops | 267 | 3-question offload test → `create_idea` autonomous, continue critical path |
| Before write_to_file/replace_in_file | 144 | Path starts `/etc/ /var/ /usr/ /opt/ /root/ /srv/` → STOP, use `ssh_command` |
| Before any send | 01 | Would Ruben type this? No em dashes, no fake departments, talk TO people in-thread |
| Before student email | 02 | Strip all apology language. Neutral acknowledgement + fix action. |
| Before chat 55 | 259 | Cline technical work does NOT go to the group. Default channel is `attempt_completion`. |
| Before attempt_completion | 91 | 47-char U+2550 divider + PICKUP PROMPT + real ids with `[disposition]` + open threads + reference ids |
| Before attempt_completion | 29 | Could I do this myself with a tool I have? → DO IT, don't list it as an open thread |
| Before attempt_completion | 267 | Reconcile EVERY filed idea with a live call; tag with `(verified: ...)` |
| Every turn start | 119 | Check `/tmp/cline_compress_signal_TASK<id>.json` FIRST. File says compress → compress, zero deliberation. |
| Any turn | 120 | Context size is NEVER a reason to do less work. Compress or work fully. |
| On "you did not use a tool" | 143 | Count CONSECUTIVE only. Strikes 1-8 recover with a simpler tool. Strike 9 = bail to `attempt_completion`. |
| Anomalous count / diagnosis | 297 | Classify the population + read the source before alarming. Scope the question before quantifying. |
| Task says "end to end" | 300 | No handoff when the tools to finish are present. A filed idea is not a deliverable. |
| Any new steer | 301 | The newest steer IS the task. Re-anchor in one line, then act on it. |
| Subagent reports a write | 99 | Unverified until the parent re-reads the file back |

### ⛔ Archived-rule gates (bodies NOT loaded — full text kept here on purpose)

**RULE 146 NEVER CLAUDE (before suggesting any model):** `frankenstein-llm` is the ONE router for EVERY LLM we own (7B → 405B, RunPods, DeepSeek, and the paid heads). **Free-local-first IS the design** — a healthy local box that can serve, serves. Only spill to paid on genuine saturation, never on a single failed probe (check `/tmp/emsu_router_audit.log` for a recent `picked=<model>` before calling anything dead). **Never suggest Claude/Anthropic/Sonnet/Opus** unless Ruben explicitly asked. Cline is PRIORITY; executor/orchestrator queue behind it. Canonical endpoint: `https://litellm.emsuniversity.com` (Cloudflare tunnel → WOPR:4000), never `127.0.0.1:4000`. Full: `clinerules_lookup(rule_id=146)`. Cross-refs: 140, 141, 148, 250.

**RULE 42 SAFE DEPLOY (before /var/www deploys):** use `safe_deploy_file` MCP. It ALREADY reloads FPM — do not deploy raw then separately reload.

**RULE 271 VERIFY BEFORE WRITING INFRA CLAIMS (before writing any infra state claim):** for EACH claim ("box is down," "needs reboot," "script doesn't exist"), did I run a tool THIS SESSION that verified it? If no → verify now or delete the claim. **No SSH to the box = no claims about the box.**

**RULE 175 NO STAFF IMESSAGE (before any send to chats 5/55/64/84/88/3750 or anyone but Ruben):** can I quote Ruben's words asking me to send this ("send," "tell," "ping," "let her know," "forward," "loop in")? If NO → do not send. Offer it in `attempt_completion` instead. This supersedes all confidence-tier autonomy.

**RULE 261 MCP FAILURE CLASSIFICATION (before declaring any MCP "wedged"):** classify first. A=server down (ECONNREFUSED → restart, don't retry). B=session expired ("No valid session ID"/401/403 → re-init + retry ONCE, server is healthy). C=transport error (result missing/502 → retry once after 5s). D=transient empty (retry once). One or two failures is NEVER a wedge. Green in Cline settings ≠ valid session.

**GATE D CONCRETE-TOOL-PATH + COPY-WINDOW FORMAT:** every copy-window step must cite a concrete tool path (e.g. `read_server_file("routes/x.php")`); zero tool paths = a prose prompt, not a copy window. Wrap copy windows in a fenced ```text block with `——[COPY]——` / `——[/COPY]——` markers. Full spec: `91-copy-window-format` (archive).

---


## 🗣️ Communication & Voice
→ Trigger: writing student email, ops chat, iMessage, staff escalation, CTA, CC/BCC, tone, apology
→ Fetch all: `clinerules_list_by_topic("voice")`
- **Student-facing email** — R: 01,02,15,19,30,35,47,48,101,127,182,203,205
- **Ops chat / iMessage to staff** — R: 01,09,10,30,32,43,57,72,96,108,111,175,177,178,179,186,187,198,207,247,259
- **Staff escalation (Vicky/Jon/Ruben)** — R: 10,13,15,19,48,117
- **CTA / link formatting** — R: 47 (full URLs, no shortcuts)
- **Ruben's electronic signature** — R: 301 (canonical file `signature2small.jpg`, NEVER extract from another PDF)
- **REGULATOR RESPONSES (AZDHS/TDSHS/BPPE/CAPCE/any agency)** — R: 302 (defensive posture, never volunteer admissions/intervals/commitments/remedies, never repeat their numbers, never restate the allegation, never adopt their premise, consolidate-and-keep-consolidating, accompanying-document consistency gate, disclaimed observation, concede-then-narrow, contemporaneous-record framing, third-party attestation, no links + flattened-extraction verification, courtesy framing wording, grace-period deadline math, enclosure pattern) + `NoiDefenseEvidence.php`
- **TDSHS / TEXAS COMPLAINTS specifically** — R: 304 (the 8/6 gold standard: section order skeleton, public-interest opening, the outset ledger, Ruben's regulator tone register, the 7-point Texas externship design defense, the Texas citation set incl. 157.32(p)(21)(F) and (u)(1)(A)/(u)(3), threshold-objection form, arrival record, per-matter letters incorporate-never-duplicate). Read 304 BEFORE drafting any TDSHS response. + `ComplianceRefs.php`

- **CS-agent response-quality bug library** — R: 270 (consult before recycling wrong replies across Email/Chat/SMS/Ticket/Voice/To AI agents; 2-strike tripwire)

---

## 🤖 Agent Behavior & Autonomy
→ Trigger: deciding whether to act or escalate, filing ideas, agent self-supervision, capability gaps, Q-cards, confidence tiers
→ Fetch all: `clinerules_list_by_topic("agent")`
- **Act vs escalate gate** — R: 12,22,23,29,36,37,38,67,68,78,80,90,93,117,124,125,167,183,193,206,208,213,238,267,279,282,283,295 (295=ship lane-clearing/regression fixes inline never queue; 267=async offload+reconcile; 279=tool-grant IS a mandate to act; 282=CFAs must resolve, not triage; 283=no human-only-research deferrals)
- **Self-supervision & repair** — R: 46,49,53,54,55,56,64,65,66,73,81,82,85,92,94,99,110,112,129,130,131,133,134,162,163,166,168,169,176,180,194,209,214,225,240,244,258,261,263,281,297,299 (263=verify-before-claim; 99=subagent writes unverified until parent re-reads; 281=execute-the-real-function schema-truth gate; 297=a COUNT(*) of impossible rows is a hypothesis, classify the population before alarming; 299=a NEGATIVE/zero result proves your query ran, not that the thing is absent — positive-control the instrument before any "none/not found/0/clean" claim)
- **Routing to humans** — R: 68,69 (Jon=policy only, Vicky=CS only)
- **Agent-found-wrong** — R: 266 (fix the instrument that misled the agent, same session)
- **Pre-EDIT guard-comment gate** — R: 314 (before changing ANY existing constant/timeout/threshold/flag, read the 20 lines ABOVE it and run `guard_check.sh <file> <line>`; exit 2 = STOP. KAIZEN structurally cannot cover this class because the code is still CORRECT at the moment of the mistake. Measured 2026-08-08: 5 guard signals + 3 dated incident refs sat above the line that was changed anyway)

- **Cline noop idempotency gate** — R: 274 (noop_check BEFORE any possibly-repeat task; store after)
- **Parallel windows protocol** — R: 29 (§"wait them out" forbidden), 137, 194, 209, 225

---

## 💻 Infrastructure, Deploy & Debugging
→ Trigger: deploying code, editing server files, restarting services, SSH, WOPR, Mac, tunnels, LiteLLM, FPM, safe_deploy
→ Fetch all: `clinerules_list_by_topic("infrastructure")`
- **Safe deploy & FPM** — R: 41,42,118,144,174
- **SSH & WOPR access** — R: 71,77,95,136,235,245,248,249 (Artemis=emsu-operations MCP never raw ssh; 245 verify host identity before declaring dead; 248 live-verify before declaring down; 249 MCP flapping → check supergateway --stateful + systemctl NRestarts FIRST)
- **Fleet serving constraints** — R: 251 (Roman CX7 TP=2 ONLY), 252 (live-probe before declaring any host down), 253 (cite WOPR endpoint not box port), 254 (verify-before-kill on GPU boxes), 255 (live evidence for material claims), 271 (no SSH to box = no claims about box), 294 (re-probe INHERITED infra facts; read `/var/www/emtskills/docs/WOPR_STATE.json`, freshness <10min)
- **Mac-side debugging** — R: 16,20,24-28,34,62,63,83,100,102,104-106,165,181,184,185,188,191,192,195,197,201,210,222,226,234
- **Cline extension model-list patching** — R: 293 (TWO bundle files: dist/extension.js AND webview-ui/build/assets/index.js, 5 object-contexts each, Node indexOf-splice never grep/sed, Restart Extension Host)
- **Live-probe fleet state** — R: 260 (never trust error_watchdog; read LLM_FLEET_STATE.md + probe), 296 (never declare an LLM dead from a cached probe field; confirm with live ground truth), 280 (no up/down claim without a quoted live probe; litellm restarts ONLY via /usr/local/bin/litellm-safe-restart.sh)
- **URL→docroot mapping** — R: 159 (emsuniversity.com/ems = /var/www/moodle/ems)
- **Connecteam is DEAD (2026-05-15)** — R: 246 (Team Hub is the replacement)
- **Fleet SSH reference** — R: 268 (canonical SSH matrix/ports/IPs — never guess), 292 (verify IP/identity ON-BOX via hostname+MAC before trusting static tables incl. 268/273; WOPR can't route the LAN, sweep from the Mac)
- **Parallel transfer + parallelism mandate** — R: 274 (multi-node rsync/tar/xargs -P, 4-5x faster), 275 (ALL agents/tools MUST use parallel streams; 3-question test before building any new agent/tool)

## 🔬 Project Frankenstein & LLM Routing
→ Trigger: LLM routing question, model serving, spill ladder, frankenstein-llm, adapter, RunPod, context windows, cost
→ Fetch all: `clinerules_list_by_topic("frankenstein")`
- **Architecture & fleet** — R: 40,44,45,51,74-76,84,86-89,121,122,138-142,146,148-155,161,189,190,196,200,204,212,215,217,219-221,223,227-232,236,237,250
- **Bug library (diagnose FIRST)** — R: 156, 278, 262 (2-strike tripwire), 305 (multi-angle sweep + induction + keyword-rich recording) + `bug_library_check_before_fix()`
- **Federation/Doorman runbook** — R: 276 (consult runbook + bug library BEFORE diagnosing routing)
- **Frankenstein Doctor (stuck window)** — R: 158,160,239 (Step 0b: Federation BEFORE bug_library)
- **Hardfloor don't-destroy** — R: 145,157 (never tear down TP=2 without permission)
- **GLM-5.2 Hexarchy PP=6 ring** — R: 273 (6 nodes: Cato/Aug/Pompey/Marcus/Tib/Cesar; PP=6 ONLY)
- **GLM-5.2 launch UMA+JIT fix (MANDATORY)** — R: 277 (VLLM_ENGINE_READY_TIMEOUT_S=1800 + gpu_memory_utilization=0.82, do NOT lower; v20 script only)
- **Doorman output-quality gate** — R: 256 (streaming validation + XML translation), 257 (keep bad LLMs out before they reach Cline)
- **Kaison autonomous repair** — R: 147,233
- **Check latest software before LLM deploy** — R: 269 (NCCL/vLLM/CUDA/OFED versions + known regressions)

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
- **Lifecycle state** — R: 79,125,128,135 + `get_student_lifecycle_state()` (FIRST move on any student issue)
- **Certificate blockers (MANDATORY traceback)** — R: 303 (walk the simplecertificate `cm.availability` tree recursively: completion + grade + grouping conditions, check `simplecertificate_issues` for an already-issued cert, NEVER send a flat quiz list or a paperwork-catalog gap as a "blocker")
- **Exam enforcement** — `emsu://reference/exam-retake-policy` (SEB+proctor+72hr), `check_exam_enforcement()`
- **NREMT under-18** — `emsu://reference/nremt-under18-policy` (deadline → 18th birthday + 60-day refresher; under-18 students are NOT past-deadline)
- **Externship** — `emsu://reference/externship-agent`, `lookup_paperwork_state()` (rule 31)
- **Moodle repair** — `fix_moodle_enrollment()`, `unstick_moodle_quiz_attempt()`
- **Compliance** — R: 08,18,60,61,103 + `emsu://reference/student-status`
- **Grievance & exam-override** — R: 216

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
| `emsu://reference/student-status` | Lifecycle: transfers, drops, fails, Moodle suspension |
| `emsu://reference/quickbooks` | Payment rules, 50/50 split, finance fees, QB sync |
| `emsu://reference/exam-enforcement` | Violation thresholds, SEB proctoring, excluded emails |
| `emsu://reference/exam-retake-policy` | CANONICAL: Final Exam + retake need SEB + proctored Zoom |
| `emsu://reference/nremt-under18-policy` | CANONICAL: under-18 deadline → 18th birthday + 60-day refresher. Read BEFORE any under-18 NREMT reminder |
| `emsu://reference/telephony` | Twilio + Vapi stack, numbers, NO third-party vendor |
| `emsu://reference/externship-agent` | Externship scheduling, agency profiles, self-service |
| `emsu://reference/shift-architecture` | Shifts, Team Hub, pickup, Zoom routing |
| `emsu://docs/handoff-notes` | HANDOFF_NOTES.md — current system state |
| `emsu://docs/copilot-instructions` | Architecture, DB creds, server paths, deploy procedures |

---

## 🔍 Using this tree

Scan the trigger lines above before acting. Match = fetch that branch FIRST via
`clinerules_lookup(rule_id=N)` or `clinerules_list_by_topic(topic="...")`.
Hardfloor rules (★) are always loaded; everything else is one lookup away.
MCP `emsu://` resources are separate from rules — cross-reference both.

**Renumbered 2026-08-08 (idea #25188) — collision cleanup.** Eleven numbers each had
TWO different rules. Nine were genuine distinct rules that had collided (a rule number
is a filename prefix, and nothing enforced uniqueness), so `clinerules_lookup(N)`
returned whichever file sorted first: a coin flip. The tree-cited rule KEPT its number;
its twin was renumbered. One (296) was a true duplicate and was retired to Rules-backups/.

| was | now | rule |
|---|---|---|
| 255 | **306** | cx7-tp2-cluster-operations-runbook |
| 273 | **307** | student-certificate-issued-means-done |
| 274 | **308** | parallel-distributed-file-transfer |
| 275 | **309** | cicero-ssh-access-and-wireguard |
| 278 | **310** | afk-mode-needs-verify-auto-deploys |
| 281 | **311** | regulator-response-playbook |
| 298 | **312** | router-reporting-must-resolve-adapter-names |
| 91 | **313** | refund-offer-not-act |
| 296 dup | retired | never-declare-llm-dead-from-cached-probe (kept the -an-llm- variant) |

`29-case-law.md` and `41-addenda.md` intentionally share their parent's number: they are
companion files to a hardfloor rule, not separate rules. That is the trim-then-archive
pattern, not a collision.

**Adding a rule?** New rules go in `Rules-archive/` by default (see `_INDEX.md`

"Adding a new rule" for the caps, the trim-then-archive pattern, and the 5 steps).
You MUST add the new number to the right `R:` line above or it is invisible to
future windows. Then reindex:
`node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only`

Full dated changelog + the long-form versions of these two sections:
`Rules-archive/_RULE_TREE_CHANGELOG.md`
Updates Rule Tree

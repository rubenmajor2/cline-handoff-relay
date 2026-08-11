# _RULE_TREE.md — Changelog Archive

Full dated changelog history moved out of `~/Documents/Cline/Rules/_RULE_TREE.md` on 2026-07-11 (idea #17168) to bring the always-loaded tree file under the 20KB meta-file G7 cap. The live file keeps only the current trigger-tree + mandatory gates; this file is the historical record of how the tree evolved.

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

2026-07-11 (later) — Rule 271's slug collided with archived rule `271-customer-facing-agentic-definition.md` at the SAME number after the 143-prefix collision fix bumped the counter to 271 and claimed that number for the renamed CFA rule. NOTE FOR NEXT WINDOW: verify this did not create a NEW collision — check whether rule 271 (verify-before-writing infra claims) already existed as a hardfloor/archive file BEFORE this session's counter bump to 271, and if so, renumber the CFA file to 272 instead.

2026-07-11 — _RULE_TREE.md trimmed from 29,206 bytes to restore G7 20KB meta-file compliance (idea #17168). This changelog file created to hold the full dated history; the live tree now carries only a cross-reference note.


---

# 2026-07-26 — G7 20KB meta-cap trim (idea #19162, hand-shipped per rule 267 GATE C)

Removed from the always-loaded `Rules/_RULE_TREE.md` to bring it under the
documented 20,480-byte G7 meta hard cap. Every rule NUMBER and trigger keyword
was preserved in the live tree; only prose elaboration moved here.


## How To Use This Tree + Adding New Rules (verbatim, moved 2026-07-26)

```markdown
## 🔍 How To Use This Tree

1. **Scan triggers before acting.** If your next action matches a domain trigger, fetch that domain's rules FIRST.
2. **Fetch by topic** via `clinerules_list_by_topic(...)`, or by number via `clinerules_lookup(rule_id=N)`.
3. **Hardfloor rules (★) are always loaded** (00,29,41,91,119,120,143,144 + _INDEX.md + _RULE_TREE.md). All other rules are one lookup away.
4. **MCP resources are separate** from cline rules — cross-reference both for operational policies (exam, payment, externship).

**Self-check:** "Does a trigger in this tree match what I'm about to do?" If yes → fetch that branch first.

## 🌱 Adding New Rules — Keep The Tree Alive

**When you create a new cline rule, you MUST also update this tree.** A rule not in the tree is invisible to future windows. Steps: (1) classify into a domain, (2) add rule number to the relevant `R:` line, (3) reindex MCP (`node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only`), (4) verify emsu:// resource cross-refs if any. Placement rules of thumb: specific tool/command → Infrastructure; specific agent behavior → Agent Behavior; specific workflow → Payments; general behavior → Task Hygiene or Agent Behavior (default).

Full dated changelog history: `Rules-archive/_RULE_TREE_CHANGELOG.md` (trimmed 2026-07-11, idea #17168, G7 compliance). 143-collision fix: CFA rule renumbered 272 (271 collided). Counter=272.

```

## MCP Resources table (long-form descriptions, moved 2026-07-26)

```markdown
| Resource URI | What It Covers |
|
```

## Infrastructure domain section (long-form, moved 2026-07-26)

```markdown
## 💻 Infrastructure, Deploy & Debugging
→ Trigger: deploying code, editing server files, restarting services, SSH, WOPR, Mac, tunnels, LiteLLM, FPM, safe_deploy
→ Fetch all: `clinerules_list_by_topic("infrastructure")`
- **Safe deploy & FPM** — R: 41,42,118,144,174
- **SSH & WOPR access** — R: 71,77,95,136,235,245,248,249 (Artemis=emsu-operations MCP, never raw ssh; 245=verify host identity before declaring dead; 248=verify live state before declaring box/endpoint down — never trust stale canary/log; 249=MCP flapping/Cloudflare 502s → check supergateway --stateful + systemctl NRestarts FIRST, not the tunnel)
- **Fleet serving constraints** — R: 251 (Roman CX7 TP=2 ONLY — no TP=1 on Cesar/Cato or Julia/Claudia), 252 (stale-info live-probe gate — probe serving ports before declaring any host down; never trust fleet_inventory heartbeat alone), 253 (LLM location citation discipline — live-probe via `llm_locate`, cite WOPR endpoint not box port, never declare Ray worker down for no listener), 254 (verify-before-kill on GPU boxes — ps identity + fleet_inventory role check + live-probe endpoint before ANY `kill -9`/`pkill`; 43GB VRAM by VLLM::EngineCore is normal, not a wedge), 255 (verify-then-report gate: live evidence required for material claims), 271 (verify-before-writing infra claims — no SSH to box = no claims about box; mechanical gate before writing infra state to durable surfaces), 294 (READ-side twin of 271: re-probe any INHERITED infra fact — pickup prompt, HANDOFF, idea body, sibling window — before repeating or acting on it; read `/var/www/emtskills/docs/WOPR_STATE.json` + freshness-check `generated_epoch` <10min; flip superseded ideas same session. Cross-window split-brain gate)
- **Mac-side debugging** — R: 16,20,24-28,34,62,63,83,100,102,104-106,165,181,184,185,188,191,192,195,197,201,210,222,226,234
- **Cline extension model-list patching** — R: 293 (add/upgrade a Claude model in Cline's Settings dropdown — TWO bundle files must both be patched: dist/extension.js AND webview-ui/build/assets/index.js, 5 object-contexts each, use Node.js indexOf-splice never grep/sed, trigger Developer: Restart Extension Host instead of asking for a VS Code restart)
- **Live-probe fleet state enforcement** — R: 260 (never trust error_watchdog for fleet health, always read LLM_FLEET_STATE.md + live-probe), 280 (NO routing/LLM up-down claim without a live probe quoted `(verified: ...)` in the same message; litellm restarts ONLY via /usr/local/bin/litellm-safe-restart.sh — raw `systemctl restart litellm` banned)
- **URL→docroot mapping** — R: 159 (emsuniversity.com/ems = /var/www/moodle/ems, NOT /var/www/emtskills/ems)
- **Connecteam is DEAD (decommissioned 2026-05-15)** — R: 246 (never recommend CT as a config surface; Team Hub is the replacement)
- **Fleet SSH access reference** — R: 268 (canonical SSH matrix, ports, IPs, passwords, diagnostic decision tree — never guess SSH paths), 292 (verify box IP/identity ON-BOX via hostname+MAC cross-check BEFORE trusting static IP tables incl. 268/273; WOPR can't route the LAN — sweep from the Mac; UDM API never located)
- **Parallel distributed file transfer** — R: 274 (multi-node rsync, tar pipes, xargs -P, nc pipe — 4-5x faster than single rsync for bulk data)
- **System-wide parallelism mandate** — R: 275 (ALL AI agents, tools, data ops MUST use parallel streams — 3-question test before building ANY new agent/tool; complete inventory of 31 parallelism targets)

---


```


## 2026-07-26 pass 2 — further G7 trim (idea #19162 hand-ship)

Rule NUMBERS and trigger keywords preserved verbatim in the live tree; only
per-rule prose elaboration moved here (it duplicates clinerules_lookup output).

### Agent Behavior domain (long-form parentheticals)

```markdown
## 🤖 Agent Behavior & Autonomy
→ Trigger: deciding whether to act or escalate, filing ideas, agent self-supervision, capability gaps, Q-cards, confidence tiers
→ Fetch all: `clinerules_list_by_topic("agent")`
- **Act vs escalate gate** — R: 12,22,23,29,36,37,38,67,68,78,80,90,93,117,124,125,167,183,193,206,208,213,238,267,279,282,283 (267=orchestrator/executor mid-task offload + end-of-task reconcile — the ASYNC sibling to rule 00's sync subagents; 279=tool-grant IS a mandate to act — has-the-tool-but-escalated = rule-29 violation; "build a tool" asks imply wire + trigger + verified live invocation; 282=CFAs MUST resolve underlying issues — handoff is NOT an excuse for inaction; every ticket gets an action pass per full capability set, bugs get resolved not triaged, backlogs get backfilled; 283=no human-only-research deferrals — discoverable facts get researched and acted on by the agent)

- **Self-supervision & repair** — R: 46,49,53,54,55,56,64,65,66,73,81,82,85,92,94,99,110,112,129,130,131,133,134,162,163,166,168,169,176,180,194,209,214,225,240,244,258,261,263,281 (263=verify-before-claim: no stale inferences, no sycophantic agreement; 99=subagent writes unverified until parent re-reads — false-success guard; 281=execute-the-real-function schema-truth gate: run the real decision function + DESCRIBE the real table + grep logs for SQLSTATE bursts BEFORE theorizing — comments claiming CORRECTED have zero evidentiary weight (TX zoom 25-day cycling incident))
- **Routing to humans** — R: 68,69 (Jon=policy only, Vicky=CS only)
- **Agent-found-wrong** — R: 266 (fix the instrument that misled the agent, same session — RCA the tool/query, patch it, verify, record)
- **Cline noop idempotency gate** — R: 274 (call noop_check MCP BEFORE starting any task that might be a repeat; skip if should_skip=true; store after completion)
- **Parallel windows protocol** — R: 29 (§"wait them out" forbidden), 137, 194, 209, 225


```

### Frankenstein domain (long-form parentheticals)

```markdown
## 🔬 Project Frankenstein & LLM Routing
→ Trigger: LLM routing question, model serving, spill ladder, frankenstein-llm, adapter, RunPod, context windows, cost
→ Fetch all: `clinerules_list_by_topic("frankenstein")`
- **Architecture & fleet** — R: 40,44,45,51,74-76,84,86-89,121,122,138-142,146,148-155,161,189,190,196,200,204,212,215,217,219-221,223,227-232,236,237,250
- **Bug library (diagnose FIRST)** — R: 156, 278 (treasure trove: failed ideas are raw material for breakthroughs), 262 (2-strike tripwire for recycling failed approaches) + `bug_library_check_before_fix()`
- **Federation/Doorman runbook** — R: 276 (consult runbook + bug library BEFORE diagnosing routing; 3-layer architecture, key invariants, diagnostic commands)
- **Frankenstein Doctor (stuck window)** — R: 158,160,239 (Step 0b: consult Federation BEFORE bug_library — #16648, #16714, #16717)
- **Hardfloor don't-destroy** — R: 145,157 (never tear down TP=2 without permission)
- **GLM-5.2 Hexarchy PP=6 ring membership** — R: 273 (6 nodes: Cato/Aug/Pompey/Marcus/Tib/Cesar; Julia/Claudia NOT in ring; PP=6 ONLY never PP=5/PP=4)
- **GLM-5.2 launch UMA+JIT fix (MANDATORY)** — R: 277 (VLLM_ENGINE_READY_TIMEOUT_S=1800 + gpu_memory_utilization=0.82 PROVEN — do NOT lower; v20 script only; bug library #1754/#1755)
- **Doorman output-quality gate** — R: 256 (streaming output validation + XML translation; Doorman = health + output quality, not just health)
- **The show must go on** — R: 257 (Doorman keeps bad LLMs out before they reach Cline; prose-no-tools gate, empty-content gate, capability gate)
- **Kaison autonomous repair** — R: 147,233
- **Check latest software before LLM deploy** — R: 269 (check NCCL/vLLM/CUDA/OFED versions + known regressions BEFORE any multi-node deploy)


```

### Student Lifecycle domain (long-form)

```markdown
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


```

## 2026-08-08 (idea #25188) — collision cleanup: full was/now mapping

Moved out of `Rules/_RULE_TREE.md` on 2026-08-11 for G8 floor-cap compliance.
Eleven numbers each held TWO different rules. A rule number is only a filename
prefix and nothing enforced uniqueness, so `clinerules_lookup(N)` returned
whichever file sorted first: a coin flip. The tree-cited rule KEPT its number;
its twin was renumbered. One (296) was a true duplicate and was retired.

| was | now | rule |
|---|---|---|
| 255 | **306** | cx7-tp2-cluster-operations-runbook |
| 273 | **307** | student-certificate-issued-means-done |
| 274 | **308** | parallel-distributed-file-transfer |
| 275 | **309** | cicero-ssh-access-and-wireguard |
| 278 | **310** | afk-mode-needs-verify-auto-deploys |
| 281 | **311** | regulator-response-playbook |
| 298 | **312** | router-reporting-must-resolve-adapter-names |
| 91  | **313** | refund-offer-not-act |
| 296 dup | ret| 296 dup | ret| 296 dup | ret| 296 dup | ret| 296 dup | ret| 296 dup | ret| 296 dm- var| 296 dup | ret| 296 dup | ret| 296 dup | ret| 296 dup | ret| 296 dup ntionally share
their parent's number: they are companion files to a hardfloor rutheir parent's number: they are companion files to a hardfloo, not a collision.

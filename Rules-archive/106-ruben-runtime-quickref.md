# 106 — RUBEN runtime quick reference (agents, crons, tables, kill switches)

Permanent rule. Workspace-scoped. Source: cline_learner_report.php topic frequency shows `ruben_ai = 324` (#1 topic across all Cline tasks). Most Cline work on this stack is RUBEN-orchestrator-adjacent (executor, scanners, KAIZEN, Fleet Agent, Personnel Agent). Cline keeps re-deriving the runtime from scratch via grep loops across `/var/www/emtskills/cron/`. This rule documents the runtime so Cline doesn't have to.

If you're about to SSH to WOPR to figure out "wait, which cron owns this?" — read this rule first. It's a reference card, not prose.

## 1. Agents — who does what

| Agent | Primary entrypoint | Kill switch (`orchestrator_config.config_json`) | Audit table | One-liner |
|---|---|---|---|---|
| **RUBEN Executor** | `/var/www/emtskills/cron/cron_ruben_autonomous.php` | `ruben_autonomous_enabled` | `orchestrator_execution_log` + `session_handoffs` | Reads approved chains/ideas, runs pre-approved plans, auto-self-heals via failure_repair_recipes |
| **RUBEN Implementer** | `/var/www/emtskills/cron/cron_ruben_implement.php` | `ruben_brain_expansion_enabled` | `orchestrator_execution_log` | Builds approved orchestrator_ideas via the build pipeline |
| **RUBEN Back-Repair** | `/var/www/emtskills/cron/cron_ruben_back_repair.php` | `ruben_back_repair_enabled` | `orchestrator_event_log` | Self-heals stuck/failed prior executions |
| **KAIZEN classifier** | (MCP-driven, no cron — `crghmr0mcp0kaizen_*`) | n/a (config in `failure_repair_recipes`) | `failure_repair_recipes` + `orchestrator_learned_patterns` | Classifies executor failures, proposes recipes |
| **Fleet Agent** | `/var/www/emtskills/cron/cron_fleet_agent.php` | `fleet_maintenance_eval_enabled` + `fleet_segment_action_enabled` | `fleet_decision_log` + `orchestrator_llm_routes` | Auto-flips LLM routes when shadow win-rate ≥55% w/ cross-judge gate |
| **Personnel Agent** | `/var/www/emtskills/cron/cron_personnel_agent.php` (+ MCP `check_personnel_pipeline`) | `personnel_agent_enabled` | `personnel_candidates` + `candidate_events` | Onboarding pipeline for new staff |
| **Bug Hunter** | `~/.ruben-ai/bug_hunter.py` (Mac launchd) | n/a (Mac-side; disable plist to halt) | `orchestrator_learned_patterns` (pattern_hash starts `bug_`) | Synthetic regression tests against student-facing surfaces |
| **Email AI** | `/var/www/emtskills/cron/cron_email_responder.php` + `lib/EmailAIResponder.php` | (no global switch — per-rule gating in `ai_compiled_rules`) | `email_inbound_log` + `email_outbound_log` + `email_ai_leak_log` | Drafts student/staff replies, scrubs leaks |
| **Voice AI** | Vapi cloud (config in `vapi_assistants` + `vapi_persona_config`) | per-persona `voice_persona_lock` | `voice_call_log` + `voice_call_recap_log` + `voice_call_resolutions` | Phone agents (CS Bella/Katie/Eric/Ronald + Ruben TNG line) |
| **Chat AI** | `/var/www/emtskills/api/chat_widget_api.php` + `lib/widget_force_handoff.php` | `chat_force_handoff_enabled` | `chat_portal_visitor_sessions` + `cs_chat_messages` | Public chat widget on emtskills sites |
| **Ticket Agent** | `/var/www/emtskills/cron/cron_ai_ticket_agent.php` + `lib/ai_ticket_agent.php` | `ticket_agent_first_touch_enabled` | `tickets` + `ai_ticket_agent_actions` + `ticket_agent_first_touch_log` | Universal first-touch on every ticket (per .clinerules/97) |
| **Grievance AI** | `/var/www/emtskills/cron/cron_ai_grievance_agent.php` | `gv_auto_approve_full_cycle_enabled` | `grievances` + `grievance_comments` | Drafts dispositions; sends only when kill switch is ON |
| **AB Grader** | `/var/www/emtskills/cron/cron_llm_ab_grader.php` | (rate-limit + budget in `orchestrator_config`) | `orchestrator_llm_shadow_log` | Grades shadow LLM calls vs primary, cross-judge gated |
| **Cross-Judge Babysitter** | `/var/www/emtskills/cron/cron_cross_judge_babysitter.php` | `ab_grader_cross_judge_enabled` + `fleet_cross_judge_gate_enabled` | `orchestrator_event_log` | Watches Fleet flips for bias bypass |
| **Mini-Pool Workers** | Mac-mini distributed workers (claim from `emsu_compute_jobs`) | n/a per-worker (kill via API) | `emsu_compute_jobs` + writeback tables | Distributed compute for OCR / link-probe / quality-scan / cross-judge |

## 2. Critical crons table (top 20)

| Cron | Schedule | What it does | Log |
|---|---|---|---|
| `cron_ruben_autonomous.php` | */5 min | RUBEN executor tick | `/var/log/cron_ruben_autonomous.log` |
| `cron_ruben_implement.php` | */5 min | Idea → build pipeline | `/var/log/cron_ruben_implement.log` |
| `cron_ai_ticket_agent.php` | */10 min | Universal ticket first-touch (rule 97) | `/var/log/cron_ai_ticket_agent.log` |
| `cron_email_responder.php` | */10 min | Email AI drafts + sends | `/var/log/emsu_email_ai.log` |
| `cron_voice_agent_health.php` | */30 min | Voice agent + Vapi health probe | `/var/log/cron_voice_agent_health.log` |
| `cron_externship_health_score.php` | daily 03:00 PT | Externship completion scoring | `/var/log/cron_externship_health_score.log` |
| `cron_fleet_agent.php` | */15 min | LLM routing flip decisions + maintenance | `/var/log/cron_fleet_agent.log` |
| `cron_mini_pool_refill.php` | */5 min | Queues new compute jobs for mini workers | `/var/log/cron_mini_pool_refill.log` |
| `cron_mini_pool_writeback.php` | */5 min | Drains done jobs into smart-loop tables | `/var/log/cron_mini_pool_writeback.log` |
| `cron_heartbeat_watchdog.php` | */10 min | Cron heartbeat freshness + auto-rerun (rule 81) | `/var/log/cron_heartbeat_watchdog.log` |
| `cron_chat_widget_healthcheck.php` | */30 min | Chat widget embed presence on all sites | `/var/log/cron_chat_widget_healthcheck.log` |
| `cron_chat_force_handoff_watchdog.php` | */10 min | Hard-escalation regression watchdog (rule 09) | `/var/log/cron_chat_force_handoff_watchdog.log` |
| `cron_ai_grievance_agent.php` | hourly | Grievance disposition drafting | `/var/log/cron_ai_grievance_agent.log` |
| `cron_prompt_rule_compiler.php` | 02:00 PT | Nightly recompile of `ai_compiled_rules` (preserves `clinerules:`-tagged) | `/var/log/cron_prompt_rule_compiler.log` |
| `cron_lora_fleet_collector.php` | */5 min | LoRA smoke tests + Runpod spend reconciliation | (writes to `lora_smoke_tests` + `runpod_spend_log`) |
| `cron_llm_ab_grader.php` | hourly | Shadow grading + win-rate rollups | `/var/log/llm-ab-grader.log` |
| `cron_cross_judge_babysitter.php` | */5 min | Cross-judge bypass detector (rule 88) | `/var/log/cron_cross_judge_babysitter.log` |
| `cron_mini_pool_health.php` | */15 min | Mac mini fleet health (rule 57) | `/var/log/cron_mini_pool_health.log` |
| `cron_zoom_daily_routing.php` | hourly | Zoom shift routing to Hub (rule 71) | `/var/log/cron_zoom_daily_routing.log` |

## 3. Critical tables

| Table | What lives there |
|---|---|
| `orchestrator_learned_patterns` | KAIZEN classifications + Bug Hunter findings + cline_learner output (`event_type` LIKE `cline_*` / `bug_*` / etc.) |
| `failure_repair_recipes` | Per-failure-class retry strategies (rule 22) |
| `orchestrator_ideas` | The idea funnel — proposed → approved → in_progress → deployed |
| `orchestrator_event_log` | Universal event firehose — every agent writes here |
| `orchestrator_execution_log` | RUBEN executor per-chain attempts (failure_category column drives rule 22) |
| `orchestrator_llm_routes` | Primary + shadow model per task_kind (Fleet Agent owns) |
| `orchestrator_llm_shadow_log` | A/B graded calls (cron_llm_ab_grader writes here) |
| `ai_compiled_rules` | Prompt-layer runtime rules (protect with `source_correction_ids LIKE 'clinerules:%'`) |
| `session_handoffs` | Multi-step build chains (`slug`, `status`, `approval_tier`, `whats_pending`) |
| `ruben_questions` | Q-cards filed by .clinerules/05/12 (portal: `ruben_questions.php`) |
| `tickets` | Student-facing tickets (Ticket Agent first-touch per rule 97) |
| `ticket_comments` | Internal + external ticket conversation (is_internal flag) |
| `communication_log` | Universal student/staff comm record (all channels) |
| `email_outbound_log` | Every outbound email (postmark_message_id, body, etc.) |
| `email_inbound_log` | Every inbound email + AI classification result |
| `email_ai_leak_log` | Post-compose scanner hits (rules 15, 19, 96) |
| `email_quality_scores` | Mini-pool quality scan output |
| `Students` | EMSU student of record (canonical email, class, enrollment) |
| `bls_students` | BLS/CPR program enrollment (separate from EMT — rule 66) |
| `emd_simulation_attempts` | EMD program (separate, rule 66) |
| `ce_students` | Continuing-education program (separate, rule 66) |
| `emsu_compute_jobs` | Mac-mini compute job queue (rule 57 smart-loop) |
| `emsu_preference_corpus` | RAG retrieval corpus (rule 50) |
| `cron_heartbeat_registry` | Cron health registry (rule 81 + 42) |
| `cline_task_running_log` | Per-task milestone log (rule 81 running log) |
| `voice_call_log` / `voice_call_recap_log` / `voice_call_resolutions` | Vapi call records |

## 4. Kill switches (all in `orchestrator_config.config_json`)

| Key | Default | Disables |
|---|---|---|
| `ruben_autonomous_enabled` | true | RUBEN executor entirely |
| `ruben_brain_expansion_enabled` | true | RUBEN idea-build pipeline |
| `ruben_back_repair_enabled` | true | RUBEN back-repair self-heal |
| `fleet_maintenance_eval_enabled` | true | Fleet Agent maintenance auto-fires |
| `fleet_segment_action_enabled` | true | Fleet Agent per-intent route flips |
| `fleet_cross_judge_gate_enabled` | true | Cross-judge gate on Fleet flips (rule 88) |
| `ab_grader_cross_judge_enabled` | true | AB grader cross-judge on Anthropic-vs-Anthropic |
| `gv_auto_approve_full_cycle_enabled` | false | Grievance auto-send (always off by default — rule 61) |
| `ticket_agent_first_touch_enabled` | true | Ticket Agent universal first-touch (rule 97) |
| `emsu_rag_enabled` | true | RAG context injection in Cline router (rule 50) |
| `chat_force_handoff_enabled` | true | Chat AI hard-escalation triggers (rule 09) |
| `student_ai_rag_enabled` | per-intent | RAG on student-facing AI (Fleet auto-flips at 55%+ W+T per-intent) |

Reverse any kill switch with one SQL: `UPDATE orchestrator_config SET config_json=JSON_SET(config_json,'$.<key>',true) WHERE id=1`.

## 5. MCPs and their canonical-first-call wrappers

| MCP namespace | When to reach for it |
|---|---|
| `emsu-operations` (most everything EMSU) | Student lookups, ticket ops, Moodle queries, FPM reloads, safe-deploy, telephony, externship, grievance, personnel, Team Hub (rule 71) |
| `ruben-orchestrator` | Ideas, decisions, events, patterns, configuration, activity feed |
| `ruben-control` | RUBEN issue tracker (iMessage-side issues, fix dispositions) |
| `kaizen` | Failure classifier nurturing, recipe seeding (rule 23) |
| `imessage` | Staff chat read/send (rules 30, 57, 81 — gate-heavy) |
| `mysql` | Last-resort raw SQL (when no wrapper fits — rule 32 says try the wrapper first) |
| `github` | Repo / PR / issue ops |
| `google-drive` | EMSU Drive files (zoom recordings, student docs) |
| `context7` | Vendor library docs lookup |
| `brave-search` | Web search when grepping Reddit / vendor docs (rule 45 addendum) |

For specific EMSU lookups, the cheat sheet is in .clinerules/32 matrix. Don't write raw SQL when a wrapper exists.

## 6. Where to grep when a question comes up

| Question | First place to look |
|---|---|
| "Is X broken?" | `error_watchdog` MCP (ruben-orchestrator) — covers PHP errors, voice outages, API health |
| "What does the policy say about Y?" | `call_ollama` with 7B-LoRA (rule 40 v3) — fine-tuned on EMSU corpus |
| "Who owns this surface?" | This rule — agents table § 1 |
| "Which cron does Z?" | This rule — crons table § 2 |
| "Where is the audit trail for [action]?" | This rule — tables § 3 (look at the agent in §1, then its audit table) |
| "How do I turn off [autonomous behavior]?" | This rule — kill switches § 4 |
| "What's the canonical reply for student question X?" | `ai_compiled_rules` WHERE `source_correction_ids LIKE 'clinerules:%'` OR query 7B-LoRA per rule 40 |
| "Did Cline already handle this?" | `cline_task_running_log` WHERE task_id (rule 81) + `cline_task_ledger.md` |
| "Did RUBEN already try this?" | `orchestrator_execution_log` + `session_handoffs` joined on slug |
| "Did a student/staff complain about this?" | `communication_log` WHERE recipient/sender + ORDER BY created_at DESC |

## Self-check before grepping

Before I run `grep -r 'foo' /var/www/emtskills/cron/`, ask: *"Is this in rule 106?"* If yes, look at the table here first. Saves 30s and an SSH round-trip. If the answer is genuinely not here, update this rule when you find it.

## Cross-references

- `.clinerules/22` — executor self-supervision loops (RUBEN classification + recipe flow)
- `.clinerules/23` — KAIZEN MCP
- `.clinerules/29` — agents act on confidence tier (the action gate this whole runtime is built around)
- `.clinerules/32` — prefer dedicated MCP wrappers over raw SQL/SSH
- `.clinerules/36` — orchestrator self-heal vs escalation
- `.clinerules/42` — proactive systemic solutions + heartbeat registry
- `.clinerules/46` — every agent correction loops back to RUBEN + KAIZEN
- `.clinerules/57` — Mac-mini onboard + smart-loop pipeline
- `.clinerules/67/68/73` — agents exhaust autonomy + surface capability gaps + close them
- `.clinerules/81` — RUBEN silent on ops chat = Cline babysits + running log
- `.clinerules/87` — Fleet Agent autonomous build authority + opportunity cost math
- `.clinerules/88` — cross-judge required when same-family Anthropic
- `.clinerules/94` — train agents, don't fix FOR them
- `.clinerules/97` — Ticket Agent universal first-touch
- `.clinerules/104` — pipeline freshness self-check
- `.clinerules/105` — turn-0 sanity check

## Last updated

2026-05-19 — initial rule per Ruben directive in cline_learner_report.php review. Filed at status=approved per .clinerules/38 + 93. This rule will drift as the stack evolves — update it when you find a runtime element that's not here yet.

# HANDOFF_NOTES.md — Archived Entries

Archived 2026-07-11 (idea #17169) to bring the always-loaded `HANDOFF_NOTES.md` under a reasonable size — it was 28,990 bytes with zero cap enforcement, consuming huge system-prompt space on every Cline task. This file holds the older entries; the live file keeps only the most recent entry + this cross-ref.

---
## [2026-07-08 17:42 PT] Frankenstein Doctor — RUBEN executor: 4 error classes fixed, throughput 5x, patient recovering

### Patient + diagnosis
**Patient:** RUBEN autonomous executor (cron_ruben_autonomous.php + RubenExecutor.php). **Symptom:** events_24h=68,161 but decisions_24h=0 — workers spawned but died on 4 error classes before completing chains → zero throughput. Ruben directive: "increase throughput 5x, babysit it, correct these dumb errors, they should be in the bug library."

### The 4 error classes (root-cause cluster) + fixes shipped

**1. system-param error (execution_log 277175, 277168) — RESOLVED**
- `messages.0: use the top-level 'system' parameter; the effort-only form (content: []) is accepted at any position`
- **Root cause:** RubenExecutor.php line 2315 appends `['role'=>'assistant','content'=>$content]` where `$content` can be `[]` (empty on 400/empty-200/transport blip). Next loop iteration sends `content:[]` back → Anthropic rejects it. Compounded by `executor_via_frankenstein=OFF` (hit Anthropic passthrough directly) + `spill_models=NULL` (no DeepSeek/local-120B before paid).
- **Core fix (deployed 17:29 PT):** Empty-content guard in generatePlan loop — if `content:[]`, substitute `[['type'=>'text','text'=>'(no content returned)']]` before appending. Backup: `RubenExecutor.php.bak-frankendoctor-20260708-172857`. FPM reloaded.

**2. PLANNED_ACTIONS_JSON empty (277173) — RESOLVED**
- `model did not return a valid PLANNED_ACTIONS_JSON block (retry also failed). First response: || Retry response:` (both empty)
- **Root cause:** Same as #1 — model returned empty on both attempts because `executor_via_frankenstein=OFF` (Anthropic passthrough failing). NOT a JSON-parsing bug.
- **Core fix:** Same as #1 (executor_via_frankenstein=ON routes through local fleet OAI path returning real content).

**3. worker_silent_death writeback (277172) — PARTIAL FIX, idea #16838 filed**
- `[shutdown-guard: worker died after completing work with 10629 output tokens. Stamped executed at 2026-07-08 17:17:45]`
- **Root cause:** Worker completed LLM work but PHP process reaped (timeout/OOM) before `finalizeLog()` stamped `outcome=executed`. Bug #724's `register_shutdown_function` only fires on the SAME process; a reaped process cannot run it.
- **Partial fix:** Cron raised to */1 (more ticks, shorter work windows). **Full fix filed as idea #16838** (writeback watchdog: rows with `output_tokens>0 + execution_ended_at=NULL` older than 2min → stamp executed).

**4. safe_write render leak user_profile.php (277170) — idea #16839 filed**
- `safe_write gate: routes/user_profile.php :: render leak (html_page_no_chrome_with_output): pre-chrome='Invalid user id'`
- **Root cause:** False positive. `user_profile.php` outputs "Invalid user id" when accessed without auth — legitimate auth-gate, NOT a render leak. Dynamic headless render executes without auth context, misclassifies. Same class as #1404/#1372 (reports.php).
- **Fix filed as idea #16839:** Add `user_profile.php` to `$__churnAggregators` exempt list in `cron_ruben_implement.php` (alongside reports.php/report_registry.php).

### Throughput increases (5x target)
- `ruben_parallel_chains`: 10 → **50** (config_json)
- Cron interval: `*/2` → **`*/1`** (/etc/cron.d/emsu-ruben-autonomous)
- `executor_via_frankenstein`: OFF → **ON** (local fleet $0, not Anthropic passthrough — the biggest throughput lever, eliminates paid-billing bottleneck)
- `ruben_executor_planner_spill_models`: NULL → **`frankenstein-tools,cesar-120b,artemis-gpt-oss-120b,deepseek-v4-pro,ollama-14b`** (DeepSeek BEFORE paid Anthropic per Ruben directive)

### Frankenstein Federation (rule 239 Step 0b) — monitor was BROKEN, fixed
- `cron_frankenstein_federation_monitor.php` probed ports 8001-8004 (phantom — no services there) → falsely reported "4/4 unreachable, degraded" → may cause eager paid spill.
- **Fixed:** ports corrected to 11510 (fleet-tools adapter), 11506 (cesar/cato CX7 120B), 11513 (joshua 70B), 4000 (LiteLLM paid-claude liveliness).
- **Missing tables created:** `federation_alert_log` + `federation_health_snapshots` (monitor was failing to log alerts/snapshots with "Table doesn't exist").

### Verification (patient recovering — rule 140 live evidence)
- **277184 executed** (17:28 PT) — first completed chain post-fix.
- **277187 executed** (17:36 PT) — second completed chain.
- **NO PLANNED_ACTIONS_JSON failures after 17:30** (post-FPM-reload). The 2 failures at 17:26/17:28 (277182/277183) were pre-fix.
- **NO system-param errors after 17:30.**
- Cron firing every */1 min (syslog confirmed).
- Config verified: `executor_via_frankenstein=true`, `spill_models` set, `parallel=50`.
- 1 new non-original error post-fix (277186: `Can't connect to server on '10.100.0.2'` — a DB/Moodle connection issue on a destructive step, NOT a throughput bug; legitimate chain failure).

### Bug library (rule 156) — ALL 4 RECORDED with solutions
Inserted into `frankenstein_router_incidents` (created_by='frankenstein_doctor'):
1. `executor_empty_assistant_content_system_param_2026_07_08` [resolved]
2. `executor_planned_actions_json_empty_2026_07_08` [resolved]
3. `executor_worker_silent_death_writeback_regression_2026_07_08` [investigating]
4. `safe_write_render_leak_user_profile_false_positive_2026_07_08` [investigating]

### Kaizen recipes — ALL 4 SEEDED
Inserted into `failure_repair_recipes` (enabled=1):
1. `planner_no_json_empty_response` (replan_compact, max_attempts=2)
2. `worker_silent_death_writeback` (exponential_backoff_30_60_120, max_attempts=2)
3. `safe_write_render_leak_auth_gate` (escalate_blocked, max_attempts=0)
4. `empty_assistant_content_system_param` (replan_compact, max_attempts=2)

### Original task #1778 (ruben_cron_guard.php schema mismatch) — DONE by prior window
- `lib/ruben_cron_guard.php` already fixed (idea #16827 shipped): uses `JSON_SET`/`JSON_EXTRACT` on `config_json` blob (id=1), not the non-existent `config_key`/`config_value` columns.
- `orc_chain_240_enabled` flag = `"1"` (verified).
- Cron firing every */1 min (syslog confirmed): `(www-data) CMD (/usr/bin/php /var/www/emtskills/cron/cron_ruben_autonomous.php)`.

*(Phases 2-9 of this same Frankenstein Doctor session, 17:42 PT through 21:33 PT on 2026-07-08, tracked throughput ramp from 0/hr to 480-564/hr, fixed a dispatcher spawn bottleneck (idea #16845), cataloged 10 total bugs in frankenstein_router_incidents with 5 resolved/5 investigating, seeded 5 kaizen recipes, backfilled 59 rows, re-queued 70+ transient-failed ideas, and promoted 4,228 ideas to autonomous tier. Full phase-by-phase detail available in git history for HANDOFF_NOTES.md prior to 2026-07-11.)*

---
## [2026-07-10 16:08 PT] Cicero 235B RESTORED to service + all merge items complete

### 235B status: SERVING
- Qwen3-235B-A22B-Thinking-2507 3bit-DWQ MLX on Cicero :11520 (launchd com.emsu.cicero, KeepAlive)
- LoRA adapter cicero-reasoning-v0 mounted
- Inference verified: reasoning trace + 46 tokens on test prompt
- Fixes applied: HF cache dir created (~/.cache/huggingface/hub), model symlink (active-3bitdwq → archived-models/cicero-235b-qwen3)
- WOPR reachability: reverse SSH tunnel (launchd com.emsu.cicero-235b-tunnel)
- Git: both machines share history (main @ latest), GitHub relay restored via deploy keys
- Learner report: cline_learner_report.php push loop wired on Cicero (wopr SSH alias added)
- Auto-sync: cron on Cicero (:15/:45), sync.sh on PH (hourly), both push GitHub

**NOTE (2026-07-11):** the original text of this entry in HANDOFF_NOTES.md contained visibly corrupted/duplicated text in the "LiteLLM registry" and "LLM_FLEET_STATE" lines (repeated garbled fragments like "LiteLLM registry:- LiteLLM registry:..." many times over). This archive preserves a cleaned reconstruction of the readable portions; the corrupted raw lines were NOT fabricated-in — they were simply omitted since their content was unreadable. If the original detail is needed, check git history for HANDOFF_NOTES.md around 2026-07-10.

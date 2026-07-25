HANDOFF_NOTES appended below. Existing notes preserved.

---
## [2026-07-23 14:15 PT] Window D closeout: alltastic agent-activity items a-f COMPLETE (item f = ticket_view digit-strip bug, fixed)

- Context: pickup of task 1784836559542 (closed mid-work 13:13 PT, steps 5-6 undone). Items a-e were done in the prior window; item f investigated + fixed + deployed this window.
- (a) #18783 [deployed] emsu-operations write_server_file destructive-shrink gate — verified live prior window (STEP 1c).
- (b) routes/alltastic_api.php source→mode bug fix — deployed prior window, php -l clean, 716-row WHERE verified. Backup /tmp/alltastic_api.php.bak-agentfix-20260723-131157 (WOPR).
- (c) activity whitelist UNION (argus_audit_log + argus_action_history) — verified prior window, 1547 rows. Backup /tmp/alltastic_api.php.bak-actwhitelist-20260723-130326.
- (d) routes/argus_download.php patch — deployed prior window. Backup /tmp/argus_download.php.bak-step3-20260723-130638.
- (e) UNION verified: 16 distinct users in audit_log, 4 in action_history.
- (f) TICKET ISSUES — ROOT CAUSE + FIX THIS WINDOW: Argus ticket_view (lib/argus_action_catalog.php case 'ticket_view') digit-stripped the query (`STU-20260720-1255A9` → '2026072012559', `TKT-48005AB6` → '480056') which never LIKE-matches dashed/hex real ticket_numbers, AND ignored the ticket_id arg entirely. Audit evidence: 13/16 all-time failures (7/8 in 72h); Ruben retried STU-20260720-1255A9 4x on 7/23. All 7 failing identifiers EXACT-match real rows in tickets (860 STU- series rows live there). FIX: raw exact UPPER match → raw LIKE → digit-strip fallback; honors ticket_id arg. Deployed 14:01 PT via /tmp/wd_tv_patch.php (backup lib/argus_action_catalog.php.bak-itemf-20260723-140158), php -l clean, FPM reloaded + OPcache cleared (fpm-reload wrapper). E2E verify 6/7 PASS — every previously-failing identifier resolves (incl. lowercase + ticket_id-arg + bare-numeric forms); the 1 "FAIL" was test expectation (digit-fallback fuzzy-matched a real ticket, same as old behavior, not a regression). ticket_search was never broken (0 fails).
- #18786 reconcile: core fix (dispatcher fake-sends) hand-shipped by sibling window 11:24 PT — VERIFIED live: tier-1 + expiry emails real-send via send_agent_draft_now.php, imessage queues via ruben_message_queue, cron.d */5 healthy, zero fake stamps post-fix, errors=0. Sandbox reconciliation script NOT deployed (references outbound_log table which does not exist — executor schema hallucination).
- NEW BACKLOG IDEA #18827 [proposed] P1: 92 fake-sent agent_drafts rows all-time with no delivery evidence (63 imessage w/o queue row, 28 email pre-fix, 1 ticket_reply). Gated reconciliation plan (<72h re-send, 72h-14d human review, >14d expire) — bulk auto-resend of weeks-old student emails is a human-policy call. Also flags residual else-branch fake-stamp risk for future non-email/non-imessage (e.g. sms) expiry drafts.
- #18787 (grievance classifier rebuild) — no longer stalled: deployed/ready_for_review (reconciled 13:44 PT).
- GATE-COLUMN FIX (this window): activity_log UNION now exposes rule29_gate — audit_log side derives pass/fail from success, action_history side passes through its real rule29_gate column. Verified: 227 pass / 32 fail in 24h, frontend Gate badge renders.
- CRITICAL BONUS FIND: the prior window's UNION had `(...) AS m0 UNION ALL (...) AS m1` aliased branches = MariaDB 1064 SYNTAX ERROR at runtime — the live activity_log endpoint was FATALING since ~13:03 PT (the prior window's "1547 rows verified" was a hand-run query, not the deployed code path). Removed the never-referenced branch aliases in both count + main queries. Deployed 14:26 PT (backups /tmp/alltastic_api.php.bak-gatecol-20260723-142139 + .bak-unionfix-20260723-142627), php -l clean x2, UNION re-verified live, FPM+OPcache reloaded.
- Lesson: direct `ssh wopr` via execute_command + scp'd PHP harness scripts (lib/db.php + config.php, db('portal')) was the reliable verification path all session; MCP transport flaky earlier. emsuserver has NOPASSWD sudo ALL except a few denied systemctl ops (php8.3-fpm reload/restart + litellm restart/stop) — deploy routes/ files via stage-to-/tmp + `sudo -n cp`, reload FPM via /usr/local/bin/fpm-reload. MariaDB on WOPR rejects aliased UNION branches — always test the EXACT deployed SQL shape, not a hand-written equivalent.

---
## [2026-07-22 01:40 PT] GLM52 blind-probe fix (bug #1896 RESOLVED) + full ring relaunch in progress

- ROOT CAUSE: medic v3 + overnight supervisor serving probes tested `/v1/models` ONLY — vLLM API server answers models from cache even with a dead PP rank. Augustus rank-1 container died ~01:03 (tonight's pattern: ONE box NVRM-OOMs ~+23-25 min post-launch, every cycle) and was removed; the chain declared "RING SERVING — medic done" at 00:45 and sat blind 36 min while completions hung.
- FIX SHIPPED: both probes now truthful 1-token chat completions (`/v1/chat/completions`, model `glm-5.2-15pct`, max_tokens=1, grep '"choices"'). Supervisor real_completion_ok model id fixed (was `glm-5.2-local`, never existed). Backups: `glm52_medic_v2.sh.bak-probefix-20260722-0127`, `glm52_overnight_supervisor.sh.bak-probefix-20260722-0127` on Desktop.
- LESSON: supervisor is launchd-managed (`com.emsu.glm52-supervisor`, KeepAlive). NEVER hand-nohup a second supervisor — duplicates double-restart the medic.
- LIVE STATE 01:40: full clean 6-rank relaunch fired 01:35-01:36 at gpu_mem 0.70 (all 6 containers up 01:37, all 6 SSH-reachable). Warmup 5-25 min; tonight's death window = launch+25 min (~02:01). Medic (fixed probe) + launchd supervisor (fixed probe) + NVRM snapshotter on Cato (`/tmp/glm52_nvrm_snap.log`) all watching.
- NEXT VERIFIER: confirm a REAL completion via `curl 192.168.1.115:8210/v1/chat/completions` (model glm-5.2-15pct) PAST ~02:05, then supervisor wire-in: registry glm-5.2-local → 127.0.0.1:8210 (glm52-tunnel-8210.service), `frankenstein_verify_routing glm-5.2-local` = $0 through router. Stale NCCL groups do NOT accept rejoining ranks — a dead rank means full relaunch (medic S4a does this automatically).
- GPUMEM NOTE: v29/v30 lineage runs 0.70 (comment: live-proven 1.51M-token KV pool). Tonight's 5 crashes at 0.70 were single-box NVRM OOMs at +25 min, cause unproven (snapshotter armed). Rule 277's 0.82 mandate predates this lineage — flagged, not resolved.
- 02:15 PT UPDATE: warmup VERIFIED — ring served REAL completions 01:42-02:01 (independent probes 01:47 + supervisor wire-in 01:43: registry → 8210 tunnel active, LiteLLM restarted, models list confirmed from WOPR loopback). Death window hit ~02:01 on schedule: ALL 6 containers mass-exited (one rank dies → NCCL hang → en-masse exit), NO medic reset (medic had exited; supervisor slow-watch caught it, restarted medic, relaunched 02:06:33). Cycle 7 VERIFIED SERVING 02:14:54 (real completion) + wired 02:13:28. Chain now self-heals every crash in ~5 min (~80% duty). MTBF ~25 min RCA filed: idea #18605 [proposed] P1 + bug #1897 (mass-exit loop, investigating). Forensics gap: v30 rm-before-capture loses dead-rank logs; NVRM snapshotter died without capturing. Router keyed chat-probe inconclusive (curl aborted mid-probe); transport-level wire verified.

**Older entries archived 2026-07-11** (idea #17169, restoring reasonable size on this always-loaded file): `Rules-archive/HANDOFF_NOTES_ARCHIVE.md` — covers the 2026-07-08 Frankenstein Doctor session (Phases 1-9, RUBEN executor throughput fix 0/hr→480-564/hr) and the 2026-07-10 Cicero 235B restoration. This file now keeps only the most recent entry inline.

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

---
## [2026-07-11] Cline rules-not-obeyed diagnostic — 5 structural defects found and fixed

Found and fixed 3 real structural defects in ~/Documents/Cline/Rules/ that plausibly contributed to degraded rule-following (all always-loaded into every task's system prompt):
1. Rule 00 (subagent dispatch) exceeded its own 12KB hardfloor cap (13,479 bytes) — trimmed to 11,077 bytes, history moved to `Rules-archive/00-case-law.md`.
2. Rule-number collision at prefix "143-" (two distinct files sharing one number) — renamed the customer-facing-agentic-definition rule to 272 (first attempt at 271 collided with a pre-existing file, self-caught and corrected).
3. `_RULE_TREE.md` exceeded its 20KB meta-file cap (29,206 bytes) — trimmed to 20,255 bytes across 3 passes, full changelog moved to `Rules-archive/_RULE_TREE_CHANGELOG.md`.
4. `HANDOFF_NOTES.md` itself (this file) was 28,990 bytes with zero cap enforcement — archived older entries to `Rules-archive/HANDOFF_NOTES_ARCHIVE.md`, kept only the most recent entries inline.
5. Filed idea #17170 to verify the nightly audit cron (`cline_rules_audit.sh`) + fswatch lint listener are actually catching this class of defect going forward (they apparently didn't catch #1-3 on their own).

No LLM/model routing changes were made — Anthropic/Claude routing was explicitly out of scope per Ruben directive.

*Updated: 2026-07-11 via Cline rules-diagnostic session*

---
## [2026-07-13 15:35 PT] reports.php FULL RESTORE — yesterday's layout + roles back, copycat fix intact

Ruben reported card order wrong + instructor role gutted after copycat-fix session. Diff archaeology found prior fix attempts had DELETED 5 whole sections (Dashboards, Instructor Area, Regular Reports, Program Director, Course Management) + 12 _view_ requires from routes/reports.php. Restored /var/www/emtskills/routes/reports.php from reports.php.bak-ruben-impl-20260712-140129 (Jul 12 14:01, 1102425 bytes, last version with all 12 sections). php -l clean. FPM-verified via minted sessions: MasterAdmin 143 cards / FATAL=0 / sections Dashboards→Instructor Area→Reports→PD→Course Mgmt→...→Quick Ref (Reports NOT at top, matching yesterday). Instructor: 14 cards, Instructor Area section restored (my_signoffs, emt_skills_signoff, first_day_roster, scenario_generator, instructor_resources, campus_tech_guide, team_hub, time_clock...), 40-Hour card NOT visible. Copycat fatal fix survives (GUARD-SKIP-MARKER in the two _view_ files, all views carry REPORT_CARD_EMBEDDED token). Diag files cleaned from web root. Pre-restore states saved: /tmp/reports_pre_restore_backup.php + /tmp/reports_pre_restore2_backup.php. Ideas filed: #17494 (patch cron_view_guard_audit for function-defining views), #17504 (git the routes dir), #17505 (per-role render harness + baselines). NOTE: executor pipeline currently broken (#17486 P0) so ideas left at proposed.

---
## [2026-07-13 17:16 PT] Executor pipeline (#17486) — 3 root causes found, 2 fixed+deployed, 1 remaining (JSON truncation)

Executor spec-gen was failing for ALL ideas. Diagnosis chain in cron/cron_ruben_implement.php callLlm():
1. FIXED: DeepSeek API "Insufficient Balance" — the executor bypass-adapter path pointed at the dead paid API. Flipped $__executorBypassAdapter=false (line ~617) so executor uses LiteLLM emsu-codegen (local free glm-5.2). Backup: cron_ruben_implement.php.bak-deepseek-balance-fix-20260713-165949.
2. FIXED: STREAM_ORDER_FIX — stream=true was set AFTER json_encode so the body never contained the flag; SSE parser captured nothing -> "Claude returned empty content" every call. Moved flag before encode + plain-JSON safety net. Backup: .bak-stream-order-fix-*.
3. FIXED: REASONING_SEPARATE_FIX — old REASONING_FALLBACK prefixed glm-5.2 thinking tokens onto real content ("Let{...") breaking extractJson. Reasoni3. FIXED: REASONING_SEPARATE_FIX — old REASONING_FALLBACK prefixed g spec J3. FIXED: REASONING_SEPARATE_FIX — old REASONING_FALLBACK prefixed glm-5.2 thinking tokens onto real content he shared max_t3. FIXED: REASONING_SEPARATE_FIX — old REASONING_FALLBACK prefixed glm-5.2 thinking tokens onto real pec calls, or set a non-reasoning model for spec-gen. Retry counters for 17494/17504/17505 reset to 0 so they re-enter the queue.
reports.php restore (earlier today) confirmed good by Ruben across roles. Ideas #17494/#17504/#17505 approved per Ruben.

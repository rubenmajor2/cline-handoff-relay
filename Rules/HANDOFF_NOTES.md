HANDOFF_NOTES appended below. Existing notes preserved.

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

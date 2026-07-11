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

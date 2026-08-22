# Rule 317 — Completion Confidence: acquire what you would miss; reversals self-correct

**HARDFLOOR** (Ruben directive 2026-08-12). A completion window must be TRUSTWORTHY.

## GOLDEN RULE (distilled from the full rule-317 reversal log; read this first)

One sentence: **Claim scope must equal probe scope.** A tool's auto-success signal (php -l, write_server_file lint+reload, exit code 0, npm build, upload-return, "deployed OK") verifies ONLY what that tool checked. It is NEVER evidence that the running deliverable works, that an external id is valid, that a credential is dead, or that a permission wall exists. Any completion claim about user-facing behavior ("console clean", "page renders", "flow works", "pickup clickable", "no errors") requires a probe of THAT surface this window, never an inference from a deploy/build tool's auto-check.

<!-- golden-rule-table:start (auto-maintained by clinerules_amend_rule, #27652) -->

The reversal log collapses to FOUR recurring failure modes, in order of frequency:

- **SELF_CONTRADICTING_DISPOSITION** (dominant: 251 of 280 telemetry failures; the #1 gate blocker). Prose says DONE/FIXED/VERIFIED next to an idea bracket that still says [proposed]/[executing]/[blocked]. Stamp the record first (UPDATE orchestrator_ideas SET status=deployed, then reconcile_ideas), THEN write the claim; or keep the honest bracket. Never write FIXED next to [proposed]. [auto-sync: +5 since 2026-08-19 | latest: Within-window reversal: reconcile_ideas reported #27697 [executing] (status=in_progress) a]
- **R317_UNVERIFIED_STATE** (24 of 280 telemetry failures). Asserting fleet/routing/pod/model-health or deliverable state from memory without a live probe returning proof. Probe first and quote the result, or label the claim UNVERIFIED. [auto-sync: +43 since 2026-08-19 | latest: 2026-08-21 Argus/lifecycle advisory reversal: raw SQL counted 73 active Students with NULL]
- **INSUFFICIENT_PROBE** (the mechanism behind most amendment case law). One auth error against one endpoint with one header is NOT a dead credential; one EACCES is NOT a permission wall (probe sudo -n / the succeeding header first); one failed id resolve is NOT a missing file; a php -l pass is NOT a working JS page; a chmod is NOT complete until the consumer process re-runs clean. Acquire the probative artifact before declaring ANY negative or completion state. [auto-sync: +51 since 2026-08-19 | latest: 'UPDATE anomaly' was carried as an open bug; reading the actual source (SHOW TRIGGERS FROM]
- **SCOPE_ERROR** (completion over-scoped to DONE). Enumerate EVERY visible defect / every deliverable in the set before claiming resolved; the undone ones become open threads with real idea ids, not hidden by a "done" headline. [auto-sync: +12 since 2026-08-19 | latest: 2026-08-19 scope reversal: the original completion said the remaining active suspensions w]
<!-- golden-rule-table:end -->

English-only, always (narration included); domain context never justifies language switching.

## NUMBERED HARDFLOOR (mechanics of the closed loop)

1. **LLM / fleet / routing state — the #1 recurring error. NEVER recite status from memory.** Probe the live source first (frankenstein_registry, frankenstein_verify_routing, mysql/reconcile, ps, systemctl). Recited state is stale by definition.
2. **Acquisition gate — what would you miss if you shipped now?** Acquire it BEFORE completion. If a claim is not backed by a tool call you ran THIS window, it is unverified — say so or run the tool.
3. **Escalation probe before declaring any wall.** Never declare "permission denied", "not available", "cannot write", "host down", or "no access" from a single unprivileged attempt. If a command fails with EACCES/EPERM, IMMEDIATELY re-run the same operation via the escalation path that exists (sudo -n, operator role, MCP tool with different credentials). A non-sudo failure is NOT a permission wall. This applies to CREDENTIAL and RETRIEVAL failures exactly as to EACCES: one auth error against one endpoint with one header is not a dead credential — copy the working header/endpoint from a production script that uses the same credential and exhaust alternate retrieval paths before declaring anything unrecoverable. Declaring a wall without probing escalation is a 297 trigger. (Source: 2026-08-16 #26617; 2026-08-17 Postmark reversal.)
4. **A within-window reversal is a mandatory 297.** When a material claim in a prior turn is corrected (state drifted, diagnosis wrong, blocker was not a blocker), file the 297 RCA AND update the CAUSAL RULE TEXT. Recording the reversal in a log without amending the rule that allowed the error is NOT a closed loop.
5. **Within-window reversal self-corrects.** If the correction happens in the same window, the rule update is still required — the extra work is just the rule-file amendment plus reindex, not a new window.
6. **The reversal is mechanical, not prose (idea #27100, 2026-08-16).** A Reversal Log entry that CLAIMS a causal-rule update but does not change the underlying artifact is cursory window-fixing — the exact failure that made this rule look decorative. Closing a reversal requires the causal rule text to ACTUALLY change on disk: call `clinerules_amend_rule(rule_id='<causal rule>', task_id='<this task>', rca_bucket='<bucket>', note='<what changed>')` for EVERY flip whose causal fix is a rule file. That single call edits the rule file, writes the proof-of-repair row in the `rule_amend` ledger, and reindexes the MCP so the fix is live everywhere (file → manifest → MCP index → FTS5 → corpus feed). A flip whose causal fix is an IDEA (not a rule file) is exempt from the amendment call ONLY if the flip line carries a real `#NNNN [disposition]` from create_idea. The completion gate `R317_REVERSAL_NOT_REPAIRED` blocks any completion whose Reversal Log lists a rule-citing flip with zero mechanical amendments this window. A reversal is closed when the artifact behind it changed, never when the prose about it changed.
7. **The gate auto-repairs, it does not just block (2026-08-17).** When a Reversal Log lists a flip that cites a causal rule file but the `rule_amend` ledger has zero rows for the task, `clinerules_validate_completion` resolves the cited rule and calls `amendRuleOnDisk` on the window's behalf — appending the dated amendment, writing the proof row, and reindexing. The completion then PASSES with an `AUTO-REPAIRED` notice because the underlying artifact actually changed. If the flip names NO causal rule, the gate blocks AND names the offending line. Both halves feed the corpus: `r317_reversal_not_repaired` (window logged a flip without repairing) and `r317_auto_repaired` (the machine closed it).
8. **Directive-interpretation check (2026-08-18 reversal).** When a directive says "upgrade X to Y everywhere" and Y is not yet available on the local backend, REPORT the local gap and ask whether to wait or proceed with the alternative — never silently convert a free-local lane to a paid/cloud one. A cost-bearing architectural change is a decision to surface, not a routing change to bury.
9. **Permission-change consumer re-run (2026-08-19 reversal).** Before chmod/chown/any permission change on a file a service reads, probe (a) the file's actual owner and (b) the consuming process's user identity; after the change, re-run the consumer once. A hardening step not followed by a consumer re-run is an unverified write.
10. **External ids resolve live (2026-08-19 reversal).** A Drive file id, URL, token, or any external identifier is not "verified" until a live resolve (get_file_info, HTTP 200, API lookup) returns it THIS window. Never publish an id from an upload-return or prior-turn capture.

## Case law + full amendment trail

`Rules-archive/317-case-law.md` (trimmed 2026-08-19 per the trim-then-archive pattern to restore G7 12KB compliance — the append-only amendment tail had grown the file to 16.8KB, failing this rule's own lint gate). The 4-mode taxonomy source: `/var/www/emtskills/docs/317-reversal-corrections.md` (280 catalogued failures). Systemic follow-ups: #27634 [executing] (amend_rule dedup + distilled-table maintenance), #27635 [executing] (auto-ingest amendments into ai_learned_corrections + emsu://reference for small-model retrieval).

## Cross-references

- Rule 297 — classify before diagnosing; a reversal is a mandatory 297 RCA
- Rule 91 — pickup prompt shape; disposition tags must match the live record
- Rule 263 — verify-before-claim on ALL facts
- Rule 321 — no hidden gates after approval (G5 premature completion)
- Rule 322 — "what was serving" = one table of underlying LLMs (probe, never recite)

## Case law + amendment trail

Amendment history (2026-08-16 through 2026-08-20 reversals) moved to `Rules-archive/317-amendments.md` per the trim-then-archive pattern (#27531).

## Amendment (from reversal, 2026-08-20 03:55 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: lockout-cfa-2026-08-19-verify
- RCA bucket: insufficient probe
- Trigger pattern: permission/log fix declared complete without re-running the consumer AS THE PRODUCTION USER; a stale www-data-owned /tmp lock kept killing the emsuserver cron every 15min after the 'fix'
- Reversal note: 2026-08-19 verification reversal: completion claimed the auto-clear heal path was restored (log perms fixed, patches in), but a live probe as the production user found /tmp/cfa_payment_auto_clear.lock owned www-data 664 which emsuserver's cron could not fopen (supplementary group not honored for write), so every 15-min cron run exited 'another instance running' and the heal path was STILL dead. Fixed: lock recreated root:root 666, write-verified for both users, end-to-end run as emsuserver succeeded. Amended behavior: after ANY permission/ownership/log fix on a cron, re-run the consumer AS THE PRODUCTION CRON USER (sudo -u <cronuser> php ...) and confirm real output lines in its log before declaring the path restored; where a script uses a /tmp lock, probe lock-file ownership/writability for the cron user as part of the check.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 03:56 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: lockout-cfa-2026-08-19-verify
- RCA bucket: scope error
- Trigger pattern: completion over-scoped the sweep complement: 'remaining 812 are genuinely owed' collapsed 4 distinct sweep buckets (682 owed / 94 no_settled_record / 5 orphan / 28 skipped-by-design) into one claim
- Reversal note: 2026-08-19 scope reversal: the original completion said the remaining active suspensions were all genuinely owed. The sweep's own log buckets say otherwise: 682 SLS-confirmed unpaid, 94 no_settled_record (SLS gate PASS but zero settled ledger rows — deliberately blocked for HUMAN review per #26434, possibly wrongful), 5 orphaned rows (student_not_found), ~28 declined_checkout_followup skipped by design. Amended behavior: when a sweep/classifier produces named outcome buckets, the completion must enumerate EVERY bucket with its count; the complement of 'cleared' is never a single uniform class. Claim scope must equal probe scope.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 04:01 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787190192283
- RCA bucket: insufficient probe
- Trigger pattern: CFA lockout completion verification: three within-window reversals (dead-cron attribution, sweep-bucket scope, stale /tmp lock) all traced to probe gaps
- Reversal note: Consolidated record of this window's three flips, all with causal rule 317: (1) 'broken since Jul 17 due to CanonicalPricing error' corrected to 'cron never ran at all since Jul 17 (log redirect permission failure); schema drift was a second latent defect' — an empty 0-byte cron log is probative evidence of a silently-dead cron; stat mtime+size and run the script manually before naming the cause. (2) 'remaining suspensions genuinely owed' corrected to the sweep's own four buckets (682 unpaid / 94 no_settled_record human-review / 5 orphaned / ~28 skipped-by-design) — enumerate every classifier bucket, the complement of cleared is never one uniform class. (3) 'heal path restored' corrected to 'still dying on a www-data-owned /tmp lock' — after any permission/log fix, re-run the consumer AS THE PRODUCTION CRON USER and probe lock-file ownership/writability before declaring the path restored. Earlier per-flip amendments exist under task ids lockout-cfa-2026-08-19 and lockout-cfa-2026-08-19

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 04:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: jose-palomares-repeat-email-rca
- RCA bucket: stale assumption
- Trigger pattern: todo-list disposition carried from memory into completion assembly without a live reconcile
- Reversal note: 2026-08-19: window todo checklist carried '#27657/#27671 approved' from filing-time memory while live reconcile_ideas returned status=proposed dev_stage=idle. Caught pre-ship by the live-read mandate; completion re-tagged [proposed]. Amended behavior: internal todo/checklist idea statuses are claims too and must be refreshed by a live reconcile_ideas or direct orchestrator_ideas read before any completion is assembled, not carried across tool rounds.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 07:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579
- RCA bucket: insufficient probe
- Trigger pattern: single-source cron lookup (root crontab only) + dedup-quiet log read as inactivity proof
- Reversal note: 2026-08-20 00:17 PT within-window flip: 'catch-relaunch cron vanished from root crontab' -> corrected 00:18: cron lived in /etc/cron.d/emsu-julia-catch-relaunch all along and HAD fired at 00:15:36; the silent 00:05-00:15 window was WARMING-state dedup suppressing repeat log lines, not inactivity. Amended behavior: before declaring a cron missing, check BOTH root crontab AND /etc/cron.d/ drop-ins; a dedup-quiet log window is not evidence of non-execution — run the script manually once to observe live behavior before claiming the scheduler is dead.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 09:34 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579-julia-235b-recovery
- RCA bucket: insufficient probe
- Trigger pattern: launch failure diagnosed from a summary 'Engine core init failed' without reading the NCCL_DEBUG root cause; assumed the previously-observed GID index issue without re-verifying the current failure mo
- Reversal note: 2026-08-20 02:34 PT reversal: after restoring Julia post-L2-dark, the TP=2 engine crashed with 'Engine core initialization failed / Failed core proc(s): {}'. Root cause was NOT a GID index (the 03:08 handoff's lane-guard/wedge theory); a live NCCL_DEBUG=INFO crash-log probe showed ibv_modify_qp EINVAL: Julia's RoCE IPv4 192.168.100.2/24 was MISSING after reboot (preflight 'ip addr add' lacked sudo, so the add silently failed), so Julia had no IPv4-mapped index-3 GID while Claudia had ::ffff:192.168.100.1. Fixed by restoring the RoCE IP, patching the preflight script's sudo bug, and relaunching TP=2. Amended behavior: when a TP=2/vLLM engine crashes at init, probe the full NCCL_DEBUG crash log for ibv_modify_qp/GID/address mismatches AND confirm both hosts' RoCE IPv4 interfaces carry their configured addresses before re-launching; check that any IP-restore preflight script actually uses sudo on the add-address command.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 19:44 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787248000000
- RCA bucket: insufficient probe
- Trigger pattern: completion overclaimed multi-part deploy + code INSERT used columns copied from an assumption rather than the live information_schema
- Reversal note: Within-window reversal: completion claimed 'all 4 parts deployed' while Part B (cfa_failure_dashboard view), the cron_cfa_failure_watchdog.php script, and its cron entry were all missing, and the SMSAIResponder logCfaModelFailure INSERT referenced fictional columns (surface/detail/model_chain_attempted/created_at) instead of the real schema (failure_time/model_attempts/error_message/source_script). Rule now requires: before claiming a multi-part deploy is complete, verify EACH part independently (SELECT from information_schema for tables/views, grep the file for the patched SQL, ls the cron script, crontab -l for the entry) and run a live INSERT through the exact SQL the code executes to prove column names match the live schema.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-21 07:56 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: wrong premise
- Trigger pattern: Building a peer-comparison anomaly detector on an unverified schedule invariant, producing false-positive flags for legitimate per-section close-date stagger.
- Reversal note: Reversal: detector v1-v2 assumed same-format sections share a close date and flagged any peer difference as an anomaly. Live probe of Course_Schedules showed close date is a legitimate function of meeting_times + course_start_date, and the 264-franchise (Houston/San Antonio) legitimately closes +24h, so the ~208 peer deltas were false positives, not incidents. Amended: before building any calendar-anomaly detector, probe the canonical close-date function from Course_Schedules; inter-section stagger is noise unless a section closes before its own scheduled_didactic_completion_date + margin.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-21 18:31 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: ops-truth-cron-user-misread-20260821
- RCA bucket: insufficient probe
- Trigger pattern: attributing a bare 'crontab -l' to root without confirming ssh_command runs as emsuserver, then destructively removing the only cron schedule based on the misread
- Reversal note: 2026-08-21 within-window reversal: claimed the ops-truth watchdog was 'duplicated in both emsuserver and root crontabs' and removed the 'root duplicate'. Reality: emsu-operations ssh_command runs as emsuserver (whoami=emsuserver), so bare 'crontab -l' AND 'sudo -u emsuserver crontab -l' both read emsuserver's crontab - the 'duplicate' was the SAME crontab read twice and mislabeled. The removal deleted the ONLY schedule from emsuserver; root crontab (27 lines) never had it. Restored to emsuserver (line 62, 1 occurrence). Amended behavior: BEFORE interpreting or destructively editing any user-scoped state (crontab, files, processes) via ssh_command, run 'whoami' to confirm the executing user; a bare crontab -l reflects that user, not root; a line seen via both bare crontab -l and sudo -u <sameuser> crontab -l is ONE crontab, not a duplicate; never 'grep -v X | crontab -' without first confirming which user's crontab is being edited and that the target line is a genuine duplicate. Complem

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-21 22:52 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786491116649
- RCA bucket: stale assumption
- Trigger pattern: deploy-claim carried across windows treated as a live capability without ever executing the artifact
- Reversal note: 2026-08-21 T4 verification reversal: check_externship_state.php was carried as 'deployed + style-pin live' from the #26089 claim, but a live probe found it built on a fictional schema (lowercase fictional tables incl. two that do not exist, PARAM_INT bind against composite student slugs, fictional site_id JOIN + agency_name column) and it had never returned data since 2026-08-17. Repaired against real tables and verified live. Amended behavior: a deploy claim inherited from a prior window must be re-probed by EXECUTING the artifact (a real run with real input), not by confirming the file exists, before it is used as a verification instrument.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-21 23:51 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786491116649
- RCA bucket: insufficient probe
- Trigger pattern: carrying request-status 'completed' as evidence of a firm placement without probing ExternshipPlacement
- Reversal note: 2026-08-21 reversal: carried prior-window inference 'completed = placed' and nearly shipped '6 completed students got post-Sept-1 dates as firm placements'; live probe of ExternshipPlacement (138 rows total, exact + LIKE match on all 6 slugs) returned 0 rows — their completed requests have NO placement record behind them (the #26071 placement-tracking gap). Amended behavior: a request status of 'completed' is never evidence of a firm placement; any placement claim requires an ExternshipPlacement row probe in the same window.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-22 00:06 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787327963594
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - "cron on schedule, first run tomorrow 6 AM (log absent = expected)" -> "cron would have FAILED tomorrow: emsuserver cannot create /var/log/ops_truth_watchdog.log (root:syslog); p

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-22 00:16 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787121837052
- RCA bucket: stale assumption
- Trigger pattern: deploy-claim carryover from prior window treated as live without re-probing the artifact
- Reversal note: VERITAS continuation window carried the prior-window claim 'rule 323 shipped and always-loaded' without re-probing; the file had been auto-archived from the Mac floor by the G8 cap and was live only via the WOPR steering mirror. Re-probe this window found the archive state. Reinforces existing 2026-08-21 amendment: a deploy claim inherited from a prior window must be re-probed by reading/executing the artifact before it is treated as live.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

# Rule 317 — Completion Confidence: acquire what you would miss; reversals self-correct

**HARDFLOOR** (Ruben directive 2026-08-12). A completion window must be TRUSTWORTHY.

## GOLDEN RULE (distilled from the full rule-317 reversal log; read this first)

One sentence: **Claim scope must equal probe scope.** A tool's auto-success signal (php -l, write_server_file lint+reload, exit code 0, npm build, upload-return, "deployed OK") verifies ONLY what that tool checked. It is NEVER evidence that the running deliverable works, that an external id is valid, that a credential is dead, or that a permission wall exists. Any completion claim about user-facing behavior ("console clean", "page renders", "flow works", "pickup clickable", "no errors") requires a probe of THAT surface this window, never an inference from a deploy/build tool's auto-check.

<!-- golden-rule-table:start (auto-maintained by clinerules_amend_rule, #27652) -->

The reversal log collapses to FOUR recurring failure modes, in order of frequency:

- **SELF_CONTRADICTING_DISPOSITION** (dominant: 251 of 280 telemetry failures; the #1 gate blocker). Prose says DONE/FIXED/VERIFIED next to an idea bracket that still says [proposed]/[executing]/[blocked]. Stamp the record first (UPDATE orchestrator_ideas SET status=deployed, then reconcile_ideas), THEN write the claim; or keep the honest bracket. Never write FIXED next to [proposed]. [auto-sync: +11 since 2026-08-19 | latest: 2026-08-27 reversal (Ruben caught it): the Exam 5 root-cause completion shipped an 'Open t]
- **R317_UNVERIFIED_STATE** (24 of 280 telemetry failures). Asserting fleet/routing/pod/model-health or deliverable state from memory without a live probe returning proof. Probe first and quote the result, or label the claim UNVERIFIED. [auto-sync: +60 since 2026-08-19 | latest: - "cloudflared restart churn is the cause (bug-library known-repair match)" -> corrected: ]
- **INSUFFICIENT_PROBE** (the mechanism behind most amendment case law). One auth error against one endpoint with one header is NOT a dead credential; one EACCES is NOT a permission wall (probe sudo -n / the succeeding header first); one failed id resolve is NOT a missing file; a php -l pass is NOT a working JS page; a chmod is NOT complete until the consumer process re-runs clean. Acquire the probative artifact before declaring ANY negative or completion state. [auto-sync: +70 since 2026-08-19 | latest: - "frankenstein-llm's rule 91 text is too shallow" → corrected: the rule TEXT was adequate]
- **SCOPE_ERROR** (completion over-scoped to DONE). Enumerate EVERY visible defect / every deliverable in the set before claiming resolved; the undone ones become open threads with real idea ids, not hidden by a "done" headline. [auto-sync: +16 since 2026-08-19 | latest: 2026-08-28 reversal (task 1787931475695): claimed GLM 5.3 served ~477 turns as the #1 engi]
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

## Amendment (from reversal, 2026-08-23 07:44 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787420772345
- RCA bucket: stale assumption
- Trigger pattern: declaring a lane offline from a stale heartbeat without a live endpoint probe, and claiming model capability ordering from raw parameter counts without checking MoE active-params or generation
- Reversal note: 2026-08-22 completion reversal: claimed 'Claudia Qwen3.8 lane is offline' from a stale 724-minute heartbeat WITHOUT a live probe; live curl showed :11521 serving HTTP 200 the whole time. Also recited '120Bs/235Bs out-think the 27B' from general priors about parameter counts without checking that Qwen3-235B-A22B is MoE with only ~22B ACTIVE params (parity with a dense 27B) and two generations older. Amended behavior: NEVER state a host/lane is down or offline in a completion from inventory/heartbeat staleness alone — probe the serving endpoint live in the same window; and never claim a capability ordering between models from parameter counts alone — MoE active-param counts and generation age must be checked (and ideally live A/B'd) before any 'X out-thinks Y' claim.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-23 17:57 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: cfa-sweep-reversal-20260823
- RCA bucket: insufficient probe
- Trigger pattern: Claimed a code fix (function) was written and a defect count was real, without a read-back probe; both the problem and the fix were fabricated from a misread/nonexistent log line.
- Reversal note: 2026-08-23 CFA-sweep reversal: the prior completion claimed (a) '72 of 88 tools missing type' was a real defect and (b) it was fixed via a normalizeParamsSchema() function. Live re-probe this window: all 88 tools have legal type fields (0 missing/illegal/dupes), NO 'missing type' log line exists anywhere (the only 'missing type' string is claude_response_sanitizer.php, which sanitizes LLM RESPONSE content blocks, not tool definitions), and grep -rn normalizeParamsSchema across the entire codebase returns ZERO hits — the claimed fix function was never written to disk. Amended behavior: a claimed code fix is not 'done' until a read-back probe (grep for the function name / re-read the edited region) confirms it exists on disk THIS window; and a defect count ('N of M items broken') is never claimed unless the M items were enumerated and each checked. A log-line fragment is a hypothesis, not a defect.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-23 20:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786491116649
- RCA bucket: insufficient probe
- Trigger pattern: claiming an automation is operational from deployed artifacts + empty output tables, without checking the agent/cron that actually produces the output
- Reversal note: Externship auto-assign appeared 'live but idle' from a surface view (deployed ideas, empty offer table). On probe: the scheduling agent has fatalled 288+ consecutive 5-min cycles at line 1015 (PDO object passed to enforceThreadStatusOnInsert, stringified in error_log), so agency routing is fully dead, zero offers can be created, and cron_externship_autoassign.php was never registered. The rule now requires verifying the driving cron/agent loop (its recent run history and failure count), not just the deployed artifact, before claiming an automation is 'live but idle'.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-24 17:42 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787461448415
- RCA bucket: insufficient probe
- Trigger pattern: outage RCA scoped to the respawn/recovery gap without probing the stop trigger
- Reversal note: 2026-08-24 WOPR nginx outage: initial completion scoped the root cause to the Restart=on-failure respawn policy (the amplifier) without probing WHAT sent the clean stop (the trigger). Ruben pushback forced the trigger investigation; journald history for the 03:55 window was purged so the trigger is unproven, strongest candidate emsu-lease-heartbeat (only script on box with 'systemctl stop nginx'). Amended behavior: on any service-outage RCA, the completion must separately state (a) the amplifier (why it stayed down) and (b) the trigger (what stopped it), each with its own evidence or an explicit UNPROVEN label with the evidence gap named; fixing the amplifier alone is not a closed root cause.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-24 17:51 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787461448415
- RCA bucket: insufficient probe
- Trigger pattern: prevention claim based on Restart= semantics without checking whether the outage was an administrative stop
- Reversal note: 2026-08-24 WOPR nginx outage, second flip: completion claimed 'Restart=always self-heals any future clean-exit stop within 5s' as the prevention, without probing whether Restart= covers the actual failure mode. Corrected: the outage's stop was an ADMINISTRATIVE 'systemctl stop' (issued by the self-fence), and systemd Restart= policy never undoes an explicit administrative stop - it only fires when the service's own process exits while the unit should be running. The real fix was the WRITER-SERVE invariant in emsu-lease-heartbeat. Amended behavior: before claiming a systemd Restart= override prevents a recurrence, verify HOW the unit went down (process-exit vs administrative stop); an administrative-stop outage needs a starter in the recovery path, not a Restart= policy.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-24 21:13 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: pd80-paperwork-20260824
- RCA bucket: unread source
- Trigger pattern: empty portal mirror table treated as evidence of missing student paperwork without probing the Moodle source-of-truth or resolving archived-vs-live Moodle accounts
- Reversal note: 2026-08-24 PD-80 paperwork reversal: initial framing treated the empty admin_portal.ExternshipFormSubmission rows (67 of 168 students at the 80% anchor with <5 portal forms) as evidence of missing externship paperwork and of idea #19419 being a false deploy. Live probe of the Moodle side reversed it: the simplecertificate availability trees ALREADY gate the EOC cert on the 5 paperwork assign modules, and sample student Kotturu had ALL paperwork submitted in Moodle under her LIVE account (uid 53198) while Students.moodle_url pointed at her ARCHIVED account (53174) and the portal table had 0 rows. Amended behavior: before claiming a compliance artifact is missing, enumerate EVERY surface where that artifact can legitimately live (portal table AND Moodle assign modules AND the cert availability tree) and probe the LIVE identity (archived accounts resolved to live) — an empty row count in one mirror table is never evidence the artifact does not exist.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-25 22:34 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-repairs-20260825
- RCA bucket: insufficient probe
- Trigger pattern: script behavior claimed from source reading instead of execution; silent-failure path (error printed, exit 0) missed entirely
- Reversal note: 2026-08-25 Argus repair window: two files (cron_argus_offloaded_task_reconciler.php, cron_argus_offloaded_task_resolver.php) were first reported as a runtime-error nuisance based on READING them. Live EXECUTION showed they fail SILENTLY: they print 'Unknown column t.idea_id' and then 'No offloaded tasks requiring reconciliation' with EXIT=0. A false-clean is materially worse than a crash because monitoring and humans read it as success. Amended behavior: a claim about what a script DOES must come from executing it and reading BOTH its output and its exit code; a non-zero-error/zero-exit combination must be explicitly checked for and reported as a false-clean, never summarized as 'it errors'.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-25 22:34 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-repairs-20260825
- RCA bucket: scope error
- Trigger pattern: pipeline declared healthy after probing only the stage that produced the visible symptom; downstream notify/escalate stage never exercised
- Reversal note: 2026-08-25 Argus repair window, second flip: the first completion reported the offload sweep as working and blamed only the confidence auto-reject cron. A later probe of the sweep's ESCALATION path (not just its classification path) found its INSERT referenced three columns that do not exist on ruben_imessage_issues (task_queue_id, idea_id, issue_text), so it exited(1) before alerting and six stranded staff requests were invisible to humans for days. Amended behavior: when a multi-stage pipeline (classify -> act -> notify/escalate) is declared healthy, EVERY stage must be probed, not just the one that produced the visible symptom; a stage that runs after the observed output is the most likely place for an unnoticed failure, and claim scope must equal probe scope across all stages.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 01:02 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-repairs-20260825b
- RCA bucket: scope error
- Trigger pattern: staff-reported production bugs listed as awaiting-human disposition without first probing them to a root cause the window could fix
- Reversal note: 2026-08-25 Argus follow-up: three staff requests were carried into a completion as items 'needing a human or a build' (#28122/#28133/#28134). Ruben pushed back: these are BUGS and should have been resolved without asking. On probe, #28134 was a dead cron plus a one-line HY093 bind defect, both fixable in-window in ~15 tool calls, and the same defect class also explained #28122. Amended behavior: before listing a staff-reported item as awaiting-human, probe it to a named root cause first; an item whose cause is an unscheduled cron, a bind error, or any defect the window has tools to fix is undone work, never an open thread. 'Real production bug, needs a human or a build' is only a valid disposition after the root cause is identified and shown to require a human policy decision.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:22 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 26816BC-17-phantom-rca
- RCA bucket: insufficient probe
- Trigger pattern: row-shape classified as bug without the population discriminator; writer declared dead from a single-directory search
- Reversal note: 2026-08-25 reversal: completion claimed the phantom stamper was gone (didactic_deadline.php 'no longer exists') after searching only /var/www/emtskills/cron, and claimed 7 purged students were bug-caused lockouts. Live record showed didactic_deadline.php alive at /var/www/moodle/ems/local/exam_enforcement/crons/ (registered in routes/scheduled_tasks.php, daily 00:00, log /var/log/exam_enforcement.log) re-stamping the purged students nightly, and the 3 current purged students had ZERO quiz_overrides rows, i.e. they were never the bug class; their zeros were by-design enforcement records. Amended behavior: (a) before declaring any writer/cron dead, search ALL docroots (emtskills AND moodle trees), the scheduled_tasks registry, and the registry's named log file, and quote the log's last run; (b) a synthetic-looking quiz_attempts row (timestart=timefinish, no question data) is NOT by itself a bug artifact: it is by-design enforcement unless the student carries an ACTIVE quiz_override; purg

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:23 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 28031
- RCA bucket: insufficient probe
- Trigger pattern: unverified DB-state claim carried into a completion while looping on the rule-91 gate
- Reversal note: Rebase-status window: during a rule-91 gate loop the completion asserted 'cron_state entries confirm watchdogs update state' without probing; a live mysql SELECT of cron_state for both watchdog slugs returned EMPTY. Amended behavior: any DB-state claim in a completion must carry a probe quote; an empty result set is reported as 'no rows returned', never as 'confirms state'.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787697242661
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - 'stamper gone, no live INSERT path' -> 'didactic_deadline.php alive in Moodle tree, daily run re-stamped purged students' | RCA: insufficient probe | causal rule updated: 317

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:57 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787606148778-mailer-rca
- RCA bucket: insufficient probe
- Trigger pattern: Named a specific function as a hang's root cause based on proximity/naming similarity to the symptom, without reading that function's actual timeout configuration, then explaining the fix surfaced the
- Reversal note: Within-window reversal: idea #28239 diagnosed a sendEmail() hang as the Postmark suppression-dump curl call. When asked to explain the fix, a source read of mailer.php showed isPostmarkSuppressed() already has an explicit CURLOPT_TIMEOUT=4, ruling it out. The real cause was the VERITAS L4 truth-judge gate (TruthJudgeClient, 250s default timeout, ~230s worst-case per its own code comment), triggered because the reply email matched a high-stakes keyword regex on the word "complete". The original diagnosis was reached by inference (a hang near mailer.php's suppression-check comments) rather than by reading every guard sendEmail() actually executes. Filed corrected idea #28242, rejected #28239 as superseded. Reinforces existing rule text: a hang/timeout root cause is not established until every code path between the call site and the failure is read, not just the one whose name matches the symptom.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 17:56 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787606148778-minicheck
- RCA bucket: wrong premise
- Trigger pattern: slow-and-wrong verification subsystem diagnosed correctly but remediated by relocating it (async/post-send) instead of replacing the mechanism
- Reversal note: 2026-08-26 VERITAS reversal: the prior completion recommended moving the LLM truth-judge OFF the synchronous send path to a post-send async audit. Ruben rejected the direction ("addresses my point, but does not completely solve the underlying issue... consult the community"). Async auditing only relocates a wrong answer downstream; the student still receives it. The community-standard fix (MiniCheck, EMNLP 2024 arXiv:2404.10774) is a small ENTAILMENT model checking claims against evidence already retrieved, at GPT-4 accuracy and ~400x lower cost — verified on our own fleet at 320ms warm vs 42,500ms, 6/6 correct. Amended behavior: when a verification/quality subsystem is measured as both slow AND wrong, do NOT propose relocating it (async, batching, sampling) as the fix — that preserves the defective mechanism. Search the literature/community for whether a different MECHANISM solves the class, and prefer a cheap deterministic or small-model check over an LLM-as-judge whenever the questi

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 17:58 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787606148778
- RCA bucket: wrong premise
- Trigger pattern: slow-and-wrong verification subsystem remediated by relocating it instead of replacing the mechanism
- Reversal note: 2026-08-26 VERITAS reversal (ledger stamp for the shipping task id; same fix as task 1787606148778-minicheck). Prior completion proposed moving the LLM truth-judge OFF the synchronous send path to a post-send async audit. Ruben rejected the direction: async only relocates a wrong answer downstream, the student still receives it. The mechanism was wrong, not its position. Community-standard replacement shipped instead (MiniCheck, EMNLP 2024 arXiv:2404.10774): a small entailment model checking claims against evidence already retrieved, verified on our own fleet at 320ms warm vs 42,500ms, 6/6 correct. Amended behavior: when a verification/quality subsystem is measured as both slow AND wrong, do NOT propose relocating it (async, batching, sampling) — that preserves the defective mechanism. Search the literature for whether a different MECHANISM solves the class, and prefer a cheap deterministic or small-model check over LLM-as-judge whenever the question can be posed as entailment against 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 22:20 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787782950000
- RCA bucket: scope error
- Trigger pattern: batch remediation population derived from the artifact table's time window instead of the defect log itself
- Reversal note: 2026-08-26 resend near-miss: the 48h resend script's first dry run returned 22 candidates from a ticket-window query alone; 5 of those tickets' notifications were never blocked (they had gone out fine) and would have been duplicate-sent. Amended behavior: any batch resend driven by a block/defect log must cross-reference the candidate population against the ORIGINAL block rows (EXISTS match on recipient + subject + block reason), never a time-window pull of the artifact table alone; the dry-run output is compared to the known blocked population before --send is allowed.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 22:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 27435-sweep-20260826
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - 'run_moodle_query wedged' -> 'wrapper mysql password stale; ssh mysql via .my.cnf works but is adminportal-only' | RCA: insufficient probe | causal rule updated: 317 (existing am

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-28 07:58 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1779186100000
- RCA bucket: wrong premise
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - "frankenstein-llm's rule 91 text is too shallow" → corrected: the rule TEXT was adequate; the ENFORCEMENT GATE was dead code (_r91_validate returned None, 0-byte violations log, 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-28 15:59 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: glm53-local-ring-upgrade-20260828
- RCA bucket: insufficient probe
- Trigger pattern: routing spill/fallback target asserted from narrative fit instead of reading the live upstream pool order and fallback chains
- Reversal note: 2026-08-28 reversal: completion asserted 'during ring-down, GLM traffic spills to the already-wired cloud glm-5.3' without reading the routing config. Live config read showed the actual frankenstein-llm ladder: (a) adapter pool FRANK_TOOLS_UPSTREAMS = 8211 fanout/8210 ring -> Artemis gpt-oss-120b (10.100.0.5:8000) -> Cesar 120b (11506) -> Cato-sta 120b (11507) -> BigMac 120b (10.100.0.19:8000), with the canary auto-quarantining dead members; (b) LiteLLM fallbacks frankenstein-llm -> glm-5.2-local -> deepseek-v4-pro-openrouter -> deepseek-v4-pro. glm-5.3 cloud is NOT in the frankenstein-llm chain. Amended behavior: any spill/fallback/routing claim must be quoted from the live pool order + fallback config in the same window before it enters a completion; a plausible-sounding spill target is an unverified routing-state claim.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 00:03 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787784000000
- RCA bucket: unread source
- Trigger pattern: correspondence drafted for an open request thread without first reading the latest inbound message on that same thread
- Reversal note: 2026-08-28 reversal: Email 2 in the DSHS copy-paste set was written as a generic 'where are my records' follow-up for TPIA-010 (ORR A08132026.0450013) while HHSC had already sent a clarification/narrowing demand on 2026-08-24 22:03 UTC that the draft never answered. Because Gov Code 552.222 tolls the 552.221 clock while a clarification is pending, sending the unresponsive draft would have left the toll running indefinitely, the exact harm the correspondence was meant to prevent. Amended behavior: before drafting ANY correspondence on an open matter thread (regulator, agency, records request, ticket), read the LATEST inbound message on that specific thread in the same window and quote its date; a draft that does not respond to the most recent inbound message is unverified by construction. Claim scope must equal probe scope applies to correspondence too: a letter claiming to advance a matter must be built on the current state of that matter, not on the state as of an earlier window.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 04:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787931475695
- RCA bucket: wrong premise
- Trigger pattern: claiming served-turn rankings from requested-lane counts or engine POST logs (which include probes/retries) instead of the router audit picked= field
- Reversal note: 2026-08-28 reversal (task 1787931475695): claimed GLM 5.3 served ~477 turns as the #1 engine, derived from (a) REQUESTED lane-name counts in the router audit log and (b) an engine-log POST count. Both are the wrong instruments: requested != served (requests get spilled/remapped downstream — the audit itself shows claude-haiku picks remapped to ollama-llama3.3-70b), and engine POST counts include health probes, canary checks, and retries. The canonical instrument is the router audit's picked= field, which frankenstein_what_served reads (rule 140/322). Corrected: GLM 5.3 local was ~90 turns (54 frankenstein-glm53-local + 7 glm-5.3-local + 29 adapter ring picks) out of 1182 total — NOT #1. Amended behavior: before claiming any served-turn/volume ranking, derive the numbers from the picked= field (frankenstein_what_served) or equivalent served-backend log, never from requested-lane counts or raw engine POST counts; the claim's scope must match the instrument's scope.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

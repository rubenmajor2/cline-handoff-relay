# Rule 317 - Amendment trail (extracted from the live rule 2026-08-19 by #27531 trim)

These sections lived in the always-loaded rule and were bloating every window's system prompt. Case law context: `317-case-law.md`.

## Amendment (from reversal, 2026-08-20 01:44 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: chat-widget-resolve-2026-08-19
- RCA bucket: insufficient probe
- Trigger pattern: Healthcheck green on a canned-200 ping while the real code path throws fatals
- Reversal note: 2026-08-19: chat-widget healthcheck send_ok stayed green for 3 days while 44,521 fatal ArgumentCountErrors hit real visitors. Causal truth verified this window: the per-site ping short-circuits at chat_widget_api.php line 168 (canned ok:true) and the global catch at line 1152 logs fatals and still returns ok, so inflight-probe success is NOT evidence the widget's AI/queue path works. A returned-200 ping is a proxy, not the outcome; only a log-grep guard (idea #27640) detects fatal-class outages. Amended behavior: health checks must either exercise the real code path or grep the error log for that path's fatals; a proxy 200 is never evidence of functioning behavior.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 02:20 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579
- RCA bucket: insufficient probe
- Trigger pattern: cyclic engine drops with clean dmesg concluded as external kill while thermal-shed + /dev/watchdog arm-failure evidence existed in side logs
- Reversal note: 2026-08-19 within-window reversal: earlier in this session Julia's ~28min serve-drop cycle was attributed to an external SIGKILL (clean dmesg, no traceback, no wedge-guard reboot). Wedge-watchdog + catch-relaunch logs then proved thermal 87-92C with THERMAL-SHED (batch cap 11513 3->1) and qwen3-235b model recreation every sweep — a thermal-throttle engine-drop, not an external kill. Amended behavior: before attributing recurring engine drops to a kill signal, probe thermal shed logs, vendor/engine throttle metrics, and hardware watchdog arm state; clean kernel logs alone are NOT evidence of a non-thermal cause.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 02:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579
- RCA bucket: insufficient probe
- Trigger pattern: protection layer reported armed from install evidence while its own log showed every ARM attempt failing on sudo
- Reversal note: 2026-08-19 within-window reversal #2: the 03:08 PT handoff claimed 'wedge-guard auto-reboot installed on Julia' (protection armed). Verified this window: the /dev/watchdog ARM fails every 2 minutes with 'sudo: 1 incorrect password attempt' (5 consecutive sweeps 19:06-19:14 PT in emsu-julia-wedge-watchdog.log) and on-box 'sudo -n true' returns rc=1 — the auto-reboot protection is NOT armed. Amended behavior: a protection/watchdog layer claimed 'installed/deployed/armed' must be verified by reading its own recent success output (an ARM-success tick in its log), never by the existence of a script, cron entry, or prior-window install claim. Install is not armed; a failing ARM log IS evidence the protection is down even while the guarded service serves.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 02:53 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787187212000
- RCA bucket: wrong premise
- Trigger pattern: Assumed every distilled failure mode should have a completion-time text gate without first classifying whether the mode is a text shape (gateable) or a probe behavior (not gateable)
- Reversal note: Reversal-log audit assumed INSUFFICIENT_PROBE needed a structural gate; corrected: it is a probe-behavior failure not gateable at completion time. The actual un-gated mode was SCOPE_ERROR, which now has the R317_SCOPE_ERROR structural gate (done/fixed/resolved headline + same-body remaining-defect enumeration + zero bracketed open-thread idea numbers = BLOCKED). Golden-rule table updated to mark SCOPE_ERROR as structurally gated.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 03:09 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579
- RCA bucket: insufficient probe
- Trigger pattern: empty output from permission-denied probe treated as clean log; temperature readings cited without checking trip points or idle baseline
- Reversal note: 2026-08-19 within-window reversal #3: the ~28min cycle was attributed to THERMAL (87-92C readings + THERMAL-SHED log lines) after Ruben challenged it. Live probes overturned it: thermal trip points are 104.8C (never tripped), zones idle at 53-57C and swing with load, GPU 73C under load. The real signature was NVRM GPU-driver OOM (NV_ERR_NO_MEMORY, 234 kern.log hits on Julia vs 24 on Claudia) correlating with serve/dark transitions — visible in kern.log all along. Compounding error: the earlier 'dmesg/kern.log clean' claim was itself unverified — dmesg requires sudo on the box and the grep had silently failed, returning empty. Amended behavior: (1) a permission-failing probe returning EMPTY output is NOT evidence of 'nothing found' — verify the probe can actually read the log before treating its output as a clean bill of health; (2) correlate temperature readings against the hardware trip points and idle baseline before attributing a failure to thermal — a load-correlated spike during m

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 03:24 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: lockout-cfa-2026-08-19
- RCA bucket: insufficient probe
- Trigger pattern: an empty 0-byte cron log file was treated as a non-signal; the cron had silently failed closed for 5 weeks (CanonicalPricing Column not found since Jul 17) while 800+ suspensions accumulated
- Reversal note: 2026-08-19 within-window reversal: the lockout cluster was initially attributed to cron-vs-SLS payment-oracle divergence. Deeper probe overturned that: cron_cfa_payment_auto_clear.php was silently broken since Jul 17 (CanonicalPricing.php queried removed columns tuition/registration_fee/total_price/effective_date vs new tuition_cents schema, throwing 42S22 on every student and failing closed), AND both it and cron_moodle_suspended_watchdog.php were stuck on first-N LIMIT (100/200) so they never reached new suspensions. Amended behavior: an auto-heal cron's LOG is probative state — stat mtime AND size and run the script manually to verify it actually executes; a 0-byte log older than the script's mtime IS evidence of a silently-dead cron. Also: any driver SELECT with LIMIT N and no OFFSET that must process 'all' rows is a stuck-scan defect; default batches must cover the full table.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

---

## Second trim batch (extracted from the live rule 2026-08-28 by the clause-11 amendment-discipline change)

34 amendments spanning 2026-08-20 03:55 UTC through 2026-08-29 04:46 UTC. They were appended to the live rule tail between the 2026-08-19 trim and 2026-08-28. Per clause 11 the amendment history lives here, not in the always-loaded rule.

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

## Amendment (from reversal, 2026-08-29 06:31 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 28610-clause11-positive-control
- RCA bucket: scope error
- Trigger pattern: clause added in prose with no mechanical enforcement, so the behavior it forbade continued unchanged
- Reversal note: Amends clause 11 (amendment discipline) with its mechanical half. Clause 11 forbade free-floating appended notes but nothing enforced it: amendRuleOnDisk still appended every amendment to the tail of the always-loaded rule file. Patched amendRuleOnDisk so any rule living under Rules/ routes its amendment trail to Rules-archive/N-amendments.md instead, leaving only hand-edited numbered clauses in the always-loaded body. This call is the positive control proving the routing works.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 06:34 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 28610
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - initial: Alexandria Waldrop and Lindsey Barnes have no Moodle account (moodle_user_id NULL) -> corrected: both have Moodle accounts, 51539 and 50701, read from the Students.moodl

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 06:40 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: dnc-ymaris-20260828
- RCA bucket: insufficient probe
- Trigger pattern: batch patcher or sed edit shipped without post-edit php -l and class-load re-run
- Reversal note: amends clause 9: code changes applied by batch patchers/sed must get the same consumer re-run as permission changes (php -l plus class-load of every patched file) before any live claim. The 2026-08-28 EmailClassifier.php:1186 parse error went out because lint was not re-run after the final sed edit.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 07:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787985551437
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - Claimed regime rendered POST_SEPT1 → corrected to before-September-1 | RCA bucket: insufficient probe | my grep matched my own newly-inserted clause text containing the same phra

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 18:12 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: frankenstein-routing-probe-20260829
- RCA bucket: insufficient probe
- Trigger pattern: Aggregating ok/traffic lines from a serving log while ignoring health/failure lines in the same file; presenting a survivor box's traffic dominance as design without classifying why the other configur
- Reversal note: Amends rule 317 by ADDING numbered clause 12 (aggregation integrity for serving/routing tables). 2026-08-29 reversal: window shipped a 'BigMac dominant, routing as designed' table while its OWN same-window probes contained the contradiction: 5 of 8 pool upstreams dead (connection reset/timeout), GLM ring HTTP-200 but decode-dead (0 tokens in 20s; floor window 0/50 vs 30% floor), Julia crash-looping a different model than the registry claimed, adapter-log health lines (usable=1-3/4, DECODE_STALL x98, QUARANTINE x3) present in the same file that was aggregated for traffic counts but never surfaced. Clause 12 requires: (a) health evidence in an aggregated log is reported with the traffic counts, (b) rows whose endpoints failed a live probe this window are marked DOWN/DEGRADED in the same table, (c) zero-traffic pool members are a symptom to classify per rule 297 never silent omission, (d) registry annotations are stale by definition and the completion must reconcile against human-stated f

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 18:27 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787960052755
- RCA bucket: insufficient probe
- Trigger pattern: restored from a misleadingly-named backup after a removal, verified only with php -l + head, without re-running the deliverable-shaped grep
- Reversal note: amends clause 3: after restoring a file from any snapshot, the restore is UNVERIFIED until a deliverable-shaped probe (the same grep that defines the deliverable, e.g. URL-targeted content check) is re-run on the restored file — php -l and head-reads are syntax/header evidence only and do not prove the restored substance. Backup filenames must reflect actual content (PRE-removal vs clean), never the intent of the operation that created them. Source: 2026-08-29 cancer-block re-entry from a backup named .bak-cancer-removed that actually held the pre-removal content.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 18:56 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: glm53-routing-rca-20260829
- RCA bucket: stale assumption
- Trigger pattern: agent repeats "ring wedged / decode-dead / floor can never be satisfied" from a state file or prior-window claim without a this-window decode probe, after intervening repairs shipped
- Reversal note: Amends clause 12 (aggregation integrity): adds the STALE-WEDGE-CLAIM INHERITANCE failure — a "wedged/decode-dead" verdict recorded in a state file, floor window, or prior-window completion is a TIMESTAMPED HYPOTHESIS that expires the moment any repair ships (e.g. the 2026-08-29 00:33 PIECEWISE fix and 10:18 vLLM 0.26.1 cutover). Multiple agents inherited "GLM ring wedged, floor can never be satisfied" from /tmp/emsu_glm_floor_window.json glm_pct=0.0 and a prior window's probe, and repeated it AFTER the ring was live-verified serving (11:47 PT: chat completion 6.4s, CANARY DECODE_LIVE 7.17 tok/s). A wedge claim now requires a decode probe run THIS window AND a check of the repair timeline (bug library + tracker doc) — a floor-percentage file is bookkeeping, never wedge evidence.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 18:59 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788021977080
- RCA bucket: insufficient probe
- Trigger pattern: Recording per-model benchmark results by request name only, without capturing which backend actually served each call, on a gateway that performs silent model substitution.
- Reversal note: Amends clause 1 (never recite LLM/fleet/routing state; probe the live source). Clause 1 said probe the live SOURCE but did not say that the model NAME in a request is not evidence of which model SERVED it. A vision bench on 2026-08-29 recorded per-lane character counts (claudia-qwen38-27b 303 chars, qwen3.8-max 2668) as if the named lane produced them; header probing showed the router's 50/50 doorman had rewritten every one of those calls to a different model, so every number in that bench measured the same two substitutes. Clause 1 now requires: for ANY per-model measurement or serving claim, capture the x-litellm-model-api-base response header (or equivalent backend attribution) in the SAME call, and repeat the call at least twice - a single sample cannot distinguish a stable route from a coin flip. A bench without backend attribution is not a bench of the models named in it.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 19:06 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788021866677
- RCA bucket: insufficient probe
- Trigger pattern: Response model field differs from requested LiteLLM lane name; agent concludes 'silent substitution' without reading /tmp/emsu_router_audit.log first
- Reversal note: Amends clause 2 (acquisition gate) via bug library #2666 case: before claiming a router/model substitution, the ROUTER AUDIT LOG (/tmp/emsu_router_audit.log) is the required probative artifact — it records the actual pick with reason. A response whose model field differs from the requested lane is the FALLBACK LADDER speaking, not the router; classify the backend per rule 315 (refused/timeout = down) before naming any substitution. Without the audit-log read, the substitution claim is a 297-class fabrication risk.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 21:29 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787960052755
- RCA bucket: unread source
- Trigger pattern: Read config/mail.php (smtp587/Postmark) and claimed that transport, when lib/mailer.php loads config/config.php merged with config.local.php; corrected via live SMTP_SEND_OK probe.
- Reversal note: Amends clause 2 (acquisition gate): a mailer's transport must be read from the config file the mailer ACTUALLY loads (config/config.php merged via array_replace_recursive with config.local.php), never from a config file that exists but is unused (config/mail.php). A config file's presence is not evidence of use; probe the loaded value or the live send path before claiming any SMTP/Postmark transport.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 23:07 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788021866677
- RCA bucket: insufficient probe
- Trigger pattern: Agent runs synthetic curl probes against a lane, all pass, then declares the surface verified without replaying the production client's exact request shape (headers, key, body shape, endpoint).
- Reversal note: Amends clause 2 (acquisition gate) with the probe-shape equivalence requirement from the 2026-08-29 Vapi incident: two production bugs (LiteLLM key allowlist rejection + router guard 400) were invisible to passing synthetic probes because the probes did not replay the EXACT client request shape (Vapi custom-llm sends messages-less greeting requests with its own key and header set). A verification probe must replicate the real client's request shape, auth identity, and endpoint — not merely hit the same model name.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 00:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: insufficient probe
- Trigger pattern: emitting a placeholder write call to satisfy turn-shape instead of the real artifact
- Reversal note: Amends clause 2: a write/deploy tool call must carry the REAL full artifact content, never placeholder text framed as 'diff applied via ssh'. This session a write_server_file call carried placeholder content and had to be restored from backup; the causal fix is clause 2 (claims/actions must be backed by real tool call content).

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 01:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788050474905
- RCA bucket: insufficient probe
- Trigger pattern: Treating a local lint pass plus a 200 from our own endpoint as proof that a third-party API will accept the payload we built.
- Reversal note: Amends clause 2 (acquisition gate) with an explicit third-party-schema case: when the deliverable is a PAYLOAD sent to an external API, a local lint pass, a 200 from our own endpoint, and a code read all verify NOTHING about whether the third party will ACCEPT it. The only probative artifact is submitting the exact payload to the real endpoint and reading its status code. On 2026-08-29 a Vapi model override passed php -l, returned 200 from our webhook, and looked correct on read, yet Vapi 400'd it twice for two independent reasons (missing model.url, then echoed model.tools) — each found only by a live POST. Clause 2 now requires: any completion claiming an external-API payload is fixed must cite a live submission to that API and its returned status.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 05:15 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788063424250
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: Amends clause 1/2 (LLM/fleet/state + acquisition gate): a previous window's 'shipped rule X, 353/23 hardfloor' claim was accepted as true from the completion prose without a live probe. Live check showed the rule file absent from ~/Documents/Cline/Rules/ and the clinerules index. Durable fix: any claim that a rule was shipped/reindexed must be backed by clinerules_lookup or read_file of the actual rule file; a stats count (353 rules) alone is not evidence that the specific rule exists.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 23:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 12860-suspension
- RCA bucket: insufficient probe
- Trigger pattern: Filtering/joining an integer column with a slug or string identifier, getting silently coerced matches, and reporting the resulting aggregate as fact without verifying the join key's schema type.
- Reversal note: Amends clause 3 (escalation/insufficient-probe gate): a JOIN or WHERE key is a schema fact, not a naming convention. Filtering an INT column with a slug string (WHERE student_id = '26814T-15' against int(10) unsigned) silently coerces to 26814 and returns a populated, plausible, WRONG result set with no error - which was then shipped as "8 duplicate invoices totaling $11,315" when the student had exactly one $1,545 invoice. Before any per-entity aggregate is claimed, the filter column's TYPE must be read (SHOW COLUMNS / INFORMATION_SCHEMA) and the correct key used. A query that returns rows is not a query that returned the right rows.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 23:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788062963405
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: Amends clause 2 (acquisition gate): I declared 47 ai_ticket_agent_actions rows 'successes mislabeled as failures' and flipped them to success=1, using only the ai_reasoning TEXT ('Warning email sent', 'Called student about ticket') as evidence. Reading action_details JSON showed the opposite: vapi_error subscriptionLimits/concurrency and sent_email:false, i.e. genuine failures. Durable rule: a human-readable narration column describes the ATTEMPTED action, never the OUTCOME. Before reclassifying any row's success/failure state, read the structured outcome fields (action_details JSON + the success column), never the prose column. Data-destructive reclassification requires the probative artifact, not a plausible-sounding string.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 00:37 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788063169755
- RCA bucket: insufficient probe
- Trigger pattern: declaring a signal/source dead from an empty column or zero-row harvest without reading the consumer function signature and producer write target
- Reversal note: Adds clause 13: before declaring a data-signal table dead or empty, verify (a) the CONSUMER's input contract — its function signature and where each argument comes from — and (b) the PRODUCER's WRITE-SIDE target table plus row-id source. This window declared orchestrator_action_log.failure_category dead (19 stale rows, May only) and marked the action learner blocked, without reading that orchestratorActionRecipeConsume() receives failure_category as a PARAMETER the executor computes live at call time, not from that column. The real defect was the executor writing failure_category to orchestrator_execution_log using the action_log insert id (cross-table id reuse), leaving the consumer's real signal table empty. A php -l pass and a 'harvested 0' run are not proof a loop is dead — probe the contract and the write target first.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 01:48 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: insufficient probe
- Trigger pattern: Declaring a public-endpoint fix verified from the server's own allowlisted IP/LAN DNS view instead of the consumer's public egress path
- Reversal note: Amends clause 2 (acquisition gate) + golden rule: claim scope must equal probe scope — a curl resolved through split-horizon/LAN DNS (or run from the allowlisted server IP) is NOT evidence that a public cloud consumer (Vapi) can reach the endpoint. When the claim is 'Vapi can reach X', the probe MUST force the PUBLIC egress view (e.g. curl --resolve to the public A record or an external resolver), because orange-cloud CF-fronted subdomains return 403 to non-allowlisted consumers while the origin curls fine. First fix of task claimed FIXED after server-side curls, call still failed with providerfault-custom-llm-llm-failed; corrected by probing via public A record 172.116.115.101 (200 + stream chunk).

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 01:57 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788062963405
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: Amends clause 2 (acquisition gate): I reported '17 Vapi concurrency-limit errors causing silent callback failures' after reading only the failure_category label I had just created. Reading the action_details JSON showed 14 of the 17 were vapi_status=201 with concurrencyBlocked:false and remainingConcurrentCalls:9 — SUCCESSFUL calls — and the 3 real failures were vapi_status=400 'Numbers Bought On Vapi Have A Daily Outbound Call Limit', a different cause entirely. Durable rule: an HTTP 2xx in a stored provider response means the call SUCCEEDED regardless of what other fields (subscriptionLimits, quotas, warnings) appear alongside it; a provider envelope that merely MENTIONS a limit is not a limit error. Before reporting any provider-failure count, group by the actual status code, never by a category label you just assigned.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 02:20 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 28758
- RCA bucket: insufficient probe
- Trigger pattern: reciting a model-route/alias claim from memory of a previous window instead of probing the live DB + litellm config this window
- Reversal note: AMENDS CLAUSE 1: claimed widget AI model claude-sonnet-4-6 'resolves to a slow local vLLM alias' from memory of a prior session. Live probe showed 42/42 chat_portal_sites rows = frankenstein-llm; claude-sonnet-4-6 existed ONLY as PHP fallback defaults (api/chat_widget_api.php:1459, lib/emsu_ai_brain.php:226) plus litellm aliases routing to deepseek/gpt, NOT a live widget model. Rule now requires: a serving-model claim about the widget MUST quote this-window evidence from chat_portal_sites.ai_model and the litellm route for THAT model string before attributing latency to it — never a prior session's recollection of an alias.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 03:17 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 12860-suspension
- RCA bucket: insufficient probe
- Trigger pattern: Declaring an entity has zero records (no invoices, no payments, owes nothing) on the basis of one convenience tool's empty section, without re-querying the underlying table by the entity's own externa
- Reversal note: Amends clause 3 again: an ABSENCE returned by a per-entity lookup is not proof the thing does not exist. verify_payment_state and get_student_360 for Lindsey Rose both returned "invoice_count 0, balance $0" because those tools join on Students.id, and her invoices were mirror-tied to a DIFFERENT student's id. Reporting "she owes nothing" from that empty result was a false negative that nearly sent a wrong letter to a student with $5,835 of real invoices. Before claiming any entity has NO records, query the record table by the entity's OWN foreign identifiers (qb_customer_id, email, external customer id) and not solely by the internal join key the convenience tool uses. A join-key-scoped empty result proves only that the join key found nothing.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 03:41 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788050474905
- RCA bucket: insufficient probe
- Trigger pattern: quoting systemd Environment= values from systemctl cat / unit file grep without resolving drop-in last-wins order or reading /proc/PID/environ
- Reversal note: Amends clause 1/INSUFFICIENT_PROBE: systemd unit config claims must resolve LAST-WINS drop-in semantics — a grep of `systemctl cat` output shows EVERY historical Environment= line and the FIRST occurrence is usually stale. The only ground truth for a running service's config is `sudo cat /proc/<MainPID>/environ`. This window claimed 'GLM never in executor tool pool by design' from a first-occurrence read; the running process env showed GLM 8210+8211 in pool with EMSU_GLM_LANES_CLINE=4/BATCH=4 exactly per Ruben's design.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 04:17 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788050474905
- RCA bucket: insufficient probe
- Trigger pattern: declaring a tunnel-fronted service dead from WOPR-side tunnel probes alone, without alternate-path probe or record check
- Reversal note: Amends clause 3 (escalation probe before declaring any wall) + reinforces rule 322 tunnel-vs-model: a WOPR-side tunnel probe returning 000/reset is evidence about the TUNNEL, never the far-end service. This window declared 'Nero dead, no remote path' from tunnel-port probes while the MLX service on the SMS Mac was running all along (Ruben's local curl returned the model list before AND after an identical kickstart — the service state never changed). Before declaring any tunnel-fronted service down: (a) check whether the far end can be probed via ANY alternate path, (b) check the record for the box's own revival/kickstart recipe, (c) if only the tunnel is unprobeable, the verdict is TUNNEL-UNREACHABLE, never SERVICE-DOWN.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 04:29 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788050474905
- RCA bucket: insufficient probe
- Trigger pattern: declaring a model capability absent from a single lane's rejection without checking the official card or a second serving stack
- Reversal note: Amends clause 1/INSUFFICIENT_PROBE: a capability rejection from ONE serving stack is NEVER a model-capability verdict. This window probed an MLX 4-bit lane (Maximus :11530), got 'Only text content type is supported', and declared Qwen3.8-27B text-only — but the official HF card says native vision-language model, and the vLLM deployment of the SAME model (Julia :11513) answered a red-pixel image correctly seconds later. Serving-stack limits (MLX harness, missing flags) must be attributed to THE LANE, never the model. Before any capability claim: check the official model card (rule 324) AND probe a second deployment of the same weights.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 05:11 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 12860-suspension
- RCA bucket: wrong premise
- Trigger pattern: Shipping a validation guard as a hardcoded absolute threshold (or a global derived one) rather than an entity-relative invariant, creating a false-block landmine that detonates when the business legit
- Reversal note: Amends clause 3: a guard expressed as a HARDCODED ABSOLUTE THRESHOLD (dollar ceiling, row-count limit, byte size, latency bound) is not a durable fix - it is a deferred outage that fires the day the business legitimately crosses it. Shipping DUNNING_MAX_PLAUSIBLE_BALANCE=6000.00 would have silently blocked collections for every student in any future course priced above $6k. Deriving the same ceiling globally from fleet-wide max was equally wrong in the other direction: it produced $32,140, which would NOT have caught the actual $12,860 defect. The durable form is a RELATIVE INVARIANT scoped to the entity: the emailed figure must reconcile to that student's OWN rows and stay within a small multiple of that student's OWN price (Alex was 8.06x his own max invoice - identical signature whether tuition is $500 or $50,000). Before shipping any guard, ask: what happens to this constant when the business grows 10x? If the answer is a false block, the threshold is the wrong shape - express it a

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 05:17 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: stale assumption
- Trigger pattern: Reciting tier/ladder/alias labels as live serving status, and emitting down/wedge/quarantine verdicts from memory or prior-window canary instead of a this-window live probe + tracker read.
- Reversal note: Amends clause 12 (aggregation integrity for serving/routing tables): a routing report that names a backend by its litellm ALIAS is a misrepresentation. frankenstein-tools, frankenstein-llm, and emsu-codegen are ALL the same gateway (api_base 127.0.0.1:11510), so grouping them as three distinct 'backends that served' overstates the fleet. A truthful routing table MUST resolve aliases to underlying adapter upstreams and cite /var/log/emsu-adapter-upstream.log per-lane counts for the window, AND must reconcile against GLM53_RING_STATE_TRACKER.md (append-only fleet identity) which redundantly warns 'READ THIS TRACKER FIRST before any fleet verdict'. A DOWN/WEDGE/QUARANTINE verdict for any endpoint (cicero-235b, decoded-wedged, fail-streak quarantine) requires a live probe THIS window returning proof: this session reported 'claude-3-7-sonnet 35 turns', '70B 6 turns', and 3 decode-wedged + 2 quarantined adapters, all DISPROVEN by config grep (alias absent), registry (70B retired:true 8/22), 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 06:27 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788143692000
- RCA bucket: scope error
- Trigger pattern: Explaining a traffic distribution change by reference to a collapsed pool without enumerating the spill rungs that remained available (cloud/DeepSeek), producing an over-broad 'nothing left' claim.
- Reversal note: Amends clause 12 (aggregation integrity): a traffic-share explanation scoped to ONE pool (the free-local adapter pool) must not be phrased as a statement about the WHOLE routing ladder. 2026-08-30: a completion said 'there was nothing else left to route to' after the local Qwen lanes died - false, because the LiteLLM ladder always retains DeepSeek-v4-pro and paid cloud rungs above the adapter pool. The correct claim shape: 'the local Qwen rung was absent, so traffic that the ladder would have kept local fell to the 120Bs and, at saturation, onward to cloud' - naming which rung was missing, never implying the chain terminated. Completion claims about routing must enumerate the full ladder including rungs ABOVE the probed pool.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 17:45 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: grievances-20260831
- RCA bucket: insufficient probe
- Trigger pattern: Wrote a batch loop that renders all PDF pages at full resolution before OCR, without checking page dimensions or swap headroom; process died mid-run.
- Reversal note: amends clause 3: before batch-rendering PDF pages for OCR, probe page dimensions and swap headroom first. This window the batch render of a full-res 3024x4032pt 4-page phone-photo PDF exhausted swap (30MB free) and killed the process silently; the corrected approach rendered one page at a time at 150 DPI then downscaled to 1568px, which succeeded. A render loop is a probe surface too: check swap and per-page pixel count before holding multiple pages in memory.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 17:49 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788161048426
- RCA bucket: insufficient probe
- Trigger pattern: Agent runs a filename/name search, gets zero hits, and records "not located" as a finding rather than as the result of one narrow probe. Especially dangerous with scanned documents, which are invisibl
- Reversal note: Amends clause 3 (escalation probe before declaring any wall) to cover DOCUMENT-ABSENCE claims: a filename or name search returning nothing is NOT evidence a document does not exist. Scanned PDFs carry no text layer, so grep and name queries are blind to them, and a file whose name omits the counterparty is invisible to both. Before declaring any instrument, contract, or record "not located," the agent must exhaust the content path: test each candidate for a text layer, rasterize and OCR the ones without, and read the party and execution blocks. Source: 2026-08-31 TDSHS 1080262054 reversal. A prior window wrote "only Karnes County EMS and Bexar-Bulverde have been found" and instructed that no filing claim all agreements were located. A content+OCR sweep of the same store located executed instruments for six of the nine organizations DSHS named plus three more, including one filed under a business-license filename and one under a null_ prefix. The false-absence claim was about to go into

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 18:02 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: insufficient probe
- Trigger pattern: Treating an errored/failed tool call as a successful probe result and propagating its would-be verdict into files, DB rows, and dispositions.
- Reversal note: Amends clauses 1 and 3 and adds clause 13: a tool call that returns an ERROR (invalid JSON, MCP child-timeout, non-zero) produced ZERO evidence and must never be treated as if it returned a probe verdict. This window wrote a Maximus 'no MLX backend / orphaned sshd' finding into the drop-in and stamped an idea [rejected] after its first probe call failed with 'Invalid JSON argument', i.e. a fabricated probe result with no probe at all.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 18:12 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: unread source
- Trigger pattern: Writing a status/disposition from an assumed enum vocabulary without reading the actual column definition, then trusting rows affected as proof the value persisted.
- Reversal note: Amends clauses 1 and 13: before writing a disposition to orchestrator_ideas.status, probe information_schema.COLUMNS; MySQL non-strict silently coerces enum values not in the column type (an UPDATE to 'superseded' became 'rejected' with rows affected=1). A live SELECT after every UPDATE or write is the proof the write is actually true.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 18:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788161048426
- RCA bucket: insufficient probe
- Trigger pattern: Agent searches the filesystem and cloud storage for a document, gets zero hits, and reports absence without ever querying the database table the application itself uses to track those documents. Compo
- Reversal note: Further amends clause 3, second reversal in the same session on the same question. The first amendment said to exhaust the CONTENT path (OCR scanned files) before declaring a document absent. That was still insufficient, because it stayed inside the filesystem. The durable rule: for any "do we have a record of X" question, query the APPLICATION'S OWN REGISTRY first, before the filesystem and before cloud storage. Filesystem and Drive hold bytes; the registry holds the mapping from bytes to meaning. Source: 2026-08-31, after OCR corrected the first false absence, the dossier still reported Colorado County EMS as not located. It was registered the whole time in ExternshipSite.compliance_doc_id -> compliance_documents as doc 11 with original_filename "Colorado County Affiliation.pdf", stored on disk under the meaningless name clinical-site-agreement_school_3a81ee00.pdf, executed by both parties. Three of the located instruments had stored filenames that named neither party, so no filesyst

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 18:35 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788162122
- RCA bucket: insufficient probe
- Trigger pattern: Declared "AMR genuinely absent, zero hits anywhere" after searching only the literal string AMR/American Medical across document registries; the organization was actively corresponding under its paren
- Reversal note: Amends clause 3 (escalation probe before declaring any wall): before declaring an ORGANIZATION or counterparty absent from the record, exhaust its ALIAS/BRAND-FAMILY names (parent company, dba, rebrand — e.g. AMR = Global Medical Response = GMR) across ALL data surfaces including email logs (email_inbound_log, email_outbound_log, jon_email_triage), not just document registries and filesystems. A zero-hit search on one brand name of a multi-brand organization is an insufficient probe.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 18:55 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788162122
- RCA bucket: insufficient probe
- Trigger pattern: Declared documents absent from Drive after bare-keyword name search of a recordings-dominated corpus, without quoted-phrase + filetype search or asking for legacy archive locations.
- Reversal note: Further amends clause 3, second reversal in the same session on the same question. The first amendment (alias/brand-family search) was still insufficient: the "AMR genuinely absent from Drive" claim was based on a name search of the DEFAULT Drive corpus, which is dominated by Zoom recordings. The human then supplied a legacy archive folder link where three executed AMR instruments sat. Rule: before declaring a document absent from Drive, (a) ask the human whether a legacy/archive folder exists, (b) use quoted-phrase searches ("American Medical Response" agreement) with file-type filters, and (c) note that older Drive files behind auth walls need the OAuth token refresh flow (google_token_drive.json), not the uc?export=download endpoint.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 22:18 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788195482100
- RCA bucket: insufficient probe
- Trigger pattern: claiming a cache-cap fix eliminated the wedge after verifying /v1/models 200 + process relaunched with flags + cache size, without a full decode probe; cold-start OOM fired right after kickstart
- Reversal note: Amends clause 13 (MLX decode-wedge). The wedge is TWO axes, not one: (1) prompt-cache growth under concurrent decode — fixed by --prompt-cache-size/bytes + decode/prompt-concurrency caps, verified by a live Prompt Cache read under load; and (2) cold-start-load OOM (large prompt arriving while the 27B model is still loading + Ollama VRAM on the same unified GPU). A fix for axis 1 is NOT proof the wedge is eliminated: a process relaunched with caps can still OOM on axis 2 ~2min after kickstart. Required: before claiming an MLX OOM fix 'prevents' the wedge, probe a COMPLETE decode POST to 200 under load from that exact process (not /v1/models, not process-cmdline, not cache size alone); a cache-stays-small read or /v1/models 200 is insufficient.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 22:55 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: insufficient probe
- Trigger pattern: SET status to a value not in the ENUM, then trusting ROW_COUNT/affected-rows instead of a read-back SELECT
- Reversal note: Amends clause 1. A write's ROW_COUNT/affected-rows is NOT a disposition probe. When any INSERT/UPDATE targets a status column, SELECT the row back and quote the returned value as the disposition proof. Specifically: an invalid ENUM value silently coerces to '' under non-strict sql_mode, and a BEFORE UPDATE trigger (orchestrator_ideas_status_audit) can re-derive the value from dev_stage, so ROW_COUNT=1 can coexist with the wrong status landed (observed: status=awaiting_review was set, coerced to '', trigger re-derived approved).

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 03:41 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: postmark-webhook-rca-20260831
- RCA bucket: insufficient probe
- Trigger pattern: Agent declared a recurring failure 'durably fixed' after verifying only the symptom-suppression layer (autoheal re-enabled the triggers) without ever probing WHY the vendor kept disabling them. Inheri
- Reversal note: Amends clause 3 (escalation probe before declaring any wall) and the INSUFFICIENT_PROBE golden-rule row. New requirement: when an EXTERNAL service reports connection-level failure (StatusCode 0, HttpRequestException, connect timeout) while your own endpoint returns 200 to LOCAL curl, a local HTTP probe is NOT probative - it traverses the hairpin path and cannot see an inbound drop. You MUST (a) run a packet capture to determine whether the vendor's SYNs arrive and are answered, and (b) inspect the FULL netfilter path including `iptables -t raw -L PREROUTING -n -v` and mangle/nat, not just INPUT, before attributing the failure to the vendor. An INPUT-chain audit returning clean is NOT evidence of no block: raw PREROUTING executes before INPUT, so an ACCEPT at INPUT position 1 can show 0 packets while tcpdump captures the SYNs. Additionally: re-enabling/restarting a resource the vendor keeps disabling is symptom suppression, not a fix - a recurrence after a claimed durable fix means the 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 04:03 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: current-lane-planning
- RCA bucket: insufficient probe
- Trigger pattern: probing stale legacy WireGuard IP 10.100.0.15/.16 instead of the live reverse-SSH tunnel path WOPR:2205/2206, then declaring the box down
- Reversal note: Amends clause 2 (acquisition gate) + clause 3 (escalation probe): a fleet box was declared PHYSICALLY DOWN (WG dead, no route, 'physical action needed') after probing a STALE WireGuard IP (10.100.0.15/.16 from the old Docker-WG era in GLM53 tracker). The REAL production access path is a reverse SSH tunnel via WOPR:2205/2206, which was reachable, no WG involved. Correct probing showed the box ALIVE (uptime 2d+) with only the vLLM LANE not serving (empty :8000 listener). New requirement: before declaring any box down/offline, enumerate the access paths a LIVE process uses (reverse tunnels, mDNS names, /etc/hosts, ssh -p 220x) and probe the one serving code actually originates from; a failed ping on a legacy IP is never evidence of physical down.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 04:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: lane-health-checkpoint-20260831
- RCA bucket: insufficient probe
- Trigger pattern: Declaring host-down from a stale IP map instead of probing the live access path (reverse tunnel ports)
- Reversal note: Carryover flip from earlier segment (same window): declared Julia/Claudia 'physically down / WG no route' based on stale Docker-WG IPs 10.100.0.15/.16; corrected to ALIVE via reverse SSH tunnels WOPR:2205/2206. Amends clause 2 (acquisition gate): host state must be probed via the REAL documented access path (reverse SSH tunnel ports), never a remembered legacy IP map.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 05:05 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788212457240
- RCA bucket: insufficient probe
- Trigger pattern: outage root-cause asserted from plausibility (laptops sleep) without reading pmset -g log / uptime on the affected box
- Reversal note: Amends clause 3 (escalation probe before declaring any wall) and the INSUFFICIENT_PROBE golden mode: an OUTAGE ROOT-CAUSE claim ("the box was asleep") is a wall-class claim requiring the box's own forensic record (pmset -g log sleep events, uptime, last reboot) before shipping. 2026-08-31 flip: claimed Maximus+Cicero vanished because "laptops sleep"; live probe showed Cicero up 11 days with ZERO Entering-Sleep events — the real cause was tunnel agents targeting an unroutable WG IP (10.100.0.1) after the box's WireGuard was disabled, making any single tunnel drop permanent. A plausible mechanism is not a root cause until the box's own logs confirm it.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 06:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: joshua-tp2-followup
- RCA bucket: insufficient probe
- Trigger pattern: Concluding 'X is not viable' from one failed attempt when the same box previously served X with a different env var; missing the config-diff instead of the hardware verdict.
- Reversal note: Amends clause 1/2 (acquisition gate): declared 'TP=2 not viable on Joshua' from a single pidfd-IPC attempt after a GPU reset storm, WITHOUT checking the box's own proven TP=2 serving recipe first. Forensics then found unit backup service.bak-tp2-20260831 (pidfd TP=2) vs the 2026-08-22 serving recipe (CCL_ZE_IPC_EXCHANGE=sockets + CCL_TOPO_FABRIC_VERTEX_CONNECTION_CHECK=0, W4A16 int4 131K, 64 tok/s@8 for days). The wedge is the pidfd path + gdm greeter contention, not TP=2 per se. Rule now requires: before declaring any flag/config combination non-viable, grep the box's own unit backups + HANDOFF_NOTES for a prior successful run of that combination and name the exact env delta.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 07:28 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: kaizen-learner-status-20260901
- RCA bucket: insufficient probe
- Trigger pattern: declaring a negative runtime state (zero failures/no activity) from a coverage report without probing the live fires table
- Reversal note: Amends clause 2 (acquisition gate): a coverage/backfill report showing '0 unclassified patterns' does NOT prove the runtime is quiet. Claimed 'zero failures since 08-30 20:32' while orchestrator_recipe_fires showed 43k live fires (33k unclassified fallback + 9.9k worker_silent_death) in the same 36h window. A completion claims about runtime activity must probe the live fires/execution table this window, never infer from the forensic coverage view.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 08:12 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: lane-health-checkpoint-20260831
- RCA bucket: insufficient probe
- Trigger pattern: Using an empty result from a guessed table/file name as positive proof that a subsystem does not exist or is not wired
- Reversal note: Amends clause 2 (acquisition gate): a NULL/empty result from a GUESSED identifier (SHOW TABLES LIKE '%minicheck%' returning nothing) is NOT evidence about architecture. I asserted 'MiniCheck is not wired to Cline, nothing was checking my numbers' citing that empty result as proof. grep -rln MiniCheckVerifier then returned 5 real callers (argus_proxy.php, AgentReplyPipeline.php, SMSAIResponder.php, mailer.php, cron_minicheck_skip_watch.php) and the class logs to truth_judge_log, whose surface column DEFAULTS to 'cline'. Clause 2 now requires: before any claim that a component is absent or unwired, grep for the CLASS/FUNCTION name in code, never infer absence from a guessed table name. Absence of a name you invented is not absence of the system.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 08:48 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788243351
- RCA bucket: insufficient probe
- Trigger pattern: Copying host-relative config (loopback ports, ssh aliases, paths) from a component on another host without re-probing from the new host, in a fail-open code path where the error is invisible
- Reversal note: Amends clause 2 (acquisition gate) for CONFIG values copied between hosts. Building the MiniCheck gate, I copied MiniCheckVerifier.php's endpoint list (127.0.0.1:11535/11455/11505) into an MCP that runs on a DIFFERENT host, and separately guessed the ssh alias 'emsu'. Both are the same defect: a config value valid in its ORIGINAL host context was reused without probing it from the NEW context. Measured: Mac curl returned 000/000/404 while WOPR returned 200/200/000; grep -c 'Host emsu' returned 0. Because the gate fails open, either error alone would have produced a verifier that looked installed and checked nothing. Clause 2 now requires: when copying an endpoint, port, host alias, or path from another component, probe it FROM THE HOST THE NEW CODE RUNS ON before shipping, and for any fail-open component add an end-to-end test that proves it returns a real verdict, since a silent no-op is indistinguishable from a healthy pass.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 08:50 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: joshua-tp2
- RCA bucket: insufficient probe
- Trigger pattern: Inferring collective viability from a prior boot on a different date or from env-flag presence instead of a live 2-tile allreduce probe this window
- Reversal note: amends clause 2 (acquisition gate): a TP=2 collective-viability claim requires a LIVE cross-tile collective probe (actual allreduce over 2 tiles reaching startup-complete), never an inference from a prior dated boot recipe. This session reversed 'TP=2 viable with proven 8/22 recipe' -> definitive wall: ProcessGroupXCCL::initXCCLComm/allreduce_impl crashes on BOTH ray and mp executors after stale-ray cleanup, so oneCCL cannot create a 2-tile communicator on Joshua with this image/driver.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 16:59 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: joshua-tp2-experiment-20260901
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: Within-window reversal: I declared 'TP=2 cannot serve on this stack today' after one env variant (CCL_ATL_SHM=1 + FI_PROVIDER=shm) wedged at shm_broadcast. Ruben then said 'babysit it to serving.' The very next variant (remove CCL_ATL_SHM + FI_PROVIDER=tcp) reached Application startup complete, HTTP:200, and a clean decode (content 'OK', finish_reason=stop, fingerprint ...tp2). Amends clause 3/numbered-clause discipline: a negative verdict ('cannot serve', 'impossible', 'not achievable') is only valid after exhausting candidate env variants, never from one failed config. The declarative unit change was verified by a live serving probe this window, not by config presence.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 17:07 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788245681701
- RCA bucket: insufficient probe
- Trigger pattern: Reading an empty output/analytics table and attributing it to low demand, without invoking the producing surface once to distinguish idle from broken.
- Reversal note: Amends clause 2 (acquisition gate): an absence-of-traffic observation is NOT evidence of low usage until the surface itself has been invoked end to end this window. The prior window read argus_analytics=0 rows/7d and reported it as "no real traffic", when every Argus request had in fact been returning HTTP 502 since 2026-08-28 because haproxy bound :4000 loopback-only while api/argus_proxy.php dials 10.100.0.1:4000. Clause 2 now requires that any claim explaining WHY a surface has no data must be backed by a live invocation of that surface, not by a row count of its own output table. A zero row count is a symptom shared by "nobody used it" and "it is completely broken", and those need opposite responses.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 17:31 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: joshua-tp2-stabilize-20260901
- RCA bucket: insufficient probe
- Trigger pattern: trusting a success-echo without re-reading the artifact
- Reversal note: Amends clause 2 (acquisition gate): a tool output that prints APPEND_OK / exit 0 is not proof of a write — the artifact content itself must be re-read. First GLM53 tracker append attempt printed APPEND_OK while the write had failed with Permission denied (stderr); corrected by re-running with sudo tee -a and verifying tail -3 showed the new section.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 18:02 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 29178
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: Amends clause 3 (escalation probe before declaring any wall): on 2026-09-01 the TastyBot task declared a credentials wall (no TASTY_API_TOKEN, no sync code) after probing only the EMSU server and Mac dotfiles. The real, already-authorized TastyBot program (OAuth client id/secret in .env, refresh_token in tokens.json, live dashboard at 127.0.0.1:8765) sat at ~/Library/Application Support/TastyBot/repo the whole time. Lesson: when the deliverable is a Mac desktop app, the Mac APP SUPPORT DIRECTORIES (~/Library/Application Support, Preferences, LaunchAgents, Containers) are probe surfaces on par with server configs; declaring any credential/source wall without enumerating them is INSUFFICIENT_PROBE.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 18:13 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788281756491
- RCA bucket: insufficient probe
- Trigger pattern: A count JUMPED after a bug fix and the jump was reported as the deliverable ("224 students unmasked") without probing whether the NEW larger population actually passes the downstream gate that consume
- Reversal note: Amends clause 3 (escalation probe / claim-scope): a bug fix that CHANGES A POPULATION COUNT is not verified by the new count alone. Before reporting the delta as the win, run the downstream consumer of that population against its own gate and confirm the two agree. If the count moved because an exception stopped throwing, the pre-fix filtering may have been accidental and the explicit gate may never have existed. Source 2026-09-01: fixed a $ov use-before-assign crash in externship_eligibility_gate, reported "224 eligible students unmasked, list 39 -> 263" as a shipped win; a dry-run of the offer dispatcher then showed 224 of the 263 fail the 80% course-progress gate (206 at 60%, 15 at 0%, 3 at 40%). The list and its consumer disagreed for ~40 minutes and the completion had already claimed the larger number. Fix: waiting list now gates on progress_ok + empty(missing) explicitly, back to 39, and dispatcher re-checks independently.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 18:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: joshua-lanes-disk-20260901
- RCA bucket: insufficient probe
- Trigger pattern: port-probe 000 treated as a fleet DOWN verdict instead of UNKNOWN
- Reversal note: Amends clause 1 (fleet/routing state) and adds a numbered blip-class rule: a single HTTP-000 on a reverse-tunnel port alias (127.0.0.1:NNNN on WOPR) is NOT a down-model verdict and MUST be recorded UNVERIFIED, never DOWN — the 000 may be a tunnel blip or stale reference while the on-box endpoint is healthy. Joshua re-probes this window: Julia/Claudia :11513 000 and :11521 000 were labeled DOWN; legal on-box re-probe must be attempted (via SSH control alias to the serving host) before any DOWN disposition. Also amends clause 12(e): HTTP-200 on /v1/models plus HTTP-200 on /v1/chat/completions is still not serving — decode body must show non-null reasoning/content tokens; a 200 with content=null and finish_reason=length can be a healthy reasoning-only generation, verified by the reasoning field, not assumed wedged.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 00:31 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: oceanside-outage
- RCA bucket: stale assumption
- Trigger pattern: Recited ring node count and watchdog status from memory instead of reading the topology doc, relaunch script, and ring state tracker first.
- Reversal note: Amends clause 1 (LLM/fleet state — never recite from memory). This window recited fleet topology and watchdog state without probing: claimed '4 Romans down' when the ring is 6 nodes (Cato rank0 2aa8 + Augustus e3b2 + Pompey 50c0 + Marcus 63ce + Tiberius e9e0 + Cesar 3b41, confirmed in GLM52_RING_TOPOLOGY.md and the relaunch script's 6 call sites), and claimed the watchdog 'silent dead 3 days' when the tracker documents it intentionally STOPPED (single-owner #2659) and re-armed this window. Both corrected by probing the topology doc, the relaunch script, and the tracker. Causal fix: a node count or fleet state must cite the authoritative artifact (GLM52_RING_TOPOLOGY.md rank table, relaunch script call sites, tracker), never memory.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 01:03 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: cli-fl-doh-500-fix
- RCA bucket: insufficient probe
- Trigger pattern: claimed 'renders after login' from an anonymous 401 probe; the authenticated render fatally errored with undefined $pdo
- Reversal note: Amends clause 2 (acquisition gate): an HTTP 401 on the anonymous surface of an auth-gated route proves only that the route exists and the front controller runs — it is NOT evidence the authenticated surface renders. Shipping 'renders after login' without probing the authenticated render path caused a live 500 to reach the user. Before claiming any page renders, probe the authenticated render path (CLI include with simulated session, or authenticated request) this window.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 01:07 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788285310173
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - Claimed 'renders after login' from an anonymous 401 probe -> corrected: the authenticated render fataled with undefined $pdo (HTTP 500) | RCA bucket: insufficient probe | causal 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 17:04 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788335461694
- RCA bucket: wrong premise
- Trigger pattern: Agent claims a patch/script/config was deployed because it ran a write command, without re-reading the target file to confirm the change landed.
- Reversal note: Amends clause 2 (acquisition gate): a prior window claimed 'boot guard wired into relauncher line 12' but ssh diff showed the relauncher byte-identical to its pre-guard backup — a deployment claim shipped without a read-back probe. Reinforces the golden rule: claim scope must equal probe scope, and a DEPLOYMENT claim specifically requires a post-patch read-back (grep/diff), never an inference from having run the patch command.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

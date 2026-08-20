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

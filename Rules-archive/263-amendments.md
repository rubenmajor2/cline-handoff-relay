Rule 263 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 263 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules-archive/263-verify-before-claim-no-stale-inference.md

## Amendment (from reversal, 2026-08-29 08:41 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787984810000
- RCA bucket: unread source
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: amends the cgroup-identity gate: never claim 'all watchdogs stopped' from pkill alone — a root-owned systemd unit (observed: glm52-watchdog.service PID 678) survives user pkill and can fire relaunches mid-boot. Always enumerate /proc/<PID>/cgroup owners for every matching PID before declaring a process class dead.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-01 18:24 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 29208
- RCA bucket: insufficient probe
- Trigger pattern: Inserting an uncatalogued value into an enum column without SHOW COLUMNS, then discovering the stored value is empty.
- Reversal note: Amends rule 263 (verify before claim): before INSERT into an enumerated column (orchestrator_ideas.domain), probe the column definition first. An unverified enum value is silently rejected and stored as empty, which is an unverified write. Corrected 29208's domain to 'academic' after SHOW COLUMNS verified the enum set.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

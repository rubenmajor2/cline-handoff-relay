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

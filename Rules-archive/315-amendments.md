Rule 315 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 315 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/315-verify-before-declaring-host-down.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 8 amendment(s))

## Amendment (from reversal, 2026-08-20 02:34 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787187212000
- RCA bucket: insufficient probe
- Trigger pattern: local mysql client failure treated as a wall instead of switching to the mysql MCP execute_query path
- Reversal note: 2026-08-19: tried a local mysql client against orchestrator_ideas and treated the failure as a blocker; the table lives on WOPR and was stamped via the mysql MCP execute_query (UPDATE Rows affected: 1). Amended behavior: before declaring a DB write blocked, probe the alternate path (mysql MCP server) first; a local-client failure is not a permission wall.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 06:31 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: wrong premise
- Trigger pattern: link-state register read interpreted as evidence of a physical connection partner
- Reversal note: 2026-08-19 Big Mac post-bifurcator probe: a root port LnkSta showing Speed+Width active (2.5GT/s x16) was initially narrated as the 4th GPU training against the port. Scope error: link-state registers prove the port's own state, not what is physically cabled to it — on this platform unconnected bifurcated root ports present the same active LnkSta signature. Corrected behavior: an LnkSta read may be claimed as evidence of a specific link partner ONLY when a downstream endpoint actually enumerates behind that port; a bare LnkSta without downstream enumeration proves port state only. Physical topology claims require physical confirmation (tech/cabling), never inference from LnkSta alone.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 14:22 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579-bigmac-297
- RCA bucket: insufficient probe
- Trigger pattern: empty journalctl output on a Docker-hosted engine treated as evidence of engine state instead of as a wrong-instrument read
- Reversal note: 2026-08-20 Big Mac 297: agent probed a CONTAINERIZED vLLM workload with 'journalctl -u bigmac-vllm.service', which returns EMPTY because the engine runs inside Docker (container bigmac-vllm). The empty output was then treated as corroborating evidence for a wedge verdict. The verdict happened to be correct (docker logs later showed startup-complete=0, :8000 unbound, log dead-ended at Ray 'Creating a new placement group'), but it was reached on non-probative evidence - a wrong-instrument read that would equally have 'confirmed' a healthy box. Amended behavior: before citing ANY log as evidence of engine state, confirm the log source matches the execution substrate - systemd unit -> journalctl -u; Docker container -> docker logs <container>; bare process -> its redirect file. The registry's vllm_logs field names the correct source per host (Big Mac: 'sudo docker logs bigmac-vllm') and MUST be consulted first per the record-first ladder. An EMPTY log read is never evidence of anything unt

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-23 22:05 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: deepseek-spillage-glm-ring-restore-20260823
- RCA bucket: insufficient probe
- Trigger pattern: restart loop with proc alive + api down read as engine failure instead of init-in-progress
- Reversal note: 2026-08-23 GLM ring restore: watchdog 'fail proc=1 api=0' log lines were read as 'engine repeatedly failing' when they actually meant 'engine loading weights (10-30 min) while watchdog tolerance was 15s' — the watchdog itself was killing every relaunch mid-init. Amended behavior: when a restart loop shows PROC alive + API down, classify as INIT-PHASE before diagnosing engine failure; read the container age (docker inspect StartedAt) and the last vllm log line (weight shard progress) before declaring the engine broken. A process at 96% CPU with no error lines is loading, not wedged.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-24 19:54 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787622244
- RCA bucket: insufficient probe
- Trigger pattern: Probed a host using an IP from fleet_inventory without cross-referencing the registry ssh_access field, hit a wrong/dead IP, and falsely declared the host down
- Reversal note: 2026-08-24 524 diagnosis reversal: declared Big Mac 'physically DOWN' by probing 10.100.0.16:8000 (wrong IP, likely from stale fleet_inventory). Big Mac's actual IP is 10.100.0.19 per frankenstein_registry.yaml ssh_access field — live probe confirms it is SERVING gpt-oss-120b. Amended behavior: Step 1 'SEARCH THE RECORD FIRST' must explicitly include cross-referencing the registry ssh_access field for the host's CANONICAL IP before any probe. fleet_inventory IPs can be stale or wrong; the registry's ssh_access line is the authoritative source for a host's WireGuard/LAN IP. Never probe an IP from fleet_inventory alone without confirming it matches the registry.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-28 07:58 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1779186100000
- RCA bucket: wrong premise
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - "frankenstein-llm's rule 91 text is too shallow" → corrected: the rule TEXT was adequate; the ENFORCEMENT GATE was dead code (_r91_validate returned None, 0-byte violations log, 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 00:33 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787931475695
- RCA bucket: stale assumption
- Trigger pattern: citing a historical patch/flag as the live cause without grepping deployed source; classifying a failure event from prior-event pattern instead of its own log signature
- Reversal note: 2026-08-28 double reversal (task 1787931475695): (1) explained BigMac's adapter-pick dominance by citing the 2232 batch-prefer-120B patch as 'still live' WITHOUT reading the adapter source; grep showed SUBAGENT_PREFER_120B no longer exists. The live mechanism is the lane-aware tier system (batch: GLM-first under a 4-seat reservation, then Qwen3.8 tier, then 120Bs; interactive: speed-ranked with a 30% GLM floor). (2) Classified the 16:41 event as 'another wedge' from wedge-history pattern alone; the watchdog log actually showed proc=0 api=0, a full container DEATH, which was the clue that led to finding the lost --no-async-scheduling flag (the true root cause of the day's instability). Amended behavior: before citing any patch/flag as 'still live' to explain current behavior, grep the deployed source for it in the same window; and classify each failure event from ITS OWN log signature (wedge = proc alive + decode zero; death = proc 0), never from the pattern of prior events.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 04:27 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787977000000
- RCA bucket: stale assumption
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - "cloudflared restart churn is the cause (bug-library known-repair match)" -> corrected: cloudflared NRestarts=0 and tunnel up since 2026-08-22, so that path was ruled out and the

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

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

## Amendment (from reversal, 2026-08-29 21:13 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 28705
- RCA bucket: insufficient probe
- Trigger pattern: lane curl http=000 reported as box DOWN without SSH/MDM cross-check or in-window relaunch attempt
- Reversal note: Amends the Step-2 classification table usage: when a LANE probe (WOPR tunnel port or WG endpoint) returns http=000 but an independent surface (MDM portal, direct SSH, reverse-tunnel shell) shows the HOST reachable, the ONLY legal verdicts are ENGINE-DOWN or TUNNEL-DOWN, never a bare host DOWN — and per rule 29 the agent MUST attempt the software repair in-window (docker start, relaunch serve script, fix tunnel forward target) before listing the lane as an open thread. 2026-08-29 case: Claudia/Joshua/Julia/Nero/Cicero all reported DOWN from curl http=000; live triage showed every host except Nero/Cicero reachable and all three fixable in-window (Joshua = docker start, Claudia = relaunch + tunnel forward target pointing at Julia's IP 192.168.1.190 instead of 127.0.0.1, Julia = crash-loop from deleted 235B weights).

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 23:26 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788044433000
- RCA bucket: insufficient probe
- Trigger pattern: drafting a "run this on box X" human command without first checking hostname/serial of the local machine against the fleet record
- Reversal note: Amends Step 1 (search the record first): before declaring a fleet Mac unreachable and drafting a human one-time on-box command, probe whether the box IS the local machine running this window (hostname + serial vs mdm_devices/registry). 2026-08-29: Cicero was reported as needing Ruben's one-time launchctl command across two windows while Cicero WAS the Mac running Cline (hostname Rubens-MacBook-Pro-3, M5 Max, serial K064QD22G9 = mdm_devices row 2). The window revived it directly in 10 minutes with zero human action.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 23:49 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788044433000
- RCA bucket: insufficient probe
- Trigger pattern: identifying a fleet box by hostname match while ignoring a visible serial-number mismatch against the fleet record
- Reversal note: CORRECTS the earlier same-day amendment, which itself caused a worse error. Box identity MUST be matched by SERIAL NUMBER, never by hostname: Ruben's fleet contains two M5 MacBooks that BOTH report hostname "Rubens-MacBook-Pro-3" — the Powerhouse Mac (serial K064QD22G9, .178, runs Cline, NO LLMs allowed) and Cicero (serial FYH2J1GFW9, .252, fleet LLM box). A window matched on hostname, declared "Cicero IS this Mac," and installed an LLM stack on the Powerhouse Mac; the local serial K064QD22G9 did NOT match mdm_devices row 2's FYH2J1GFW9 and that mismatch was visible in the same probe output but ignored. New requirement: an identity claim about a fleet box requires the SERIAL to match the fleet record; a hostname match with a serial mismatch is a NEGATIVE identification.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 00:32 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788135215000
- RCA bucket: stale assumption
- Trigger pattern: Declaring a box blocked-on-credentials from repeated auth failures against a RECORDED tunnel port, without verifying the port still maps to that box. Reverse-tunnel listener ports on a jump host are c
- Reversal note: Amends the Step-1 record-search ladder: a recorded reverse-tunnel PORT is a stale hypothesis, not an identity. Before declaring a box unreachable/blocked-on-key at tunnel port N, identify WHO actually holds port N (ss -ltnp for the sshd pid, then ss -tnp for the client IP, or hostname probe). 2026-08-29 incident: Maximus was declared blocked on Ruben's authorized_keys command for multiple windows, but WOPR :2224 had been stolen by Joshua's wopr-reverse-tunnel.service (-R 2224:Joshua:2222) since 08-22; the real Maximus was on :2226 the whole time with the key already working.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 01:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788050474905
- RCA bucket: wrong premise
- Trigger pattern: Reading call-log durations or call counts as proof that the voice AI layer is serving, without probing whether an assistant ever attached.
- Reversal note: Amends the Step-2 four-state classification table: a CALL RECORD carrying a long duration is NOT evidence that the AI/assistant layer ever ran. On 2026-08-29 the Vapi SIP parent legs logged 610s durations while every assistant-request response was 400'd and the call died at 0s, so a dead front door read as a busy one for 11 hours and a prior window reported "lines healthy, no action needed". The clause now requires, for any voice-lane health claim, a probe of the ASSISTANT-ATTACH layer (an accepted assistant-request shape or a call with a non-empty artifact.transcript), never a duration or call-count reading from the telephony log.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 01:19 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788135215000
- RCA bucket: insufficient probe
- Trigger pattern: SSH publickey denial on a reverse-tunnel port interpreted as key/auth failure when the port actually reached a different box (port stolen by another host's -R forward)
- Reversal note: Adds the mechanical countermeasure for the port-theft class: cron_tunnel_identity_watchdog.php (WOPR, */15) now probes every reverse-tunnel port and verifies HOSTNAME + hardware SERIAL of the answering box against an identity map. Rule text now requires: any SSH auth failure on a tunnel port MUST first check the identity watchdog log (/var/log/tunnel-identity-watchdog.log) before concluding key problems — a listener that answers as the WRONG box is an IDENTITY_MISMATCH, not an auth failure. Joshua's rogue -R :2224 was renumbered to :2227; :2224 is reserved-Maximus and alarmed.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 00:43 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788305443198
- RCA bucket: wrong premise
- Trigger pattern: pinging a remote-site private IP from a host on a different site's identically-numbered subnet and declaring the box down
- Reversal note: Amends Step 2 classification: cross-site ping/ARP from a jump host is NOT valid down-evidence for remote-site boxes. WOPR's 192.168.1.x is its own San Diego LAN; the Oceanside Sparks share the same private range but are only reachable via their dial-out reverse tunnels. Before classifying any remote-site host DOWN, verify the probing vantage shares the target's actual L2 (gateway MAC check) or probe via the tunnel/fleet heartbeat — same-numbered private subnets across sites made 6 healthy Romans look LAN-dark on 2026-09-01.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 05:00 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: llm-turns-fleet-assessment-20260901
- RCA bucket: insufficient probe
- Trigger pattern: Building a fleet serving-state table from log traffic counts + registry labels instead of per-endpoint live probes, then collapsing "zero rows" into "DOWN" and "high internal running count" into "satu
- Reversal note: Amends Step 2 (the four-state classification): ZERO TRAFFIC IN A LOG IS NOT A STATE. A box with 0 turns in /var/log/emsu-adapter-upstream.log may be (a) not a member of that pool at all (direct LiteLLM lanes like claudia/julia/cicero are NOT :11510 adapter members, so absence there is expected and meaningless), (b) tunnel-flapping, (c) genuinely down, or (d) serving other traffic. Before any DOWN claim sourced from a traffic table, the agent must FIRST check pool membership (FRANK_TOOLS_UPSTREAMS) and THEN live-probe /v1/models this turn. Also adds a fifth mis-classification to ban: reporting an engine as SATURATED from its own internal running-count while startup-complete=0 — that is the BOOTING/WEDGED state (state 3), never saturation. Source: 2026-09-01, a fleet report declared Julia/Claudia/Nero DOWN off an 8h traffic table while Claudia :11521 was live serving qwen3.8-27b and Nero :11525 was live on MLX; the same report called the GLM-5.3 ring "saturated by design" when docker log

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

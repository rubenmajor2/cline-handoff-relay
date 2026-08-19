# Rule 315 — Verify before declaring a host down (search the record FIRST; status is not serving)

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS, on any infrastructure / LLM / host / engine DOWN claim**
**Created: 2026-08-09 by Cline (Ruben directive: "rule [on] why you got the LLM info wrong... and how to ensure it does not happen again. RCA 297, etc")**

## Core principle

A "down" claim is a destructive operational statement. It triggers halts, restarts, reroutes, and human alarm. It must therefore be earned by (a) searching the written record FIRST and (b) a live probe executed THIS TURN. Two failure modes caused 2026-08-09's false-downs, and both are banned outright:

1. **SEARCH-THE-RECORD-FIRST violation.** The operator (me) guessed usernames — `rubenmajor`, `root`, `emsuserver`, `bigmac` — got publickey denials, then went off trying other keys, ProxyJump through WOPR, SSH from Artemis, SSH from Julia, and a full port sweep, and called Big Mac "blocked on SSH access". The credential was written down the whole time in Big Mac's OWN onboarding idea: `ssh -i /home/emsuserver/.ssh/id_ed25519 emsu-big-mac@10.100.0.19`. **Guessing usernames is not a search. Sweeping the network is not a search. Reading the box's own files is a search.**
2. **STATUS-IS-NOT-SERVING conflation.** `systemctl is-active` = the process exists. `docker ps Up X hours` = the container exists. Ray head alive = Ray is up. **NONE of these mean the engine ever bound its port or served a single request.** The 2026-08-09 wedge: `bigmac-vllm.service` reported active and the container "Up 10 hours", but it had never served one request — hung in the middle of Ray init at "No current placement group found. Creating a new placement group.", startup-complete count zero, port 8000 never bound. Only `curl /v1/models` HTTP 200 (and for real liveness, a decode probe that yields tokens) proves an engine is serving.

## Mandatory ladder BEFORE any down claim

When any actor reports or you suspect a box is down:

### Step 1 — SEARCH THE RECORD FIRST (before reaching for any tool that touches the network)
- The box's own onboarding idea / idea text
- `frankenstein_registry.yaml` (WOPR `/etc/litellm/`) — login lines + serving facts live next to the box
- `HANDOFF_NOTES.md` / `cline_task_ledger.md`
- Bug library (`frankenstein_router_incidents`) — past incidents for this host class
- `fleet_inventory` (`fleet_inventory()` MCP) — canonical IPs, roles, SSH path
- If a documented credential exists, USE IT. Do not guess. Do not sweep. If none exists, say "record does not contain access" and file an idea to add it, do NOT brute-force identity.

### Step 2 — CLASSIFY INTO EXACTLY ONE OF FOUR STATES (never a bare "down")
| State | Evidence | Claim wording |
|---|---|---|
| **HOST DOWN** | SSH + ping/WireGuard unreachable (verify against `fleet_inventory` IPs; rule 294 reprobe inherited facts) | "X down — host unreachable (SSH refused, WG dead)" |
| **PROCESS DOWN** | systemd unit `failed`/`exited`, or container exited | "X down — process exited (unit state failed)" |
| **ENGINE WEDGED / NEVER BOUND** | process alive + container "Up" for a long time + **startup-complete count = 0** + port not listening — hung mid-init (classic: Ray placement-group message with nothing after it) | "X down — engine wedged mid-init (log stopped at <line>, 0 startup-complete, :port never bound)" |
| **ENGINE SERVING** | `curl /v1/models` HTTP 200 and/or decode probe produced tokens | "X up — /v1/models 200, serving" |

Only states 1-3 justify the word DOWN, and even then the claim must carry the state name + the evidence that proves it. A bare "X is down" with no state classification is a violation of this rule AND rule 297.

### Step 3 — LIVE-VERIFY THIS TURN
A cached probe is a hypothesis (rule 296). The probe that justifies the word DOWN must have run in the turn where DOWN is printed. Inherited facts from an earlier window must be re-probed (rule 294). If the fleet API is unreachable, say probe-failed, not down (rule 299: negative evidence is not proof).

### Step 4 — HOST-UP ≠ ENGINE-DOWN — SAY WHICH, and prefer a RESTART over a death certificate
Julia 2026-08-09: Ray head alive at `ray::IDLE` with no `api_server` = a restart, NOT a dead box. `~/julia_full_relaunch.sh` brought it back at 131K ctx / 0.287s gen. When only some layers are down, say "host up, engine down (restart needed)" — never collapse it to "down".

## Detector for the silent wedge (the expensive one, so it gets its own line)

On any box that claims hours of uptime: `grep -c "startup complete" <container-log>`; if the count is 0 on a container that claims long uptime, it is wedged mid-init even though systemd + docker both report healthy. (Bug library 2299.)

## Why this rule exists (RCA 297 — 2026-08-09)

- **Symptom:** Big Mac "blocked on SSH" (total fabrication — record had the line all along); Julia + Claudia reported down (Julia was host-UP/engine-DOWN needing a restart; Claudia was eventually verified serving with all four upstreams at HTTP 200, 38.0 / 33.4 / 22.3 / 12.7 tok/s).
- **Root cause:** (1) searched the network instead of the record (guessed 4 usernames before reading the onboarding idea); (2) treated `systemd active` + `docker Up` as serving evidence; (3) carried earlier stale state forward instead of live-probing before each claim.
- **Causal-rule fix:** this rule (315) — replaces the guess-first habit with a fixed record-first ladder, and bans status-≠-serving conflation. Bug library 2297/2298/2299 record the incident; the Big Mac SSH line now sits in `frankenstein_registry.yaml` with the "systemd active ≠ serving" warning next to the box, so the record itself carries the fix.
- **Self-check (per rule 297):** would a fresh agent given the same symptom tomorrow reach into `frankenstein_registry.yaml` before the network? If the answer is ever no, this rule is not being read — reindex and re-train.

## Cross-references

- Rule 297 (classify before diagnosing — read source, state the bucket)
- Rule 296 (never declare an LLM dead from a cached probe)
- Rule 294 (reprobe inherited infrastructure facts)
- Rule 299 (negative evidence is not proof)
- Rule 140 (routing claims need live verification with headers)
- Rule 263 (verify-before-claim on ALL facts, system state included)

**Source incidents: 2026-08-09 Big Mac wedge + credential-guess hour; Julia host-up/engine-down mis-call; earlier Claudia false-down (all resolved same session; fleet fully restored 22:51 PT)**
## Amendment (from reversal, 2026-08-17 17:07 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786932084
- RCA bucket: insufficient probe
- Trigger pattern: Declaring a multi-node GPU cluster outage 'physical / needs human power-cycle' after probing only host reachability (ping/SSH/tunnels/WG), without probing the CLUSTER FABRIC state (RoCE/IB interface I
- Reversal note: Julia/Claudia 235B: I classified the outage as host-down requiring physical intervention because ping/SSH/WG/tunnels were all dead, and reported no remote recovery path. After the boxes returned, the real root cause was software and fully remotely fixable: Julia lost its RoCE IPv4 (192.168.100.3/24 on enp1s0f1np1) across reboot, leaving GID index 3 empty, so NCCL paired a link-local IPv6 GID against Claudia's IPv4-mapped GID and ibv_modify_qp failed EINVAL(22) INIT->RTR, surfacing only as the generic 'NCCL unhandled system error / Engine core initialization failed'. The @reboot auto-start fired every boot and failed identically, which made a working guard look absent. Amendment: for any TP/PP multi-node engine that fails to init, the host-state ladder is NOT sufficient. Before declaring physical/human-required, probe the fabric: (a) ip -4 addr on the RoCE/IB netdev on EVERY node, (b) the GID table (/sys/class/infiniband/<dev>/ports/1/gids + gid_attrs/types) and confirm all peers expose

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 19:21 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786932084
- RCA bucket: insufficient probe
- Trigger pattern: Reporting a host as 'unreachable / unverifiable remotely' after exhausting only the IP-layer ladder (ping, SSH, tunnels, WG), without testing the PHY layer on a directly-cabled peer that could disting
- Reversal note: Julia 235B: I reported the box as unreachable with no remote path and deferred to WOL/physical access, having probed only ping/SSH/tunnel/WireGuard. Ruben pointed out Julia is directly cabled to Claudia over CX7. Bringing all four CX7 netdevs administratively UP from the reachable peer and reading carrier gave a decisive answer the entire IP ladder could not: admin-UP with NO-CARRIER on every port (link flags <NO-CARRIER,BROADCAST,MULTICAST,UP>, IB state DOWN, phys_state 3 Disabled) is positive evidence the far-end NIC is unenergized, because a CX7 NIC in a running box asserts carrier even when the OS is wedged, has no IP, or refuses SSH. Amendment to the host-down ladder: before classifying a host as HOST DOWN / unreachable, check the record for any DIRECTLY CABLED peer that is reachable; if one exists, bring the shared link admin-UP on the peer and read /sys/class/net/<dev>/carrier plus the IB port state. Carrier=1 means the box is powered and the fault is above the PHY (OS wedge, se

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 23:43 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786932084
- RCA bucket: scope error
- Trigger pattern: Asserting a user-facing model/service availability claim from an endpoint-level probe alone, without checking whether the router rewrites the model name to a sibling before dispatch
- Reversal note: Julia/Claudia 235B: I probed the BOX (:11513 ConnectionRefused, WG/SSH/LAN dead from two vantage points, canary healthy=False) and from that correctly-measured box state asserted a USER-FACING capability claim, that julia-235b "is not serving". Ruben was at that moment iterating on litellm:julia-235b fast and successfully. Both were true because the router REWRITES THE REQUEST: _router_core.py:5148 `data["model"] = sibling` in the admission_control_fast_fail path silently retargets model-name julia-235b to glm-5.2-local. Measured last 30 min: 18 julia-235b requests, 16 rerouted to glm-5.2-local (prompt_tokens ~70,300), 1 hard 500. Rule 315 taught that process-alive is not serving; the inverse hole was unguarded, that a model NAME can serve perfectly while its declared endpoint is dead. Amendment: a box-level probe licenses a claim about THE BOX only. Before asserting that a MODEL NAME is unavailable to callers, additionally (a) grep the router for a rewrite of data["model"] on that nam

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 02:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: insufficient probe
- Trigger pattern: Concluding a physical-layer fault from a 2-boot comparison without tabulating all boots, and drawing conclusions from register writes that were silently discarded by Secure Boot kernel lockdown withou
- Reversal note: Big Mac 4th GPU: two claims reversed. (1) Boot-14 concluded "a fresh reseat produced zero receiver detect, so the adapter or card-in-adapter connection is the fault"; the per-boot journal showed the port ALSO absent on boot -4 BEFORE any hands-on work and PRESENT on the three boots after the reseat, so presence alternates per boot and the reseat inference was unsupported. (2) Idea #26238 recorded REFCLK/CommClk as the primary lead because hand-setting the bits "did not train the link"; dmesg shows "Lockdown: setpci: direct PCI access is restricted" (SecureBoot enabled, lockdown=integrity), so those writes never landed, and the link later trained to 8GT/s x4 with CommClk- STILL SET. Amendment: when a probe writes to hardware registers (setpci, /sys/bus/pci writes, MSR pokes), the write MUST be read back and verified to have changed before any conclusion is drawn from its effect; a shell command that exits 0 while the kernel discards the write is indistinguishable from a successful write

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 04:07 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: unread source
- Trigger pattern: Reading a multi-option sysfs file (lockdown, and similarly *_available / *_governor style files) and quoting the first token instead of the bracketed active selection; asserting a kernel cmdline flag 
- Reversal note: Big Mac 4th GPU: I read /sys/kernel/security/lockdown, saw "none [integrity] confidentiality", and reported "LOCKDOWN=none is LIVE, PCI register writes will now land". That file is a MENU, not a value: the BRACKETED entry is the ACTIVE mode, so lockdown was still [integrity] and every setpci write continued to be discarded. dmesg carried the decisive line I had not read, "Kernel is locked down from EFI Secure Boot mode", proving that lockdown=none on the kernel cmdline is silently ignored whenever Secure Boot is enabled, even though the flag parses cleanly and appears verbatim in /proc/cmdline. Amendment: when a sysfs file presents a SET of options, the claim must quote the bracketed/selected element, never the first token; and before asserting that a kernel cmdline parameter took effect, confirm the SUBSYSTEM reports it active (dmesg/kernel log), because appearing in /proc/cmdline only proves it was passed, not honoured. Second amendment from the same window: a boot-time module load c

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 04:50 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: unread source
- Trigger pattern: Quoting a PCIe/sysfs register field by name (PresDet, DLActive, LnkSta) without naming the containing status-vs-control register, so an interrupt-enable mask bit is reported as device state
- Reversal note: Big Mac 4th GPU: a prior window recorded "SltSta PresDet-" and built the primary fault lead (the adapter's presence-detect circuit) on it. Live reads three times two seconds apart are stable PresDet+ -- the card IS present-detected. The "-" was read off the SltCtl line ("Enable: ... PresDet-", an interrupt-ENABLE mask bit) instead of the SltSta line ("Status: ... PresDet+", the actual state). Two different registers whose lspci output contains the same substring, one register field name. Amendment: when reading a device register field by name, quote the CONTAINING register (SltSta vs SltCtl, LnkSta vs LnkCtl, DevSta vs DevCtl) in the claim itself, because status and control registers in PCIe/lspci output share field names and differ only by the enclosing line. A bare "PresDet-" or "DLActive-" with no register named is not a readable measurement. Corollary: re-read any single-sample register that a fault hypothesis rests on at least twice before building on it -- the same window also pr

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 05:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: insufficient probe
- Trigger pattern: Treating a systemd unit's failure exit status as proof its effect did not occur, and gating on an asynchronously-settling sysfs state with a single sample instead of a bounded poll
- Reversal note: Big Mac watchdog-arm: earlier this same session I amended rule 315 with "a unit reporting SUCCESS is not evidence its effect happened" (the cold-boot case where systemd-modules-load exited 0 while sp5100_tco was absent). The INVERSE then fired within the hour and I nearly recorded it as a real safety regression: bigmac-watchdog-arm.service reported failed/status=1 while the protection WAS fully live (watchdog0 state=active, identity="SP5100 TCO timer", timeout=60, sp5100_tco loaded, RuntimeWatchdogUSec=1min). Cause was a race, not a fault: the script sampled /sys/class/watchdog/watchdog0/state exactly once immediately after daemon-reexec, read "inactive", and exited 1 before systemd finished opening the device. Log proof: 22:11:41 "wdt_state=inactive FAIL", then after the fix 22:14:39 "armed=1min wdt_state=active timeout=60". Amendment: a unit's FAILURE status is likewise not evidence that its effect did NOT happen. Before acting on either a success or a failure report, probe the EFFEC

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 01:15 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787081272363
- RCA bucket: insufficient probe
- Trigger pattern: Concluding POWERED-OFF from CX7 NO-CARRIER + failed WOL, without physically checking chassis heat/power LED or reading the previous-boot journal; WOL failure + no-carrier can ALSO mean a kernel/driver
- Reversal note: Julia L2-dark 2026-08-18: I declared Julia POWERED OFF from CX7 NO-CARRIER + 1786 failed WOL packets + multi-vantage ARP-dead. Ruben corrected: the chassis was HOT when he touched it to restart. A hung kernel (thermal/driver) can leave the NIC silent and unresponsive to WOL exactly like a powered-off box. Amendment: NO-CARRIER + WOL-exhaustion proves UNRESPONSIVE NIC, not power state. Before asserting POWERED OFF, add (a) physical heat/LED check via the human, or (b) post-recovery journal read of the previous boot to distinguish panic/hang from power loss. Default classification for a dark Spark with hot chassis: KERNEL-WEDGE-UNRESPONSIVE, requiring hardware watchdog arming, not just WOL.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

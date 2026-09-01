# Rule 315 Case Law — Mechanical Amendment Trail (trim-then-archive, 2026-08-19)

Moved from Rules/315-verify-before-declaring-host-down.md (10 amendments, ~11KB)
to restore G7/G8 floor compliance. Parent rule: Rules/315. The distilled lessons are
folded into the parent rule's ladder text; this is the verbatim proof trail.

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

## Amendment (from reversal, 2026-08-19 08:34 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787123639000
- RCA bucket: stale assumption
- Trigger pattern: scp from a recalled /tmp path without re-probing, and using an MCP server name as an SSH hostname instead of searching ~/.ssh/config
- Reversal note: Two flips in the TDSHS PDF delivery window: (1) attempted scp from a /tmp path recalled from prior context, but the file actually lived at /var/www/emtskills/uploads/tdshs/inspection-5196-2026/ — a find on the server located it; (2) attempted scp using MCP server name 'emsu-operations' as hostname instead of searching ~/.ssh/config for the documented alias 'wopr'. Amendment: before any file transfer from WOPR, re-probe the actual file path with find/ls THIS window (never scp from a recalled path), and search ~/.ssh/config for the documented SSH alias before guessing hostnames. The MCP server name is never an SSH hostname.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 22:05 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787129383579
- RCA bucket: wrong premise
- Trigger pattern: Treating a handoff/record claim ('WG link 10.100.0.15 down') as a real infrastructure component without first probing the host for the component's existence (wg binary, /etc/wireguard, wg0 device), th
- Reversal note: 2026-08-19 follow-up: I filed #27613 'Julia WG link 10.100.0.15 down' from a handoff claim without first probing that the component existed. On-site evidence (sudo -S escalation via crontab) proved Julia has NO /etc/wireguard, NO wg/wg-quick binary, NO wg0 device; Claudia has no wg0 either; WOPR wg0=10.100.0.1/24 has zero reachable peers. The WG fleet path was decommissioned (reverse SSH tunnels :2205/:2206 are canonical). Amendment: before declaring any link/component 'down' or filing a restore/repair idea, probe the target for the COMPONENT'S EXISTENCE first (binary, config dir, interface list) — a stale registry ref or record can name a path that was never installed. A 'link down' diagnosis requires the link to exist.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Mechanical amendments (moved from Rules/315-verify-before-declaring-host-down.md on 2026-08-19 ~18:16 PT, concurrent-window batch)

## Amendment trail — moved (2026-08-19)

10 mechanical amendments (2026-08-17 through 2026-08-19) appended by
clinerules_amend_rule grew this file to 20,895 bytes (1.7x the G7 cap), failing
the G8 floor gate. The verbatim trail now lives in
`Rules-archive/315-case-law.md`. Distilled lessons folded into the ladder above:

- **Multi-node engine fails to init → probe the FABRIC before declaring physical.**
  For any TP/PP engine, check RoCE/IB IPv4 on every node's netdev, the GID table
  (/sys/class/infiniband/<dev>/ports/1/gids + gid_attrs/types), and matching GID
  types across peers. NCCL EINVAL(22) INIT->RTR is usually a GID mismatch, fully
  remotely fixable, not a power-cycle (2026-08-17 17:07).
- **Directly-cabled peer = a PHY-layer probe the IP ladder cannot give.** Before
  HOST DOWN, bring the shared link admin-UP on the reachable peer and read
  /sys/class/net/<dev>/carrier + IB port state. Carrier=1 = box powered, fault
  above the PHY. Admin-UP + NO-CARRIER on every port = positive evidence the
  far-end NIC is unenergized (2026-08-17 19:21).
- **Box-level probe licenses a claim about THE BOX only.** Before asserting a
  MODEL NAME is unavailable to callers, grep the router for a rewrite of
  data["model"] on that name and check the router audit log — a model name can
  serve perfectly (via sibling rewrite) while its declared endpoint is dead
  (2026-08-17 23:43).
- **Hardware register writes must be READ BACK.** setpci//sys/MSR pokes can be
  silently discarded by Secure Boot kernel lockdown; exit 0 while the kernel
  drops the write is indistinguishable from success. Tabulate ALL boots, not a
  2-boot comparison, before inferring from presence/absence (2026-08-18 02:38).
- **Multi-option sysfs files: quote the [bracketed] active selection, never the
  first token.** A kernel cmdline flag in /proc/cmdline only proves it was
  passed — confirm the subsystem reports it active (dmesg) before claiming it
  took effect (2026-08-18 04:07).
- **Name the CONTAINING register when quoting a field** (SltSta vs SltCtl,
  LnkSta vs LnkCtl): status and control registers share field names; a bare
  "PresDet-" with no register named is not a measurement. Re-read any
  single-sample register a hypothesis rests on at least twice (2026-08-18 04:50).
- **A systemd unit's exit status (success OR failure) is not evidence its effect
  did or did not happen — probe the EFFECT.** Async-settling sysfs state needs a
  bounded poll, not a single sample (2026-08-18 05:14).
- **NO-CARRIER + WOL-exhaustion proves UNRESPONSIVE NIC, not power state.** A
  hung kernel leaves the NIC silent exactly like power-off. Before POWERED OFF:
  physical heat/LED check or post-recovery previous-boot journal. Dark box + hot
  chassis = KERNEL-WEDGE-UNRESPONSIVE (arm the hardware watchdog) (2026-08-19 01:15).
- **Never scp from a recalled path — re-probe with find/ls THIS window.** Search
  ~/.ssh/config for the documented alias before guessing hostnames; an MCP
  server name is never an SSH hostname (2026-08-19 08:34).
- **Probe a component's EXISTENCE before declaring it down.** A stale registry
  ref can name a path never installed (Julia had no wg binary/config/wg0 at all).
  A "link down" diagnosis requires the link to exist (2026-08-19 22:05).
## Amendment (from reversal, 2026-08-20 01:12 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-2408-role-heal
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - initial: 'self-heal cron needs to be built from scratch (per #27631 executor spec)' → corrected: 'cron already existed but was broken (wrong DB name/user, bad INSERT columns, mis

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 01:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787169118771
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - initial: 'self-heal cron needs to be built from scratch (per the executor spec of #27631 [deployed])' → corrected: 'cron already existed but was broken (wrong DB name/user, bad I

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

# Cline Window Discipline (and the Mac-Panic / Artemis-Storm Pattern)

## Why this rule exists

On 2026-05-02 19:14 PT my Mac kernel-panicked (`AppleARMWatchdogTimer panic flow Config Engine Trigger` per the macOS log). At the same time, Artemis logged a 12-PID heap-balloon storm in cline-heap-pressure.log with 12 separate alert emails landing in my inbox between 19:22:01 and 19:22:09 PT. These were the same event, not two events.

The mechanism:

1. I had ~15 active VS Code windows on the Mac, every one of them attached to Artemis (Cline-Tempe) via Remote-SSH through `wopr` ProxyJump. Every window's UI runs on Mac. Every window's ext-host runs on Artemis. The Cline state files (`ui_messages.json`, `api_conversation_history.json`) live on Artemis.
2. The Mac's CPU/SoC stalled hard enough that the kernel watchdog tripped → forced reboot at 19:14.
3. While the Mac was offline, the WireGuard tunnel and 15 SSH sessions to Artemis dropped, and the Artemis-side ext-host processes either got renice'd by `exthost-watchdog.sh` or sat idle.
4. When Mac came back up and VS Code resumed, all 15 windows reconnected to Artemis at the same time. Each one re-attached to its existing ext-host process. Each ext-host then tried to parse-on-resume the bloated `ui_messages.json` for its associated task. Because they all hit V8 simultaneously, 12 of them ballooned within 8 seconds (19:22:01-09).
5. cline-heap-pressure.sh dedupes per-PID, so 12 different PIDs = 12 first-time alerts in 8 seconds.

The watchdog stack handled the storm correctly. I did not lose data. But the inbox flood was a symptom, and more importantly, the underlying parse-on-resume balloon class is real.

## The discipline

These are the operational rules for keeping the storm from hurting more than it has to:

### W1. Cap the number of concurrently-attached Cline windows

I genuinely run 15-20+ VS Code windows. That is the workflow. I am not going to give that up. But I should be aware that **every additional Remote-SSH-attached Cline window is a future ext-host that may simultaneously parse-on-resume after a host blip**. There is no hard cap; this is just an awareness rule. If I notice the count crept above 20 active Cline conversations, prune the ones I don't need to come back to using `attempt_completion` and close the window.

### W2. Don't fight the bloat — archive it

Bloated `ui_messages.json` (>2 MB) on Artemis is the single biggest balloon source. The auto-archiver (`~/bin/cline-task-archiver.sh`) runs every 5 minutes (was hourly until 2026-05-02) and moves any `ui_messages.json` >2 MB whose mtime is >10 min old into `tasks-archive/`. Cline still resumes from that archived path on demand. **Do not fight this**: don't manually re-inflate by editing archived tasks back into the active dir.

If I'm actively chatting in a long task and don't want it archived, the file's mtime is fresh (the IDLE_MIN=10 min guard handles that) so the archiver leaves it alone.

### W3. After Mac reboot, expect a storm — don't react to individual emails

The cline-heap-pressure storm-cap (added 2026-05-02) collapses 3+ alerts in a 5-min window into ONE digest email titled "STORM digest: N PIDs ballooned (max X GB)". If I get a `STORM digest` email in close proximity to a Mac reboot, I should:

1. Skim the digest.
2. Not panic.
3. Wait 5 min for the watchdog stack to do its job (renice + recycle).
4. Reload any Cline window where the UI looks frozen — that respawns a healthy ext-host.

If I get a STORM digest WITHOUT a recent Mac reboot, that's actually interesting and worth digging into.

### W4. Mac panic is a higher-priority signal than Artemis storm

If a Mac panic and an Artemis storm coincide, the Mac side is the cause and the Artemis side is downstream. Don't waste time on Artemis until I understand what panicked the Mac. Useful inputs:

- `last reboot` — confirm the Mac actually rebooted.
- `sudo log show --predicate 'eventMessage CONTAINS "panic"' --last 6h | grep -i "trigger\\|watchdog\\|memory\\|displaycrossbar"` — find the panic root cause line.
- `/Library/Logs/DiagnosticReports/*.panic` — Apple's panic reports if present.
- `vm_stat` and `sysctl vm.swapusage` — were we actually OOM, or was it a kernel/driver fault?

The 2026-05-02 panic was `AppleARMWatchdogTimer Config Engine Trigger` — a kernel/SoC stall, not a memory pressure event. RAM was fine (51 GB total, swap was 0.0 MB at the moment of crash check). Possible triggers: Thunderbolt/DisplayPort port re-enumeration storm (the log shows AppleATCDPAltModePort/AppleATCDPINAdapterPort messages right at the panic timestamp, which is consistent with a hot-plug or display sleep race).

### W5. When the system catches the storm, trust it

The watchdog stack on Artemis is layered:

| Layer | Script | Trigger | Action |
|---|---|---|---|
| Earliest | `cline-heap-pressure.sh` */1 min | RSS jumped >2 GB in 60s | Email alert (storm-capped). Log only. |
| Mid | `exthost-watchdog.sh` (its own loop) | RSS sustained >12 GB OR CPU >70% | renice +15 (deprioritize but don't kill). |
| Late | systemd cgroup `MemoryMax=100G` (service) and V8 `--max-old-space-size=16384` (ext-host) | Hard cap | OS or V8 kills the offender. |
| Cleanup | `cline-oom-tagger.sh` */5 min | OOM-killed process detected | Tag the task in DB so I notice repeat offenders. |
| Prevention | `cline-task-archiver.sh` */5 min | `ui_messages.json` >2 MB, idle >10 min | Move to `tasks-archive/` (reversible). |

Each layer assumes the layer below will catch it if it doesn't. Do NOT add a 6th watchdog that fights the existing ones. (See `lib/mcp_self_heal.sh` Mac-side postmortem 2026-04-18 for the exact failure mode of overlapping self-heal layers.)

## The SSH path (for anyone reading later)

Mac → WOPR (76.167.100.188:2222 public) → WireGuard tunnel → Artemis (10.100.0.5:22). All hops use `~/.ssh/id_ed25519`. ProxyJump is set in `~/.ssh/config` under `Host artemis`. This works from any ISP because WOPR is on a public-facing static IP. **No additional VPN client is required on the Mac.**

If WireGuard between WOPR and Artemis goes down, this path breaks — but `last reboot`-style ssh to WOPR still works, so I can diagnose from there.

## Last updated

2026-05-02 — initial rule. Source: post-mortem of the Mac kernel panic + Artemis 12-PID balloon storm at 19:14-19:22 PT. Code changes deployed in same session: `cline-task-archiver.sh` thresholds tightened (5MB→2MB, 30min→10min, hourly→every-5-min) and `cline-heap-pressure.sh` got a global storm rate-cap.

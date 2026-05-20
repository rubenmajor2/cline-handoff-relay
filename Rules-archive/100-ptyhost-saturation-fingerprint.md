# pty-host Saturation Fingerprint (code-server / VS Code Remote-SSH)

## Why this rule exists

On 2026-05-03 I (Cline) misdiagnosed a code-server outage as a generic "IPC RequestStore desync" and shipped a watchdog that papered over the actual problem. Subagent research (post-fix) traced the error string to the exact source line and showed I was wrong about the mechanism. This rule exists so the next time anyone — me, another Cline agent, or Ruben himself — sees the same fingerprint, the diagnosis is correct on the first read.

## The fingerprint

**Symptom Ruben reports:** "Cline UI is unreachable, can't even open the panel, Reload Window does nothing, Artemis seems locked up."

**Host metrics look fine:** load <2, free RAM plenty, watchdog stack idle, no OOM events, no kernel errors. The "host locked up" framing is misleading — host is healthy.

**The actual fingerprint to grep:**

```sh
ssh artemis "journalctl -u code-server@emsuserver --since '5 min ago' --no-pager | grep -c 'RequestStore#acceptReply'"
```

- Healthy: 0
- Saturated: 100s+ in 5 min, often 1+ per second sustained.

## What the error actually means

The error string `RequestStore#acceptReply was called without receiving a matching request` originates in **microsoft/vscode** at exactly:

`src/vs/platform/terminal/common/requestStore.ts:70`

It is **NOT** from `src/vs/base/parts/ipc/common/ipc.ts` (generic IPC). It's specifically the **pty-host (terminal subsystem)**. The `RequestStore<T,RequestArgs>` helper has a hardcoded **15-second timeout** per request. The warning fires when a reply arrives AFTER the timeout already cleared the requestId from the pending map.

It's used by exactly two callers, both pty-host RPCs:
1. `_resolveVariablesRequestStore` in `ptyHostService.ts` — pty-host asks workbench to resolve shell environment variables.
2. `_detachInstanceRequestStore` in `ptyService.ts` — terminal detach/reattach RPC across window reloads.

So a sustained burst of these warnings means: **pty-host has so much queued work that legitimate replies are arriving 15+ seconds late.** The pty-host is one process serving ALL windows. If it falls behind, every window's terminal-related RPC sits in the queue.

## What causes it (the mechanism)

The pty-host is a single shared bottleneck:

- One pty-host process per code-server instance (by design).
- Every VS Code window opens at least one pty-host channel for terminal init, env var resolution, shell integration handshake, etc.
- The Cline extension's `execute_command` tool spawns terminals via pty-host on every shell call.
- VS Code default settings keep terminal sessions persistent across reloads (`terminal.integrated.enablePersistentSessions = true`, `persistentSessionScrollback = 10000`).
- Stack: many windows × many Cline command calls × shell integration variable resolution × persistent scrollback retention → pty-host queue grows faster than it can drain.

Once pty-host gets behind, every new RPC piles on, replies arrive past the 15s timeout, warnings cascade, and Cline's webview RPC depends on terminal init to resolve some calls — so the UI looks dead.

## The fix (verified 2026-05-03)

**Immediate (clears the queue):**
```sh
ssh artemis "sudo systemctl restart code-server@emsuserver"
```
~10 seconds downtime, browser tabs auto-reconnect, Cline tasks resume from disk. Confirmed: 0 RequestStore errors post-restart.

**Mitigation in place (deployed 2026-05-03):**
- `/usr/local/bin/cline-ipc-watchdog.sh` — cron `*/2 * * * *` watches journalctl for `RequestStore#acceptReply`. If >=50 in last 2 min, restarts code-server. Rate-capped 1/30min via `/var/tmp/cline-ipc-watchdog-laststart`. Logs `/var/log/cline-ipc-watchdog.log`.
- `cline-nightly-restart.timer` — preventive restart at 04:00 PT daily. Resets the pty-host queue before drift accumulates.
- (2026-05-03 follow-up) settings.json on code-server has `terminal.integrated.shellIntegration.enabled = false` + `terminal.integrated.persistentSessionScrollback = 100` + `terminal.integrated.enablePersistentSessions = false` to reduce pty-host RPC volume.

## What does NOT fix it

- **Reload Window** doesn't fix it — pty-host is shared across all windows; the broken state is in the parent.
- **Closing some windows** doesn't fix it (helps load but doesn't drain the existing queue).
- **Full Artemis reboot** is overkill — `systemctl restart code-server@emsuserver` accomplishes the same thing at the right scope, faster.
- **Tuning V8 heap, ext-host watchdog, archiver, cgroup limits** — these are for the OOM/balloon failure mode (rules 96/97/98), NOT for pty-host saturation. Don't conflate.

## Architectural truth — code-server is not designed for this scale

**Coder explicitly does not support 40 windows on one code-server instance.** Per https://coder.com/docs/code-server FAQ "Is multi-tenancy possible?": *"we recommend using virtual machines (provide one VM per user)… or sysbox/kubernetes."* Their baseline req is **1 GB RAM and 2 vCPU per user/window**.

Single-instance ceiling estimates (with the 2026-05-03 mitigations in place):
- 1-5 windows: rock solid.
- 5-15 windows: works, occasional pty-host hiccup caught by watchdog.
- 15-25 windows: increasingly brittle, watchdog will fire frequently.
- 25-40 windows: NOT recommended on a single instance.

For 25+ windows the right architecture is multiple code-server instances (`code-server@emsuserver-1` through `-N` via systemd template), each with its own pty-host, routed by nginx. This is filed as orchestrator idea `multi-instance-code-server-on-artemis` for when EMSU actually needs to scale past ~15 active windows.

## Diagnosis algorithm for next agent

When Ruben says "Artemis is locked up" or "Cline UI is dead" or "I can't get to Cline":

1. **Check host first.** `ssh artemis "uptime; free -h; cat /var/tmp/cline-watchdog-heartbeat"`. If load >5, RAM <10GB free, or watchdog reports rate_capped/kills_last_hour > 0 — go to rule 97 (extension host OOM), it's the balloon class.
2. **If host is fine, grep journalctl.** `ssh artemis "journalctl -u code-server@emsuserver --since '5 min ago' | grep -c RequestStore"`. If >0, pty-host saturation.
3. **If pty-host saturation:** check `/var/log/cline-ipc-watchdog.log`. The watchdog should be auto-restarting at 50/2min. If watchdog log shows recent rate-cap, that means the watchdog is firing but the saturation is so bad it's hitting the 30-min cooldown — Ruben needs the manual `systemctl restart code-server@emsuserver` and we need to tighten the watchdog threshold.
4. **If neither host issue NOR pty-host saturation:** check WireGuard tunnel between Mac and Artemis. `ssh -o ConnectTimeout=5 artemis 'echo ok'`. If that fails, network problem, not Artemis.

Never assume "memory" when host metrics are clean. Always grep first.

## Red-flag mistakes I made (don't repeat)

- Latching onto the name "IPC RequestStore" without grep'ing the actual source file. The error lives in the **terminal** subsystem, not generic IPC.
- Calling it "code-server brain damage" when it's a queue-saturation pattern with clear remediation.
- Naming the watchdog `cline-ipc-watchdog.sh` (sticks with the wrong label). The mechanism it actually catches is **pty-host saturation**, but renaming it would break HANDOFF_NOTES references — leave as is, just understand what it really watches.

## Last updated

2026-05-03 — initial rule. Source incident: Artemis Cline UI dead at 5 active windows, 990 RequestStore errors in 10 min, pty-host saturated. Root cause discovered via parallel subagent research after my initial misdiagnosis. Watchdog + nightly restart + settings.json tune all deployed same day.

# 24 — Cline tabs: 5-per-instance ceiling and round-robin distribution

Permanent rule. Workspace-scoped. Source incident: 2026-05-05 — Ruben opened
22 Cline tabs all on `cline-tempe/` (instance 0 of 9) on Artemis. Three
separate kernel memory-pressure stalls in one day, including a 2.5h
lockup that required physical power-cycle. Caused by Cline 3.82 eagerly
parsing both `api_conversation_history.json` AND `ui_messages.json` into
V8 RAM on every webview activation.

## The bright-line rule

**Never open more than 5 Cline tabs on the same `code-server-N` instance.**

With Cline 3.82's behavior (verified by reading the installed extension's
`dist/extension.js`), each tab carries 1-15GB of V8 RSS depending on
conversation size. The code-server@emsuserver cgroup has `MemoryHigh=80G`
and `MemoryMax=100G`. Six bloated tabs on one instance can saturate the
slice and trigger kernel pressure stall — at which point the on-box
watchdog stalls too because it lives in the same slice.

## The distribution rule

Artemis has **9 code-server instances** at:

- `code-server@emsuserver` → public URL `/emtskills/cline-tempe/`
- `code-server-multi@1` through `@8` → `/emtskills/cline-tempe-1/` through `/cline-tempe-8/`

Each instance has its own cgroup, its own MemoryHigh, its own pty-host. A
runaway tab on instance 3 cannot affect instances 0, 1, 2, 4-8.

**The launcher at `/Users/rubenmajor/Desktop/CLINE_TASKS.html` round-robins
tabs across all 9 instances by task ID.** When opening tabs by hand or
script, use round-robin: tab 1 → cline-tempe, tab 2 → cline-tempe-1, ...,
tab 9 → cline-tempe-8, tab 10 → cline-tempe (back to start).

## Math

| Tabs total | Per instance | Status |
|---|---|---|
| 9 | 1 | Trivial |
| 18 | 2 | Trivial |
| 27 | 3 | Comfortable |
| 36 | 4 | Still safe |
| **45** | **5** | **Soft cap. Safe.** |
| 54 | 6 | Approaching brittle |
| 63 | 7 | Watchdog will fire |
| 72+ | 8+ | NOT recommended |

So **45 windows distributed across 9 instances** is the working ceiling
under Cline 3.82's eager-load behavior.

## What I (Cline) MUST do

When the user asks to open multiple Cline tabs:

1. **Refuse to bulk-open more than 5 on a single instance.** Distribute
   across instances. If I find myself writing a loop that hits the same
   `cline-tempe/` URL more than 5 times, that's wrong.
2. **Use the launcher** at `/Users/rubenmajor/Desktop/CLINE_TASKS.html`
   when generating links — it round-robins by design.
3. **Never bulk-open >9 tabs in one shot** even distributed. Open
   in batches with 30-60s between batches so each instance has time to
   stabilize parse-on-resume before the next batch.
4. **Skip the round-robin only if the user is explicitly asking for tabs
   on a specific instance** (e.g. "open this on cline-tempe-3"). Then
   honor their instance choice but still cap at 5 on that instance.

## How to detect the failure mode going forward

The auto-restart watchdog at `/usr/local/bin/artemis-stall-watchdog.sh`
(installed 2026-05-05) catches kernel pressure stalls at 10 min sustained
and triggers a clean reboot. Logs at `/var/log/artemis-stall-watchdog.log`.

But pre-stall warning signs from on-box:

- `journalctl -u code-server@emsuserver --since '5 min ago' | grep -c 'Reached heap limit'` — V8 fatal-aborts BEFORE pressure stall hits
- `cat /proc/pressure/memory` — `full avg60 ≥ 60%` is yellow; ≥ 80% is the watchdog's red line
- `systemctl show code-server@emsuserver -p MemoryCurrent --value` — if approaching MemoryHigh=80G (80000000000 bytes), reduce open tabs

If any of these fire while I'm working in a Cline session, my next
action is **stop opening new tabs** and consider closing some.

## Cross-references

- `.clinerules/97-extension-host-oom.md` — the V8 heap OOM mechanism
- `.clinerules/100-ptyhost-saturation-fingerprint.md` — pty-host failure mode (different from this one but related)
- `/Users/rubenmajor/Desktop/ARTEMIS_COMPREHENSIVE_PLAN.md` — full analysis
- orchestrator_ideas #1371 — Cline lazy-load patch (multi-week effort to fix root cause upstream)

## Last updated

2026-05-05 — initial rule. Source incidents: three pressure-stall lockups
in one day on Artemis from 22 tabs on one instance. Comprehensive plan +
auto-restart watchdog shipped same day.

# 25 — "All my Cline tabs just died" — Mac-side Chrome discard, NOT a server issue

Permanent rule. Workspace-scoped. Source incident: 2026-05-06 09:56 PT —
~20 cline-tempe Chrome tabs on the Mac all went blank at the same time.
Initial framing was "Artemis crashed, can only run 20 tabs?" Actual cause
was Chrome's Memory Saver discarding inactive renderers under macOS
memory pressure. Artemis was completely healthy throughout.

## The diagnosis algorithm — run this BEFORE assuming the server died

When Ruben says "every Cline window just died" / "all my tabs went blank"
/ "Artemis crashed", do these checks IN THIS ORDER. Don't skip ahead.

### Step 1 — Is Artemis actually unhealthy?

```bash
ssh -o ConnectTimeout=10 artemis "uptime; free -h; cat /proc/pressure/memory; \
  cat /var/tmp/cline-watchdog-heartbeat; \
  tail -40 /var/log/cline-watchdog.log; \
  tail -30 /var/log/artemis-stall-watchdog.log"
```

If load < 5, RAM has plenty free, pressure stall avg300 < 30%, watchdog
heartbeat is recent and reports `ext_hosts_seen=N` close to the number of
tabs Ruben thinks should exist, and **kills_last_hour=0** — the server
is fine. The work didn't die on Artemis. It died on the Mac side.

If any of those are unhealthy, escalate to rules 24, 96, 97, 100.

### Step 2 — Is the Mac in swap pressure?

```bash
sysctl vm.swapusage
vm_stat | head -10
ps -axo rss,comm | grep -iE "google chrome|chromium" | \
  awk '{sum+=$1} END {printf "Chrome total: %.1f GB / %d procs\n", sum/1024/1024, NR}'
ps -axo rss,comm | grep -v -iE "google chrome|chromium" | sort -n -r | head -10
```

Red-flag signals:
- swap **used > 70%** of total
- **swapouts ≥ 3× swapins** (sustained pressure, not a transient burst)
- Pages free < 10,000 (16 KB pages on Apple Silicon = ~160 MB free)
- Chrome total > 4 GB across more than 50 procs

If any of those are red, the Mac was the bottleneck. Chrome killed the
tab renderers as a memory-pressure response. The tabs will reload fine.

### Step 3 — Is the Cline keep-alive extension installed?

`/Users/rubenmajor/Desktop/cline-tab-keepalive/` is the extension built
2026-05-06 to mark cline-tempe tabs as `autoDiscardable: false`. Confirm
it's installed at `chrome://extensions/` (must be in Developer mode).
Confirm it's working at `chrome://discards/` — every cline-tempe tab
must show **Auto Discardable: No**.

If not installed, that IS the fix. INSTALL.md in that folder is the
runbook.

If it IS installed and tabs still died, see "When this rule does NOT
apply" below.

## What's actually happening (the mechanism)

1. Mac has 51 GB RAM. Chrome (5+ GB), VS Code (3-4 GB), Spark, terminals,
   browsers etc. consume most of it.
2. Mac swap fills (8-9 GB). Sustained swapouts.
3. macOS sends `MEMSTATUS_PRESSURE_CRITICAL` to Chrome.
4. Chrome's Memory Saver looks at all open tabs across all windows,
   picks the inactive ones, calls `chrome.tabs.discard()` on each in
   one batch.
5. Discarded tabs lose their renderer process AND their WebSocket to
   code-server.
6. From the user's POV: "every Cline tab just died at the same time."
7. Behind the scenes: ext-hosts on Artemis kept running. Watchdog shows
   them healthy. A simple reload reconnects each tab.

This is **not** a rule-24 / rule-97 / rule-100 incident. Those are all
server-side. This one is Chrome on the Mac.

## The permanent fix

Three layers, none of which are "give up tabs":

1. **Chrome extension** at `~/Desktop/cline-tab-keepalive/`. Marks every
   cline-tempe tab as `autoDiscardable: false`. Chrome will refuse to
   discard those even under critical memory pressure. (Chrome can still
   crash the whole app if the kernel OOM-kills it, but that's much
   rarer than the preventative-discard path.)

2. **Mac discipline** — when swap goes above ~70%, that's a Mac
   problem, not a Cline-tab-count problem. Close non-essential Chrome
   tabs, quit Spark / unused apps, or reboot the Mac. The extension
   only blocks Chrome's discard heuristic; it doesn't free RAM.

3. **Distribution still matters** — rule 24 (5 tabs per code-server
   instance, round-robin across the 9 instances on Artemis) is still
   in force. That rule is about Artemis-side ext-host RAM and pty-host
   saturation. This rule (25) is about Mac-side Chrome renderer
   memory. They're orthogonal — both still apply.

## What I (Cline) MUST do when this report comes in

1. **Don't reach for ssh artemis "systemctl restart code-server"** as
   the first move. That's the wrong layer. Run Step 1 above first.
2. **Don't tell Ruben to reduce his tab count below 20** unless Step 1
   shows a server-side problem. The server can handle the 20 fine
   (rule 24 budget is 5/instance × 9 instances = 45). The bottleneck
   was the Mac.
3. **If the keep-alive extension is missing, install it.** That's the
   fix.
4. **If the extension is installed and tabs still died** — that's a
   different failure mode. Check whether Chrome itself OOM-died (not
   just discarded tabs):
   ```bash
   log show --predicate 'process == "Google Chrome"' --last 1h | \
     grep -i "killed\|memory\|jetsam"
   ```
   If Chrome got jetsam'd by macOS, the extension can't have helped —
   the whole app went down. Fix is reduce Mac RAM pressure.

## When this rule does NOT apply

- The keep-alive extension is installed AND `chrome://discards/` shows
  cline tabs as `autoDiscardable: No` AND tabs still died → suspects
  shift to: macOS jetsam'd Chrome itself, network blip, or actual
  server-side issue (re-check step 1).
- Only ONE tab died, not all of them → that's a single-tab failure,
  probably an ext-host issue (rule 97) or a stale WebSocket. Reload it.
- Tabs died one by one over hours, not all at once → not a
  memory-pressure event. Probably each ext-host hit its own ceiling
  (rule 97 again).

## Cross-references

- `~/Desktop/cline-tab-keepalive/INSTALL.md` — extension install guide
- `~/Desktop/cline-tab-keepalive/manifest.json` — MV3 manifest
- `~/Desktop/cline-tab-keepalive/background.js` — service worker logic
- Rule 24 — tab distribution on Artemis (server side)
- Rule 96 — Cline window discipline (covers the Mac-Artemis storm
  pattern, complementary to this one)
- Rule 97 — extension host OOM (server side)
- Rule 100 — pty-host saturation (server side)

## Last updated

2026-05-06 — initial rule. Source incident: 20 cline-tempe tabs
went blank simultaneously on Mac with 90% swap (8.25 GB / 9.2 GB),
Artemis healthy throughout (load 1.27, 113 GB free, watchdog
seeing 20 ext-hosts, 0 kills).

## 2026-05-06 10:05 PT addendum — sister failure: Artemis SWAP-thrash class

Same day, ~10 min after the original Mac-side incident, Artemis hit a
DIFFERENT failure: swap thrash on the Linux side. New windows wouldn't
open, existing ones started dropping.

**Fingerprint:**
- Load 24-32 (vs healthy 1-3)
- Memory pressure stall avg10 > 60% (kernel page-thrashing)
- `Swap: 8.0Gi / 8.0Gi / 0B` (100% used, no headroom)
- N ext-hosts at ~2.0-2.4 GB RSS each, +800-1000 MB swap each
- watchdog reports 0 kills (because each individual host is BELOW the
  12 GB renice threshold — many medium-bloat hosts is the trap)
- `journalctl _COMM=systemd-oomd` empty (kernel hasn't OOM'd, just
  IO-stalled on swap)

**Why the watchdog misses this class:** rule 97 watchdog triggers at
12 GB RSS sustained per process. 7 hosts at 2.2 GB each = 15.4 GB
total + ~7 GB swap, but no single host crosses the threshold. The
watchdog is correctly tuned for the rare-giant case; it's blind to the
common-medium case.

**The right fix (used 2026-05-06):**
1. Add swapfile (`fallocate + mkswap + swapon`) — non-destructive,
   ~2 sec, zero existing windows die.
2. Persist to /etc/fstab.
3. Pressure drops within 60s as kernel finishes paging out deferred
   work into the new headroom.

**The WRONG fix:** SIGTERM the bloated ext-hosts. That's destructive
(kills active Cline conversations on the user's screen). It also can't
be done synchronously when the box is already swap-thrashing because
the SSH that delivers SIGTERM serializes behind the kernel's page-fault
queue and stalls. Don't try to kill your way out of swap thrash.

**Detection algorithm:** if Step 1 of the diagnosis algorithm (above)
shows load > 10 + pressure stall > 50% + swap 100% used → this class.
Add 16-32 GB more swap immediately. Do NOT kill ext-hosts.

**Permanent swap configuration shipped 2026-05-06:**
- `/swap.img` (original) — 8 GB
- `/swapfile-cline-emergency-2026-05-06` — 16 GB
- `/swapfile-cline-emergency2-2026-05-06` — 32 GB
- All three in /etc/fstab, total 56 GB swap available
- This gives the medium-bloat-many-hosts pattern enough room to ride
  out parse-on-resume bursts without thrashing.

## Future watchdog improvement (idea, not yet shipped)

Rule 97's per-process threshold should be supplemented with a
TOTAL-RSS-across-all-ext-hosts soft cap. When the sum exceeds e.g.
70% of physical RAM, renice the OLDEST ext-hosts first (they're most
likely to be parked tabs). Files this as orchestrator idea
`exthost-cumulative-rss-watchdog` for future build.

# 25 â€” "All my Cline tabs just died" â€” Mac-side Chrome discard, NOT a server issue

Permanent rule. Workspace-scoped. Source incident: 2026-05-06 09:56 PT â€”
~20 cline-tempe Chrome tabs on the Mac all went blank at the same time.
Initial framing was "Artemis crashed, can only run 20 tabs?" Actual cause
was Chrome's Memory Saver discarding inactive renderers under macOS
memory pressure. Artemis was completely healthy throughout.

## The diagnosis algorithm â€” run this BEFORE assuming the server died

When Ruben says "every Cline window just died" / "all my tabs went blank"
/ "Artemis crashed", do these checks IN THIS ORDER. Don't skip ahead.

### Step 1 â€” Is Artemis actually unhealthy?

```bash
ssh -o ConnectTimeout=10 artemis "uptime; free -h; cat /proc/pressure/memory; \
  cat /var/tmp/cline-watchdog-heartbeat; \
  tail -40 /var/log/cline-watchdog.log; \
  tail -30 /var/log/artemis-stall-watchdog.log"
```

If load < 5, RAM has plenty free, pressure stall avg300 < 30%, watchdog
heartbeat is recent and reports `ext_hosts_seen=N` close to the number of
tabs Ruben thinks should exist, and **kills_last_hour=0** â€” the server
is fine. The work didn't die on Artemis. It died on the Mac side.

If any of those are unhealthy, escalate to rules 24, 96, 97, 100.

### Step 2 â€” Is the Mac in swap pressure?

```bash
sysctl vm.swapusage
vm_stat | head -10
ps -axo rss,comm | grep -iE "google chrome|chromium" | \
  awk '{sum+=$1} END {printf "Chrome total: %.1f GB / %d procs\n", sum/1024/1024, NR}'
ps -axo rss,comm | grep -v -iE "google chrome|chromium" | sort -n -r | head -10
```

Red-flag signals:
- swap **used > 70%** of total
- **swapouts â‰¥ 3Ã— swapins** (sustained pressure, not a transient burst)
- Pages free < 10,000 (16 KB pages on Apple Silicon = ~160 MB free)
- Chrome total > 4 GB across more than 50 procs

If any of those are red, the Mac was the bottleneck. Chrome killed the
tab renderers as a memory-pressure response. The tabs will reload fine.

### Step 3 â€” Is the Cline keep-alive extension installed?

`/Users/rubenmajor/Desktop/cline-tab-keepalive/` is the extension built
2026-05-06 to mark cline-tempe tabs as `autoDiscardable: false`. Confirm
it's installed at `chrome://extensions/` (must be in Developer mode).
Confirm it's working at `chrome://discards/` â€” every cline-tempe tab
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

2. **Mac discipline** â€” when swap goes above ~70%, that's a Mac
   problem, not a Cline-tab-count problem. Close non-essential Chrome
   tabs, quit Spark / unused apps, or reboot the Mac. The extension
   only blocks Chrome's discard heuristic; it doesn't free RAM.

3. **Distribution still matters** â€” rule 24 (5 tabs per code-server
   instance, round-robin across the 9 instances on Artemis) is still
   in force. That rule is about Artemis-side ext-host RAM and pty-host
   saturation. This rule (25) is about Mac-side Chrome renderer
   memory. They're orthogonal â€” both still apply.

## What I (Cline) MUST do when this report comes in

1. **Don't reach for ssh artemis "systemctl restart code-server"** as
   the first move. That's the wrong layer. Run Step 1 above first.
2. **Don't tell Ruben to reduce his tab count below 20** unless Step 1
   shows a server-side problem. The server can handle the 20 fine
   (rule 24 budget is 5/instance Ã— 9 instances = 45). The bottleneck
   was the Mac.
3. **If the keep-alive extension is missing, install it.** That's the
   fix.
4. **If the extension is installed and tabs still died** â€” that's a
   different failure mode. Check whether Chrome itself OOM-died (not
   just discarded tabs):
   ```bash
   log show --predicate 'process == "Google Chrome"' --last 1h | \
     grep -i "killed\|memory\|jetsam"
   ```
   If Chrome got jetsam'd by macOS, the extension can't have helped â€”
   the whole app went down. Fix is reduce Mac RAM pressure.

## When this rule does NOT apply

- The keep-alive extension is installed AND `chrome://discards/` shows
  cline tabs as `autoDiscardable: No` AND tabs still died â†’ suspects
  shift to: macOS jetsam'd Chrome itself, network blip, or actual
  server-side issue (re-check step 1).
- Only ONE tab died, not all of them â†’ that's a single-tab failure,
  probably an ext-host issue (rule 97) or a stale WebSocket. Reload it.
- Tabs died one by one over hours, not all at once â†’ not a
  memory-pressure event. Probably each ext-host hit its own ceiling
  (rule 97 again).

## Cross-references

- `~/Desktop/cline-tab-keepalive/INSTALL.md` â€” extension install guide
- `~/Desktop/cline-tab-keepalive/manifest.json` â€” MV3 manifest
- `~/Desktop/cline-tab-keepalive/background.js` â€” service worker logic
- Rule 24 â€” tab distribution on Artemis (server side)
- Rule 96 â€” Cline window discipline (covers the Mac-Artemis storm
  pattern, complementary to this one)
- Rule 97 â€” extension host OOM (server side)
- Rule 100 â€” pty-host saturation (server side)

## Last updated

2026-05-06 â€” initial rule. Source incident: 20 cline-tempe tabs
went blank simultaneously on Mac with 90% swap (8.25 GB / 9.2 GB),
Artemis healthy throughout (load 1.27, 113 GB free, watchdog
seeing 20 ext-hosts, 0 kills).

## 2026-05-06 10:05 PT addendum â€” sister failure: Artemis SWAP-thrash class

Same day, ~10 min after the original Mac-side incident, Artemis hit a
DIFFERENT failure: swap thrash on the Linux side. New windows wouldn't
open, existing ones started dropping.

**Fingerprint:**
- Load 24-32 (vs healthy 1-3)
- Memory pressure stall avg10 > 60% (kernel page-thrashing)
- `Swap: 8.0Gi / 8.0Gi / 0B` (100% used, no headroom)
- N ext-hosts at ~2.0-2.4 GB RSS each, +800-1000 MB swap each
- watchdog reports 0 kills (because each individual host is BELOW the
  12 GB renice threshold â€” many medium-bloat hosts is the trap)
- `journalctl _COMM=systemd-oomd` empty (kernel hasn't OOM'd, just
  IO-stalled on swap)

**Why the watchdog misses this class:** rule 97 watchdog triggers at
12 GB RSS sustained per process. 7 hosts at 2.2 GB each = 15.4 GB
total + ~7 GB swap, but no single host crosses the threshold. The
watchdog is correctly tuned for the rare-giant case; it's blind to the
common-medium case.

**The right fix (used 2026-05-06):**
1. Add swapfile (`fallocate + mkswap + swapon`) â€” non-destructive,
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
shows load > 10 + pressure stall > 50% + swap 100% used â†’ this class.
Add 16-32 GB more swap immediately. Do NOT kill ext-hosts.

**Permanent swap configuration shipped 2026-05-06:**
- `/swap.img` (original) â€” 8 GB
- `/swapfile-cline-emergency-2026-05-06` â€” 16 GB
- `/swapfile-cline-emergency2-2026-05-06` â€” 32 GB
- All three in /etc/fstab, total 56 GB swap available
- This gives the medium-bloat-many-hosts pattern enough room to ride
  out parse-on-resume bursts without thrashing.

## 2026-05-06 11:11 PT addendum â€” systemic fix shipped: cumulative-RSS watchdog + tightened archiver

After three failures stacked in 75 minutes (Mac discard at 09:56,
swap thrash at 10:05, watchdog reboot at 11:05), Ruben's directive at
11:10 PT was: *"That's cool and everything but does not address the
fact that Cline kills Artemis way too quickly."* Fair. Adding swap was
treating the symptom. The actual problem is the medium-bloat-many-hosts
pattern that the per-process rule 97 watchdog can't see.

**Shipped same session:**

1. **`/home/emsuserver/bin/exthost-cumulative-watchdog.sh`** â€” runs every
   minute via cron. Sums RSS across all `extensionHost` processes. When
   the sum exceeds **SOFT_CAP_GB=70** (56% of 125 GB phys RAM), renices
   the 2 OLDEST ext-hosts to nice +15. When it exceeds **HARD_CAP_GB=85**
   (68% of phys), renices the 4 OLDEST. **Renice-only, never SIGKILL** â€”
   honors Ruben's "don't kill my active windows" directive. Renice has
   no user-visible effect on a tab actually being used; for parked tabs
   it stops them from competing for memory bandwidth during page-faults.
   Per-PID 10-min cooldown so the same host doesn't get reniced repeatedly.
   Heartbeat at `/var/tmp/cline-watchdog-cumulative-heartbeat`,
   log at `/var/log/cline-watchdog-cumulative.log`.

2. **Tightened archiver thresholds** in `~/bin/cline-task-archiver.sh`:
   - `SIZE_THRESHOLD_MB`: 2 MB â†’ 1 MB (more aggressive eviction)
   - `IDLE_MIN`: 10 min â†’ 5 min (evicts bloat faster after task goes idle)
   - Backup at `~/bin/cline-task-archiver.sh.bak-2026-05-06`

3. **Did NOT touch the V8 heap ceiling** (currently 24 GB base / 16 GB
   multi-instance). Lowering it requires `systemctl restart code-server`
   per instance which kills all active windows on that instance. That's a
   destructive change and goes against the "don't kill my active windows"
   directive. Logged for a future maintenance window when Ruben is OK
   with a clean restart cycle.

**Why this stops the failure class:**

The 11:05 PT reboot was triggered by 7 ext-hosts at 2-3 GB each summing
to ~22 GB working set + swap. With the new watchdog:
- At 70 GB cumulative â†’ 2 oldest hosts get reniced. Their 2-3 GB pages
  start drifting to swap (kernel deprioritizes them in the LRU sense).
- At 85 GB â†’ 4 oldest get reniced. The active hosts get sched priority.
- Pressure stall stays below 50%. The artemis-stall-watchdog never has
  a reason to fire a reboot.

The tightened archiver also feeds back: a 1 MB / 5-min ui_messages.json
gets archived sooner, so when a tab reloads, parse-on-resume finds a
trimmed file instead of a 30 MB one. Lower V8 working set per host =
fewer hosts crossing the 2-3 GB band.

**Verified live:** first cron run at 11:12:01 PT saw 6 ext-hosts at
1 GB total, tier=ok. Box load 0.54, pressure 0%. Cumulative watchdog
will fire silently when needed; you'll see CUMULATIVE_RENICE entries
in `/var/log/cline-watchdog-cumulative.log` if the pattern recurs.

**What's NOT covered (deliberately deferred):**

- V8 heap ceiling tuning (8 GB cap per host) â€” requires destructive restart
- Cline 3.82 lazy-load patch upstream â€” multi-week effort, tracked as
  orchestrator idea #1371
- A "soft TERM at 12 GB single-host" companion to the cumulative watchdog
  â€” would catch genuinely runaway single hosts; for now relying on rule
  97's existing renice-then-kill tier


## 2026-05-06 14:00 PT addendum â€” ACTUAL ROOT CAUSE was a Chrome user setting

After 4+ hours of engineering today (Chrome extension v1.0.0 â†’ v1.1.0, server-side cumulative-RSS watchdog v1 â†’ v2, scheduled heap-cap rotation fired early, 56â†’88 GB swap), Ruben mentioned **Atlas browser does not have this problem with the same workload.** That's the one-line diagnostic I should have asked for at 09:56 PT.

**Actual root cause:** Chrome 147's Memory Saver feature is enabled by default with "Moderate" aggressiveness. Atlas (Chromium-based) ships it disabled. The fix is a 30-second user-setting toggle at `chrome://settings/performance`.

**Correct configuration (Ruben applied at 14:00 PT):**
- Memory Saver: OFF â€” Chrome won't auto-discard inactive tabs at all
- Energy Saver: OFF â€” no background CPU throttling (relevant for powerhouse desktops)
- emsuniversity.com on "Always keep these sites active" list â€” belt+suspenders
- Preload pages: OFF â€” no extra background memory pressure

That replaces the entire extension layer I built. The extension still works as redundant protection but is no longer doing meaningful work.

**Diagnostic lesson:** when a browser-specific issue appears, ask about OTHER browsers FIRST. A 30-second cross-browser test can save 4 hours of engineering.

### NEW Step 0 â€” does it reproduce in another browser?

Open the same tabs in Atlas (or Edge / Firefox / Safari). Wait 5 min for them to park. Trigger a memory-pressure event. If they survive in browser X but die in Chrome, the cause is a Chrome user setting â€” check `chrome://settings/performance` first. Only if it reproduces in MULTIPLE browsers do you proceed to Step 1 (server health check) and Step 2 (Mac swap pressure).

**Why this matters:** Chrome 122+ shipped Memory Saver enabled by default. Most users have never seen the setting. The first move on any "tabs died" report should be cross-browser repro, NOT server diagnosis.

## What's still genuinely useful from today's server-side work

The cumulative-RSS watchdog v2 (with pressure-based trigger), 88 GB swap on `/etc/fstab`, tightened archiver, and 8 GB heap caps are all in place and DID prevent an Artemis auto-reboot at 13:37 PT today when pressure spiked to 87% (would have triggered stall-watchdog reboot at 10 min sustained â€” instead cleared in 1 tick after emergency renice + extra swap). Those defenses remain useful as a backup layer.

## Extension cleanup (optional)

`/Users/rubenmajor/Desktop/cline-tab-keepalive/` v1.1.0 is now redundant. Keep it (harmless defense-in-depth) or remove it (simpler) â€” both fine.

## 2026-05-07 00:05 PT addendum â€” DIFFERENT failure class: tab THROTTLING (not discard)

After the 14:00 PT settings fix, a new symptom surfaced: **"Cline window stops working until I scroll/look at it."** This is NOT the same failure as the 09:56 PT batch-discard event. It's a separate Chrome behavior class that the existing rule 25 wording conflates with discard.

### The two classes are distinct

| Class | Trigger | Symptom | Renderer state | Fix |
|---|---|---|---|---|
| **Discard** | macOS memory pressure â†’ Chrome Memory Saver picks inactive tabs in batch | All tabs go blank simultaneously, need reload to recover | Renderer process killed, WebSocket dropped | Memory Saver OFF (Chrome setting) + cline-tab-keepalive v1.0.0+ (autoDiscardable=false) |
| **Throttling** | Chrome 122+ default behavior on ANY hidden tab — no Mac pressure required, no setting to disable | Tab "frozen" until you focus or scroll, then catches up instantly | Renderer alive, WebSocket alive, paint loop paused | cline-tab-keepalive v1.2.0+ silent-audio loop |

### The mechanism (Chrome ≥122)

When a tab is hidden (other tab forward, window minimized, on another macOS Space, fully occluded by other windows), Chrome unconditionally:

- **Pauses `requestAnimationFrame` entirely** — no rAF callbacks fire until visible. **This is the killer for Cline.** Cline's React webview render-commit loop rides on rAF, so paint freezes even though data is arriving.
- Clamps `setTimeout` / `setInterval` to ≥1s minimum.
- There is no Chrome setting to disable this. The `chrome://flags/` flag for cross-origin iframe throttling exists but doesn't cover top-level tab throttling. The fix is to make Chrome think the tab is "active" via one of the documented exemptions — playing audio is one.

### Diagnosis algorithm â€” distinguishing throttle from discard

When Ruben says "my cline tab stopped working":

1. **Did all tabs die at once?** â†’ discard class. Look at swap (`sysctl vm.swapusage`) + `chrome://discards/`. Fix is rule 25's existing playbook.
2. **Did ONE tab freeze, recover when you scrolled or focused it?** â†’ throttling class. Fix is the silent-audio loop.
3. **Did the tab show a reload-needed banner / blank chrome:// page?** â†’ discard.
4. **Did the tab look 100% normal but messages were old, then catch up instantly when you looked?** â†’ throttling.

### The fix shipped 2026-05-07 â€” keep-alive extension v1.2.0

`/Users/rubenmajor/Desktop/cline-tab-keepalive/` bumped from v1.1.0 to v1.2.0. content.js now plays a silent Web Audio loop while the tab is hidden:

- 1-second buffer of zeros (literal silence) at 22050 Hz, looped
- Routed through a 0-gain node (belt+suspenders against denormal sample drift)
- Toggles on `visibilitychange`: starts when hidden, stops when visible
- Requires `chrome://extensions/` → Cline Tab Keep-Alive → refresh icon → confirm v1.2.0 → reload existing cline tabs once so the new content.js is injected.

### What the v1.2.0 fix does NOT cover

- **Tabs you've already opened** before installing v1.2.0 — must reload them once.
- Throttle and discard are two distinct failure modes; both mitigations live in the same extension now and run independently.

### What I (Cline) MUST do when this report comes in (throttle variant)

**Run Step 0 (other-browser repro) and Mac-side remediation first.** Throttling is purely Mac-side / Chrome-side. Artemis health metrics will be clean.

### Cross-references

- `~/Desktop/cline-tab-keepalive/INSTALL.md` â€” install + v1.2.0 update guide
- `~/Desktop/cline-tab-keepalive/content.js` â€” silent-audio implementation
- Rule 24 â€” server-side tab distribution (5 per instance Ã— 9 instances)
- Rule 96 â€” Mac/Artemis storm pattern (companion failure mode)

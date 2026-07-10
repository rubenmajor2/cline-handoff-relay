# 29 — Mac jetsam cliff WITHOUT the argv.json amplifier (the residual class)

Permanent rule. Workspace-scoped. Source incident: 2026-05-07 22:42-22:55 PT,
the cline-tab-rescue session. Ruben reported "Cline Artemis died yet again
with very few windows and I can't even get past the troubleshooting on that
box with cline windows because it keeps closing them." Artemis was healthy.
argv.json was already cleaned earlier the same day (rule 28). Yet cline-tempe
Chrome tabs still died.

## Why this rule exists alongside rules 25 and 28

Rules 25 (Chrome Memory Saver) and 28 (argv.json js-flags amplifier) named
two specific causes of the Mac-side memory cliff. Each had a clean fix.
After both fixes shipped, **the cliff still recurs** because the genuine
underlying constraint is structural: a 51 GB Mac with ~10 VS Code windows,
~10-20 Chrome cline-tempe tabs, Mail/Spark/Slack/etc. eats RAM faster than
the macOS compressor can buy headroom. macOS jetsam fires Chrome (the
largest discardable target), and every cline-tempe tab dies at once.

This rule is the residual case. It documents the cliff that's left after
rules 25 and 28 are applied.

## The fingerprint

All five conditions can be true simultaneously and that IS the failure mode:

1. `vm_stat` "Pages free" × 16 KB < 500 MB
2. `vm_stat` "Pages occupied by compressor" × 16 KB > 25 GB
3. `sysctl vm.swapusage` shows used = 0 (compressor still holding it all)
4. `log show --process "Google Chrome" --last 30m | grep "App termination approved"` returns 1+ hits
5. Total VS Code RSS (sum of all Code Helper procs + main) > 8 GB

When condition 4 fires, every cline-tempe Chrome tab on Artemis dies
simultaneously. Symptom matches "Cline windows on Artemis all closed at
once."

The compressor is the leading indicator: it can hold ~30 GB on a 51 GB
Mac before macOS gives up and starts jetsaming. Once it crosses ~25 GB,
opening one more window or browser tab is enough to push it over.

## Why subagents and naive diagnosis miss this

In the source incident, two subagents reached different wrong conclusions
because:

- Subagent A misread `extensions.json` keys (`location.fsPath` vs
  `location.path`) and reported all 6 entries phantom. They were not.
- Subagent B reported argv.json clean. The script's grep for
  `max-old-space-size` matched the comment text describing the removal.
  Active config was actually clean — but the false positive sent the
  diagnosis sideways.
- Neither suspected the residual cliff because both prior rules had been
  "fixed today."

The lesson: **the diagnostic must distinguish "rule 28 still active" from
"rule 28 fixed but the cliff remains anyway" from "rule 26 phantom" from
"rule 25 Memory Saver re-enabled."** A single-shot grep cannot.

## The diagnostic script

`/Users/rubenmajor/bin/cline-windows-died-diagnose.sh` ships the canonical
6-step check. Run it the moment Cline windows on Artemis die or while you
are losing them. Output gives:

- Artemis health (5s SSH probe)
- Chrome force-termination events in last 30 min
- Mac swap, free RAM, compressor pressure
- Mac VS Code total footprint + Plugin proc count
- argv.json amplifier check (comment-stripped)
- extensions.json phantom check (correct key)
- VERDICT line + the specific fix that maps to which rule fired

The script is the durable repair: future windows-died incidents become a
~10-second check instead of a 30-minute hunt through subagent results.

## When this rule fires (the residual cliff specifically)

If the script returns:

- `MAC_JETSAM_CHROME` ✓
- `MAC_RAM_CLIFF` ✓ (free < 500 MB) OR `MAC_COMPRESSOR_HIGH` ✓ (compressor > 25 GB)
- `ARGV_JSON_AMPLIFIER` ✗ (clean)
- `PHANTOM_MANIFEST` ✗ (clean)
- `ARTEMIS_*` ✗ (Artemis healthy)

…then this rule is the relevant one. The cause is structural Mac RAM
exhaustion under the legitimate workload, not a misconfiguration.

## The fix (in priority order)

Three reversible options. Pick by how much disruption you accept:

1. **Restart Chrome only.** Cmd+Q on Chrome, reopen. Frees ~2 GB. Loses
   cline-tempe tabs. Mac VS Code state preserved. Chrome reopens with
   "Restore tabs" so the tabs come back, but their renderers are fresh.
   *Time: ~10 sec. Use this when the Mac VS Code work is mid-task.*

2. **Quit and reopen VS Code.** Cmd+Q on VS Code, reopen. Frees ~10 GB
   (the heaviest single consumer). Cline tasks on Artemis resume from
   disk because they live on Artemis. Mac VS Code tasks resume from
   their on-disk task folders. **This is the highest-leverage fix.**
   *Time: ~30 sec. Use this when Mac VS Code is heavy (>10 GB) or when
   restarting Chrome alone hasn't freed enough.*

3. **Reboot the Mac.** Nuclear option. Use only if 1 and 2 don't help
   or if multiple things look weird at once. *Time: ~2 min.*

After any of these, Artemis-side ext-hosts reconnect cleanly because
Artemis itself never died.

## What NOT to do

- **Don't kill individual Code Helper Plugin procs by PID.** VS Code
  respawns them. You'll just churn.
- **Don't close cline-tempe tabs one at a time hoping it'll relieve
  pressure.** Chrome doesn't give RAM back to the OS until you quit
  the whole app or restart it.
- **Don't open MORE Cline windows to "investigate."** Each new window
  pushes the compressor closer to the cliff. The diagnostic script
  exists precisely so you don't need a Cline window to triage.
- **Don't ssh + restart code-server on Artemis.** Artemis is healthy.
  Restarting it kills your remaining live windows for no reason.

## Long-term mitigations (planned, not yet built)

1. **VS Code Profile separation** (per rule 28): a "Cline-Artemis"
   Profile on Mac VS Code that only loads Cline + Remote-SSH +
   launcher. Drops per-window Plugin proc count from ~5 to 1. Cuts
   Mac VS Code RAM by ~60% in steady state.
2. **Hard cap on simultaneous Cline-Artemis Chrome tabs** at 8-10
   (Ruben's working sweet spot). At 12+ the cliff becomes
   probabilistic.
3. **Auto-snooze**: a launchd job that runs the diagnostic script
   every 10 min and posts a one-line iMessage to Ruben if the
   `MAC_COMPRESSOR_HIGH` warning fires while Chrome is alive.
   Prevents the silent walk to the cliff.

## Cross-references

- `/Users/rubenmajor/bin/cline-windows-died-diagnose.sh` — diagnostic
  script (canonical)
- Rule 25 — `25-mac-side-cline-tab-die-chrome-discard.md` (Memory Saver
  variant)
- Rule 28 — `28-mac-vscode-argv-js-flags-amplifier.md` (argv.json
  variant)
- Rule 24 — `24-cline-tabs-cap-and-distribution.md` (Artemis-side
  windows distribution; ALSO bound by Mac RAM as documented here)
- Rule 96, 97, 100 — Artemis-side rules (rule out FIRST via the
  script's step 1)
- Rule 17 — `00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds.md`
  (the source incident showed why subagent dispatch + cross-check is
  required when rules 25/28 are already-fixed AND symptoms persist)

## Last updated

2026-05-07 — initial rule. Source: cline-tab-rescue session; live
incident with Chrome force-terminated at 22:46:41 PT under 67 MB free
RAM and 30 GB compressor pressure on a 51 GB Mac, while argv.json was
clean and Artemis was healthy.

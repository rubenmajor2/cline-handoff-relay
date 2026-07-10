# 102 — Mac battery drain → MCP fork bomb fingerprint

Permanent rule. Workspace-scoped. Source incident: 2026-05-19 ~13:30 PT.
Ruben's MacBook drained to ~2% battery overnight/earlier. When he reported
"free up memory on my Mac" later that day, found 333 runaway `npm exec` MCP
processes consuming 21+ GB RAM + swap. Same root cause: post-battery-drain
stuck child-tracker state in supergateway parent processes for the public
MCPs (`@modelcontextprotocol/server-memory`, `server-sequential-thinking`,
`@upstash/context7-mcp`).

## The fingerprint

When the user reports any of:
- "Mac is slow"
- "Free up memory"
- "Mac is glitchy after [low battery / sleep / wake / power event]"
- "Cline tabs sluggish"

…AND macOS Activity Monitor / `vm_stat` shows high compressor + swap pressure:

1. `vm_stat | grep "Pages free"` < 50K pages (~800 MB) AND
2. `sysctl vm.swapusage` shows >90% swap used AND
3. `ps -ax | grep 'npm exec @' | wc -l` returns >50

→ It's almost certainly the supergateway+npx fork-bomb pattern, often
triggered by an OS power event (battery <5%, forced sleep, kernel panic
recovery) that left supergateway parents in a stuck-child-tracker state.

## What macOS battery <5% does to background services

When battery hits critical threshold, macOS aggressively:
- Sends SIGSTOP / suspends background processes
- Throttles I/O / disk activity
- Pauses launchd-managed daemons

When power is restored, daemons resume but their internal state (child
process trackers, file descriptors, pending writes) may be inconsistent.
Specifically for `supergateway --stdio npx -y @<mcp>` chains:
- Parent supergateway resumes
- Child npm exec is gone (killed during suspend)
- supergateway doesn't notice; tries to spawn fresh child on next request
- Old child tracker never cleaned up
- Every subsequent Cline retry → new child spawned, none cleaned up
- Fork bomb grows until reaper catches up OR memory crisis

## What to do (the fix sequence, in order)

### Step 1: Diagnose (parallel probes per rule 75)
```bash
vm_stat | head -8
sysctl vm.swapusage
ps -axo rss,command | grep -E 'npm exec @' | sort -n -r | head -10
ps -ax | grep supergateway | grep -v grep
tail -5 /tmp/mcp-reaper.log
```

### Step 2: Identify which MCPs are leaking
```bash
for pat in 'server-memory' 'server-sequential-thinking' 'context7-mcp'; do
  echo "$pat: $(ps -ax | grep -E "$pat" | grep -v grep | wc -l)"
done
```

If a SINGLE MCP shows 30+ children → that one supergateway parent is the
stuck-tracker source. Surgical fix: kill JUST that supergateway parent.
If ALL 3 show 20+ each → broader stuck state, kill all 3 supergateway
parents.

### Step 3: Surgical kill of stuck supergateway parent(s)
```bash
# Find PID of the leaky supergateway:
ps -ax | grep 'supergateway.*server-sequential-thinking' | grep -v grep
# Kill it (DO NOT touch the iMessage MCP supergateway PID 67952 or similar):
kill <pid>
# Force-clean any orphaned children:
pkill -9 -f 'server-sequential-thinking'  # or whichever pattern
```

### Step 4: Wait for auto-reconnect
`com.emsu.cline-mcp-auto-reconnect` launchd job (runs every 30s) will
detect the missing MCP server and re-trigger Cline to reconnect, which
spawns a FRESH supergateway parent with a clean child tracker.

### Step 5: Drain accumulated children
```bash
# Run reaper a few times to clear the backlog
for i in 1 2 3 4 5; do /usr/bin/python3 ~/bin/emsu-mcp-reaper.py; sleep 2; done
```

### Step 6: Verify steady state
```bash
ps -ax | grep -E 'npm exec @' | grep -v grep | wc -l   # should be < 30
vm_stat | grep 'Pages free' | awk '{printf "%.1f GB free\n", $3*16384/1024/1024/1024}'
sysctl vm.swapusage   # swap may still be high; macOS pages back gradually
```

## CRITICAL: Do NOT disable MCPs in cline_mcp_settings.json

Ruben uses ALL 3 of the public MCPs (`memory`, `sequential-thinking`,
`context7`) for prompt quality. Don't propose disabling them. The fix is
to clear the stuck supergateway parent, not remove the MCP.

## CRITICAL: Reaper caps are now (3, 5) — don't loosen

`~/bin/emsu-mcp-reaper.py` PATTERNS dict was tightened from (20, 30) to
(3, 5) on 2026-05-19. This means each MCP class is capped at 5 procs
total. If a future fork bomb happens, max blast is ~30 procs across all
patterns instead of unbounded growth. **Do NOT loosen these caps** —
each MCP only needs 1-2 procs to serve Cline requests; (3, 5) gives
plenty of headroom.

Backup of pre-tightening version at:
`~/bin/emsu-mcp-reaper.py.bak-20260519-133500-pre-tightening`

## Why this rule exists separate from rule 96/97/98

Rule 96 is Mac/Artemis storm pattern (Cline-windows-reload-after-reboot).
Rule 97 is extension host OOM (V8 heap blowout in Cline ext-host on
Artemis).
Rule 98 is edit discipline (don't bloat ui_messages.json).

This rule (102) is **Mac-side OS-power-event-induced supergateway state
corruption**. Different layer entirely. The fingerprint (333 npm exec
procs from a stable count of <20) is unique to the supergateway+npx+power-
event interaction.

## Cross-references

- Rule 25 — Mac jetsam cliff (related Mac memory pressure pattern, but
  Chrome-side not MCP-side)
- Rule 28 — Mac VS Code argv.json amplifier (different mechanism)
- Rule 29 — agents act on confidence tier (the kill-stuck-supergateway
  fix is high-confidence + reversible + small blast = act, don't ask)
- Rule 32 — prefer dedicated MCP wrappers
- Rule 75 — verification tasks default to MCP + subagents
- Rule 89 — Ollama cold-load timeout (not broken vs slow distinction)
- Rule 92 — work at the core, not bandaids (this rule IS the core fix)
- `~/bin/emsu-mcp-reaper.py` — the runtime guard
- `~/Library/LaunchAgents/com.emsu.cline-mcp-auto-reconnect.plist` — the auto-recovery layer

## Specifically: when Cline encounters a Mac memory crisis

1. Run `vm_stat` + `sysctl vm.swapusage` first (rule 75 verification).
2. If swap > 90% AND compressor > 25 GB AND `npm exec @` proc count > 50
   → this rule's class. Don't go hunting for bigger memory hogs first.
3. The fix is ~30 seconds (surgical kill + wait for auto-reconnect).
4. Don't kill VS Code Helper procs (those are active Cline windows).
5. Don't kill iMessage MCP supergateway (critical for ops).
6. Don't disable MCPs in settings.json (Ruben needs them).
7. Don't unload `com.emsu.cline-mcp-auto-reconnect` launchd (it's the
   recovery layer, not the problem).

## Self-check before any wrap-up

If I just ran kills + reaper on the Mac, did I:
1. Verify `npm exec @` proc count is < 30?
2. Verify all 4 supergateway parents are alive (iMessage + memory +
   sequential-thinking + context7)?
3. Verify free RAM jumped by ≥3 GB?
4. NOT disable any MCPs in settings?
5. NOT kill any VS Code Helper procs?
6. Codify the learning if this is a recurring pattern?

If any answer is no, finish the work before reporting completion.

## Last updated

2026-05-19 — initial rule. Source incident: Ruben's MacBook drained
to ~2% battery, then later that day Mac was glitchy + memory crisis.
Diagnosed mid-conversation: 333 runaway MCP procs, free RAM 57 MB,
swap 95%. Fix: tightened mcp-reaper caps (20,30)→(3,5) permanently +
surgically restarted supergateway parents. Result: 9.73 GB free RAM
recovered, all MCPs preserved.

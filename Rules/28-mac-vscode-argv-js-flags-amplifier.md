# 28 — Mac VS Code `argv.json` js-flags amplifier (the 50-Plugin-procs trap)

Permanent rule. Workspace-scoped. Source incident: 2026-05-07 ~09:55 PT —
Ruben reported "I just lost all my Artemis Cline windows AGAIN" with only
5-10 Remote-SSH windows open. Diagnosis traced through stale ssh muxes
(rule 27 / dynamic port forwarding) → Mac swap pressure → root cause:
`~/.vscode/argv.json` had `"js-flags": "--max-old-space-size=24576"`
intended to give the ext-host more heap, but that flag inherits to EVERY
child process VS Code spawns. With ~10 Remote-SSH windows × 5 local
Plugin procs/window = 50 V8 isolates, each thinking it could grow to
24 GB. V8 GCs lazily inside that ceiling, so every proc was carrying
350-450 MB of mostly-garbage. Mac swap saturated → macOS jetsamed Code
Helper procs → Remote-SSH `ssh -D` tunnels died → "Failed to set up
dynamic port forwarding" + windows blank.

## The bright-line rule

**Do NOT put `--max-old-space-size=N` in `~/.vscode/argv.json` `js-flags`
on macOS.** That field passes through Electron's
`app.commandLine.appendSwitch('js-flags', ...)` to every child renderer,
every utility, every extension host (Code Helper Plugin), and every LSP
server. With even 5 Remote-SSH windows × ~5 local extensions/window, a
24 GB cap means 25 separate V8 isolates each willing to hold 24 GB of
old-space heap before triggering full-GC pressure. The default V8 cap
on a 64-bit build is ~4 GB and that's plenty for anything Mac-side.

The `js-flags` field in `argv.json` is for very specific Electron-level
tuning (e.g. `--harmony-something` to enable a Node feature). It is
NOT a knob for "give my one extension more heap." It hits everything.

## What's actually safe to do if you really need ext-host heap

Two cases:

1. **The ext-host runs on Mac (no Remote-SSH).** Use VS Code's
   `extensions.experimental.affinity` to isolate the heavy extension
   into its own ext-host, but accept the default 4 GB cap. If 4 GB
   isn't enough, the extension itself has a memory leak — file an
   issue with the extension author. Bumping the cap just delays the
   crash, doesn't prevent it.

2. **The ext-host runs on a remote box (Remote-SSH).** The remote
   ext-host is a separate Node process on the remote (governed by
   rules 96/97 on Artemis). Mac side never needs the bump. argv.json
   js-flags affecting Mac procs is irrelevant to the remote ext-host
   anyway — it does NOT propagate over Remote-SSH to the remote
   server. So the entire premise of "I'll bump argv.json js-flags
   to give Cline more heap" is wrong when Cline lives on the remote.

## The safer config for a Cline-Artemis Remote-SSH workflow

`~/.vscode/argv.json`:
```json
{
  "enable-crash-reporter": true,
  "crash-reporter-id": "<keep your existing UUID>"
}
```
That's it. No `js-flags`. No `--max-old-space-size`. Default V8 cap
is fine on Mac.

For VS Code `settings.json` (User scope), the durable knobs that
ACTUALLY reduce per-window Mac-side cost when targeting Remote-SSH:

```jsonc
{
  // Don't auto-install local extensions on the remote — keep them
  // local where they help, and skip running them in the remote
  // ext-host where they don't.
  "remote.SSH.defaultExtensions": ["saoudrizwan.claude-dev"],

  // Limit how aggressively the local ext-host preloads stuff that
  // won't be used (mainly affects startup memory).
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,

  // Reduce file-watcher memory; for Remote-SSH you don't need
  // local file watchers anyway.
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/node_modules/**": true,
    "**/.venv/**": true,
    "**/dist/**": true,
    "**/build/**": true
  },

  // Prevent local extensions from eagerly running per workspace —
  // Remote-SSH already auto-disables many, this tightens it.
  "remote.SSH.useLocalServer": true
}
```

For the heaviest local extensions that auto-activate on every
window even with a Remote-SSH workspace (and therefore spawn one
local Plugin proc per window each), the highest-leverage fix is:
**uninstall the ones you don't need on Mac**. Or use a separate
**VS Code Profile** ("Cline-Artemis") with only the Cline extension
enabled. Profiles isolate the extension list per-window, so the
Mac-side Plugin proc count for those windows drops from ~5 to 1.

The local extensions Ruben currently has that fire per window (as
of 2026-05-07): eslint, prettier, gitlens, intelephense,
php-cs-fixer, errorlens, todo-tree, php-debug,
php-namespace-resolver, dbclient, mysql-client, intelephense.
That's ~10-12 plugin procs per Remote-SSH window all by themselves,
none of which Cline needs.

## Profile-based isolation (the cleanest long-term shape)

VS Code Profiles let you define an extension subset per-workspace.
For a "Cline-Artemis" profile:

1. Settings (Cmd+,) → click the gear-with-arrow icon top-right → New
   Profile → name it "Cline-Artemis" → choose "Empty profile"
2. Inside that profile, install only:
   - `saoudrizwan.claude-dev` (Cline)
   - `ms-vscode-remote.remote-ssh` (and `-edit`)
   - `auto-open-cline` (Ruben's launcher) if needed
3. Do NOT install eslint, prettier, gitlens, php tooling, etc.
4. Open Cline-Artemis windows from the launcher with this profile
   (the launcher can pass `--profile Cline-Artemis` on the CLI).
5. Use the default profile for everything else (full IDE work).

Expected Mac RAM drop: from ~2 GB/window (renderer + 5 plugin procs)
to ~600-800 MB/window (renderer + 1 plugin proc). 10 windows go from
~20 GB Mac-side footprint to ~7-8 GB.

## Detection (for future-me reading this rule)

If a Remote-SSH user reports any of:
- "All my windows died at the same time"
- "Failed to set up dynamic port forwarding" (rule 27 — but that's
  symptom, not cause when it recurs)
- "VS Code is slow / crashing"
- Mac swap above 70%

Diagnostic algorithm:

```bash
# 1. Check argv.json for the trap
cat ~/.vscode/argv.json | grep -i "js-flags\|max-old-space"
# Any non-empty match → the trap is set. Remove it.

# 2. Count Plugin procs and confirm heap-cap inheritance
ps -axo pid,rss,command | grep "Code Helper (Plugin)" | wc -l
ps -axo command | grep "Code Helper (Plugin)" | head -1 | tr ' ' '\n' | grep -i max-old
# If the second line returns "--max-old-space-size=24576" or similar
# >4096, the argv.json trap is active.

# 3. Mac swap status
sysctl vm.swapusage
# > 70% used = jetsam will start firing
```

## What this rule does NOT cover

- Rule 25 (Chrome Memory Saver) — different mechanism, browser-side
- Rule 26 (phantom Remote-SSH manifest) — different mechanism
- Rule 27 (stale ssh ControlMaster mux) — symptom layer, not root cause
- Rule 96/97 — remote ext-host (Artemis) memory; UNAFFECTED by Mac argv.json

## Cross-references

- `~/.vscode/argv.json` (the file)
- `~/.vscode/argv.json.bak-2026-05-07-cline-memfix` (backup pre-fix)
- VS Code Profiles docs: https://code.visualstudio.com/docs/editor/profiles
- Rule 27 (ssh mux) — frequently fires as downstream symptom of this rule
- Rule 96/97 — remote ext-host watchdog stack on Artemis

## Last updated

2026-05-07 — initial rule. Source incident: Mac 48 GB, swap 4.2 GB / 5 GB
used (82%), 50 Code Helper (Plugin) procs each capped at 24 GB heap due
to argv.json js-flags. Removed the line; documented profile-based
extension isolation as the durable per-window mitigation.

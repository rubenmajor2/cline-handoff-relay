# 31 — Cline 3.82.0 chat input gets erased mid-typing (and the self-heal patch)

Permanent rule. Workspace-scoped. Source incident: 2026-05-08 ~10:50 PT.
Ruben reported: "my prompts that I have are being deleted or removed from
Cline randomly at random times… It just happened 2x this morning."

## What's actually happening

Cline 3.82.0 has a webview bug where the chat input field is unilaterally
cleared during normal task progression. Specifically, the React webview
runs this useEffect (deobfuscated from the bundle at offset 1789349):

```js
useEffect(() => {
  if (lastMessage?.type === "say" &&
      lastMessage.say === "api_req_started" &&
      lastAsk?.ask === "command_output") {
    setInputValue("");          // <-- this line is the bug
    setSelectedImages([]);
    setSelectedFiles([]);
  }
}, [lastMessage?.type, lastMessage?.say, lastAsk?.ask, hookRef]);
```

The intent is "after the user approves a command and a new API request
fires, clear the input box." The problem is the dep array also re-fires
this effect on benign re-renders and on certain state-context updates,
so it can run mid-typing while the user has a draft in the box. Net
effect: text Ruben is typing disappears.

## This is upstream, not local

Verified 2026-05-08:

- Mac is healthy. No swap, no jetsam, no ext-host crashes (the original
  Cline Plugin procs from 00:49 PT this morning are still alive 10+ hrs
  later).
- argv.json js-flags is clean (rule 28 not in play).
- Chrome Memory Saver is off (rule 25 not in play).
- Watchdog stack is silent.

The bug is in the Cline 3.82.0 webview bundle. **3.82.0 is the latest
published version on the VS Marketplace and GitHub releases (2026-05-01),
so there is no upgrade-out**. There are 4+ open upstream issues all
unfixed:

- https://github.com/cline/cline/issues/5160
- https://github.com/cline/cline/issues/8248
- https://github.com/cline/cline/issues/9141
- https://github.com/cline/cline/issues/9453

The user-facing reproduction in those issues is "switch from Plan to Act
mid-typing and your draft disappears", but the same useEffect fires on
several other transitions, which is why it feels random.

## What we did

1. **Patched the webview bundle** at
   `~/.vscode/extensions/saoudrizwan.claude-dev-3.82.0/webview-ui/build/assets/index.js`
   to remove the single `setInputValue("")` call from that useEffect. The
   image/file clears (`setSelectedImages([])`, `setSelectedFiles([])`)
   stay because those ARE supposed to clear after a real send.
2. **Backed up the original** at `index.js.bak-2026-05-08-cline-input-clear-fix`
   so reverting is one `cp` away.
3. **Shipped a self-heal script** at
   `~/Documents/Cline/cline_input_clear_fix.sh`. It re-applies the patch
   to whatever `saoudrizwan.claude-dev-*` directory is currently newest,
   so it survives Cline auto-updates. Idempotent: detects already-patched
   state and exits clean. If upstream eventually re-bundles in a way that
   makes the byte pattern not match, the script silently no-ops rather
   than damaging the bundle.
4. **Loaded a launchd job** at
   `~/Library/LaunchAgents/com.ruben.cline-input-clear-fix.plist` that
   runs the script at load AND every 3600 s. Logs to
   `/tmp/cline-input-clear-fix.log`.
5. **Synced through cline-handoff-relay** so the script + this rule
   are versioned in the relay repo.

## Side-effect of the patch

Tiny: when you approve a `command` and the next API request fires, your
input box keeps whatever you previously typed (instead of being auto-
cleared). If that text is stale, Cmd+A + Backspace clears it. Worst
realistic outcome on an accidental submit is one extra send of the
previous text. Compared to losing what Ruben is typing live, this is the
right tradeoff.

## What I (Cline) MUST do going forward

1. **Don't re-diagnose this as a memory/jetsam/ext-host issue.** It
   isn't. Ext-hosts on Mac stay alive across all of these clears. The
   smoking gun is the `setInputValue("")` line at offset 1789349 of the
   webview bundle — confirmable with
   `grep -c 'setInputValue("")' ~/.vscode/extensions/saoudrizwan.claude-dev-*/webview-ui/build/assets/index.js`.
   - 0 = patched
   - 1 = unpatched (run the self-heal script)
2. **If Ruben reports the input clearing again**, first check:
   ```sh
   tail -20 /tmp/cline-input-clear-fix.log
   grep -c 'setInputValue("")' ~/.vscode/extensions/saoudrizwan.claude-dev-*/webview-ui/build/assets/index.js
   launchctl list | grep cline-input-clear-fix
   ```
   If grep returns 1, run the self-heal manually:
   `bash ~/Documents/Cline/cline_input_clear_fix.sh`. Then **reload the
   Cline window** (Cmd+Shift+P → "Developer: Reload Window") so the
   webview reloads the patched bundle.
3. **When Cline updates** to 3.83.x or beyond, the launchd job should
   handle it on its own. But the FIRST time it runs against a new version
   the script will log `buggy pattern NOT found and no patched marker —
   Cline bundling changed, skipping`. That is the signal to **manually
   re-derive the new minified pattern** and update the `OLD`/`NEW`
   constants in `~/Documents/Cline/cline_input_clear_fix.sh`. Do this by:
   ```sh
   WV=~/.vscode/extensions/saoudrizwan.claude-dev-*/webview-ui/build/assets/index.js
   grep -aboE 'setInputValue\(""\)' $WV
   # then dd around the offset to see context, find the same expression shape
   ```
   If upstream finally fixes the bug (i.e. no `setInputValue("")` in the
   bundle anywhere), do nothing — the script's "no buggy pattern, no
   patched marker, skipping" branch is correct.
4. **Never patch the extension host bundle** (`dist/extension.js`) for
   this. The bug is purely in the webview React component. The extension
   host runs on Artemis when using Remote-SSH; the webview runs on the
   Mac. The patched file is local to the Mac and stays even when the
   workspace is Remote-SSH (the webview bundle ships with the local
   extension install).

## Reload required after every patch

The Cline webview only reads the bundle at window-load time. After a
fresh patch the running window keeps the unpatched version in memory.
Cmd+Shift+P → "Developer: Reload Window" picks up the new bundle. The
launchd job runs hourly so most of the time the bundle is patched
before the window even opens, but immediately after a Cline auto-update
+ self-heal, the open window will still need a reload.

## Files / locations

| Path | What |
|---|---|
| `~/.vscode/extensions/saoudrizwan.claude-dev-3.82.0/webview-ui/build/assets/index.js` | The patched bundle |
| `~/.vscode/extensions/saoudrizwan.claude-dev-3.82.0/webview-ui/build/assets/index.js.bak-2026-05-08-cline-input-clear-fix` | Original byte-exact backup |
| `~/Documents/Cline/cline_input_clear_fix.sh` | Re-apply script, idempotent |
| `~/Library/LaunchAgents/com.ruben.cline-input-clear-fix.plist` | Hourly + on-load runner |
| `/tmp/cline-input-clear-fix.log` | Runtime log |

## Cross-references

- Rule 28 (`28-mac-vscode-argv-js-flags-amplifier.md`) — argv.json clean
  was a precondition for ruling out other classes of input loss.
- Rule 25 (`25-mac-side-cline-tab-die-chrome-discard.md`) — Chrome
  discard would kill the whole tab, not just the input. Different class.
- Rule 97 (`97-extension-host-oom.md`) — ext-host OOM would gray the
  whole UI, not just clear the input. Different class.
- Rule 17 (`00-READ-FIRST-17-…`) — used subagents to triangulate against
  upstream issues + bundle source. Confirms the diagnosis.

## Last updated

2026-05-08 ~10:58 PT — initial. Source incident: Ruben "my prompts are
being deleted… 2x this morning". Patched in this same session. Self-heal
launchd job loaded and confirmed running.

# 26 — Phantom VS Code extension manifest (the `code --list-extensions` lie)

Permanent rule. Workspace-scoped. Source incident: 2026-05-07 ~00:50 PT — local
VS Code "Cline Artemis" window showed "No remote extension installed to resolve
ssh-remote" and Ruben separately reported "Cline stops working until I scroll
or look at it." First-pass diagnosis went wrong because `code --list-extensions`
reported Remote-SSH as installed when it wasn't actually on disk. Wasted ~1 hour
chasing the wrong layer (Chrome rAF throttling, rule 25 territory) before
subagent re-investigation surfaced the real cause.

## The bright-line rule

**`code --list-extensions` is NOT a source of truth.** It reads
`~/.vscode/extensions/extensions.json` (the manifest) and reports what the
manifest says. The manifest can — and on this Mac did — list extensions whose
on-disk folders have been deleted. From that point on:

- VS Code activates → tries to load the listed extension → finds no folder →
  emits a generic "extension failed to load" or, for Remote-SSH specifically,
  "No remote extension installed to resolve ssh-remote".
- `code --install-extension <ext> --force` reads the manifest, sees the entry,
  and refuses with **"Extension X is already installed"** — the install-with-
  force path doesn't actually re-fetch when the manifest claims presence.
- VS Code's UI extension panel may also show the extension as installed because
  it's reading the same manifest.

The real source of truth is **the actual folder under `~/.vscode/extensions/`**.

## Recognition (when does this rule fire)

Any of these symptoms with stock VS Code (Microsoft, not Cursor / VSCodium /
Windsurf), in roughly decreasing order of specificity:

1. **"No remote extension installed to resolve ssh-remote"** when opening a
   workspace whose URI starts with `vscode-remote://ssh-remote+...`.
2. Generic "Extension Y failed to activate" with no obvious crash trace, where
   Y *should* be installed.
3. `code --install-extension Y --force` exits 0 saying "already installed" but
   `ls ~/.vscode/extensions/ | grep Y` shows nothing.
4. UI extension list shows Y as installed but clicking the gear / details
   silently does nothing.
5. Reload doesn't fix it; reinstall doesn't fix it; even uninstall + reinstall
   doesn't fix it because the uninstall path also short-circuits if it can't
   find the folder.

If symptom 1 surfaces in conjunction with "VS Code window stops working until
I scroll/look at it" — that's the exact 2026-05-07 incident. The two are the
same bug: the local webview is wedged waiting on a remote that won't resolve
because the local Remote-SSH extension can't load.

## Diagnosis algorithm

When you see any of the above, run BOTH of these and compare:

```sh
# What the manifest claims
code --list-extensions | grep -iE "<short-name>"

# What's actually on disk
ls ~/.vscode/extensions/ | grep -iE "<short-name>"
```

If the manifest says "yes" and the disk says "no" — that's the trap. The
canonical Python check that exposed it cleanly on 2026-05-07:

```sh
cat ~/.vscode/extensions/extensions.json | python3 -c "
import json, os, sys
data = json.load(sys.stdin)
print('Total entries:', len(data))
for e in data:
    eid = e.get('identifier', {}).get('id', '')
    if '<short-name>' in eid.lower():
        loc = e.get('location', {}).get('fsPath', '')
        exists = os.path.exists(loc) if loc else False
        print(f'  id={eid} version={e.get(\"version\",\"?\")} location={loc} exists={exists}')
"
```

`exists=False` (or empty `location`) on any entry = phantom.

## Fix (the only one that actually works)

1. **Backup the manifest** (before mutating it):
   ```sh
   cp ~/.vscode/extensions/extensions.json ~/.vscode/extensions/extensions.json.bak-$(date +%Y%m%d-%H%M%S)-cline-rescue
   ```
2. **Remove the phantom entries from the manifest** with python (don't try to
   hand-edit JSON):
   ```sh
   python3 <<'EOF'
   import json
   p = "/Users/rubenmajor/.vscode/extensions/extensions.json"
   data = json.load(open(p))
   before = len(data)
   data = [e for e in data if "<short-name>" not in e.get("identifier",{}).get("id","").lower()]
   after = len(data)
   json.dump(data, open(p, "w"))
   print(f"removed {before-after} phantom entries, before={before} after={after}")
   EOF
   ```
3. **Reinstall fresh from Microsoft marketplace via VS Code CLI**:
   ```sh
   /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code \
     --install-extension <publisher.full-id> --force
   ```
   With the manifest entry removed, the CLI now actually fetches.
4. **Verify on disk**:
   ```sh
   ls ~/.vscode/extensions/ | grep <short-name>
   # should now show <short-name>-<version>/ folder
   ```
5. **Reload the window** (Cmd+Shift+P → Developer: Reload Window). If this is
   Remote-SSH, VS Code will then auto-install vscode-server on the remote box.

For Remote-SSH specifically (the 2026-05-07 source case), do BOTH
`ms-vscode-remote.remote-ssh` AND `ms-vscode-remote.remote-ssh-edit`. They are
two separate extensions and both must be present.

## Why this happens (best-guess root cause)

Manifest entries leak when:
- A manual cleanup script deletes extension folders without updating the
  manifest. Cline itself has done this in past tasks ("clean up old extension
  versions"), see prior #cline-rescue tasks.
- `rsync --delete` or similar wipes the disk side without telling VS Code.
- Time Machine restore of an older `~/.vscode/extensions/` selectively skipped
  the actual extension folders but not the manifest.
- VS Code crashes mid-install, leaving the manifest entry but partial files
  that get later cleaned up by a different process.

Once the disk and the manifest diverge, VS Code never self-heals — it trusts
the manifest absolutely. The CLI's "already installed" lie reinforces the
divergence.

## What I (Cline) MUST do going forward

1. **Never trust `code --list-extensions` as proof an extension exists.** It
   only proves the manifest *claims* it exists. Cross-check against
   `ls ~/.vscode/extensions/`.
2. **If a user reports an extension misbehaving, run the diagnosis algorithm
   above FIRST.** Before considering Chrome layer, network layer, OS layer.
   This is a 30-second check and rules out the most common silent failure.
3. **For Remote-SSH-specific reports** ("ssh-remote unavailable", "file system
   provider not available"), include this rule in the diagnosis path. The
   cause is almost always either (a) the manifest phantom from this rule, or
   (b) a genuine SSH connectivity issue (test with raw `ssh artemis "echo OK"`
   first).
4. **Don't let the symptom pull you toward a different layer.** "Stops working
   until I scroll/look" sounds like Chrome rAF throttling (rule 25 territory)
   but in this incident it was actually downstream of the manifest phantom.
   Always check the simpler layer first.

## Cross-references

- Rule 16 (`16-yolo-threshold-and-recovery.md`) — `state.vscdb` lives in the
  same `~/.vscode/` (Mac) or `~/.vscode-server/` (Remote-SSH) tree. See
  Rule 16's 2026-05-07 addendum for the dual-path issue.
- Rule 25 (`25-mac-side-cline-tab-die-chrome-discard.md`) — different layer
  entirely; do NOT conflate with this rule despite the overlapping
  "stops working" symptom.
- Rule 17 (`00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds.md`) —
  the dispatch-subagent-first habit is what broke this incident open. The
  first-pass solo diagnosis (Chrome) was wrong; the subagent re-check found
  the manifest phantom in 4 minutes.

## Last updated

2026-05-07 — initial rule. Source incident: VS Code "Cline Artemis" window
"No remote extension installed to resolve ssh-remote" with downstream "stops
working until I scroll" symptom. Phantom entries: ms-vscode-remote.remote-ssh
v0.120.0, v0.122.0 (duplicate row), and remote-ssh-edit v0.87.0 — all three
had `location=""` and `exists=False`. Fix took 3 minutes once correctly
diagnosed; 1+ hour was burned chasing the wrong layer first.

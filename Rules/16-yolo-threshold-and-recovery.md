# YOLO Threshold + Tool-Failure Recovery

## Why this rule exists

YOLO learner DB at `~/Documents/Cline/yolo_learner/yolo_trips.sqlite` showed **272 trips in 30 days** of "[YOLO MODE] Task failed: Too many consecutive mistakes (3)". Each one kills a Cline task mid-work. Two root causes (2026-05-03 post-mortem):

1. **The threshold was the default of 3.** Cline's `maxConsecutiveMistakes` global setting was never written, so the extension fell back to its built-in default of 3. Three strikes is brutally tight when one of the failures is a tool wall hit (rule 95) that wasn't predictable.
2. **The dominant trip pattern is `timeout > no-tool-use > no-tool-use`** (97 of all triples). The 30-second tool wall fires once, the model emits prose explaining the timeout instead of calling another tool, prose again → game over.

## Fix shipped 2026-05-03

**`maxConsecutiveMistakes` bumped from 3 → 10** in Cline's `globalState` (state.vscdb on this Mac). Verified with:

```sh
sqlite3 -cmd ".timeout 8000" \
  "/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb" \
  "SELECT value FROM ItemTable WHERE key='maxConsecutiveMistakes';"
# → 10
```

This takes effect on the next VS Code reload (or on every newly-launched Cline window). It does NOT change behavior of already-running tasks until they're restarted.

If the YOLO learner ever shows the trip count climbing again at 10, the next move is bumping to 20 — not lowering the bar of recovery. Premature task termination is much more expensive than "model takes 6 turns to figure out a hard recovery."

## What "consecutive mistake" actually means

From reading the Cline 3.82 extension source:

- Every tool handler calls `taskState.consecutiveMistakeCount++` when it hits a problem (missing required parameter, `replace_in_file` SEARCH didn't match, write to a forbidden path, the model emitted no tool calls, etc.)
- Every successful tool call calls `taskState.consecutiveMistakeCount = 0`.
- The kill check is `if (consecutiveMistakeCount >= maxConsecutiveMistakes) { fail }`.
- "no-tool-use" specifically fires when the model produces an assistant turn that contains zero tool calls. The system then sends `Hr.noToolsUsed(...)` reminding the model and increments the counter.

So a single tool flake plus two prose-only follow-ups is enough at threshold 3, but at threshold 10 the model has real room to run discovery before the floor falls out.

## What I (Cline) MUST do when a tool fails

The threshold bump is the floor, not the ceiling. The actual behavior rules from rule 95 + rule 99 still apply, just with breathing room:

1. **A tool failed → next action MUST be a tool call, not prose.** No "Let me look into this..." paragraphs. Either:
   - call a different tool that gathers info to recover, OR
   - call `attempt_completion` with what's known so far, OR
   - call `ask_followup_question` (or in YOLO mode, just continue with discovery tools).
2. **Same tool failed twice in a row → change approach on the third attempt.** Per rule 99 meta-rule. The threshold bump doesn't authorize three identical retries — it just keeps an honest discovery loop from being killed.
3. **30s timeout on `execute_command` → switch to scp-script + nohup pattern.** Rule 95 covers this. Don't retry the same command synchronously.
4. **API overloaded twice → idle, don't burn the budget.** Per rule 99.

## Cross-references

- Rule 95: `95-cline-30s-tool-wall-and-remote-long-running-work.md` — the pattern that produces the timeout half of the dominant triple.
- Rule 99: `99-yolo-prevention-learned.md` — auto-generated playbook per failure category, refreshed every 30 min by the YOLO learner.
- Rule 98: `98-edit-discipline.md` — keeps the conversation small enough that recovery loops don't OOM the ext-host.

## 2026-05-07 addendum — there are TWO `state.vscdb` paths to keep in sync

The 3→10 bump per the original rule is per-machine **AND per-Cline-runtime**. On Artemis specifically, the same user account can have TWO Cline state databases:

| Runtime | state.vscdb path | When used |
|---|---|---|
| **VS Code Remote-SSH** (you connect from a local Mac VS Code via SSH to artemis) | `~/.vscode-server/data/User/globalStorage/state.vscdb` | Local VS Code on Mac → ssh-remote+artemis workspace |
| **code-server (browser)** | `~/.local/share/code-server/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb` | Chrome cline-tempe-N tab opening `https://emsuniversity.com/emtskills/cline-tempe*` |

**They are independent databases.** Setting `maxConsecutiveMistakes=10` in one does not affect the other. A user can run BOTH runtimes in parallel — switching between local VS Code and Chrome tabs targeting the same Artemis box — and end up with the threshold applied in only one of the two paths.

Symptom of this gap: a Cline session you opened via VS Code Remote-SSH yolos at the default 3 even though Mac and the Chrome cline-tempe tabs both have the bump. (This was the live failure on 2026-05-07.)

### The fix is automated

`/Users/rubenmajor/Documents/Cline/cline_settings_apply.sh` (the canonical settings importer that runs hourly via the cline-handoff-relay cron on Artemis) was patched on 2026-05-07 to:
1. Try BOTH paths in priority order (`~/.vscode-server/...` first, `~/.local/share/code-server/...` fallback).
2. Apply to ALL state.vscdb files that exist with an `ItemTable` (so both runtimes get the same settings).
3. Use `INSERT OR REPLACE` instead of `UPDATE` (works even when the key never existed in this DB).
4. Skip gracefully when `ItemTable` doesn't yet exist (Cline hasn't initialized that runtime — script logs and waits for next cron tick).

The keys it propagates from `~/Documents/Cline/Rules/cline_settings.json`:
- `maxConsecutiveMistakes` (currently `"10"`)
- `useAutoCondense` (currently `"true"`)
- `autoApprovalSettings` (auto-approve config blob)

Mac is the authoritative source. The cron runs `git pull` first to get the latest cline_settings.json from Mac, then applies to whichever Artemis state.vscdb files exist.

### Bootstrapping a fresh VS Code Remote-SSH connection on Artemis

When you first open a VS Code Remote-SSH workspace on Artemis (after vscode-server is freshly installed), `~/.vscode-server/data/User/globalStorage/state.vscdb` is 0 bytes — Cline hasn't written its first global-state value yet, so `ItemTable` doesn't exist. The apply script correctly skips this DB until `ItemTable` is created. You don't need to manually bootstrap it; ItemTable gets created as soon as Cline performs its first state write (any tool call, any setting save). Within the next hourly cron run after that, the threshold gets bumped automatically.

If you need it bumped RIGHT NOW (don't want to wait an hour for the cron):
```sh
ssh artemis "bash ~/Documents/Cline/cline_settings_apply.sh"
```
Re-run after Cline has initialized ItemTable.

### When this rule does NOT apply

- Pure Mac VS Code (no Remote-SSH). Single state.vscdb at `~/Library/Application Support/Code/User/globalStorage/state.vscdb`.
- WOPR-side code (different box entirely; no Cline runtime on WOPR by design).
- Any new Cline-runtime path that ships in the future. Append it to the table above + add it to `DB_CANDIDATES` in `cline_settings_apply.sh`.

### Cross-reference

- Rule 26 (`26-phantom-vscode-extension-manifest.md`) — the failure that exposed this dual-path gap was a phantom Remote-SSH manifest entry, which prevented VS Code from ever connecting to Artemis and creating the `~/.vscode-server/...` state.vscdb in the first place.

## 2026-05-08 addendum — Artemis runs 9 code-server instances, each with its own state.vscdb

The 2026-05-07 dual-path patch covered VS Code Remote-SSH (`~/.vscode-server/...`) and the legacy code-server path (`~/.local/share/code-server/...`). It missed a third class: **the 8 code-server-multi@N instances** (services `code-server-multi@1` through `@8`) that Artemis runs in parallel for tab distribution per rule 24.

Each multi-instance has its own user-data-dir at `~/.local/share/code-server-N/`. Each instance's Cline state lives at:

```
~/.local/share/code-server-N/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb
```

These are NOT shared with the main instance — only the `tasks/` directory is symlinked to `~/.local/share/cline-tasks-shared` (so task history is unified). The settings DB is per-instance.

**Symptom of the gap:** open a tab on `https://emsuniversity.com/emtskills/cline-tempe-N/` (any N=1..8) and Cline runs with the **default `maxConsecutiveMistakes=3`** because `state.vscdb` doesn't exist for that instance and the apply script never targeted it. Per rule 24, your tabs are round-robin'd across all 9 instances → 8 out of 9 tabs run at threshold 3. Result: dominant `no-tool-use > no-tool-use > no-tool-use` triple, ~80% of recent YOLO trips on Artemis.

**The fix shipped 2026-05-08:**
1. Bootstrapped each missing multi-instance `state.vscdb` by `cp`-ing the canonical main-instance file (size 12288 bytes, has ItemTable with the three keys).
2. Patched `cline_settings_apply.sh::DB_CANDIDATES` to include all 8 multi-instance paths so the hourly cron keeps them in sync going forward.
3. Verified: re-running the apply script now reports `unchanged` for all 9 DBs (settings already correct on disk).

**Detection for next agent:** when Mac says threshold=10 but Artemis is still YOLO-tripping, run:
```sh
ssh artemis 'for i in "" 1 2 3 4 5 6 7 8; do f=~/.local/share/code-server${i:+-$i}/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb; if [ -f "$f" ]; then val=$(sqlite3 "$f" "SELECT value FROM ItemTable WHERE key=\"maxConsecutiveMistakes\";" 2>/dev/null); echo "inst ${i:-main}: maxConsecutiveMistakes=$val"; else echo "inst ${i:-main}: MISSING"; fi; done'
```
If ANY instance shows MISSING or a value other than 10, that instance needs the bootstrap.

**When a new code-server-multi@N instance is added** (e.g. scaling past 9), append its `state.vscdb` path to `DB_CANDIDATES` in `~/Documents/Cline/cline_settings_apply.sh` AND bootstrap the file by copying from the main instance.

## Last updated

2026-05-08 — multi-instance addendum (code-server-multi@1..8). Source incident: 8 of 9 Artemis instances running with default threshold=3, dominant `no-tool-use` triple, "lots of YOLOs on Cline Artemis." Bootstrapped all 8 missing state.vscdb files + patched cline_settings_apply.sh to keep them synced.

2026-05-07 — added dual-state.vscdb-path addendum + cline_settings_apply.sh patch documentation. Source incident: VS Code Remote-SSH connection to Artemis, fresh state.vscdb 0 bytes, original apply script targeting only the legacy code-server path missed it entirely.

2026-05-03 11:43 PT — initial rule. Source incident: 272 cumulative YOLO trips, top triple = `timeout > no-tool-use > no-tool-use` (97 hits). Threshold bumped 3→10 in Cline globalState.

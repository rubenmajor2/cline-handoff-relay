# Cline Extension Host OOM — Why It Happens, How It's Caught

## The mechanism in plain terms

Every active Cline window is one OS process (a Node.js "ext-host") that holds the entire conversation in V8 memory. The conversation is two files on disk per task:

- `api_conversation_history.json` — the canonical message history that Cline replays to Anthropic on every turn.
- `ui_messages.json` — the rendered chat-bubble log shown to the user. Bigger than #1 because it includes tool-call snapshots, screenshots, full file contents, etc.

When you reload a Cline window or VS Code resumes after a Mac reboot, the ext-host **parses the entire ui_messages.json into V8 memory in one shot.** It does not stream. It does not lazy-load. A 30 MB ui_messages.json becomes a 1.5–3 GB V8 heap because the parsed JS objects are 30–100x the on-disk byte size.

V8's heap cap is 16 GB (set by `--max-old-space-size=16384` on Cline-Tempe / Artemis). When parse-on-resume crosses that, the process is killed by V8 with a "JavaScript heap out of memory" error. The Cline UI for that window goes dark — the host machine and other windows are unaffected.

## Why this isn't a Cline bug per se

The 16 GB cap is generous. The bloat is coming from the conversation actually getting that large. Common causes:

1. **`read_file` on a screenshot / PDF / video.** A 5 MB image is base64-encoded into the message stream as a 7 MB string, but during parse it inflates to ~30 MB of V8 string objects. Three screenshots = 90 MB. Six = 180 MB. Etc.
2. **`read_file` on a large source file** that gets quoted in full into the message history. A 200 KB file with a long history of partial-read iterations adds up.
3. **`replace_in_file` SEARCH/REPLACE with serialized blobs** — copy-pasting a minified JS bundle, a base64 image, or a 3000-line PHP route into the SEARCH section.
4. **Long Cline tasks that span days** — every tool call adds to the log forever.
5. **Many "remember everything" tool result blocks** — Claude and Cline both retain full outputs unless explicitly truncated.

This is what `.clinerules/98-edit-discipline.md` is supposed to enforce on the AI side: don't include big blobs in messages, don't `read_file` images for "vibes," summarize tool output instead of pasting it raw.

## How the watchdog stack catches it

See `96-cline-window-discipline.md` for the layered defense diagram. The critical points:

| Defense layer | Lives at | Catches |
|---|---|---|
| V8 hard cap (16 GB) | `--max-old-space-size=16384` arg on each ext-host | Real heap blowout — process dies cleanly. |
| Heap-pressure early warning | `~/bin/cline-heap-pressure.sh` */1 min | RSS jumped >2 GB in 60s → alert email + log. |
| CPU/RSS sustained renicer | `~/bin/exthost-watchdog.sh` | RSS sustained >12 GB OR CPU >70% → renice +15. |
| systemd cgroup MemoryMax | `code-server@emsuserver.service` drop-in | Whole code-server tree limited to 100 GB. |
| Bloat preventer | `~/bin/cline-task-archiver.sh` */5 min | Moves any `ui_messages.json` >2 MB idle >10 min into `tasks-archive/`. |
| Repeat-offender tagger | `~/bin/cline-oom-tagger.sh` */5 min | Detects OOM-killed PIDs and tags the originating task in DB. |

The archiver (`cline-task-archiver.sh`) is the actual root-cause mitigation. The others are damage control.

## What you (Ruben) see vs. what happens under the hood

- "My Cline window went dark / froze." → Ext-host for that window probably hit the 16 GB cap. Reload the window to spawn a fresh one. The task folder on disk is fine; Cline will reparse `api_conversation_history.json` (the smaller file) and resume cleanly. The chat bubbles up to the archive point are visible; new turns from there forward are recorded fresh.
- "I got an email about a balloon." → Heap-pressure caught a fast jump. No action needed unless you also see the window go dark, in which case → reload that window.
- "I got a STORM digest email." → 3+ ext-hosts ballooned in 5 min. Almost certainly synchronized parse-on-resume after a Mac reboot or WireGuard blip. Wait 5 min, reload the affected windows. See `96-cline-window-discipline.md` § W3.
- "Cline-Tempe is unreachable." → Almost never the host itself. Check `ssh artemis "uptime"` first. If that works, the issue is Cline-side (one window's ext-host) not Artemis-side.

## Last updated

2026-05-02 — initial rule. Codified during the post-mortem of the Mac kernel panic + Artemis 12-PID balloon storm at 19:14-19:22 PT.

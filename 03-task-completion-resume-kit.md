# Task Completion Format — the "Resume Kit"

## Why this rule exists

Ruben keeps 15–20 VS Code windows open at once because each one holds a Cline thread he might need to scroll back and reference later. That's consuming 8–12 GB of RAM just for scroll-back. We confirmed (2026-04-22) that all 681+ past Cline tasks are already saved to disk at `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/<task_id>/`, so the raw history is never actually at risk of being lost — what's at risk is **the context needed to pick up where we left off**.

This rule fixes that. Every `attempt_completion` call must produce a message that is self-contained enough for Ruben to close the window, and months later paste "pick up task XYZ from where we left off" into a fresh Cline and have it work without him re-reading the old thread.

## The required format for `attempt_completion.result`

When a task is done and we're about to call `attempt_completion`, the `result` field must follow this structure. Use this EVERY time — not just when it seems "important." Ruben decides what's important later; our job is to make every thread resumable.

```
TASK #<task_id> — <3–7 word topic>

WHAT WE WERE DOING
<1–2 sentences in plain voice. What was the goal. What problem triggered it.>

WHAT WE ACTUALLY DID
- <concrete action 1, with file paths / PIDs / IDs where applicable>
- <concrete action 2>
- <concrete action 3>
(Keep to 3–7 bullets. No fluff. Actions, not narration.)

CURRENT STATE
<1–3 lines: what's now true that wasn't before. "Load avg is down to 15, 4 GB free, DockHelper killed." Or "Ticket 4127 resolved, student reinstated in Moodle." Or "Schema drafted but not deployed." Be specific.>

TO RESUME THIS TASK LATER
Paste this into a fresh Cline: "pick up task #<task_id> from where we left off — <one-line context cue>"
Then add whatever new instruction you have.

OPEN THREADS / NEXT MOVES (if any)
- <thing we discussed but didn't do>
- <thing that still needs review>

FILES TOUCHED (if any)
- <absolute path>
- <absolute path>
```

The task_id comes from the current Cline thread. To get it, list the newest folder in `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/` — the most recent directory name IS the task_id. If uncertain, show the top 3 so Ruben can confirm.

## Also: log it to the local ledger

After writing the `attempt_completion` result, also append a one-line summary to `~/Documents/Cline/cline_task_ledger.md` so Ruben has a greppable index. Format:

```
- 2026-04-22 13:45 | #1776877985355 | topic here | STATUS | quick context cue
```

STATUS is one of: `done`, `open` (resumable), `blocked`, `abandoned`.

This uses `execute_command` with an appended echo before the `attempt_completion`. It's cheap — a single shell line, no files to read, no risk of breaking anything.

## The "close or continue?" prompt

At the end of a task where it's not obvious whether Ruben considers it done, the LAST line before `attempt_completion` (inside the result) should be:

> Want me to mark this one `done` in the ledger and you can close the window, or leave it `open` so you can resume later?

This gives Ruben the agency to pick. Do NOT auto-decide on tasks that involve code changes pending review, anything tagged for Jon/Vicky, or anything where Ruben said "I'll think about it."

## When this rule does NOT apply

- Pure Q&A ("what's the capital of X", "explain this code"). No ledger entry needed. A one-line completion is fine.
- Read-only diagnostics where nothing changed and the answer was delivered in full in the chat body. Still OK to skip the formal resume kit if the result parameter itself is short and complete.
- The task was aborted by Ruben and he said "never mind" — mark it `abandoned` in the ledger, don't write a long resume kit.

## Why the format matters (for future-me reading this rule)

- **TASK #<id> header** makes the literal copy-paste trivial: "pick up task #1776877985355 from where we left off." Cline (via the future MCP tool, once built) or Ruben's memory can look up the disk folder by that ID.
- **WHAT WE WERE DOING** — sets goal frame so the next session doesn't replay the whole discovery arc.
- **WHAT WE ACTUALLY DID** — the action record. Not tool calls, not narration, just outcomes with IDs/paths.
- **CURRENT STATE** — the delta. This is what the next agent needs to not redo work.
- **TO RESUME** — the literal phrase to paste. Make it one line.
- **OPEN THREADS** — catches the "oh yeah we also meant to..." items that would otherwise be lost.
- **FILES TOUCHED** — lets Ruben or the next agent immediately open the right files without searching.

## Future enhancement (planned, not yet built)

Phase 2 of this work (designed 2026-04-22, not yet scheduled) is a WOPR-side mirror of the task folder plus a UI tab on `ruben_executor_live.php` and MCP tools `search_cline_tasks` / `resume_cline_task(id)`. When that ships, this rule gets an addendum: "call `resume_cline_task(<id>)` first when Ruben says 'pick up task #X' — it returns a Claude-synthesized summary so you don't have to replay 80 KB of raw JSON." For now, rely on the local ledger + disk folder.

# 138 — "Star this task" = the Ruben Open Tasks tracker, not a Cline-UI toggle

Source: 2026-06-05 Ruben directive. After a build, Ruben said "star this task." Cline wrongly assumed that meant the native Cline sidebar pin (a UI-only toggle with no tool). Ruben corrected: there is a real, server-side starred-task tracker at `ruben_open_tasks.php?status=starred`, and the capability must be documented so any future window knows it exists and how to use it.

## What "star a task" actually means

There is a MasterAdmin portal page — **`routes/ruben_open_tasks.php`** ("📋 Open Cline Tasks", a tab on `ruben_executor_live`) — that mirrors the Mac ledger (`~/Documents/Cline/cline_task_ledger.md` → pushed to `data/cline_task_ledger.json`) into a browser view. It has a **"⭐ Important"** status tab (`?status=starred`). Starring a task pins it under that tab so Ruben can find the notable threads.

Canonical URL pattern (what Ruben pasted):
```
https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php?q=<search>&sort=recent&per_page=25&status=starred
```

## The data model (schema verified 2026-06-05, rule 17)

- **Stars table:** `admin_portal.ruben_task_stars (task_id, starred, note, starred_by, starred_at)`. `task_id` is the **normalized** task id (see `normalize_task_id()` in `ruben_open_tasks.php`: trim, strip leading `#`, collapse whitespace, lowercase). `starred=1` means pinned.
- **Toggle endpoint:** `api/ruben_open_tasks_action.php`, `action=toggle_star`, body `{ task_id, starred: 1|0, note? }`. It does an `INSERT ... ON DUPLICATE KEY UPDATE starred=VALUES(starred)` when starring, `UPDATE ... SET starred=0` when unstarring.
- **Status overrides** (open/done/blocked/abandoned) live in a separate table `cline_task_status_overrides` via the same endpoint's `mark_done`/`bring_back` actions — do not confuse with stars.

## How to star a task as Cline (when Ruben says "star this task")

1. Determine the task id. For the CURRENT task it is the Cline task id (the numeric id in environment_details / task resumption banner). Normalize it (strip `#`, lowercase).
2. Star it by writing the row directly (DB is the source of truth; the endpoint is auth-gated to a MasterAdmin browser session):
   ```sql
   INSERT INTO ruben_task_stars (task_id, starred, note, starred_by, starred_at)
   VALUES ('<normalized_task_id>', 1, '<one-line why>', 'cline', NOW())
   ON DUPLICATE KEY UPDATE starred=1, note=VALUES(note), starred_by='cline', starred_at=NOW();
   ```
   Run it through the emsu-operations MCP (`ssh_command` with the mysql client, or a small PHP one-liner that calls `db()` so creds come from bootstrap — the `emsuserver` shell user is NOT granted direct mysql, so prefer a PHP harness under `routes/` that `require_once '../bootstrap.php'` then runs the prepared statement, exactly like `_cline_test_menu.php` does).
3. Confirm it shows under `?status=starred` (the `$counts['starred']` tab badge increments).

## Do NOT

- Do NOT tell Ruben "star it yourself in the Cline UI" — that's a different, UI-only feature and is not what he means. He means the portal tracker.
- Do NOT write to `ruben_task_stars` with a raw, un-normalized `#1779...` id — the page keys on the normalized form, so an un-normalized row won't match and won't render.
- Do NOT confuse starring (importance pin) with status (open/done) — they are separate tables/actions.

## Self-check

If Ruben says "star this", "mark this important", "pin this task": the action is a row in `ruben_task_stars` keyed by the normalized task id, verifiable at `ruben_open_tasks.php?status=starred`. Not a Cline sidebar toggle.

## Cross-references

- `routes/ruben_open_tasks.php` — the tracker page (starred tab, normalize_task_id, ledger source)
- `api/ruben_open_tasks_action.php` — toggle_star / mark_done / bring_back / auto_clear_done actions
- `routes/_cline_test_menu.php` — pattern for a PHP harness that mints a session / runs portal-DB queries via bootstrap
- `.clinerules/07` — task ledger discipline (the ledger that feeds this page)
- `.clinerules/91` — every completion needs a pickup prompt (the ledger rows come from these)
- `.clinerules/17` — schema verified before write

## Last updated

2026-06-05 — initial. Source: Ruben "star this task" → Cline assumed Cline-UI pin → Ruben pointed at ruben_open_tasks.php?status=starred and said put it in the MCP/clinerules. This rule is the durable Cline-side definition.

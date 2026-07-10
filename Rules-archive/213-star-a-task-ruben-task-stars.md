# 137 — "Star this task" = INSERT into admin_portal.ruben_task_stars (it's a real system, not just a Cline UI button)

Source: 2026-06-03 Ruben directive. Cline said "star this task" was only a Cline-UI action it couldn't trigger. WRONG — there is a real starred-tasks system in the RUBEN portal, and Cline can star a task itself via SQL. Ruben: "huh, yes it is. You forgot, add to cline rules."

## The bright-line rule

When Ruben says **"star this task" / "mark this important" / "star it"**, Cline MUST star it in the database, not punt to the UI. Stars live in `admin_portal.ruben_task_stars` and surface at:
`https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php?status=starred` (the ⭐ Important tab).

## How to star (the exact action)

```sql
INSERT INTO ruben_task_stars (task_id, starred, note, starred_by)
VALUES ('<task_id_or_slug>', 1, '<one-line why + where the recovery/handoff doc lives>', 'cline')
ON DUPLICATE KEY UPDATE starred=1, note=VALUES(note), updated_at=NOW();
```

Run it via the `mysql` MCP (`execute_query`) or emsu-operations. Table schema: `task_id` (varchar PK, normalized = lowercase, leading `#` stripped), `starred` tinyint, `note` varchar(500), `starred_at`, `starred_by` (default 'cline'), `updated_at`.

### task_id conventions
- The portal keys stars by **normalized task_id**: `strtolower(ltrim(task_id, '#'))`. Match the ledger row's task_id when one exists (numeric like `1779186100000` or a slug like `cline_artemis_70b_offload_recovery_2026-06-03`).
- If the current Cline task has a numeric task_id (from environment_details / [TASK RESUMPTION]), use that so the star lands on the exact ledger card. If it's a multi-window saga with no single numeric id, use a descriptive `cline_<topic>_<date>` slug (orphan stars still show in the ⭐ Important tab — the portal appends orphan stars to that view per the 2026-05-27 fix).
- To UNSTAR: `UPDATE ruben_task_stars SET starred=0 WHERE task_id='<id>'` (or just don't insert).

## Always include a useful note

The `note` is shown on hover in the portal. Put: one line of why it's important + WHERE the durable context lives (handoff doc path, fleet_inventory row, memory entity). So the star is a pointer to the full state, not just a flag.

## Self-check

If Ruben says "star this" and Cline's response is "that's a UI button I can't press" — that's this rule violation. The correct move is an `INSERT ... ON DUPLICATE KEY UPDATE` into `ruben_task_stars`, then confirm it shows in the ⭐ Important tab.

## Cross-references

- ruben_open_tasks.php (the ⭐ Important tab, status=starred filter; stars overlay onto cline_task_ledger.json rows)
- .clinerules/07 (cline_task_ledger) — stars decorate ledger rows
- .clinerules/91 (pickup prompts) — the star note should point at the pickup/handoff doc

## Last updated

2026-06-03 — initial. Source: Ruben "star this task" → Cline wrongly claimed it couldn't. Stars = admin_portal.ruben_task_stars, surfaced at ruben_open_tasks.php?status=starred.

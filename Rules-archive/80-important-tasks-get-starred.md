# 80 — When Ruben says a task is "important," star it on ruben_open_tasks.php

Permanent rule. Workspace-scoped. Source: 2026-05-15 — Ruben directive verbatim
during task #1778525737952 (CAPCE Round 2 reply):

> *"I would like for you to create a link or important tasks like this one. In
> fact I would like to be able to star a task to be able to be held like I
> would hold this task inside of that area. But also you could sort by
> favorited or important tasks. The idea here is that this way I don't lose
> track of this particular task and other like this. Additionally I would like
> to make this a cline rule that if I tell you that a task is important that
> it gets filed like this. So this will be your first important task."*

## The bright-line rule

**When Ruben says a task is "important," "critical," "high priority," "don't
lose this," "starred," or any close variant — the current Cline task MUST be
starred on `https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php`
in the same turn. No clarifying question, no "would you like me to?" — just
do it, then mention it in the wrap-up.**

This is rule-29 act-on-confidence-tier territory: reversible (one SQL flip),
small blast (single row), high confidence (Ruben said it), and the cost of
forgetting (Ruben loses track of a task he flagged) is much higher than the
cost of star-when-borderline.

## Signal phrases that trigger the star

Any of these, paraphrased or verbatim, mean STAR THE TASK:

- "this is an important task" / "this one is important"
- "make this important" / "mark this important"
- "star this" / "star this task" / "favorite this"
- "don't lose this" / "don't forget this one"
- "this is critical" / "this is high priority" / "high P"
- "I want to come back to this" / "keep this on my radar"
- "this is one I really care about" / "this is a key task"
- "P0 task" / "make this P0" (in addition to filing the orchestrator idea
  at P0 if applicable per .clinerules/56)

If Ruben gives the task a project name and asks you to "save" or "track"
it specifically, that also counts.

## How to star a task (the mechanic)

There is a UI button (a hollow ⭐ on each task card) on the Open Tasks page,
but Cline acts via the action API directly so the user doesn't have to click:

```bash
TASK_ID="<task id from current Cline window, digits only, no #>"
NOTE="<one-line reason this is important, plain English>"
# Insert/upsert via the existing emsu-operations MCP execute_query tool.
```

Concrete SQL via MCP `execute_query`:

```sql
INSERT INTO ruben_task_stars (task_id, starred, note, starred_by)
VALUES ('<task_id_norm>', 1, '<note>', 'cline')
ON DUPLICATE KEY UPDATE starred=1, note=VALUES(note), starred_at=NOW();
```

The `task_id_norm` is the normalized form per .clinerules/07: lowercase, no `#`
prefix, no whitespace. For numeric Cline thread IDs it's just the digits.

After starring, the task appears under the ⭐ Important filter pill at the
top-left of https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php
and shows with a gold border + yellow background on its card.

## How to UN-star (if Ruben says it's no longer important)

```sql
UPDATE ruben_task_stars SET starred = 0 WHERE task_id = '<task_id_norm>';
```

Or via the UI button (filled ⭐ on a starred card toggles back to hollow).

## When to mention it to Ruben

In the same `attempt_completion` where the work was done, add a line to the
end of the body:

> ⭐ Starred this task as important per your directive. Filter pill on Open Tasks:
> https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php?status=starred

Do NOT ask "want me to star this?" — that violates rule 67 (act autonomously
before escalation) and rule 29 (high-confidence + reversible + small = ACT).

## What this rule does NOT do

- Does NOT replace `orchestrator_ideas` filing for systemic patterns
  (per .clinerules/42). Star + idea can both fire.
- Does NOT auto-star every task — only when Ruben uses an explicit signal phrase.
- Does NOT affect status (open/done/blocked). A task can be both starred AND done.
  Starred filter shows starred tasks regardless of status. To clear a starred
  done task from the active view, unstar it OR rely on the Open filter (which
  excludes done by default).

## Anti-patterns that violate this rule

- ❌ Asking "would you like me to star this?" when Ruben already said important
- ❌ Mentioning the star in wrap-up but not actually inserting the SQL row
- ❌ Starring tasks Ruben didn't flag (creates noise — only star when triggered)
- ❌ Forgetting to mention the star in attempt_completion (then Ruben can't verify)
- ❌ Trying to use a star to override status (use mark_done / bring_back actions
  for status changes — stars are an orthogonal dimension)

## Database schema (reference)

```sql
CREATE TABLE ruben_task_stars (
  task_id     VARCHAR(120) NOT NULL PRIMARY KEY,  -- normalized: lowercase, no #
  starred     TINYINT(1)   NOT NULL DEFAULT 1,
  note        VARCHAR(500) DEFAULT NULL,           -- one-line reason
  starred_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  starred_by  VARCHAR(64)  DEFAULT 'cline',
  updated_at  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

UI rendering and filter logic lives in `routes/ruben_open_tasks.php`. Toggle
action endpoint at `api/ruben_open_tasks_action.php` (action: `toggle_star`).

## Cross-references

- .clinerules/07 — task_id discipline (no composite IDs, normalize for stars)
- .clinerules/29 — agents act on confidence tier (this is the act-don't-ask basis)
- .clinerules/42 — proactive systemic solutions (star ≠ idea, both can fire)
- .clinerules/47 — full URLs in human-facing output
- .clinerules/56 — offer ideas when implied (star is the per-task version)
- .clinerules/67 — agents exhaust autonomy before escalation
- .clinerules/78 — idea mentions need Y/N + explanation + recommendation
  (stars are simpler: just announce that you starred + give the link)

## First starred task

Task #1778525737952 — CAPCE Round 2 reply to Jay Scott. Starred 2026-05-15
00:42 PT by Cline per Ruben directive in the source incident.

## Last updated

2026-05-15 — initial rule. Database schema + route patch + action API +
this clinerule all shipped same session. Filter pill live at
https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php?status=starred

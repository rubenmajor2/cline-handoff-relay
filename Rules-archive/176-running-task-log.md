# 81 — Running task log: log milestones to WOPR so dead tasks become resumable

Permanent rule. Workspace-scoped. Source: 2026-05-15 task #1778525737952 — Ruben
directive verbatim: *"whenever you are working a task in a new task window,
keep a running log of important information so that a future agent can pick
up right where you left off."* Approved Y per rule 38 (Ruben-asks =
autonomous tier minimum).

## Why this rule exists (the gap)

Rule 03 (Resume Kit) only fires at `attempt_completion`. The YOLO learner
(rule 99) recorded ~440 trips in the last 30 days — every one of those is a
task that died BEFORE `attempt_completion` could write the Resume Kit.
Combined with ext-host OOMs (rule 97) and the Mac jetsam cliff (rule 29),
that's hundreds of tasks per month with zero handoff to a future agent.

This rule closes that gap with **incremental** logging: every meaningful
milestone gets written to WOPR mid-task, so even when the task dies in the
middle of a turn, a future agent can pick up the exact progress trail via
the Open Tasks portal.

## The bright-line rule

**When working any non-trivial task in a Cline window, call
`log_task_progress` at every meaningful milestone — NOT every tool call.**

Default trigger list (call `log_task_progress` when ANY of these happens):

| milestone_type | When to fire |
|---|---|
| `started` | First substantive turn after task open (after Ruben's framing settles) |
| `file_deployed` | Successful `safe_deploy_file`, `write_to_file`, `replace_in_file` against a production path |
| `idea_filed` | After inserting an `orchestrator_ideas` row |
| `qcard_filed` | After inserting a `ruben_questions` row (rule 12) |
| `ticket_action` | Created / updated / closed a ticket row |
| `mcp_destructive` | Any DB UPDATE/DELETE/INSERT touching real student/business data |
| `direction_change` | Ruben pivoted ("actually do X instead") |
| `blocker` | Hit sudoers wall, tool wall, missing creds, Anthropic 402, etc. |
| `decision` | Picked option A over B with reasoning (rule 53 Signal 1 + 3 cases) |
| `starred` | Applied star per rule 80 |
| `completion_summary` | Right before `attempt_completion` (back-fill the Resume Kit) |
| `note` | Anything else that future-me will want to know |

**Skip these (noise — would bloat the log):**
- `read_file`, `list_files`, `search_files`
- `describe_table`, `list_tables`
- Schema reconnaissance / discovery greps
- ssh diagnostic commands (uptime, ps, ls, etc.)
- Status checks that just confirm state

## The MCP tools (emsu-operations)

```
log_task_progress(
  task_id: "1778525737952",          // or kebab-slug, no leading #
  milestone_type: "file_deployed",
  note: "Deployed cron_cline_log_archive.php to /var/www/emtskills/cron/",
  refs_json: '{"file":"/var/www/emtskills/cron/cron_cline_log_archive.php","sha256":"..."}'  // optional
)

get_task_running_log(
  task_id: "1778525737952",
  include_archived: false,           // default false (hot rows only)
  limit: 100                          // default 100, max 500
)
```

Per rule 32 — use these dedicated wrappers, not raw SQL.

## The architecture (3 layers)

| Layer | Location | Purpose |
|---|---|---|
| Hot | `admin_portal.cline_task_running_log` | Active tasks <30d, fast portal queries |
| Cold | `/home/emsuserver/cold_storage/cline_logs/YYYY/MM/<slug>.json.gz` | Filesystem gzip ~10x smaller than uncompressed |
| Pointer | `cline_task_running_log.archived_path` | Hot summary row points to cold file for retrieval |

Schema:
```sql
CREATE TABLE cline_task_running_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  task_id VARCHAR(120) NOT NULL,
  milestone_type ENUM('started','file_deployed','idea_filed','qcard_filed',
                      'ticket_action','mcp_destructive','direction_change',
                      'blocker','decision','starred','completion_summary',
                      'note','archived') NOT NULL,
  note VARCHAR(2000) NOT NULL,
  refs_json JSON NULL,
  source VARCHAR(64) DEFAULT 'cline',
  cline_session_id VARCHAR(120) NULL,
  archived_path VARCHAR(255) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_task_id (task_id, created_at),
  INDEX idx_milestone (milestone_type, created_at),
  INDEX idx_archived (archived_path)
);
```

## How it surfaces on the Open Tasks portal

`https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php` — each
task card with running-log entries shows:

- Blue "📝 Running log" indicator with entry count + last milestone type + first 90 chars of last note
- ▶ "Show full log" disclosure that expands to the full ordered log (up to 100 entries)

Patches in the route are tagged `RULE_81_RUNNING_LOG_OVERLAY` (data load) and
`RULE_81_RUNNING_LOG_CARD` (per-card render).

## How a fresh Cline picks up a task

When Ruben pastes "pick up task #N from where we left off", the FIRST
non-trivial tool call should be:

```
get_task_running_log(task_id: "N")
```

Combined with the on-disk task JSON, you're caught up in ~2 seconds — no
grepping needed, no replaying 80 KB of raw history.

## Auto-backfill from attempt_completion (planned, not yet built)

When this rule's adoption stabilizes, a follow-on hook in `attempt_completion`
will auto-extract bullets from the "WHAT WE ACTUALLY DID" section of the
Resume Kit (rule 03) and back-fill any `log_task_progress` calls the agent
forgot to make mid-task. So even forgetful runs end up with a complete log.

Tracked separately — see orchestrator_ideas slug
`rule81-auto-backfill-from-attempt-completion`.

## Pruning policy (cron_cline_log_archive.php, nightly 03:00 PT)

Three-tier:

| Task state | Age | Action |
|---|---|---|
| open / blocked | <30d | Keep hot, no entry limit |
| open / blocked | >30d | Archive entries older than 30d to cold gzip, keep last 5 in hot |
| done | <30d | Keep hot |
| done | >30d | Archive ALL entries to cold, keep 1 summary row in hot ("Archived N entries to cold storage") |
| abandoned | >7d | Archive ALL immediately, keep 1 summary row |

Soft cap on `/home/emsuserver/cold_storage/cline_logs/` total: 1 GB. If
exceeded, oldest gzips drop first. Heartbeat registered in
`cron_heartbeat_registry` (rule 42 dashboard) at expected interval 86400s,
warn=1.5x, crit=2.5x.

Status resolution: cron joins against `cline_task_status_overrides` (DB)
and `cline_task_ledger.json` (Mac push) — same sources the Open Tasks
portal uses. Defaults to "open" if not found (safe default — keeps the log
visible).

## Hard caps to prevent runaway logs

- 100 entries per task hard cap on `get_task_running_log` retrieval
- 2000 char hard cap on `note` field (truncated server-side)
- 50 KB total per task (enforced by the archive cron when it sees a hot
  row count exceeding policy)

## What this rule does NOT do

- Does NOT bloat Cline conversation context — log is written to WOPR and
  forgotten (rule 98)
- Does NOT bloat MySQL backups — cold tier on filesystem
- Does NOT replace Resume Kit (rule 03) — complementary; Resume Kit fires
  at `attempt_completion`, this fires mid-task
- Does NOT replace task ledger (rule 07) — different surface; ledger is
  task-level high-signal, log is milestone-level
- Does NOT replace HANDOFF_NOTES — HANDOFF is institutional memory, this
  is per-task progress
- Does NOT log reads / discovery noise — bar is "real milestone" only

## Self-check before any attempt_completion

Ask: *"Did I log at least 3-5 milestones during this task?"* If the task
involved deploys, idea filings, Q-cards, or any destructive MCP action and
the running log has fewer than 2 entries, back-fill them now (rule 49 —
offer to do it).

## Cross-references

- Rule 03 — Resume Kit format (this rule complements; Resume Kit at end,
  running log mid-task)
- Rule 07 — task_id discipline (no composites; same normalization applies)
- Rule 22 — executor self-supervision loops (same shape on the agent side)
- Rule 29 — agents act on confidence tier (logging is high-confidence small
  green action — always do it)
- Rule 32 — prefer dedicated MCP wrappers (log_task_progress is one)
- Rule 38 — Ruben-asks = autonomous tier minimum (basis for shipping)
- Rule 42 — proactive systemic solutions (this rule IS one)
- Rule 80 — starring (compatible — star + running log show on the same card)
- Rule 97 — extension host OOM (this rule's survival case)
- Rule 99 — YOLO prevention (running log survives the trips this rule
  documents)

## Source incident

Task #1778525737952 — Ruben asked for this rule directly. Approved Y at
13:46 PT. Shipped phases 1-5 by 14:00 PT same session.

## Last updated

2026-05-15 — initial. Shipped:
- Schema: `cline_task_running_log` table on admin_portal
- Cold storage: `/home/emsuserver/cold_storage/cline_logs/` on WOPR
- MCP tools: `log_task_progress` + `get_task_running_log` in emsu-operations
- Portal: extended `ruben_open_tasks.php` with per-card running-log block
- Cron: `cron_cline_log_archive.php` nightly at 03:00 PT, registered in
  `cron_heartbeat_registry` for rule 42 dashboard visibility
- This rules file

# 274 — Cline noop idempotency gate: call noop_check BEFORE starting work

Source: 2026-07-18 Ruben directive — "is noop actually being used? if not, enable it for efficiency"

## The rule

**Before starting any task that might be a repeat, call `noop_check` (emsu-operations MCP) as your FIRST tool.** If it returns `should_skip: true`, immediately `attempt_completion` with the noop reason. This is the Cline-level equivalent of the server-side `executed_noop` recurrence gate.

## When to call noop_check

Call it on ANY task that matches one or more of:
- Same idea # as a prior task (pass `chain_slug: "idea-NNNNN..."`)
- Same student lookup (pass `task_type: "student_lookup"`, `task_text: "check student 26901FT-14"`)
- Same ticket action (pass `task_type: "ticket_action"`, `task_text: "update ticket 12345"`)
- Same file analysis (pass `task_type: "file_analysis"`, `task_text: "analyze /var/www/.../foo.php"`, `file_paths: ["/var/www/.../foo.php"]`)
- Same code review (pass `task_type: "code_review"`, `task_text: "review PR #123"`)
- Same MCP call (pass `task_type: "mcp_call"`, `task_text: "check_student 26901FT-14"`)

## How to call it

```
use_mcp_tool(server_name="emsu-operations", tool_name="noop_check", arguments={
  "task_type": "<category>",
  "task_text": "<description>",
  "file_paths": ["<path1>", ...],  // optional
  "chain_slug": "<idea-NNNNN...>",  // optional, also checks orchestrator_execution_log
  "context_version": "<sha or version>"  // optional, for cache invalidation
})
```

## Interpreting the result

| Result | Action |
|---|---|
| `should_skip: true`, `reason: "cline_cache_hit"` | `attempt_completion` with "noop: cline_cache_hit (verified: noop_check returned should_skip=true, prior log #N)" |
| `should_skip: true`, `reason: "executor_noop_recent"` | `attempt_completion` with "noop: executor_noop_recent (verified: noop_check returned should_skip=true, prior log #N)" |
| `should_skip: true`, `reason: "executor_completed_recent"` | `attempt_completion` with "noop: executor_completed_recent (verified: noop_check returned should_skip=true, prior log #N)" |
| `should_skip: false` | Proceed with the task normally |

## After completing a task successfully

Call `noop_store` to cache the result so future calls skip:

```
use_mcp_tool(server_name="emsu-operations", tool_name="noop_store", arguments={
  "task_type": "<same as noop_check>",
  "task_text": "<same as noop_check>",
  "file_paths": ["<same as noop_check>"],
  "result_data": "<JSON or text summary of what was done>",
  "context_version": "<same as noop_check>"
})
```

## Why MCP not subagents

Subagents CANNOT use MCP tools (rule 00 — local shell + filesystem only). The noop check needs DB access (`cline_task_noop_cache`, `orchestrator_execution_log`). So it MUST be an MCP tool called from the Cline main window.

## Budget impact

Each skip saves the full task cost ($0.05-$0.50 depending on complexity). At 2,326 server-side noops/day already, the Cline-level noop catches tasks that pass the recurrence hash but still need no action — estimated 30-50% additional savings.

## Cross-references

- Rule 00 — subagents cannot use MCP tools (noop_check must be inline)
- Rule 29 — act on confidence tier (noop_check IS an action, not inaction)
- Rule 91 — pickup prompt required (noop completions need it too)
- RubenExecutor.php line 2791 — planner-level noop(reason) tool (server-side, separate mechanism)

## Source

2026-07-18 — Ruben directive: "is noop actually being used in Cline? if not, enable it for efficiency. It should be leveraging the MCP for noop as well as subagents. But subagents can't use tools so MCP may be better." Verified: subagents cannot use MCP (rule 00). Built `noop_check` + `noop_store` MCP tools in emsu-operations. Fixed planner prompt in RubenExecutor.php line 2791 to teach the planner when to use `noop(reason)`. Idea #18360.

## Last updated

2026-07-18 — initial. Shipped noop_check + noop_store MCP tools, planner prompt fix, this clinerule.
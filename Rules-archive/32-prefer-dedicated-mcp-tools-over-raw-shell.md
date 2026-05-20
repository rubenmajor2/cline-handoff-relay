# 32 — Prefer dedicated MCP wrappers over raw ssh/SQL/training-data recall

Permanent rule. Workspace-scoped. Source incident: 2026-05-08 — Ruben flagged
that "sometimes today it was not consulting the MCP properly and the MCP
servers were all up. So I'm not really sure why the LLM chose to disregard
the MCP when the information was low hanging fruit." This rule exists to
close that gap before the same failure mode recurs tomorrow.

## The bright-line rule

**When a task touches a domain that has dedicated MCP tools, my FIRST tool
call MUST be one of those dedicated wrappers, not `ssh_command`, not
`run_moodle_query`, not `chq1Rz0mcp0execute_query`, not training-data
recall.** Raw shell/SQL is a fallback when the wrapper genuinely doesn't
fit, not the default.

Same shape as rule 17 (default-on subagent dispatch): the bar is "obviously
trivial exception or use the wrapper." Not "judge each case."

## Why this rule exists

Three failure modes converge on the same symptom (agent skips the right
tool):

1. **Tool-name salience drops with 50+ tools loaded.** With ~50 tools in
   `emsu-operations` alone (plus ruben-control, ruben-orchestrator,
   imessage, kaizen, github, etc.), the model pattern-matches against
   recently-seen names instead of scanning the registry. If the task
   wording doesn't trigger a name the model has used in the last few
   turns, it falls back to `ssh_command` or raw SQL.
2. **Training-data shortcut.** The model "knows" Moodle's mdl_user /
   mdl_user_enrolments / mdl_quiz_attempts schema from training. It
   writes a raw SELECT and skips the wrapper. The wrapper would have
   surfaced business logic the SELECT misses (e.g.,
   `check_proctoring_status` includes the SEB+Zoom enforcement reminder;
   `check_moodle_enrollment` includes suspension state; raw SQL doesn't).
3. **One-strike downgrade.** A single tool timeout or host-resolver
   glitch (rule 20) and the model silently downgrades to `ssh_command`
   for the rest of the session. Shell-out always works; the MCP is "in
   memory" marked flaky even after the underlying issue cleared.

All three resolve with the same fix: a hard rule that the dedicated
wrapper is the first move.

## The dedicated-tool-first matrix (EMSU)

If the task touches any of the topics on the left, the FIRST tool call
must be from the right column. Reach for ssh / raw SQL / training only
after the dedicated tool clearly doesn't fit (and document why in
`attempt_completion`).

| Topic | First-move tools (emsu-operations unless noted) |
|---|---|
| Moodle enrollment, course access, suspension, completion | `check_moodle_enrollment` |
| Moodle course content, sections, activities | `list_moodle_course` |
| Adding pages/URLs/quizzes to Moodle | `deploy_moodle_content` |
| Moodle cache (after direct DB writes) | `purge_moodle_cache` |
| Exam integrity, AI violations, exam policy track | `check_exam_enforcement` |
| Proctoring deadlines, SEB, Zoom sessions | `check_proctoring_status` |
| Integrity reflections | `check_integrity_reflections` |
| Exam deadline overrides | `check_exam_overrides` |
| Student lookup (Students table) | `check_student` |
| Student communication history | `check_student_comms` |
| Class roster | `check_class_roster` |
| Tickets — search, lookup, comment, status | `search_tickets`, `check_ticket`, `add_ticket_comment`, `update_ticket` |
| QuickBooks invoices for a student | `check_qb_invoices` |
| Authorize.net transaction lookup | `check_authnet_transaction`, `find_authnet_by_email`, `find_authnet_by_name` |
| Externship status, placement, forms | `check_externship_status`, `lookup_paperwork_state` |
| Grievance lookup | `check_grievance` |
| Server health, FPM, MySQL status | `server_status` |
| Server logs (PHP-FPM, nginx, syslog) | `check_server_logs` |
| FPM reload after PHP file deploy | `reload_php_fpm` (NOT systemctl — sudoers blocks it, see rule 99) |
| Personnel / candidate pipeline | `check_personnel_pipeline`, `trigger_personnel_agent` |
| Compliance / accreditation status | `check_compliance_status`, `check_capce_status` |
| Telephony / Vapi voice agents | `check_telephony_health`, `vapi_*` |
| Chat widget health | `chat_widget_healthcheck` |
| Discord channel reads / posts | `scan_discord_channel`, `post_discord_message`, `discord_*` |
| HANDOFF_NOTES read/write | `read_handoff_notes`, `update_handoff_notes` |
| RUBEN orchestrator state | `cHgCL60mcp0orchestrator_status`, `cHgCL60mcp0list_decisions`, `cHgCL60mcp0list_ideas`, etc. |
| RUBEN issue tracking | `cpQpdK0mcp0check_ruben_state`, `cpQpdK0mcp0get_ruben_issues` |
| YOLO/agent failure classification | `clsgJ00mcp0kaizen_*` |
| iMessage staff chat read/send | `cjxkvm0mcp0read_messages`, `cjxkvm0mcp0send_message` |
| GitHub repo / PR / issue ops | `c8jMnB0mcp0*` |

## Specifically: do NOT default to these without checking the matrix first

- `chq1Rz0mcp0execute_query` / `chq1Rz0mcp0fetch_data` — generic MySQL
  client. Useful for ad-hoc admin_portal queries, but if the question is
  "what's this student's enrollment", `check_student` is the move.
- `run_moodle_query` — same shape. Useful for one-off reads not covered
  by the wrappers, but the wrappers should be tried first.
- `ssh_command` — last resort for things genuinely outside the MCP
  surface. Not the default.

## Self-check before any non-trivial first tool call

Before I call my first tool on a task, ask:

1. *"Does this task touch any topic in the dedicated-tool matrix above?"*
2. If yes → my next tool call MUST be one of the listed wrappers, not
   ssh / raw SQL.
3. If a wrapper call returns an error or doesn't have the field I need,
   THEN fall back to ssh / raw SQL — and document in `attempt_completion`
   why the wrapper didn't fit, so the next agent knows.

If I'm halfway through writing a `ssh_command` or `run_moodle_query` for
a topic that's on the matrix, abandon and call the wrapper instead.

## When this rule does NOT apply

- The topic is genuinely not in the matrix (rare for EMSU work).
- The wrapper exists but a known limitation rules it out (e.g.,
  `check_moodle_enrollment` returns last 5 quizzes, you need 50 — raw
  SQL is fine; document why).
- A dedicated wrapper just failed and the same call would fail again
  (timeout / 5xx) — fall back to ssh + log to the failure path.
- One-off schema exploration (`describe_table`, `list_tables`).

## Cross-references

- Rule 17 — default-on subagent dispatch. Same shape; subagents are to
  research what dedicated tools are to ops.
- Rule 20 — MCP host-resolver discipline. Why MCPs sometimes look flaky
  and when to retry vs. fall back.
- Rule 23 — KAIZEN. The right place to log "raw SQL was used when a
  wrapper existed" so the pattern surfaces over time.
- Rule 29 — agents act on confidence tier. Wrappers carry business
  logic; raw SQL doesn't. Confidence is higher with the wrapper.
- Rule 99 — YOLO prevention. The "fpm-reload sudoers wall" entry is a
  direct instance of this rule's class: `reload_php_fpm` exists as a
  wrapper; raw `systemctl reload` always fails.

## Last updated

2026-05-08 — initial rule. Source: Ruben asked "do we have an MCP for
Moodle, should we?" — answer: yes, inside emsu-operations (9 dedicated
Moodle tools), no don't split. Real concern: agents skipping those tools
when the MCPs were healthy. This rule is the durable behavior fix.

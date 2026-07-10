# 54 — Subagents CAN take destructive action — but via LOCAL tools only (no MCP). MCP-routed actions stay on the main agent.

Permanent rule. Workspace-scoped. Source: 2026-05-12 — Ruben directive verbatim:

> *"I think with our new intended use, this should be modified slightly. I think it should absolutely be able to make these changes and executions in the same manner as we have now setup for rebasing locking files, etc.. and avoiding collisions for example on RUBEN executor. The logic is much more indepth than this, but the idea is the same. This is a much more efficient use than just saying it's read only. Also, i would say that the subagents need to be able to be called throughout the iteration as needed to complete the task."*

Replaces the cultural "subagents are read-only research" pattern with an explicit "subagents CAN write — under audit + locking." Pairs with `.clinerules/53` (which mandates iteration use + inline model narration).

## 2026-06-07 CORRECTION — subagents have NO MCP access (live-verified)

**The original v1 of this rule wrongly claimed subagents could call "MCP destructive tools (ticket comments, SQL writes, Moodle deploy_content)." They cannot.** This was live-tested on 2026-06-07: a dispatched subagent's complete toolset is exactly six LOCAL tools — `read_file`, `list_files`, `search_files`, `list_code_definition_names`, `execute_command`, `attempt_completion`. Zero MCP-server tools are wired into a subagent's schema (no `emsu-operations`, `fleet-state`, `mysql`, `imessage`, `ruben-orchestrator`, `memory`, `google-drive`, etc.). This matches `.clinerules/53` (lines 87-114) and `.clinerules/75` (lines 53-54), which both already state it correctly. The Ruben directive quoted above was reasonable intent, but the Cline subagent runtime never actually exposed MCP to subagents — so the capability was aspirational, not real. Dispatching a subagent for MCP/server work just burns tokens and returns "MCP not available" (the exact wasted-time failure this correction prevents).

## The bright-line rule

**Subagents CAN perform destructive operations that go through LOCAL tools** — `replace_in_file`, `write_to_file`, and `execute_command` that mutates state (including `safe_deploy` invoked as a CLI command, local SQL via a CLI client, git operations, file moves) — **provided ALL of the following are true:**

1. The destructive action uses the same **locking + audit primitives** the main agent uses.
2. The main agent **prevents same-resource collisions** in its fan-out (see "Collision avoidance" below).
3. The destructive action is **NOT on the irreversibility hard-floor list** from `.clinerules/29`.
4. The destructive action does **NOT require an MCP-server tool**. Anything MCP-routed (ticket comments via `add_ticket_comment`, DB writes via `execute_query`, `reload_php_fpm`, `deploy_moodle_content`, iMessage/Discord sends, orchestrator decisions, etc.) is **MAIN-AGENT-ONLY** — subagents physically cannot call those tools. If the action needs an MCP tool, it is not subagent-dispatchable; run it inline in the main window.

This is NOT a blanket permission. It's "yes — for LOCAL destructive actions, under the same discipline. MCP actions stay on the main agent."


## Required locking + audit primitives

When a subagent does a destructive action, it MUST use these exactly as the main agent would:

### File writes
- **`safe-deploy --expected-sha256`** on every WOPR file write. The CAS check is the lock. Two subagents writing the same file → second one fails the sha check and aborts cleanly. No corruption.
- **Backup file always created** (safe-deploy creates `.bak-*-<reason>` automatically).
- Local file writes (Mac side): same shape — read first, check sha, write, leave a backup. `replace_in_file` SEARCH/REPLACE is its own CAS — two subagents won't both match the same SEARCH block.

### Database writes (only via a LOCAL CLI client, NOT the mysql MCP)
- A subagent can run SQL **only** through `execute_command` invoking a local CLI (e.g. `mysql -h ... -e "..."` if credentials are wired locally). It CANNOT use the `mysql` MCP `execute_query` tool. If no local CLI path exists, the SQL stays on the main agent.
- **Per-row primary key or unique constraint** prevents two subagents inserting the same row.
- **`UPDATE ... WHERE id=N`** is naturally atomic.
- For multi-row mutations, **`flock(/tmp/cline-subagent-<resource>.lock)`** at the start of the operation, release at end. Same primitive RUBEN executor uses.

### MCP destructive tools — MAIN AGENT ONLY (subagents cannot reach them)
- `add_ticket_comment`, `execute_query`, `reload_php_fpm`, `deploy_moodle_content`, iMessage/Discord sends, orchestrator decisions, and every other MCP-server tool are **not in a subagent's schema** (live-verified 2026-06-07). A subagent that tries to call one gets "tool not found / MCP not available."
- Therefore any work that requires one of these tools is **not subagent-dispatchable**. The main agent does it inline. The audit row (`orchestrator_event_log`, `agent_name='cline_main'`) is written by the main agent.

### Cross-system operations
- Local cross-system work (touching multiple files / local services via `execute_command`) uses the same flock pattern: `flock /tmp/cline-subagent-<system>.lock` before the action.
- Anything that reaches a system via an MCP tool (e.g. `reload_php_fpm`) is main-agent-only — a subagent has no way to call it, so the rate-limit/flock concern there belongs to the main agent.


## Collision avoidance (main agent's responsibility)

The main agent dispatching subagents MUST design the fan-out so no two subagents target the same resource:

- **Same file**: serialize into one subagent. E.g. don't dispatch 3 subagents all writing `/var/www/emtskills/lib/EmailAIResponder.php`.
- **Same student**: serialize. Don't dispatch 2 subagents both updating `Students.id=N`.
- **Same chain**: serialize. Don't dispatch 2 subagents both processing `session_handoffs.id=M`.
- **Same ticket**: serialize unless they're writing different comment threads (different `is_internal` values etc).
- **Same cron / config**: serialize.

If the main agent finds itself wanting two subagents on the same resource, that's a sequence, not a parallel fan-out. Make it one subagent that does both steps.

Cross-resource parallelism is unbounded and cheap. Same-resource parallelism is one subagent.

## Irreversibility hard-floor (NEVER subagent-actioned)

These stay on the main agent under explicit human approval, NEVER autonomous, regardless of locking primitives:

- External email/SMS to students, regulators, attorneys, accreditors
- Charging or refunding cards (Authnet, Affirm, QB invoices, payment_suspensions)
- Lifting Moodle suspensions for real students
- Anything regulator/grievance/legal-grade
- Posting to public emsuniversity.com pages or external marketing channels
- Vault credential writes (Meta tokens, Authnet creds, etc.)
- Anything `.clinerules/29` lists as irreversible-tier

Subagents can RESEARCH these (read AI compiled rules, read invoice history, read grievance text). They CANNOT execute the final destructive action. That stays main-agent + Q-card per `.clinerules/12` + `/29`.

## Required attribution in audit log

Every subagent destructive action must leave a row in `orchestrator_event_log` (or equivalent audit surface) with:

```
event_type = 'cline_subagent_action'
source     = 'cline_subagent'
agent_name = 'subagent_<N>_of_<dispatch_id>'    -- so we can correlate back to the fan-out
subject    = '<short description>'
payload    = {
  parent_task_id: '<cline_task_id>',
  parent_model:   '<claude-sonnet-4-6 etc>',
  subagent_model: '<claude-haiku-4-5 etc>',
  action:         'safe_deploy | sql_update | add_ticket_comment | etc',
  resource:       '<file path | row id | ticket id>',
  reversal_cmd:   '<exact command to undo>',
  before_state:   '<sha256 | row value | etc>',
  after_state:    '<sha256 | row value | etc>'
}
```

So if a subagent does the wrong thing, the main agent (or Ruben) can find ALL of that dispatch's subagent actions with one query and reverse them.

## Examples — what this enables (LOCAL actions only)

**Parallel LOCAL file edits (the canonical valid fan-out):**
- Main agent: "These 8 local config files each need the same one-line patch."
- Main agent: dispatches 8 subagents in parallel (one per file), each does its own `replace_in_file` / `write_to_file`. Different files = no collision. 8x wall-clock speedup.

**Parallel LOCAL shell work:**
- Main agent: "Regenerate 5 local report artifacts in /tmp, one per dataset."
- Main agent: 5 subagents in parallel, each running its own `execute_command` (python/jq/sed) on its own file. flock per output path prevents clobber.

**NOT subagent-dispatchable (MCP-routed — main agent only):**
- "UPDATE 8 ai_compiled_rules rows via the mysql MCP `execute_query`" → main agent runs these (parallel tool calls in ONE response block is the speedup, not subagents).
- "purge_moodle_cache for 5 courses" → `purge_moodle_cache` is an MCP tool → main agent only.
- A subagent sending Vicky an SMS about a refund → rule 29 hard-floor AND MCP-routed. Main agent only, with Q-card. No exception.


## What this rule does NOT do

- Does NOT remove `.clinerules/29` confidence-tier gates. Those still apply to whatever the subagent does.
- Does NOT allow subagents to override curated AI rules (`source_correction_ids=clinerules:*`).
- Does NOT permit subagents to deploy without safe-deploy CAS just because they're a subagent. Same discipline as main agent.
- Does NOT change subagent-to-main-agent communication shape — subagents still return text results, the main agent still reads them and decides next steps.

## Cross-references

- `.clinerules/17` — default-on subagent dispatch (when to dispatch)
- `.clinerules/22` — executor self-supervision loops (where these locking primitives originated)
- `.clinerules/29` — agents act on confidence tier (irreversibility hard-floor)
- `.clinerules/41` — post-deploy: call the tool, don't narrate (same applies to subagent actions)
- `.clinerules/53` — subagent iteration + narration (this rule's companion)
- `lib/safe_deploy.sh` on WOPR — the safe-deploy CAS implementation
- `orchestrator_event_log` table on admin_portal — the audit surface

## Last updated

2026-06-07 — CORRECTION. Removed the false "subagents can call MCP destructive tools" claim after a live test proved subagents have NO MCP access (toolset = read_file, list_files, search_files, list_code_definition_names, execute_command, attempt_completion only). Rescoped the rule to LOCAL destructive actions; MCP-routed actions are now explicitly main-agent-only. Source: Ruben asked why a subagent dispatched to use the fleet-state MCP returned "MCP not available" and wasted ~11K tokens / 0 tool calls. Root cause: this rule (v1) told agents to dispatch subagents for MCP work they categorically cannot do. Aligns 54 with `.clinerules/53` + `.clinerules/75`, which were already correct.

2026-05-12 — initial rule. Source: cline-7b-phase3-analysis session
(task #1778607736240). Ruben directive verbatim quoted at top. Pair-shipped
with `.clinerules/53` so the iteration-use mandate and destructive-action
permission land together.


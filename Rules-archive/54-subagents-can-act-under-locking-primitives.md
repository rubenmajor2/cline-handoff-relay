# 54 — Subagents CAN take destructive action under the same locking primitives the main agent uses

Permanent rule. Workspace-scoped. Source: 2026-05-12 — Ruben directive verbatim:

> *"I think with our new intended use, this should be modified slightly. I think it should absolutely be able to make these changes and executions in the same manner as we have now setup for rebasing locking files, etc.. and avoiding collisions for example on RUBEN executor. The logic is much more indepth than this, but the idea is the same. This is a much more efficient use than just saying it's read only. Also, i would say that the subagents need to be able to be called throughout the iteration as needed to complete the task."*

Replaces the cultural "subagents are read-only research" pattern with an explicit "subagents CAN write — under audit + locking." Pairs with `.clinerules/53` (which mandates iteration use + inline model narration).

## The bright-line rule

**Subagents CAN perform destructive operations** — `safe_deploy_file`, `replace_in_file`, `write_to_file`, `execute_command` that mutates state, MCP destructive tools (ticket comments, SQL writes, ollama create/rm, Moodle deploy_content, etc.) — **provided ALL of the following are true:**

1. The destructive action uses the same **locking + audit primitives** the main agent uses.
2. The main agent **prevents same-resource collisions** in its fan-out (see "Collision avoidance" below).
3. The destructive action is **NOT on the irreversibility hard-floor list** from `.clinerules/29`.

This is NOT a blanket permission. It's "yes, under the same discipline."

## Required locking + audit primitives

When a subagent does a destructive action, it MUST use these exactly as the main agent would:

### File writes
- **`safe-deploy --expected-sha256`** on every WOPR file write. The CAS check is the lock. Two subagents writing the same file → second one fails the sha check and aborts cleanly. No corruption.
- **Backup file always created** (safe-deploy creates `.bak-*-<reason>` automatically).
- Local file writes (Mac side): same shape — read first, check sha, write, leave a backup. `replace_in_file` SEARCH/REPLACE is its own CAS — two subagents won't both match the same SEARCH block.

### Database writes
- **Per-row primary key or unique constraint** prevents two subagents inserting the same row.
- **`UPDATE ... WHERE id=N`** is naturally atomic.
- For multi-row mutations, **`flock(/tmp/cline-subagent-<resource>.lock)`** at the start of the operation, release at end. Same primitive RUBEN executor uses.

### MCP destructive tools
- Same shape: each tool either is naturally idempotent (e.g. `add_ticket_comment` writes a new row) or has its own dedup logic.
- Each call writes a row to `orchestrator_event_log` with `agent_name='subagent_N_of_<dispatch_id>'` and `source='cline_subagent'` so the audit trail is greppable.

### Cross-system operations
- Same flock pattern: `flock /tmp/cline-subagent-<system>.lock` before the action.
- E.g. two subagents both wanting to `reload_php_fpm` → flock prevents the second from firing within the rate-limit window.

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

## Examples — what this enables

**Before this rule (research-only pattern):**
- Main agent: "Find which 8 ai_compiled_rules rows mention 'Wonderlic'"
- Subagent: returns list of 8 row IDs
- Main agent: serially UPDATEs each row → 8 sequential SQL writes

**After this rule:**
- Main agent: dispatches 8 subagents in parallel (one per row ID), each does its own `UPDATE WHERE id=X`. Different rows = no collision. 8x wall-clock speedup.

**Before this rule:**
- Main agent: "Check 5 Moodle courses for stale completion_state"
- Subagent: returns 5 problem rows
- Main agent: serially calls `purge_moodle_cache` for each

**After this rule:**
- Main agent: 5 subagents in parallel, each calling `purge_moodle_cache(course_id=X)` for its own course. flock prevents Moodle cron interference.

**Still NOT allowed (rule 29 hard-floor):**
- Subagent sending Vicky an SMS about a refund. Main agent only, with Q-card. No exception.

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

2026-05-12 — initial rule. Source: cline-7b-phase3-analysis session
(task #1778607736240). Ruben directive verbatim quoted at top. Pair-shipped
with `.clinerules/53` so the iteration-use mandate and destructive-action
permission land together.

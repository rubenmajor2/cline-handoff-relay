# 73 — Close the Agent Capability Gap: if you end up doing it, give the Agent the capability + playbook before you walk away

Permanent rule. Workspace-scoped. Source: 2026-05-15 — Ruben directive verbatim
during the Sara Barrett EMD ticket routing fix:

> *"Cline rule, if there is an Agent, where it should be within their scope
> to repair an issue but you end up having to do so, they should be given
> the capability to do that repair and instructions to do so if any other
> such situations arise."*

## What this rule does that rule 68 didn't

Rule 68 says SURFACE the capability gap (file an idea, log it, route to human).
Rule 73 says CLOSE it: if you end up performing work that should have been an
Agent's job, ship the Agent the capability + the playbook in the SAME session,
so the next time the situation arises the Agent handles it autonomously without
needing Cline.

Rule 68 = "report the gap." Rule 73 = "close the gap before you leave."

## The bright-line rule

**When Cline ends up performing work that falls within an Agent's defined
scope (Ticket Agent, Email Agent, Voice Agent, Chat Agent, Personnel Agent,
RUBEN Executor, KAIZEN, etc.), Cline MUST in the same session:**

1. **Perform the work** (the immediate fix the user is waiting on).
2. **Ship the Agent the capability** (new function / tool / classifier / branch).
3. **Ship the Agent the playbook** (curated `ai_compiled_rules` row OR
   `failure_repair_recipes` row OR documented detection signature, with
   `source_correction_ids` prefixed `clinerules:73` so the nightly
   recompiler protects it).
4. **Re-test that the Agent autonomously handles a repro of the same case.**
   If Cline can't construct a repro because the underlying signal was
   one-off, document the exact trigger conditions in the playbook so the
   Agent recognizes them next time.
5. **Update the Agent's tool registry / decision tree** so the new
   capability is reachable from the Agent's existing entry points (e.g.
   `technical_subbucket` mapping, `category` enum mapping, ticket triage
   keyword set, etc.) — NOT just sitting as a dead function nobody calls.

## What "ending up doing the Agent's work" means concretely

Cline crosses into Agent territory whenever Cline:

- Resets a stuck quiz attempt by hand (that's Ticket Agent's `emd_module_simulation` /
  `stuck_quiz_reset` job per rule 69).
- Writes a corrective student email manually (that's Email Agent's job; the
  rule + the prompt-level guidance should already exist).
- Manually classifies a ticket subbucket (that's Ticket Agent's
  `auto_diagnostic_verdict` job).
- Resolves a fix_failed RUBEN chain by hand (that's RUBEN's recipe-driven
  retry loop per rule 22).
- Routes a ticket by manual UPDATE on `assigned_to_user_id` (that's the
  ticket triage step in `cron_ai_ticket_agent`).
- Hand-corrects an AI's outbound by sending a follow-up reply (that's the
  post-compose scanner / safe-fallback path in `lib/EmailAIResponder.php` +
  related).

If Cline does any of those: the Agent had a gap, and rule 73 fires.

## The 5-step capability-close pattern

### Step 1: Perform the immediate fix
Do not block on the systemic work. The user (and the affected student) come
first.

### Step 2: Identify the Agent + the gap precisely
Be explicit. "Ticket Agent has no `resolveEmdSimulationStuck()` method"
is correct; "the Agent doesn't handle EMD stuff" is not. Identify:
- WHICH Agent (file path of its main `lib/*.php` or `cron/*.php`)
- WHICH function / tool / branch was missing
- WHICH trigger signal would have invoked it (subject regex, ticket subbucket,
  ai_compiled_rules row, email_inbound_log intent, etc.)

### Step 3: Ship the capability
Add the function / tool / branch as a real code patch via safe-deploy with
CAS sha256. Lint clean (`php -l` for PHP, equivalents for other langs).
Backup file written. FPM reloaded if relevant.

### Step 4: Ship the playbook
The Agent needs to KNOW when to use the new capability. Pick one of these
based on where the Agent decision-routes:

| Agent decision layer | Where the playbook lives |
|---|---|
| Email Agent prompt-level | `ai_compiled_rules` row, `source_correction_ids` LIKE `clinerules:73%` |
| Ticket Agent triage | `ai_compiled_rules` row OR `auto_diagnostic_verdict` mapping in `lib/ai_ticket_agent.php` |
| RUBEN executor | `failure_repair_recipes` row with `detection_pattern` + `planner_input_modifier` |
| Chat / Voice AI | `ai_compiled_rules` row with `channel='chat'` or `'voice'` |
| KAIZEN classifier | new pattern in the scanner + recipe in `failure_repair_recipes` |

The playbook row MUST include:
- Detection signature (keyword regex / subbucket / DB-state signature)
- The action the Agent should take (function name, tool call, SQL fix)
- The student-facing reply template (no apology, no time promise — rules 02/72)
- The CC list for any human visibility (Vicky on QB stuff, Jon on academic
  overrides per rules 13/31, etc.)
- The reversal command for the action (so future agents can undo if wrong)

### Step 5: Re-test with a repro
Either:
- Construct a synthetic case that exercises the trigger (e.g. an inbound
  email with the right phrasing + a known stuck DB row) and verify the
  Agent now handles it without Cline intervention, OR
- If repro isn't feasible, install a watchdog that scans for the live
  occurrence + flags any case the Agent fails to handle (KAIZEN-style).

## What this rule does NOT do

- Does not require infinite generalization. If the gap is narrow (one
  specific table, one specific intent), ship the narrow capability. Don't
  rewrite the Agent for a single incident.
- Does not require building a UI. The Agent's existing decision plumbing
  is what gets extended. UI updates can ship as a separate idea per rule 78.
- Does not waive the immediate fix. The user is not waiting on systemic
  work; perform step 1 first.

## When the Agent genuinely can't have the capability

If the work is on the rule-29 irreversibility hard-floor (touching money,
sending regulator-grade comms, lifting Moodle suspensions without payment
confirmation, etc.), the Agent SHOULD NOT auto-do it. In that case:
- Cline does the work manually (rule 29 Q-card discipline applies).
- The Agent's role becomes detecting + flagging + creating the ticket for
  the human, NOT performing. The playbook codifies that handoff shape.
- Rule 73 still applies in the limited sense: the Agent gets the
  DETECTION capability + the routing playbook, even if not the action.

## Cross-references

- Rule 22 — executor self-supervision loops (RUBEN's recipe-driven retry)
- Rule 23 — KAIZEN MCP failure classifier (where new failure patterns get
  registered)
- Rule 29 — agents act on confidence tier (the irreversibility hard-floor
  this rule respects)
- Rule 32 — prefer dedicated MCP wrappers (the capabilities you ship under
  rule 73 should be reachable via existing MCP tool surfaces when possible)
- Rule 42 — proactive systemic solutions (rule 73 is the "block at source"
  layer of rule 42's three-tier model)
- Rule 46 — every agent correction loops back to RUBEN + KAIZEN
- Rule 67 — agents act autonomously before human escalation (rule 73 is
  what makes 67 actually doable for new failure classes)
- Rule 68 — agents exhaust tools + surface capability gaps (rule 73 graduates
  the "surface" step to "close")
- Rule 69 — Jon is policy/override, NOT technical fixer (so technical fixes
  belong to Ticket Agent or RUBEN, not Jon)

## Source incident

2026-05-15 Sara Barrett EMD third-party-redirect → Cline routed Sara's
underlying EMD quiz error to Vicky (TKT-20260515-20343C39) instead of
Ticket Agent. Per rule 69 that's wrong (Vicky doesn't reset Moodle quiz
state). Per this new rule 73, Ticket Agent gets the EMD-stuck-attempt
capability + the routing playbook so the next EMD student with the same
class of issue is handled autonomously.

## Last updated

2026-05-15 — initial rule per Ruben directive in the Sara Barrett ticket
routing follow-up. Companion deploy: Ticket Agent `resolveEmdSimulationStuck()`
capability + curated `ai_compiled_rules` playbook row + KAIZEN-style
watchdog for "third-party lecture fired against non-vocational student"
class.

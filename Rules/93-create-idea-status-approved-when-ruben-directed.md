# 93 — When filing an idea per a Ruben directive, set status='approved' at create time

Permanent rule. Workspace-scoped. Source: 2026-05-18 11:02 PT cline-pickup-1779067527659
session. Idea #4891 (refund MCP tools) and #4971 (Authnet portal reconciliation)
were both filed during the session per direct Ruben directives, but landed at
`status='proposed'` because that's the create_idea MCP tool's default. Ruben
asked "if these are approved autonomous why do we need another session?" —
which surfaced the gap.

Companion to `.clinerules/38` (Ruben-asked = autonomous tier minimum) and
orchestrator idea #4990 (the upcoming MCP tool fix that adds a `status` param
at creation).

## The bright-line rule

**When Cline files an `orchestrator_ideas` row in response to a Ruben directive
in this same Cline session, the idea MUST land at `status='approved'` so
RUBEN executor picks it up on the next cron tick without further intervention.**

Filing at `proposed` and then forgetting to flip is a rule-38 violation. Two
acceptable paths:

### Path 1 (preferred, after idea #4990 ships)

`create_idea(title=..., description=..., status='approved', priority='P1', domain='technical')`

The MCP tool will accept `status='approved'` at create time and populate
`approved_by`, `status_changed_at`, `status_changed_by` in one call.

### Path 2 (current, until #4990 ships)

Use the existing `create_idea` MCP tool, capture the returned id, then
immediately follow with:

```sql
UPDATE orchestrator_ideas
   SET status='approved',
       approved_by='ruben_directive_YYYY-MM-DD_<session-slug>',
       status_changed_at=NOW(),
       status_changed_by='cline_via_ruben_y_directive',
       updated_at=NOW()
 WHERE id=<idea_id> AND status='proposed'
```

Both queries must run in the SAME response block (parallel tool calls per
rule 53) or sequentially with no other tool calls between them.

## When this rule applies

Triggers ANY of:
- Ruben said "file that as approved" / "ship it" / "do it" / "yes file it"
- Ruben said "this should be P0/P1/P2" without "let me think about it"
- Ruben said any close variant of "this needs to happen" while pointing at a
  feature or capability gap
- The idea is a direct response to a Ruben-described bug/missing-tool

Does NOT trigger:
- Cline files an idea while triaging on its own initiative (not Ruben-directed)
- The idea is genuinely speculative or needs human judgment first
- The idea would touch the irreversibility hard-floor (per rule 29) — those
  stay at `proposed` regardless, with a Q-card to surface them

## Self-check before any `create_idea` MCP call

Ask: *"Did Ruben directly direct this idea in this session?"*
- If YES → status MUST land at 'approved' (either via status param when #4990
  ships, OR via immediate UPDATE follow-up)
- If NO → status='proposed' is correct, leave it alone

If I'm about to call `create_idea` for a Ruben-directed feature without an
immediate flip-to-approved plan, I'm violating this rule. Restructure.

## Audit / sanity check

Periodically (or when the rule-38 violation counter surfaces in
.clinerules/00-READ-FIRST-17 detector), grep:

```sql
SELECT id, title, status, status_changed_at,
       TIMESTAMPDIFF(SECOND, created_at, COALESCE(status_changed_at, NOW())) as flip_lag_sec
  FROM orchestrator_ideas
 WHERE created_by_agent LIKE '%cline%'
   AND created_at >= NOW() - INTERVAL 30 DAY
   AND status IN ('approved', 'in_progress', 'deployed')
   AND status_changed_at IS NOT NULL
   AND TIMESTAMPDIFF(SECOND, created_at, status_changed_at) BETWEEN 0 AND 300
 ORDER BY created_at DESC
 LIMIT 30
```

Rows where `flip_lag_sec` is between 1-300 seconds are evidence of this
rule's manual-flip pattern firing. Once idea #4990 ships, that lag should
trend toward 0 (created and approved in one MCP call).

## Cross-references

- `.clinerules/38` — Ruben-asked = autonomous tier minimum (this rule
  implements the create-time enforcement)
- `.clinerules/22` — executor self-supervision loops (RUBEN's pipeline that
  consumes approved-status ideas)
- `.clinerules/29` — agents act on confidence tier (irreversibility hard-floor
  exceptions stay at proposed)
- `.clinerules/42` — proactive systemic solutions (this rule + #4990 IS one)
- `.clinerules/46` — every agent correction loops back to RUBEN + KAIZEN
- `.clinerules/49` — if Ruben implies an action, offer it (companion: if he
  directs, file at approved)
- orchestrator_ideas #4990 — emsu-operations MCP create_idea status param
  (the durable code fix)

## Source incident

2026-05-18 — Cline filed #4891 + #4971 per direct Ruben directives during
the avani umbrella pickup session. Both landed at `status='proposed'`
because create_idea's default is proposed. Ruben asked "if these are
approved autonomous why open another session?" which surfaced the gap.
Manual UPDATE flip ran in the same session. Rule filed to make the
default-on behavior explicit until #4990 makes it automatic.

## Last updated

2026-05-18 — initial rule per Ruben Y directive in same session.

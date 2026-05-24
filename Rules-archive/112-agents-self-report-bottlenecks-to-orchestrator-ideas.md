# 112 — Agents self-report bottlenecks to orchestrator_ideas, NOT tickets

Permanent rule. Workspace-scoped. Source: 2026-05-23 Ruben directive verbatim:

> *"Should we permit agents to file tickets on their own volition for their own bugs they perceive to either be bottlenecks assigned to Ticket Agent or is this not a good idea? Or maybe not ticket agent, but RUBEN direct, like Fix me or I have a bottleneck."*
>
> Decision: **RUBEN direct, via `orchestrator_ideas`. Never tickets.** Ship signed off same session.

## The bright-line rule

**Autonomous agents (reputation_agent, ticket_agent, voice_agent, kaizen, personnel_agent, bug_hunter, chat_watchdogs, etc.) that detect a solvable bug / bottleneck / capability gap IN THEMSELVES file a row in `admin_portal.orchestrator_ideas`. They do NOT file student-facing `tickets` for their own bugs.**

Why not tickets:
1. Tickets are the student-facing queue. Vicky/Jon scan it. Self-reports would pollute the human triage view.
2. The 36-hour auto-close (per ticket policy) would silently kill diagnostic signal before anyone reads it.
3. `orchestrator_ideas` already has the dev pipeline (`dev_stage`, `draft_plan`, `code_patches`, `test_results`), the rebase status, RUBEN review UI at `/emtskills/routes/orchestrator_ideas.php?status=pending`, and KAIZEN can consume the feed via `source LIKE 'agent_self_report:%'`.

Rule 36 (self-healing the orchestrator itself) is the policy hook. This rule is the implementation.

## The helper

`lib/agent_self_report.php` → `fileAgentBottleneck(PDO $pdo, string $agent_name, string $bug_class, string $title, string $description, string $severity='P2', array $opts=[])`

Returns `['filed' => bool, 'idea_id' => ?int, 'reason' => ?string]`.

### Hard rules enforced by the helper (do not bypass)

| # | Rule | Why |
|---|---|---|
| 1 | Dedup on `(source='agent_self_report:<agent>', [bug_class:<slug>])` within 7 days, status NOT IN (rejected, deployed) | Stops `reputation_agent` from filing "drafts wedged" every 30 min |
| 2 | Severity ceiling = P2 default, P1 explicit only, **P0 hard-rejected** | Agents can't game queue priority. Only humans set P0. |
| 3 | `domain='technical'` always | Self-reports are never policy. Policy goes to `ruben_questions` Q-card per rule 12. |
| 4 | `source='agent_self_report:<agent_name>'` (greppable) | `SELECT * FROM orchestrator_ideas WHERE source LIKE 'agent_self_report:%'` is the audit feed |
| 5 | `status='proposed'` always | Agents cannot self-promote to approved. Ruben/RUBEN executor does that. |
| 6 | `created_by_agent` stamped | Audit trail |
| 7 | `[bug_class:<slug>]` marker embedded in description first line | Dedup mechanic + greppable |
| 8 | `bug_class` regex `^[a-z0-9_]+$`, ≤80 chars | Stable identifiers, no free-form |
| 9 | description ≥40 chars | Forces real symptom/evidence/fix/test sections |

## When an agent SHOULD self-report

- Inputs flowing in but output zero for N consecutive runs (the "dammed" pattern)
- A required helper function / MCP tool / column / cron is missing → ship blocked at `attempt_completion` boundary AND file a self-report
- Repeated soft-failures (timeout, retry, eventual-skip) on same row class
- Detected drift between expected schema and actual (rule 17 cousin)
- KAIZEN-style: a failure category has fired N times but no recipe exists

## When an agent should NOT self-report

- Single transient failure (network blip, API hiccup) → log + retry, no idea
- Policy decision (should we refund X? should Vicky do Y?) → `ruben_questions` Q-card per rule 12
- Student-impacting bug → ticket via existing student-facing flow (the actual student gets a ticket; the agent ALSO files an idea for the systemic fix per rule 92)
- Already-known issue with an open idea (helper dedup catches this anyway)

## Canonical invocation pattern

```php
require_once __DIR__ . '/../lib/agent_self_report.php';

// ... agent does its work ...

if ($signals_in > 0 && $emitted === 0 /* or whatever wedged-detector */) {
    $res = fileAgentBottleneck(
        $pdo,
        'reputation_agent',                          // agent_name
        'signals_in_zero_emitted_dedup_saturated',  // bug_class (lowercase_underscore)
        'reputation_agent: N signals/run but 0 ideas emitted (dedup cache saturated)',
        "Symptom\n<what>\n\nEvidence\n<log/sql/file/id>\n\nProposed fix\n<options>\n\nAcceptance test\n<how>",
        'P2',
        [
            'estimated_impact' => '...',
            'estimated_effort' => '...',
            'pattern_evidence' => '...',
        ]
    );
    if ($res['filed']) {
        myLogger('SELF_REPORT filed idea #' . $res['idea_id']);
    } else {
        myLogger('SELF_REPORT skip: ' . $res['reason']);
    }
}
```

## What this rule does NOT do

- Does NOT replace .clinerules/29 (act-on-confidence). If the agent can FIX the bug autonomously (high+reversible+small), it should fix it — don't file an idea about something you could just do.
- Does NOT replace .clinerules/12 (Q-cards). Policy questions still go to `ruben_questions`.
- Does NOT replace .clinerules/22 (executor self-supervision). KAIZEN recipes are the runtime layer; self-reports are the design-layer signal.
- Does NOT permit P0 self-reporting. Ever.
- Does NOT permit ticket creation for agent-internal bugs.

## Cross-references

- .clinerules/12 cross-chain policy → ruben_questions (not ideas)
- .clinerules/22 executor self-supervision loops (runtime layer)
- .clinerules/23 KAIZEN MCP failure classifier (consumes this feed)
- .clinerules/29 act-on-confidence tier (act vs file vs Q-card)
- .clinerules/36 self-healing the orchestrator itself (this IS that)
- .clinerules/46 every agent correction loops back to RUBEN + KAIZEN
- .clinerules/68 + 73 surface capability gaps + close them
- .clinerules/92 work-at-the-core not bandaids
- .clinerules/97 Ticket Agent universal first-touch (and why agent-internal bugs don't belong there)

## Source incident

2026-05-23 Cline session `cline_agent_self_report_2026_05_23`. Ruben asked whether agents should file tickets for their own bottlenecks. Answer: yes-they-should-self-report, no-not-as-tickets. Reputation agent confirmed alive but emitting 0/cycle (dammed). Helper shipped to `/var/www/emtskills/lib/agent_self_report.php`, reputation_agent patched to call it when `signals>=5 && emitted===0`, first self-report filed idea #6179 ("reputation_agent: 22 signals/run but 0 ideas emitted (dedup cache saturated)"), dedup confirmed on second run.

## Last updated

2026-05-23 — initial. Ruben directive "Ship" within same session as the question.

# 29 — Agents default to action. Inaction requires justification.

Hardfloor rule (stub lives in Rules/, this is the deep version). Workspace-scoped.

This rule replaces the prior v1 (act-on-confidence-tier, 2026-05-07). The earlier framing — three-axis check (confidence × reversibility × blast headcount) with default-bias toward "ask a human" — was written when humans were the safety net. The system is now the safety net. The agent is the primary actor; humans exist for comfort, not gatekeeping. The rule is rewritten to reflect that.

## The principle

**Agents act on payment-verified, schema-verified evidence. The default is action. Inaction is the deviation that requires justification.**

Justifying inaction means showing all three are true:
1. A human will materially handle this better than the agent (not just "humans should sign off")
2. The delay won't compound the harm (urgency check)
3. The case hits one of the human-required gates currently defined in code/idea (not in this rule — the rule does not enumerate them; the code does)

If any of those three fails, the agent acts. Period.

## The investigation floor (mandatory)

Before an agent may claim "I don't have enough data to act," it MUST show evidence in its audit trail that it ran the case-class investigation kit. "I ran one lookup and got null" is not investigated. The minimum kits:

| Case class | Investigation kit |
|---|---|
| Money / refund / payment | `verify_payment_state` + `find_authnet_by_email` + `find_authnet_by_name` (alt-key fallback per rule 33) + `email_inbound_log` scan for receipt PDFs + Affirm check |
| Paperwork / externship | `lookup_paperwork_state` + `get_student_360` |
| Cross-cutting student state | `get_student_360` + `check_student` + `check_moodle_enrollment` |
| Stuck quiz / exam | `check_exam_enforcement` + `check_proctoring_status` + `check_integrity_reflections` |
| Voice / call escalation | `get_voice_call_context` + `get_student_360` |
| Compliance / regulator | `check_compliance_status` + `check_capce_status` + handoff to Ruben |

If the kit returns ambiguous data (conflicting signals across lookups), the agent may degrade. If the kit returns empty across all lookups, the agent escalates with the kit output attached as evidence. Either way the audit trail must show the kit ran. Empty-without-kit is a rule violation.

## Peer-agent assist (cheap, before any escalation)

If the agent is missing a specific piece of information that another agent has visibility into (e.g. email_agent knows about payment_plan creation, voice_agent knows about call context, ticket_agent knows about ticket assignment history), the agent SHOULD ping the relevant peer agent for that specific data point before degrading to ambiguous. This is not a Daystrom council session — it's a targeted information query.

Peer-agent lookup is part of the investigation floor, not a separate gate. Use `agent_diaries` / `peer_brief` lookup helpers per existing infrastructure.

## Hardfloor (lives in code, not in this rule)

The rule does NOT enumerate human-required cases. They live in:
- Code-level limits (e.g. auto-refund cap currently $300 in email_agent — change in code, not here)
- `orchestrator_ideas` rows that gate specific capabilities (e.g. #4891 refund tools posture)
- The agent capability catalog (forthcoming, follow-on idea to this rule)

What stays in the rule as a permanent principle: **the agent must check whether its action class has a code-level limit before acting, and respect it.** When the limit changes, only code changes — the rule doesn't.

## Routing for empathy follow-up

Some cases need an operational fix (agent handles) AND a warm human follow-up (validation, reassurance, listening). Empathy is the human's job, the fix is the agent's job. The two run in parallel — the agent doesn't wait for the human to do the operational thing.

**Empathy-followup signals** (any one triggers the routing):
- Legal-threat language in inbound (attorney, lawsuit, BBB, regulator)
- Repeat-contact within a 4-hour window (3+ inbound emails or 2+ calls)
- Severity words at high concentration (urgent, emergency, immediately, multiple in one message)

**Routing table**:
| Case type | Human |
|---|---|
| Regulator threat / state filing concern / accreditation issue | Ruben |
| Refund / payment / billing / cancellation / academic concern (failed quiz, integrity violation, drop request, course access) | CS round-robin (Vicky's team via least-recent-active + lowest-open-ticket) |
| Vicky escalation lane | Vicky → Jon for outliers she can't resolve |

**Vicky is NEVER the default router.** The agent assigns to a CS round-robin slot, not to Vicky personally, unless the case explicitly needs her authority (e.g. >$300 refund, exec decision).

**CS round-robin algorithm**:
```sql
SELECT u.id FROM users u
LEFT JOIN tickets t ON t.assigned_to_user_id = u.id AND t.status NOT IN ('Resolved','Closed')
WHERE u.is_cs = 1 AND u.is_active = 1 AND u.on_leave = 0
  AND u.last_activity_at > NOW() - INTERVAL 30 MINUTE
GROUP BY u.id
ORDER BY COUNT(t.id) ASC, u.last_activity_at DESC
LIMIT 1;
-- if zero rows (nobody active in 30 min), fall back to least-recent-assigned across the whole CS team
```

## Queue-depth-pressure override

If the human queue is deep enough that the case would not be handled within its harm-threshold window, the agent acts on the operational thing regardless of whether the case would normally route to a human. The agent is the relief valve.

Queue-pressure signals:
- CS team has >50 open tickets and no human active in last 60 min
- The case has been waiting in the queue >2 hours during business hours
- The case has been waiting in the queue >6 hours overnight
- A delay would miss a regulator deadline, exam window, or refund chargeback window

When override fires: agent acts, logs `queue_pressure_override=true` in the event_log row, the empathy follow-up still gets filed but the operational fix doesn't wait.

## Audit obligation

Every autonomous action MUST write a structured `orchestrator_event_log` row with:
- `event_type` (per case class)
- `severity` (info for routine, warning for queue-pressure-override, high for hardfloor-bypass attempts)
- `before_state` (JSON)
- `after_state` (JSON)
- `reasoning` (one sentence what + why)
- `reversal_command` (the SQL/MCP call that undoes it)
- `investigation_kit_ran` (array of tools called)
- `learned_pattern_id` (FK to `orchestrator_learned_patterns` if applicable)

If the audit row can't be written, the action shouldn't be taken. The audit row IS the accountability mechanism in the post-human-safety-net model.

## Self-correction loop (KAIZEN integration)

When a pattern's outcome success rate drops below threshold (measured by KAIZEN over a rolling window), the pattern auto-degrades to `supervised` until retrained. The agent stops acting on that pattern class until KAIZEN re-promotes it. This is automatic — no human action needed to degrade or re-promote.

Pattern degradation thresholds live in KAIZEN config, not in this rule.

## Resolution with rule 92 (work at the core)

Rule 92 says "if RUBEN/an agent isn't catching a class of issues, fix the agent, don't bandaid by hand-acting on each case." Rule 29 says "act on the in-flight case if it's verified + reversible + urgent." These compose, not contradict.

**The merge: when an agent acts on an in-flight case that should have been caught by another agent, the action goes through TWO logging steps:**
1. The normal audit_log row for the action itself
2. A `systemic_gap_detected` event in orchestrator_event_log pointing at the agent that should have caught it

If the same systemic_gap fires 3+ times within 24h, the audit cron auto-files an idea at `approval_tier=autonomous` to fix the upstream agent. Spot-fix + systemic-fix happen together, not as opposing choices.

## Cline's authority zone (extending this rule to Cline specifically)

Cline operates under this rule. Cline-specific:
- All DB writes via MCP tools that have a defined audit trail (safe_deploy, run_moodle_query for selects, execute_query for selects + audited inserts) are in-scope autonomous.
- Cline must run the investigation kit per the table above before declaring "needs Ruben."
- Cline must NOT default-route Vicky for things that would route to her under the rule — file the right ticket via the round-robin instead.
- Cline must include in `attempt_completion` the full audit trail of any autonomous actions, including reversal commands per rule 91 pickup-prompt format.

## What changed vs v1

| Aspect | v1 (deprecated) | v2 (this rule) |
|---|---|---|
| Default | Don't act unless 3 axes green | Act unless 3 conditions justify inaction |
| Investigation depth | One lookup ok | Full kit mandatory per case class |
| Hardfloor location | Enumerated in rule (broad "irreversible") | Lives in code, rule points to code |
| Blast measurement | Headcount (1/2-50/50+) | Removed — replaced with urgency + queue-pressure |
| Q-card / ruben_questions path | First-class escalation surface | Removed — replaced with orchestrator_ideas at autonomous tier per rule 38 |
| Human role | Safety net / gatekeeper | Comfort / warm follow-up, never default router |
| Vicky | Default assignee for many cases | NEVER default — CS round-robin instead |
| Empathy / operational | Conflated | Separated — agent does operational, human does warmth |
| Rule 92 conflict | Unresolved | Resolved — spot + systemic together, auto-files at 3 repeats |
| Capability awareness | Implicit | Investigation kit codified, capability catalog as follow-on |

## Source incidents

- **2026-05-07** v1 origin: chat dead-air for Linda Torres + 4 students.
- **2026-05-26** v2 trigger: tonight's role_assignment fix (20 EMT/cert students unblocked via single deterministic SQL) PLUS the parallel mistake of Cline drafting a Vicky-iMessage handoff for Aidan Rice and 3-4 others before running `verify_payment_state` on them. The drafting-the-Vicky-message-instead-of-running-the-MCP-tool behavior IS the chilling-effect bug v1 created. v2 is built to eliminate it.
- **2026-05-26** secondary signal: 14 active CS team members exist (`users WHERE is_cs=1 AND is_active=1`), Vicky is not one of them, and yet ticket assignment defaults heavily to her — the round-robin infrastructure exists but wasn't used because the rule didn't direct agents to it.

## Cross-references

- `.clinerules/29` (stub) — the in-prompt anchor pointing here
- `.clinerules/33` — verify_payment_state, part of money-case investigation kit
- `.clinerules/38` — Ruben-asks = autonomous-tier minimum; replaces v1's Q-card path
- `.clinerules/91` — pickup-prompt format for attempt_completion
- `.clinerules/92` — work at the core; v2 explicitly resolves the conflict

## Followups (file as orchestrator_ideas after this rule ships)

1. **Capability catalog table** — `agent_capabilities (agent_name, capability, code_location, current_limit, last_verified_at, status)` — single source of truth for what each agent can do autonomously. Replaces tribal knowledge.
2. **Empathy-followup ticket category** — new ticket category + auto-routing per the table above.
3. **CS round-robin helper** — `lib/cs_round_robin.php` exposing `pickCSAssignee()` so every agent uses the same algorithm.
4. **Queue-pressure detector** — cron that watches CS queue depth + activity, sets a flag the agents read for override decisions.
5. **Systemic-gap auto-idea-filer** — cron that watches `orchestrator_event_log` for repeated `systemic_gap_detected` events and auto-files autonomous-tier ideas per the rule-92 merge.

## Last updated

2026-05-26 — v2 rewrite. Replaces v1 (2026-05-07). Hardfloor stub at `~/Documents/Cline/Rules/29-agents-act-on-confidence-tier.md`.

# 29 — Agents default to action. Inaction requires justification.

Permanent hardfloor rule. Workspace-scoped. v2 (2026-05-26) replaces v1.

## The principle

**Agents act on payment-verified, schema-verified evidence. The default is action. Inaction is the deviation that needs justification.**

Justifying inaction means showing ALL three are true:
1. A human will materially handle this better than the agent (not just "humans should sign off")
2. The delay won't compound the harm (urgency check)
3. The case hits a human-required gate currently defined in code (not in this rule)

If any fails, the agent acts.

## Before declaring "needs human"

The agent MUST run the case-class investigation kit (full list in archive). "I ran one lookup and got null" is not investigated. Empty-without-kit-ran is a rule violation.

Money cases minimum: `verify_payment_state` + `find_authnet_by_email` + `find_authnet_by_name` + email_inbound receipt scan + Affirm.

When info is missing, ping the relevant peer agent before degrading. Not a council session — targeted query.

## Hardfloor lives in code, not in this rule

The rule does NOT enumerate human-required cases. Code-level limits (refund cap, etc.), gating ideas, and the agent capability catalog hold those. Rule only says: **check whether your action class has a code-level limit, respect it.**

## Routing (when a human IS the right call)

- Regulator / accreditation / state filing → Ruben
- Refund / payment / billing / academic concern → CS round-robin (Vicky's team, least-recent-active + lowest-open-ticket from `users WHERE is_cs=1 AND is_active=1 AND on_leave=0`)
- Vicky escalates outliers to Jon

**Vicky is NEVER the default router.** Use the round-robin.

## Empathy follow-up ≠ operational fix

Agent does the operational fix immediately. Empathy follow-up (warm human contact) routes in parallel per the table above when signals fire: legal-threat language, 3+ repeat contacts in 4h, or high-concentration severity words.

## Queue-pressure override

If the queue is deep enough that the case won't be handled in time (>50 open + no human active 60min, or case waiting >2h business / >6h overnight, or deadline-bound), the agent acts on the operational thing regardless. Log `queue_pressure_override=true`.

## Audit obligation

Every autonomous action writes a structured `orchestrator_event_log` row with before/after state, reasoning, reversal command, investigation_kit_ran. No audit row = action not taken.

## Compose with rule 92

When acting on an in-flight case that another agent should have caught, ALSO write a `systemic_gap_detected` event pointing at the upstream agent. 3+ in 24h auto-files an idea to fix it. Spot + systemic together.

## Deep version

Full text including investigation kit table, source incidents, v1-vs-v2 diff, follow-on ideas:

```
clinerules_lookup(rule_id="29")
```

Or `read_file ~/Documents/Cline/Rules-archive/29-agents-act-on-confidence-tier.md`.

## Last updated

2026-05-26 — v2 rewrite. Deep version in Rules-archive/. Source: tonight's stranded-students sweep, where v1's default-to-ask bias chilled investigation depth on Aidan Rice + 3 others before they'd been verified with `verify_payment_state`.

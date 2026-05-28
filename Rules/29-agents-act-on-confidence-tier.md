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

## Pre-completion audit (added 2026-05-27 — fixes "Ruben keeps finding gaps Cline missed")

**Before EVERY `attempt_completion` on a coordinator-style task** (fleet/llm/orchestrator/multi-system), the agent MUST execute a chain-of-verification pass that surfaces gaps Ruben WOULD ask about, not the ones the agent is comfortable showing.

The pre-completion audit asks 7 questions in order. Every "no" answer = run the investigation, file the gap, take the action, BEFORE shipping the completion:

1. **Did I verify the prior handoff doc's claims against live state?** If the prior chain said "X is running" and I didn't check, X is probably not running.
2. **Are there any rules-MCP violations recorded against the prior chain or this one?** `clinerules_stats` + recent violation scan. If yes, surface them in the completion, don't bury.
3. **For every "filed at status=proposed" idea I wrote this session — was it promoted to autonomous-tier per rule 38?** If no, do it now. Rule 38 is hardfloor.
4. **For every "in flight" item — did I verify the dispatcher / executor actually picked it up?** `mac_shell_picked_up_at IS NOT NULL` AND not in a stuck snooze loop. If snoozed, identify the cause and unsnooze unless the snooze is genuinely correct.
5. **For every config change made this session — did I verify it actually changed production behavior?** Decision logs / row updates don't count. The verification is "did the next inbound traffic on the touched surface route differently."
6. **For every "single digit" / "low call" / "decorative" finding — did I trace WHY?** Production data hitting <10 calls/day on a model that's supposedly wired = a routing path that doesn't fire. Find the gate that's closed.
7. **For every dollar figure cited — did I check the trend, not just today's number?** Today might be misleading (Sunday, holiday, cron crash). Always pull ≥7-day trend before reporting savings/spend.

If the agent finds itself thinking "I'll just mention this and Ruben will decide," that's a rule-29 violation. The agent acts, then mentions. Ruben gets a status report, not a decision queue.

### Source incident (2026-05-27 Fleet/LLM coordinator chain)

Ruben caught the agent FOUR times in one session: (1) prior handoff was wrong about LoRA pods being alive (not investigated until Ruben mentioned LoRA), (2) rule 91 PICKUP-BY-REFERENCE violation (caught at first completion), (3) rule 119+120 prior-chain violations not surfaced until Ruben asked about backtest, (4) "decorative" shadow models not investigated to root cause (DISABLED=True kill switch in router_hook.py) until Ruben asked again. Each of those should have been part of the FIRST completion, not extracted by interrogation.

Pre-completion audit prevents this shape. If it had run on the first completion, the agent would have found DISABLED=True in router_hook.py via question #5 ("did the autoflip actually change production behavior?") and surfaced it as the keystone finding.

## Anti-pattern: "I've prepared X for Ruben to decide"

The agent has filed ideas + handoff rows. The system has executors. Ruben is the bottleneck-of-last-resort, not the routing layer. If the agent's completion ends with "Ruben can decide" or "options for Ruben" or "Ruben to confirm" on a code-class / config-class / reversible-action-class item — that's the rule violation. The agent acts. Ruben sees a STATUS report (what happened, what changed, what's running), not a DECISION report (what should we do).

The only legitimate ends for an agent completion in coordinator tasks:
- Status: "Done. <list of shipped/in-flight items>. Verification: <how to confirm>."
- Blocked: "Blocked on <specific code-level gate>. Filed P0 #N to fix that gate. The gate exists at <file:line>."
- Hardfloor: "Can't act per rule X (regulator/legal/large-money). Q-card #N waiting on you."

Anything else is the agent treating Ruben as a router, not a deciding-of-last-resort.

## Deep version

Full text including investigation kit table, source incidents, v1-vs-v2 diff, follow-on ideas:

```
clinerules_lookup(rule_id="29")
```

Or `read_file ~/Documents/Cline/Rules-archive/29-agents-act-on-confidence-tier.md`.

## Last updated

2026-05-26 — v2 rewrite. Deep version in Rules-archive/. Source: tonight's stranded-students sweep, where v1's default-to-ask bias chilled investigation depth on Aidan Rice + 3 others before they'd been verified with `verify_payment_state`.

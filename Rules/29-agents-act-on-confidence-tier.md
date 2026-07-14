# 29 — Agents default to action. Inaction requires justification.

Permanent hardfloor rule. v3 (2026-06-25) trims v2's 28KB of case law to the core gate + essential tests. Full case law archived in `Rules-archive/29-case-law.md`.

## BINARY GATE (run BEFORE routing to a human OR listing an open thread)

**Before you route a case to a human OR list anything as an "open thread" in a pickup prompt, ask: "Can I do this right now with a tool I have?" If YES → DO IT. Do not list it. Do not route it.** This gate fires BEFORE any other consideration. The default is action. Inaction is the deviation that needs justification.

**The 2-second test:** scan every candidate "open thread" or "route to human" item. For each: do I have a tool (update_ticket, add_ticket_comment, create_idea, ssh_command, fix_moodle_enrollment, SQL write, safe_deploy, etc.) that performs this action? If yes → it is NOT an open thread. It is undone work. Do it now.

## The principle

Justifying inaction means showing ALL three are true:
1. A human will materially handle this better (not just "humans should sign off")
2. The delay won't compound the harm (urgency check)
3. The case hits a human-required gate defined in code (not in this rule)

If any fails, the agent acts.

## Three sneaky forms of inaction (all are violations)

1. **"Defer to the system"** — naming "the Fleet Agent / cron / executor will do it" is NOT acting if there's a known wiring gap. Verify the system CAN do X now; if not, do X directly or fix the wiring this session.

2. **"I don't have the artifact"** — missing a payment link, URL, section code, phone number is a RESEARCH task, not an escalation trigger. If it's discoverable (curl it, query it, call it), go get it and act. A human is only right when the missing thing is a *decision*, never when it's a *fact the agent can retrieve and verify*. Verify URLs resolve (HTTP 200) before sending.

3. **"Wait for parallel windows"** — telling Ruben to "wait for the other windows to finish" is forbidden. Every window works its own unit to done independently. Query live system state; don't speculate about other windows. Banned phrases: "wait for the other Cline windows," "let the parallel sessions complete first," "pause until the other windows are done."

## Unanswered Ruben questions are a hardfloor violation

If Ruben asks a direct question, the agent's completion MUST answer it inline. "I'll look into it" / "your call" / leaving it in a pickup prompt does not count. If answering requires investigation, do the investigation THEN answer.

## Routing (when a human IS the right call)

- Regulator / accreditation / state filing → Ruben
- Refund / payment / billing / academic concern → CS round-robin (least-recent-active + lowest-open-ticket from `users WHERE is_cs=1 AND is_active=1 AND on_leave=0`). **Vicky is NEVER the default router.**
- Vicky escalates outliers to Jon

**What humans CAN'T do (route to agent instead):** SQL changes, API calls, code edits, Moodle role/enrollment flips, QB invoice voids, Authnet refunds (<$300 cap), email composition. Vicky can: phone empathy, manual QB payment matching, approve refunds >$300. Jon can: policy overrides, >$1000 refund yes/no. Ruben can: regulator correspondence, business-shape decisions.

## Pre-completion audit (coordinator-style tasks)

Before EVERY `attempt_completion` on fleet/llm/orchestrator/multi-system tasks, verify:
1. Prior handoff claims checked against live state?
2. Rule violations from this/ prior chain surfaced (not buried)?
3. All "filed at proposed" ideas promoted to autonomous tier per rule 38?
4. All "in flight" items verified picked up (not snoozed) — via a rule-267 GATE B reconcile call (`list_decisions` / `get_idea_progress`) returning the LIVE executor state, NOT a filing-time memory?
5. **Every filed idea's disposition tag in the rule-91 pickup prompt reflects the verified live executor state** (deployed / executing / queued / blocked) — NOT the filing action? `[approved:autonomous]` in a final prompt = audit FAIL (ambiguous between "executing" and "queued").
6. Config changes verified to change PRODUCTION behavior (re-run failing case end-to-end, not grep)?
7. Low-call / decorative findings traced to WHY?
8. Dollar figures checked against ≥7-day trend?

If thinking "I'll mention this and Ruben decides" → rule-29 violation. The agent acts, then mentions. Ruben gets a STATUS report, not a decision queue.

## Pickup-prompt-as-decision-queue is forbidden

The rule-91 PICKUP PROMPT is NOT a parking lot. If an "open thread" item is a reversible action the agent has tools for → DO IT, don't list it. Only list genuine human-policy decisions (refund amount, regulator wording) or IMMINENT-budget-deferred work.

**Ambiguous-disposition tags are also forbidden.** Ruben reads the tag to decide whether to close the thread or act. A tag like `[approved:autonomous]` is ambiguous between "the executor is building it right now" and "it is sitting in a queue" — both produce the same filing action but need opposite responses from Ruben. The reconcile call (rule 267 GATE B) returns the live state that disambiguates them; the rule-91 tag must carry that verified state. If you cannot map the reconcile return to a verified tag, the thread is NOT closeable — act on it (rule 29) or re-file.

## Alternative-path discipline (failed access = try next path, never ask)

"Permission denied" on one SSH path is NOT a blocker — try the next path (different port/key/MCP tool/host). Log the gap via `fleet_act mark_host_status=degraded`. File a repair idea. Never ask "want me to proceed?" after a single failed attempt or after Ruben already said yes.

## Audit obligation

Every autonomous action writes a structured `orchestrator_event_log` row with before/after state, reasoning, reversal command, investigation_kit_ran. No audit row = action not taken.

## Queue-pressure override

If the case won't be handled in time (>50 open + no human active 60min, or waiting >2h business / >6h overnight, or deadline-bound), the agent acts regardless. Log `queue_pressure_override=true`.

## Cross-refs

- Rule 91 — pickup prompt shape (Gate 0 here = Gate 0 there)
- Rule 38 — Ruben-asked = autonomous tier minimum
- Rule 92 — fixing broken systems IS the work
- Rule 137 — Definition-of-Done + self-converge
- Full case law + source incidents: `Rules-archive/29-case-law.md`

## Source

2026-05-26 v2, 2026-06-25 v3 trim. Core principle unchanged: agents act on payment-verified, schema-verified evidence. The default is action.
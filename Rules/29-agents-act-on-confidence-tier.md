# 29 — Agents default to action. Inaction requires justification.

Permanent hardfloor rule. v3 (2026-06-25) trims v2's 28KB of case law to the core gate + essential tests. Full case law archived in `Rules-archive/29-case-law.md`.

## BINARY GATE (run BEFORE routing to a human OR listing an open thread)

**Before you route a case to a human OR list anything as an "open thread" in a pickup prompt, ask: "Can I do this right now with a tool I have?" If YES → DO IT. Do not list it. Do not route it.** This gate fires BEFORE any other consideration. The default is action. Inaction is the deviation that needs justification.

**The 2-second test:** scan every candidate "open thread" or "route to human" item. For each: do I have a tool (update_ticket, add_ticket_comment, ssh_command, fix_moodle_enrollment, SQL write, safe_deploy, write_server_file, etc.) that performs THE ACTUAL WORK? If yes → it is NOT an open thread. It is undone work. Do it now.

**`create_idea` is NOT an action that satisfies this gate.** Filing an idea is *recording* the work, not *doing* it. An idea filed for work you had the tools to finish this session is a rule-29 violation that PASSES every downstream gate (rule 91's bare-number scan, rule 267's reconcile, `clinerules_validate_completion`) because those gates only verify that an idea number EXISTS, never whether it should have existed. That makes it the most dangerous shape of inaction: it looks like compliance. See rule 208 STEP 0.

**Before ANY `create_idea` call, name the blocker** that stops you doing it right now: a missing tool, a human-policy gate (money over cap / regulator / irreversible), a genuinely multi-session scope, or an exhausted budget. If you cannot name one, cancel the call and do the work. **The tell:** if your idea description contains a specific implementation plan naming the files and queries, you had enough to execute it.

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
5b. **TAG-SCAN audit:** does the ENTIRE `result` (not just the pickup prompt block) contain ANY bare `#NNNN` without a disposition bracket? If yes → audit FAIL — the agent shipped a raw idea number Ruben cannot interpret. Tag every bare number before shipping. The rule-91 context-scan (primary gate — scan result text directly in context, no subprocess) catches these mechanically — run it before `attempt_completion`. A bare `#17537` in a "Where we left off" prose paragraph is exactly this violation. Python/grep/awk subprocesses are unreliable on this host and should NOT be the primary check (systemic FD issue, idea #17619 [deployed]).
6. Config changes verified to change PRODUCTION behavior (re-run failing case end-to-end, not grep)?
7. Low-call / decorative findings traced to WHY?
8. Dollar figures checked against ≥7-day trend?

If thinking "I'll mention this and Ruben decides" → rule-29 violation. The agent acts, then mentions. Ruben gets a STATUS report, not a decision queue.

## Pickup-prompt-as-decision-queue is forbidden

The rule-91 PICKUP PROMPT is NOT a parking lot. If an "open thread" item is a reversible action the agent has tools for → DO IT, don't list it. Only list genuine human-policy decisions (refund amount, regulator wording) or IMMINENT-budget-deferred work.

**Ambiguous-disposition tags are also forbidden.** Ruben reads the tag to decide whether to close the thread or act. A tag like `[approved:autonomous]` is ambiguous between "the executor is building it right now" and "it is sitting in a queue" — both produce the same filing action but need opposite responses from Ruben. The reconcile call (rule 267 GATE B) returns the live state that disambiguates them; the rule-91 tag must carry that verified state. If you cannot map the reconcile return to a verified tag, the thread is NOT closeable — act on it (rule 29) or re-file.

## Transient backend-busy states are never a user-facing excuse (2026-07-23)

**A "server busy" / gateway-timeout / 502-503-504 / stream-dropped condition is infrastructure noise, not a fact the end-user needs to hear.** Any customer-facing agent or tool (Argus, CFA email/chat/SMS/voice) that surfaces a message like "the server was busy and could not answer, press Send to try again" WITHOUT first attempting automatic retries through the frankenstein-llm spill ladder is committing a rule-29 violation — it is choosing to make the human do the retry work the system should do itself.

**The gate:** before ANY user-facing error/failure message ships, ask: "Did the system retry through the spill ladder first?" If no → this is not a real failure yet, it's an untried recovery path. Wire the retry (2-3 attempts against frankenstein-llm's local-first ladder, short backoff) BEFORE ever telling the user. If retries are exhausted, the fallback message must never dead-end the interaction — requeue the original request and tell the user work is continuing in the background, not that they must manually resend.

**Source incident:** 2026-07-23 — Argus terminal (`argus_download.php`, `argus-chrome/sidebar.js`) showed "The server was busy reloading and could not answer right now... press Send to try again" on any stream failure or non-retryable gateway error, with zero automatic recovery attempt on that failure class. Ruben live-reproduced it and called it out directly: "The user doesn't need to know the server is busy as an excuse not to do something either... I already explained how this is supposed to work." Fixed same-session via a macro-retry wrapper (3 auto-retries before ever showing a message, then a non-dead-end "still working in background" fallback that requeues the request) — see idea #18806.

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
## Amendment (from reversal, 2026-08-18 23:02 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787014605175
- RCA bucket: wrong premise
- Trigger pattern: Reading an automated system's gate/hold label (deploy_human_gated, regression_risk_review, needs_guidance, HUMAN_GATED) as evidence that a human decision is outstanding, and listing the item as human-
- Reversal note: I listed 5 impl_failed ideas as "genuine human gates, need your review" purely because the executor had labeled them deploy_human_gated / regression_risk_review. Ruben asked "what do we do per rule 29 here?" On actually running the gate: 3 of the 5 already had approved_by populated (Ruben, Jon Thompson, agent-core) and only needed the documented one-shot auto_deploy_override; 1 needed no build because the change was already on disk; 1 rested on a stale premise (the grievance it targeted was resolved 5 days earlier). Zero required a human. Amendment: a gate/hold label emitted by an automated system states what THAT SYSTEM may not do autonomously, never who owns the decision. Before calling any item human-only, the binary gate must additionally check (a) whether an approval record already exists on the row, and (b) whether the described change is already present in the target artifact. An item carrying a prior human approval is by definition NOT awaiting a human.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

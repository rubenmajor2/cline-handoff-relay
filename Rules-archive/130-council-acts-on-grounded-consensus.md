# 130 — The Daystrom Council acts on grounded consensus. It does not park work for humans.

Permanent rule. Workspace-scoped. Source: 2026-06-02 Ruben directive during the #9090 close-loop session: *"is the council acting per rule 29? A rule of its own like rule 29. I think it should."*

This is rule 29 (agents default to action) applied to the Daystrom Council specifically. The council is an agent like any other. When it reaches consensus on a concrete ops action, that action is subject to the same act-or-route discipline as every other agent surface.

## The bright-line rule

**Every `daystrom_ops_actions` row the council commits MUST be grounded against live DB state and disposed via rule-29 act-or-route at commit time — never parked open for a human to find later.**

The council's job is NOT to generate a to-do list for Jon/Vicky/Ruben. It is to act on what it can, route only what genuinely needs a human, and dismiss what it hallucinated. Parking an action open (the old behavior: extract → insert status='open' → walk away) is the council-shaped version of the rule-29 chilling-effect bug.

## The three dispositions (same as rule 29)

For each committed action, the shared `lib/CouncilActionRouter::disposeAction()` grounds it then picks ONE:

1. **DISMISS (ungrounded)** — the action references IDs that don't join. Two known classes:
   - **grievance↔student mismatch**: the action pairs "grievance #N" with "student SLUG" but `grievances.student_id` for #N is a *different* student. The council hallucinated the pairing.
   - **false suspension premise**: the action asserts day-30 delinquency / imminent suspension, but the student's `course_end_date` is still in the future with no `drop_date`/`fail_date`.
   On dismiss, publish a `council_grounding_required` pattern to the bus (#9077) so future councils gate on grounding before committing.

2. **ACT (agent-doable)** — `owner_role='agent'` OR the action is "surface the specific blocker IDs". The router resolves the real blocker (ExternshipRequest status, student state) and writes it into the completion note. No human needed. Mark `done`.

3. **ROUTE (genuine human-policy/money)** — a real judgement call only a human can make (Vicky phone call, Jon policy override, money over the agent cap). Log to `promise_ledger` + assign CS round-robin, mark `escalated`. Per rule 29's "what CS/Vicky/Jon literally CANNOT do": route here ONLY when the human actually has a lever the agent lacks.

## Why this rule exists (source incident)

2026-06-02: the council had committed 11 ops_actions over several days, all parked `status='open'`. On inspection: grievances #61/#63 were paired with students 26209A-14 / 26206T-06 — but #61/#63 actually belong to Kevin Quezada (25727A) and Ishita Aggarwal, NOT Jason Schuerhoff / Jakub Dudek. The "day-30 suspension" framing was also false (both students' course_end was 2026-06-24, three weeks out). The council had **hallucinated the pairings and then handed the hallucination to a human as a task**. A human acting on "resolve grievance #61 for 26209A-14" would have wasted time on a nonexistent linkage.

Grounding + act-or-route at commit time catches this: 4 of the 11 were dismissed as ungrounded, 2 acted (real ER blocker surfaced), 5 routed with grounded context.

## Where this is wired (rule 92 — at the core, one source of truth)

- `lib/CouncilActionRouter::disposeAction($pdo, $actionRow, $bus, $dry)` — the single grounding + act-or-route engine.
- `cron/cron_daystrom_council.php` — calls it at session close, right after the ops-actions extraction loop, so nothing is ever parked.
- `cron/cron_council_action_driver.php` (every 2h) — sweeps any backlog row that slipped through (defense in depth) using the same engine.

Both callers use the SAME lib. Do not fork the logic.

## Self-check before the council commits an ops action

1. *Does this action name a grievance id AND a student slug?* → the grievance MUST join to that student via `grievances.student_id`. If it doesn't, it's a hallucinated pairing — dismiss, don't commit.
2. *Does it claim suspension / day-30 delinquency?* → verify `course_end_date` has passed AND `drop_date`/`fail_date` is set. If not, false premise — dismiss.
3. *Can the agent surface the real blocker itself?* → act, don't route.
4. *Is a human the only one who can do this (phone call, policy, money over cap)?* → route to promise_ledger + CS. Otherwise the agent acts.

## Cross-references

- `.clinerules/29` — agents default to action (this rule is its council specialization)
- `.clinerules/92` — fix at the core (the router is shared, not forked)
- `.clinerules/38` — Ruben-asked = autonomous tier (the disposal is autonomous)
- `.clinerules/46` — corrections loop back to RUBEN + KAIZEN (the grounding pattern goes to the bus)

## Last updated

2026-06-02 — initial. Source: Ruben asked whether the council acts per rule 29 and requested a rule of its own. Wired `CouncilActionRouter` into the council's commit block + the backlog driver; both ground each action and dispose it (act / route / dismiss) instead of parking it open.

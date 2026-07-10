# 109 — Every idea / file / ticket / thread mentioned in attempt_completion MUST carry an explicit disposition status

Permanent rule. Workspace-scoped. Source: 2026-05-22 18:55 PT during task #1779470044277 (cline_mail_outage_2026_05_22) wrap-up. Ruben directive verbatim:

> *"You didn't tell me whether or not the open threads were ideas approved autonomous or deferred or what their status was. Per cline rule I need those statuses if you don't have a rule like that. I need you to make one"*

Companion to .clinerules/03 (Resume Kit shape), .clinerules/07 (task_id discipline), .clinerules/12 (Q-cards on cross-chain policy), .clinerules/38 (Ruben-asks = autonomous-or-shipped), .clinerules/91 (every-completion-needs-pickup-prompt), EXECUTE_ORDER_66 (wrap-up protocol). This rule is the disposition-status layer those rules implicitly assumed.

## The bright-line rule

**Every concrete deliverable named in `attempt_completion.result` — orchestrator idea, ticket, ruben_questions Q-card, file touched, chain/cron deployed, person paged, fix shipped, follow-up needed — MUST be tagged with one of the disposition tokens below. No bare ID references. No "filed idea #5875" without saying what state it's in.**

Without the disposition, Ruben (or the next agent) has to open each row to learn whether it's been approved for autonomous execution, sitting at `proposed` waiting for human review, deferred to a later session, blocked on something external, or already shipped. That's friction this rule eliminates.

## The disposition tokens (canonical, in priority order)

| Token | Meaning | When to use |
|---|---|---|
| **shipped** | Code is in production right now. Tested. Reversible if needed. | After safe_deploy lands a real change |
| **landed** | DB row INSERT/UPDATE that the world can act on (a ticket comment posted, a chain row created, etc.) | After a meaningful DB write |
| **approved (autonomous)** | Filed at `orchestrator_ideas.status='approved'` so RUBEN executor will pick it up at next tick without further review | Ruben-directed ideas per rule 38 |
| **approved (supervised)** | Filed at `orchestrator_ideas.status='approved'` but with a note that human should review the executor's plan before run | Non-trivial idea, Ruben wants eyes on each step |
| **proposed** | Filed at `orchestrator_ideas.status='proposed'`. Waiting for Ruben triage at /orchestrator_ideas.php | Background-noise ideas Ruben didn't directly request |
| **pending (q-card)** | Filed at `ruben_questions.status='pending'`. Waiting for yes/no decision per rule 12 | Cross-chain policy questions, irreversible / large-blast actions |
| **answered (q-card)** | Settled inline this session; q-card filed retroactively at status='answered' per rule 12 for the audit trail | Decision was made in conversation, needs durable record |
| **deferred** | Identified during this session but explicitly punted to a later task | Out of scope; flagged for backlog |
| **blocked** | Cannot ship until some external precondition lands | Waiting on ownership transfer, vendor approval, payment, regulator, hardware, etc. |
| **abandoned** | Considered and explicitly dropped (no longer relevant after we learned X) | Scope changed during the session; don't leave it hanging |

## Required placement

Every section of the attempt_completion Resume Kit (per rule 03 shape) that names a concrete deliverable gets the token inline.

### IDEAS FILED (this wrap-up)

Format: `- idea #<N> [<token>] — <title>`. Examples:

- idea #5875 **[approved (autonomous)]** — ensure_mail_forwards.sh v2 (controller portforward DB)
- idea #5876 **[approved (autonomous)]** — Watchdog on /var/log/mail_forwards.log with Twilio paging
- idea #5877 **[approved (autonomous)]** — External 5-min prober via check-host.net
- idea #5878 **[approved (autonomous), blocked on ops]** — UDM ownership transfer (P0 ops; can't ship as code)
- idea #5879 **[approved (autonomous)]** — Cline mail-outage autonomy retro
- idea #5882 **[approved (autonomous)]** — Operational learnings + toolkit + .clinerules candidates

### Q-CARDS FILED (this wrap-up)

Format: `- ruben_questions #<N> [<token>] — <title> [defaults]`. Examples:

- ruben_questions #4501 **[pending (q-card)]** — Should we treat all California externship rejections as approval-with-stipulation? [default: yes, per rule 60]
- ruben_questions #4498 **[answered (q-card)]** — How should we handle student X's quiz reset? [answered inline 18:42 PT]

### TICKETS / TKT- references

Format: `- TKT-<id> [<token>] — <one-line topic>`. Examples:

- TKT-20260522-D7DD24EE **[shipped]** — closed and posted reply with refund confirmation
- TKT-20260522-EF12345A **[pending (q-card)]** — Vicky decision required on credit amount
- TKT-20260522-AA98BBCC **[deferred]** — non-urgent; queued for next session

### FIXES SHIPPED / FILES TOUCHED / CHAINS DEPLOYED

Format: `- <path or chain slug> [<token>] — <one-line summary>`. Examples:

- /var/www/emtskills/cron/cron_ai_ticket_agent.php **[shipped]** — added share-balance-orphan pickup at line 247
- /var/www/emtskills/scripts/ensure_mail_forwards.sh **[blocked]** — v2 rewrite blocked on UDM ownership transfer per idea #5878
- chain_zoom_watchdog_v2 **[landed]** — session_handoffs row inserted; cron will execute at next tick

### OPEN THREADS / NEXT MOVES

Format: `- [<token>] <one-line topic>`. Examples:

- **[deferred]** Audit the rest of /etc/cron.d/ for log-redirect targets to add to self_heal_heartbeat (covered by idea #5882 item 1, but bigger sweep)
- **[blocked]** Generalized #5876 watchdog requires #5882 item 1 (self_heal_heartbeat table) to land first
- **[pending (q-card)]** Should the watchdog page Vicky directly or route through Jon first?

## What "deferred" requires

`deferred` is NOT a place to hide things you should have done. When using it, also note:

1. WHY deferred (out of session scope, blocked on something, lower priority than other items)
2. WHERE the work will resurface (orchestrator_ideas row, ticket, ledger row, future session pickup)
3. WHO is on the hook to pick it up next (Cline next session / Ruben / Vicky / Jon)

Bad: `- [deferred] cleanup`. Good: `- [deferred] cleanup of legacy cron files older than 90 days — out of scope, lower priority than the mail outage fix; filed as orchestrator_ideas #5883 at status=proposed for next monthly maintenance window.`

## What "blocked" requires

`blocked` requires naming the unblocker:

Bad: `- [blocked] ensure_mail_forwards v2`. Good: `- [blocked] ensure_mail_forwards v2 Track A (Cloud Connector path) blocked on UDM ownership transfer #5878. Track B (LAN SSH restore) is unblocked and immediate; consider shipping Track B first.`

## What "approved (autonomous)" implies for the next session

Once an idea is `approved (autonomous)`, the RUBEN executor will attempt to pick it up at the next cron tick (within minutes). If a fresh Cline session opens and sees the idea is still in `approved` status hours later, that means RUBEN is either stuck, deferred it, or hasn't gotten to it. Investigate before re-filing.

The Cline session that originally filed the idea is NOT obligated to also ship it manually — that's the whole point of autonomous tier. But if the work is high-leverage and Cline has cycles, shipping it manually in the same session is even better (per rule 38: "shipped now OR autonomous-approved").

## Audit trail at the SQL layer

The disposition tokens map to actual DB column values, so future-Cline can grep for them:

```sql
-- find every approved-autonomous idea filed today
SELECT id, title FROM orchestrator_ideas
WHERE status='approved' AND DATE(created_at)=CURDATE();

-- find every blocked idea (mention 'blocked' in description)
SELECT id, title FROM orchestrator_ideas
WHERE description LIKE '%blocked on%';

-- find every Q-card pending decision
SELECT id, title FROM ruben_questions WHERE status='pending';
```

## Self-check before any attempt_completion

Ask: *"For every concrete ID or file path I just named in the result body, is the disposition explicit?"* If I have to flip a tab or run SQL to know "is this idea approved or just proposed?", the wrap-up is broken. Rewrite.

## Cross-references

- .clinerules/03 task-completion-resume-kit — the Resume Kit shape this rule extends
- .clinerules/07 task_id discipline — every row in the ledger references one canonical task_id
- .clinerules/12 cross-chain Q-cards — destination for `pending (q-card)` / `answered (q-card)` rows
- .clinerules/38 Ruben-asks = autonomous-or-shipped — establishes which tier directed ideas land at
- .clinerules/91 every-completion-needs-pickup-prompt — pickup prompts in /Open Threads section must also use these tokens
- EXECUTE_ORDER_66 — wrap-up protocol; this rule fills in the disposition that order 66's IDEAS FILED + OPEN THREADS sections require

## Source incident

2026-05-22 18:55 PT — mid-wrap-up on the 15-hour mail outage incident (task #1779470044277), I (Cline) sent an attempt_completion that listed 6 orchestrator ideas (#5875, #5876, #5877, #5878, #5879, #5882) by ID and title but did NOT carry their disposition. Ruben pointed out he couldn't tell from the wrap-up which were approved-autonomous, which were sitting at proposed, which were blocked on ownership transfer. He correctly required this rule.

## Last updated

2026-05-22 19:04 PT — initial. Rule 109. Filed per Ruben directive in the same session that surfaced the gap.

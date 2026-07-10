# 168 — RUBEN ops: resolve-then-CLOSE, never refile. Ticket URL in chat = existing ticket. LOOP CAP = 2.

Permanent rule. Workspace-scoped. Source: 2026-06-22 — analysis of TKT-20260601-202C1E91 (Jacob Soukup, ticket 7386) which looped 8+ RUBEN AI "needs Vicky" / "findings" comment cycles over 5 days (June 16-20), was self-fixed on June 20 (flipped is_duplicate=0), but is STILL Pending as of June 22 — never closed. Combined with the broader pattern of RUBEN refiling new tickets for existing issue URLs posted in staff chat.

## The bright-line rule (4 clauses)

### 1. Ticket URL in chat = EXISTING ticket — never file a new one

When a staff member posts a ticket URL in ops chat (Discord, iMessage, Team Hub, email), that URL ALREADY points to an existing ticket. The agent MUST NOT:
- File a new ticket in the tickets table
- Insert a new `ruben_questions` / `session_handoffs` row for the same issue
- Create a duplicate "investigation" ticket

Instead: open the existing ticket, read its full history, and continue working on the existing thread. A duplicate ticket for the same issue is never the answer.

### 2. Resolve-then-CLOSE — never ack-and-loop

After the agent diagnoses and applies the fix (or routes to the correct human), the ticket MUST be moved to a terminal status:
- If the agent resolved it: set status=Resolved immediately after the fix. Then CLOSE within 1 hour (or set a close-at timestamp).
- If the agent handed off to a human: add ONE comment naming who owns it + why, set status=In Progress / Waiting as appropriate. Do NOT add more "findings" / "checking" / "needs X" comments after the handoff. Extra comments on a routed ticket are the loop.
- If the agent cannot resolve and the ticket is stuck: set status=Waiting (for external input) or Closed (if no action possible). Never leave a ticket Pending-without-action indefinitely.

**Never "ack-and-loop":** acknowledging a ticket by posting "looking into it" / "needs X" / "handing to Y" without closing the loop is the #1 source of ticket drift. Every comment on a ticket must either (a) be immediately actionable toward resolution, or (b) be the terminal handoff comment.

### 3. LOOP CAP = 2 — two "needs Vicky"/"findings" posts on one ticket → escalate ONCE

A single ticket may accumulate multiple agent comment cycles. The cap:
- **First comment cycle**: agent investigates, posts findings, routes to the appropriate human (Vicky / Jon). This is normal.
- **Second comment cycle**: the ticket came back (or a new agent/poll cycle saw it). Agent re-checks the status. If the original findings still hold and the human hasn't acted, the agent does NOT re-post the same findings. Instead, the agent:
  1. Posts ONE escalation comment: "This ticket has been routed to [human] since [date]. Needs human action: [specific one-line ask]. Escalating."
  2. Changes status to reflect the escalation (e.g., In Progress -> Waiting for reply, or flags as escalated).
  3. Stops. No more polling, no more re-analysis cycles on the same unresolved ticket.
- **Third+ cycles**: the agent's LOOP CAP is hit. If the same ticket keeps popping into scope, the agent notes it ONCE in HANDOFF_NOTES as a stale-escalation pattern and ignores further cycles. Do NOT keep adding thoughts to a capped-out ticket.

Source incident: **TKT-20260601-202C1E91 (ticket 7386)** — Jacob Soukup portal access issue. Created 2026-06-01. Between June 12 and June 20, RUBEN AI posted 8+ comment rounds on this single ticket, each saying some variant of "needs Vicky" / "findings for Vicky" / "handing to Vicky." The ticket was self-fixed on 2026-06-20 (comment 108591: flipped Students.is_duplicate=0), yet as of 2026-06-22 the status is still Pending — never Resolved, never Closed. 8 rounds of re-investigation on a ticket that should have been closed after the first route-to-human or immediately upon self-fix.

### 4. Honest close-the-loop messaging — no false states, no chat IDs, no em dashes

When posting the terminal comment on a resolved ticket:
- State what was fixed, in plain language. "Flipped is_duplicate=0, portal now accessible. Jacob can log in with 26211FT-15." Not "investigated and resolved."
- If a new artifact was created (a new ticket for a DIFFERENT issue, a new ruben_questions row for a genuinely NEW question), name the real entity and its ID. Do NOT say "ticket filed" when no ticket was filed — that's a false state. Per rule 06 (no lying) + rule 81 (truthful reporting across surfaces).
- Do NOT include chat IDs (Discord channel IDs, iMessage chat IDs) in ticket comments — those are internal routing metadata, not relevant to the ticket's resolution narrative. Per rule 01 (voice persona).
- No em dashes in any ticket or ops-communication text. Use commas, colons, or periods. Per rule 01.

## Self-check before posting ANY ticket comment

1. *Is this ticket already in its terminal state (Resolved / Closed)?* If yes, do NOT add another comment. Close the ticket instead.
2. *Has this ticket already had 2+ "findings/routed to human" comment cycles?* If yes, the LOOP CAP is hit — post exactly ONE escalation comment or ignore.
3. *Am I about to post a "looking into it" / "findings" / "needs X" comment that doesn't change the ticket's trajectory?* If yes, do NOT post it. Either take a concrete action or route once and stop.
4. *Is the ticket URL from chat an existing ticket?* If the URL starts with `https://emsuniversity.com/emtskills/routes/ticket_view.php?id=` or similar, it IS an existing ticket. Do not file a duplicate.
5. *Does my terminal comment honestly describe what happened?* If it says "ticket filed" but no new ticket exists, rewrite. No false states.

## Cross-references

- Rule 90 — (related: ticket triage / answer routing)
- Rule 81 — truthful reporting across surfaces (no false "ticket filed" claims)
- Rule 46 — every agent correction loops back to RUBEN + KAIZEN (the cap prevents correction loops from becoming infinite)
- Rule 01 — voice & persona: no em dashes, no chat IDs in ticket comments
- Rule 92 — work at the core, not bandaids (fix the loop-generating behavior, not the individual ticket)
- Rule 29 — act on confidence tier (resolve-and-close is the default action; deferring with another "needs Vicky" comment is inaction)

## Source incident

TKT-20260601-202C1E91 (ticket #7386) — Jacob Soukup. Created 2026-06-01 for student portal access. Between June 12 and June 20, RUBEN AI posted 8+ investigation-and-route-to-human comments, all saying effectively the same thing ("needs Vicky / findings for Vicky / handing to Vicky"). The actual fix (flip is_duplicate=0) was found and applied on June 20 by comment 108591. As of June 22, the ticket is still Pending — never resolved, never closed. The 8-cycle loop is the canonical failure this rule prevents. Total comment count on a single ticket: 22 (8 from RUBEN AI alone).

## Last updated

2026-06-22 — initial. Source: Window D, COPY PROMPT 4 — "Resolve-then-close-no-refile" rule from RUBEN ops triage analysis.
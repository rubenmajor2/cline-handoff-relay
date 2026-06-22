# 168 — RUBEN ops: resolve-then-CLOSE, never refile. Ticket URL in chat = existing ticket. LOOP CAP = 2.

Permanent rule. Workspace-scoped. Source: 2026-06-22 — analysis of TKT-20260601-202C1E91 (Jacob Soukup, ticket 7386) which looped 8+ RUBEN AI "needs Vicky" / "findings" comment cycles over 5 days (June 16-20), was self-fixed on June 20 (flipped is_duplicate=0), but is STILL Pending as of June 22 — never closed. Combined with the broader pattern of RUBEN refiling new tickets for existing issue URLs posted in staff chat.

## The bright-line rule (4 clauses)

### 1. Ticket URL in chat = EXISTING ticket — never file a new one

When a staff member posts a ticket URL in ops chat (Discord, iMessage, Team Hub, email), that URL ALREADY points to an existing ticket. The agent MUST NOT:
- File a new ticket in the tickets table
- Insert a new `ruben_questions` / `session_handoffs` row for the same - Insert a new `ruben_questions` / `session_handoffs` row for the same - Insert a new `ruben_questions` / `sessd continue working on the existing thread. A duplicate ticket for the same issue is never the answer.

### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ##priate### 2. ### 2. ### 2. ###ngs" / "check### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### ute### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ###). Nev### 2. ### 2. ### 2. ### 2. ### 2. ###on ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. ### 2. # terminal handoff comment.

### 3. LOOP CAP = 2 — two "needs Vicky"/"findings" posts on one ticket → escalate ONCE

A single ticket may accumulate multiple agent comment cycles. The cap:
- **First comment cycle**: agent investigates, posts findings, routes to the appropriate human (Vicky / Jon). This is normal.
- **Second comment cycle**: the ticket came back (or a new agent/poll cycle saw it). Agent re-checks the status. If the original findings still hold and the human hasn't acted, the agent does NOT re-post the same findings. Instead, the agent:
  1. Posts ONE escalation comment: "This ticket has been routed to [human] since [date]. Needs human action: [specific one-line ask]. Escalating."
  2. Changes status to reflect the escalation (e.g., In Progress -> Waiting for reply, or flags as escalated).
  3. Stops. No more polling, no more re-analysis cycles on the same unresolved ticket.
- **Third+ cycles**: the agent's LOOP CAP is hit. If the same ticket keeps popping into scope, the agent notes it ONCE in H- **Third+ cycles**: le-- **Third+ cycles**: the agent's LOOP CAP is hit. If the same ticket keeps popping into st ticket.

Source incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: **TKT-20260601-202C1E91 (ticket 7386)** is sinSource incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: **TKT-20260601-202C1E91 (ticket 7386)** is sinSource incident: **TKT-20260601-202Cstill Pending — Source incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: *y uSource incident: **TKT-20260601-202C1E91 (ticket 7386)** — JaSource incident: **TKT-20no em dashes

When postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhenagWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhenagWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhen postWhenagWhen postWhen postWhen postWhen postWhen postWhen p, name the real entity and its ID. Do NOT say "ticket filed" when no ticket was filed — that's a false state. Per rule 06 (no lying) + rule 81 (truthful reporting across surfaces).
- Do NOT include chat IDs (Discord channel IDs, iMessage chat IDs) in ticket comments — those are internal routing metadata, not relevant to the ticket's resolution narrative. Per rule 01 (voice persona).
- No em dashes in any ticket or ops-communication text. Use commas, colons, or periods. Per rule 01.

## Self-check before posting ANY ticket comment

1. *Is this ticket already in its terminal state (Resolved / Closed)?* If yes, do NOT add another comment. Close the ticket instead.
2. *Has this ticket already had 2+ "findings/routed to human" comment cycles?* If yes, the LOOP CAP is hit — post exactly ONE escalation comment or ignore.
3. *Am I about to post a "looking into it" / "findings" / "needs X" comment that doesn't change the ticket's trajectory?* If yes, do NOT post it. Either take a concrete action or route once and stop.
4. *Is the ticket URL from chat an existing ticket?* If the URL starts with `https://emsuniversity.com/emtskills/routes/ticket_view.php?id=` or similar, it IS an existing tick4. *Is the ticket URL from chat an existing ticket?* If the URL starts with `https://emsuniversity.com/emtskills/routes/ticket_view.php?id=` or similar, it IS an existing tick4. *Is the ticket URL from cha (4. *Is the ticket URL from chat an existing ticket?* If the URL starts with `https://emsuniversitse "t4. *Is the ticket URL from chat an every agent correction loops back to RUBEN + KAIZEN (the cap prevents correction loops from becoming infinite)
- Rule 01 — voice & persona: no em- Rule 01 — voice & persona: no em- Rule 01 — voice & persona: no em- Rule 01 — voice & persona: no em- Rule 01 — voice & persona: no em- Rule 01 29 — act on confidence tier (resolve-and-close is the default action; deferring with another "needs Vicky" comment is inaction)

## Source incident

TKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacob SoukupTKT-20260601-202C1E91 (ticket #7386) — Jacono-refile" rule from RUBEN ops triage analysis.

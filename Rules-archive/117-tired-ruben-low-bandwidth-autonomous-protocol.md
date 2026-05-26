# 117 — Tired Ruben Rule: Low-Bandwidth Autonomous Protocol

Permanent rule. Workspace-scoped.

## Source incident

2026-05-25/26, task ending ~00:06 PT 2026-05-26. Raenah Tee case (26711FT-08). After a long session of multi-agent post-mortem, Ruben said:

> *"Rebase, I am getting tired, i need you to act autonomously with high confidence issues remaining, give proposals with time deadlines if i don't accept to act how you would act if I don't reply in 12 hours via email on any outstanding on those, approve, deny modify button and then make the rest ideas and questions"*

Later: *"Can we call this the Tired Ruben rule and make it a cline rule if I cite it?"*

The session demonstrated the pattern — high-confidence DB patches shipped immediately, student-facing corrective emails queued as tier-2 drafts with 12h auto-send deadlines, systemic fixes filed as `orchestrator_ideas` at `status=approved`, policy questions filed as ideas with `[QUESTION]` prefix.

## The five-tier protocol

When Ruben is at low bandwidth (end-of-day, mid-session context drain, "rebase and wrap"), apply this tier assignment for every pending action:

---

### Tier 1 — Act now, report in attempt_completion

**Criteria:** high confidence (deterministic SQL match, schema-verified, pattern with `confidence ≥ 0.85` in `orchestrator_learned_patterns`) + reversible + small blast radius (1 student, 1 ticket, 1 row).

Per `.clinerules/29` (act on confidence tier): this is the green lane. **No Q-card. No proposal. No draft. Just do it and log it.**

Examples that belong here:
- Posting an internal ticket comment with correct data
- Inserting an `orchestrator_event_log` row
- Marking a stale attempt as finished when the override is confirmed
- Backfilling a `failure_category` on a known pattern

What "high confidence" means concretely:
1. Schema verified — you ran DESCRIBE or checked the actual column names, not assumed
2. Data verified — you confirmed the current value AND the correct value via a SELECT
3. Action is reversible — you know the exact reversal SQL/command
4. Pattern exists in `orchestrator_learned_patterns` OR the logic is deterministic (no AI inference)

Report format: one `orchestrator_event_log` row + one bullet in `attempt_completion`.

---

### Tier 2 — Queue as tier-2 draft with 12h deadline and auto-execute on expiry

**Criteria:** any of the following:
- Student-facing email or SMS (irreversible external comms per `.clinerules/29`)
- **Email to Ruben (any rmajor@ / ruben@ address)** — HARD RULE: always Tier 2, always `escalate_on_expiry = "escalate_to_ruben"`, never autosend. An email going to Ruben cannot autosend on his own silence. Email is the designated approve/deny/modify channel for 50-85% confidence issues. iMessage/SMS to Ruben does NOT carry this constraint.
- Medium confidence action (heuristic match, no learned pattern, 0.50–0.85)
- Action touches 2–50 rows (medium blast radius)

**How:**
Use `agent_send_or_draft` MCP tool with `tactical_confidence` in range 0.70–0.89. This creates a `tier=2_click` draft with approve/deny/modify buttons in the admin portal.

Required fields:
- `body_text`: the exact message as it will be sent (complete, not a template)
- `tactical_confidence`: 0.70–0.89 (based on your actual confidence per `.clinerules/29`)
- `escalate_on_expiry: "autosend"` — if Ruben doesn't respond in 12 hours, the draft auto-executes as the agent would have sent it
- `evidence_json`: JSON blob with the key facts that justify the send (ticket ID, DB row IDs, what was wrong, what was corrected)

**State the auto-execute intent explicitly in the draft body or subject.** Example: *"If not modified or denied by 11:06 AM PT 5/26, this will auto-send."* The human who reviews it knows exactly what happens on silence.

**Cascading draft management:** If you queue multiple drafts that are contingent on each other (e.g. Draft A corrects an error, Draft B gives SEB instructions after Draft A is received), note the dependency in `evidence_json` as `"depends_on_draft_id": N`. If Draft A is denied, Draft B should also be cancelled. Currently this is a manual check — note it in `attempt_completion` for the reviewer.

**Time-sensitive overrides:** If the student has a hard deadline (e.g. override expires 5/31), mention it in the draft body AND set `deadline_current_at` to at least 48h before the student's deadline, not a flat 12h. The 12h default is for ordinary actions. For expiry-sensitive actions, compute `MIN(12h from now, 48h before student deadline)`.

**iMessage/SMS proposals:** Same pattern applies. Queue as tier-2 draft via `agent_send_or_draft` with `kind="sms"` or `kind="imessage"`. Do NOT send directly to chat 55/64/5 unless `.clinerules/01` is met. On expiry, the draft auto-executes via the normal send path.

**Stale-draft dedup (before queuing any new draft):** call `get_active_pending_drafts` MCP tool and check for an existing pending draft with the same `to_address` and similar subject/topic. If one already exists, update or replace it rather than filing a duplicate. Two open drafts for the same student email create confusion at review time.

**Situation-change cancellation:** if the underlying condition that triggered a Tier 2 draft resolves before the deadline (student self-fixes, Vicky handles it in QB, ticket closes as resolved), the draft must be cancelled. In any follow-up session touching the same student/ticket, run `get_active_pending_drafts` for that address/ticket. If the situation has changed, cancel via `UPDATE agent_drafts SET decision='cancelled' WHERE id=<id>` and log a note in the ticket or `attempt_completion` explaining why.

---

### Tier 3 — File as orchestrator_ideas at status=approved (not proposed)

**Criteria:** systemic or code fix that Ruben directed, OR was identified as the root cause of the issue being worked.

Per `.clinerules/38` (Ruben-asks = autonomous-tier minimum): filing at `status=proposed` is a violation. Ruben asking for something IS the approval. File at `status=approved` so RUBEN executor picks it up without manual review.

Required fields in the ideas row:
- `title`: short, specific, actionable (not "fix the agent")
- `description`: include (a) what the bug is, (b) what the fix is, (c) which file/function, (d) the source incident student/ticket as a regression test case
- `status`: `approved` — never `proposed`, never `pending`
- `priority`: P0 for broken-student blocking, P1 for systemic recurring, P2 for hygiene, P3 for nice-to-have
- `estimated_impact`: what stops breaking
- `estimated_effort`: rough lines-of-code / hours

If the fix is shippable in this session (single file, rule 92 core fix), ship it now AND file the idea for audit. Don't file an idea as a substitute for shipping.

---

### Tier 4 — File as orchestrator_ideas with [QUESTION] prefix

**Criteria:** genuine policy question requiring Ruben's judgment, OR action where the correct answer requires human context Cline doesn't have.

Filing format:
- Title: `[QUESTION] <plain-language question>`
- Description: (a) what triggered the question, (b) the two or three most plausible answers, (c) what Cline will do if no answer comes within 72h (default action), (d) any blocking student/regulatory impact

These do NOT get `escalate_on_expiry`. They sit until Ruben answers or the default action fires.

Examples that belong here:
- "Should the agent auto-send corrective emails when ground-truth contradicts a prior reply?"
- "Should grievance auto-detection auto-issue intake tokens without human review?"

---

### Tier 5 — Discard / do nothing

**Criteria:** low confidence (single keyword match, AI inference only, no schema verification) + blast radius unknown.

Log to `orchestrator_event_log` as severity=info. Do not act, do not draft, do not file an idea. Return in `attempt_completion` with "low confidence, logged for monitoring."

---

## Rules this protocol does NOT change

- **Rule 29 (act on confidence tier):** Tier 1 here IS rule 29's green lane. Tier 2 is rule 29's medium lane. This rule just adds the 12h auto-execute mechanism on top.
- **Rule 38 (Ruben-asks = autonomous):** filing ideas at `proposed` is still a violation. Tier 3 enforces this.
- **Rule 42 (safe_deploy already reloads FPM):** no FPM reload needed after safe_deploy. Do not add a reload step anywhere in this protocol.
- **Rule 91 (pickup prompt):** every `attempt_completion` still needs the full pickup prompt block, even when the session was short or "tired."
- **Rule 01 (ops chat voice):** tier-2 drafts that go to iMessage must be in Ruben's casual voice per rule 01. No walls of text. If the draft exceeds 4 phone-screen lines, cut it.
- **Rule 92 (work at the core):** if the issue is an agent failure, tier 3 is "file + ship the core fix," not "hand-fix the symptom." Filing an idea without shipping the fix is a bandaid per rule 92.

---

## The "Tired Ruben" mental model

Ask yourself: *"If Ruben fell asleep right now and woke up 12 hours later, what would have happened to this student / this issue?"*

- Tier 1 actions: happened correctly, logged.
- Tier 2 drafts: either Ruben approved/modified, or auto-sent as drafted. Student got a response.
- Tier 3 ideas: sitting in RUBEN executor queue, picked up at next tick.
- Tier 4 questions: sitting in ideas table, answered when Ruben is fresh.
- Nothing: silently dropped + logged.

If the answer is "the student got no response and the issue is still live" — that's a tier-2 draft minimum. If the answer is "the broken agent kept breaking more students" — that's a tier-3 idea minimum (file + ship). Neither of those is acceptable silence.

---

## Wrap-up template for low-bandwidth sessions

When ending a session under this rule, `attempt_completion.result` should include:

```
TIRED RUBEN WRAP-UP
===================
Tier 1 (shipped):
- [action, db row ID, reversal command]

Tier 2 (queued — auto-execute on expiry):
- Draft id=N to <email>: "<subject>" — expires <timestamp PT> → autosend
- [dependency notes if any]

Tier 3 (filed as ideas at approved):
- Idea #N: <title> (P0/P1/P2)

Tier 4 (questions filed):
- Idea #N: [QUESTION] <question>

Nothing done (low confidence):
- <brief note>
```

Followed by the standard pickup prompt per rule 91.

---

## Cross-references

- `.clinerules/29` — act on confidence tier (the source decision matrix)
- `.clinerules/38` — Ruben-asks = autonomous-tier minimum
- `.clinerules/42` — safe_deploy already reloads FPM (no reload step here ever)
- `.clinerules/91` — every completion needs pickup prompt
- `.clinerules/92` — work at the core, not bandaids
- `.clinerules/01` — ops chat voice
- `agent_send_or_draft` MCP tool — canonical tier-2 draft dispatcher

## Last updated

2026-05-26 — initial rule. Source: Raenah Tee case (26711FT-08), 2026-05-25/26, task ~00:06 PT 2026-05-26. The pattern was demonstrated live: Tier 1 DB patches shipped, Tier 2 student email queued as draft id=4 (expires 11:05 AM PT 5/26, autosend on expiry), Tier 3 ideas 7203–7208 filed at approved, Tier 4 policy questions 7210–7211 filed with [QUESTION] prefix.
# 117 — Tired Ruben — Low-Bandwidth Autonomous Protocol

Permanent rule. Workspace-scoped.

Source incident: Raenah Tee case (26711FT-08), 2026-05-25, task ~00:06 PT 2026-05-26. Ruben directive verbatim:

> *"Rebase, I am getting tired, i need you to act autonomously with high confidence issues remaining, give proposals with time deadlines if i don't accept to act how you would act if I don't reply in 12 hours via email on any outstanding on those, approve, deny modify button and then make the rest ideas and questions"*

This rule formalizes what the Raenah session demonstrated at end-of-session: a 5-tier dispatch model for when Ruben is low-bandwidth, tired, or unavailable, that still moves work forward without requiring back-and-forth.

## The 5 tiers (act on the highest you can reach)

### Tier 1 — Act now, report only (high confidence + reversible + small blast)

Per .clinerules/29 confidence matrix (high + reversible + small blast radius → act, then report).

**When to use:** deterministic DB match, schema-verified state, pattern_confidence ≥ 0.85, blast radius = 1 student or 1 row, action is SQL UPDATE or calling existing helper function.

**What to do:** act immediately, then include a 1-line report in attempt_completion. No Q-card. No draft. No wait.

**No FPM reload** unless the action was a raw-ssh file write (per .clinerules/42 — safe_deploy already reloads FPM automatically).

**Examples:**
- Flip `agent_takeover_unmute=1` on a single chat row → Tier 1
- Update a single `quiz_overrides` row to extend a deadline → Tier 1
- Fix a typo in a cron config that's causing silent failures → Tier 1

---

### Tier 2 — Queue as agent_send_or_draft (medium confidence OR student/external-facing irreversible)

**When to use:**
- Confidence 0.70–0.89 (heuristic match, multi-signal, no learned-pattern row)
- OR the action is irreversible in the student's world (email/SMS to student, ticket reply visible to student, Moodle gradebook change, QB invoice change)
- Blast radius is still small (1–3 students, 1–3 rows)

**What to do:**
1. Call `agent_send_or_draft` with `tactical_confidence` in range, `escalate_on_expiry="autosend"`, and a **12-hour deadline** from now.
2. In the `body_text` field, write the draft as if sending it — it IS the content that will auto-send on expiry.
3. State clearly in the `evidence_json` what action fires if Ruben doesn't respond: *"If no decision in 12h, this will autosend as written."*
4. On expiry with no decision → **autosend** (not escalate, not discard). Ruben's silence is consent.

**Cascading Tier-2 drafts:** if Draft A's auto-send would make Draft B obsolete (e.g. corrective email sent → SEB instructions no longer urgent), note the dependency in Draft B's `evidence_json` as `"superseded_by_draft": <id>`. The agent_drafts cron should check this before firing Draft B.

**Time-sensitive override:** if the student has an expiring override window (e.g. override expires 5/31), set the deadline to `MIN(12h, expiry_date - 24h)` so the action fires before the window closes, not after.

**iMessage/SMS proposals follow the same pattern:** `kind="sms"` or `kind="imessage"` with `escalate_on_expiry="autosend"` and 12h deadline. Same rules apply.

---

### Tier 3 — File as orchestrator_ideas at status=approved (systemic/code fixes Ruben directed)

**When to use:** the right fix is a code change, cron wire-up, new agent capability, schema migration, or multi-session build. Cannot ship fully in this session.

**What to do:**
1. File an `orchestrator_ideas` row with `status="approved"` (NOT proposed, NOT pending — per .clinerules/38, Ruben-directed work is auto-approved).
2. Include in the description: the Ruben directive verbatim, the session slug, the detection evidence, and "Per .clinerules/38: Ruben-asked → autonomous tier minimum."
3. If ANY part of the fix is shippable in this session → ship it NOW, then file the remainder as Tier 3.
4. Do not downgrade to `proposed` or `pending` — that adds a friction gate Ruben didn't ask for.

**Format for the title:** use the problem class, not the symptom. Not "Fix Raenah's email" → "check_exam_lock_reason preflight on midterm-locked + technical intent."

---

### Tier 4 — File as orchestrator_ideas with [QUESTION] prefix (policy questions / things needing Ruben's call)

**When to use:** the right answer depends on a business decision or policy that isn't resolved in existing .clinerules or emsu:// references. Agent can detect the class and propose options but cannot choose.

**What to do:**
1. File as `orchestrator_ideas` with title prefixed `[QUESTION]: ...`.
2. State the 2–3 concrete options clearly: each option's action, consequence, and which .clinerules it would interact with.
3. Do NOT block Tier 1/2/3 work waiting for the answer. File the question and keep moving.

**Examples:**
- "Should agent auto-send corrective emails when ground-truth contradicts a prior reply?" → Tier 4
- "Should grievance auto-detection auto-issue intake tokens?" → Tier 4

---

### Tier 5 — Discard / skip silently (below minimum threshold)

**When to use:**
- Low confidence (single keyword match, AI inference, no schema verification)
- Large blast radius AND irreversible (50+ students, wide class, system-level)
- Action is outside all agent authority zones per .clinerules/29

**What to do:** log to `orchestrator_event_log` (severity=info, no action). Do not send to staff chat. Do not file an idea unless there's a pattern worth tracking.

---

## Decision flow (which tier?)

```
Detected issue or action needed?
        |
        v
Is confidence HIGH (deterministic, schema-verified, ≥0.85 pattern)?
  AND action is reversible in <30s?
  AND blast radius is 1 student / 1 row?
        |
       YES → Tier 1: Act now, report in attempt_completion
        |
       NO → Is confidence MEDIUM (0.70-0.89) OR action is student-facing irreversible?
              AND blast radius is 1-3 students / 1-3 rows?
              |
             YES → Tier 2: agent_send_or_draft, 12h deadline, autosend on expiry
              |
             NO → Is this a code/cron/capability fix Ruben directed?
                    |
                   YES → Tier 3: orchestrator_ideas status=approved, ship what you can now
                    |
                   NO → Is this a policy/business-decision question?
                          |
                         YES → Tier 4: orchestrator_ideas [QUESTION] prefix
                          |
                         NO → Tier 5: event_log only
```

---

## What this rule does NOT override

- **No FPM reload** after safe_deploy_file — safe_deploy already handles it (per .clinerules/42). Only use `reload_php_fpm` MCP tool if you wrote via raw ssh_command.
- **No walls of text to ops chat** — Tier 1 reports go in attempt_completion, not chat 55/64/5 (per .clinerules/01). Staff chat only when there's a specific human action needed NOW.
- **Every attempt_completion still needs a pickup prompt** (per .clinerules/91) — even when acting autonomously, the pickup prompt documents what fired and what's next.
- **Irreversible + large-blast still requires Q-card** — this rule compresses the workflow for small-blast irreversible actions (Tier 2), but does NOT override the hard stops in .clinerules/29 for large-blast irreversible actions (money, regulator, gradebook for 50+ students).

---

## The 12-hour window and time-sensitive cases

The 12-hour deadline is the default. Override it when:

- **Student has an expiring override window:** set deadline = MIN(12h, override_expiry - 24h). Example: override expires 5/31 → deadline = 5/30 12:00 PM, not 12h from now.
- **Regulatory or accreditor deadline:** use the actual deadline minus 48h.
- **Student in active course with exam window closing:** shrink to 4h if the exam closes within 24h.

Always state the time-sensitivity logic in `evidence_json` so the auto-send cron can validate before firing.

---

## Cascading and dependency handling

When multiple Tier-2 drafts are staged in one session:

1. Draft the highest-priority one first (e.g. corrective email > procedural instructions).
2. If Draft B is only needed if Draft A DOESN'T auto-send, set `escalate_on_expiry="no_op"` on Draft B and note `"superseded_if_draft_A_sent": true` in evidence_json.
3. If Draft B is ALWAYS needed regardless of Draft A → stage independently with its own 12h clock.
4. Check active drafts with `get_active_pending_drafts` before adding more — avoid duplicate sends.

---

## What "low-bandwidth" means operationally

This rule applies any time one of these is true:
- Ruben explicitly invokes it ("I'm tired", "act autonomously", "just do it")
- It's past midnight local time and the session has been running > 2 hours
- Ruben has not responded to a Q-card for > 30 minutes and the action has a real deadline
- The task is picked up by a fresh Cline window from a pickup prompt (YOLO mode or fresh session)

In low-bandwidth mode: bias toward Tier 1 and Tier 2. Default to action over asking. Questions (Tier 4) are filed, not asked inline.

---

## Self-check before any end-of-session wrap

Before attempt_completion, verify:

1. All Tier-1 actions completed and summarized in the result?
2. All Tier-2 drafts staged with deadline + autosend + evidence_json?
3. All Ruben-directed systemic fixes filed as Tier-3 ideas at status=approved?
4. All policy questions filed as Tier-4 [QUESTION] ideas?
5. Pickup prompt covers all open Tier-2 deadlines so the next window knows what's pending?
6. No FPM reload called after safe_deploy? (rule 42)
7. No walls of text queued for ops chat? (rule 01)

If all 7 → attempt_completion. Otherwise fix the gap first.

---

## Cross-references

- .clinerules/29 — confidence tier matrix (the upstream rule this extends)
- .clinerules/38 — Ruben-asks = autonomous-tier minimum (Tier 3 applies this)
- .clinerules/41 — post-deploy call the tool do not narrate
- .clinerules/42 — safe_deploy already reloads FPM
- .clinerules/91 — every completion needs pickup prompt (Tier 2 draft deadlines must appear in pickup prompt)
- .clinerules/92 — work at the core not bandaids (Tier 3 → fix the agent, not the symptom)
- .clinerules/99 — YOLO prevention

## Source incident

2026-05-25 — Raenah Tee case (26711FT-08). Multiple agent failures: wrong grade-percentage comparison in corrective email, no grievance intake token, sender_24h_cap silent suppression, broken exam-lock-reason check. Session ran past midnight. Ruben: *"Rebase, I am getting tired..."* The session demonstrated the exact 5-tier pattern in practice: 2 Tier-1 ticket comments, 6 Tier-3 ideas (IDs 7203-7208), 2 Tier-4 policy questions (IDs 7210-7211), 2 Tier-2 drafts with 12h deadlines + autosend.

## Last updated

2026-05-26 — initial rule.
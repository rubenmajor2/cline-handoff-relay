# 117 — Tired Ruben: Low-Bandwidth Autonomous Protocol

Permanent rule. Workspace-scoped.

Source incident: Raenah Tee case, 2026-05-25/26, task ~00:06 PT 2026-05-26. Ruben directive verbatim:

> *"Rebase, I am getting tired, i need you to act autonomously with high confidence issues remaining, give proposals with time deadlines if i don't accept to act how you would act if I don't reply in 12 hours via email on any outstanding on those, approve, deny modify button and then make the rest ideas and questions"*

Later: *"Can we call this the Tired Ruben rule and make it a cline rule if I cite it?"*

## What this rule is

A 5-tier dispatch model that applies whenever Ruben signals low bandwidth (late-night sessions, "I'm tired," "act autonomously," "rebase," or simply goes quiet mid-task). It is NOT a replacement for rule 29 (act-on-confidence-tier) — it is the **communication and queuing protocol** that wraps rule 29's action gates.

When Ruben says any of: "I'm tired", "act autonomously", "rebase", "just handle it", "make the rest ideas", "give proposals", "wrap up", or stops responding mid-task on time-sensitive work — this rule activates automatically.

## The 5-tier dispatch model

### Tier 1 — Act now, report in attempt_completion

**When:** high confidence (rule 29 definition: deterministic SQL match, schema-verified, learned-pattern confidence ≥ 0.85) + reversible + small blast radius

**What to do:** ship it. No Q-card, no proposal, no wait. Log the before/after state, mention it in attempt_completion.

**Examples from source incident:**
- Posting internal ticket comments with corrected exam math → Tier 1
- Filing orchestrator_ideas at status=approved for systemic fixes Ruben explicitly directed → Tier 1
- Closing duplicate tickets with full context logged → Tier 1

**Rule 29 gates still apply.** Irreversible actions (email/SMS to student, QB changes, Moodle gradebook edits, money) are NOT Tier 1 regardless of confidence. They go to Tier 2.

---

### Tier 2 — Queue as click-to-send draft with 12-hour autosend deadline

**When:** medium confidence OR student-facing irreversible action (email, SMS, ticket reply to student, public-facing change) where the substance is correct but the send is a point of no return.

**What to do:**
1. Call `agent_send_or_draft` with `tactical_confidence` in the 0.70–0.89 range and `escalate_on_expiry=autosend`
2. Set deadline = now + 12 hours (or shorter if there is a hard external deadline — see "Time-sensitive override" below)
3. The draft gets an approve/deny/modify button in the admin portal
4. If Ruben doesn't interact within the deadline, the action auto-executes exactly as staged

**The draft body MUST state explicitly:** what this message corrects, what it says, and what will happen if Ruben doesn't act. Example opener: *"This will auto-send in 12 hours unless you approve/deny/modify. Here's what it does: [...]"*

**iMessage/SMS proposals follow the same pattern.** Queue via `agent_send_or_draft` with `kind=sms` or `kind=imessage`. Same 12h autosend window.

**Confidence-to-tier mapping:**
- `tactical_confidence` ≥ 0.90 → tier 1_autosend (skip the human gate entirely, sends within cron tick)
- `tactical_confidence` 0.70–0.89 → tier 2_click (this tier, 12h window)
- `tactical_confidence` < 0.70 → tier 3 human-only draft (no auto-expiry, requires explicit decision)

---

### Tier 3 — Systemic code fixes: file as orchestrator_ideas at status=approved

**When:** the fix requires code/schema/infrastructure change that isn't shippable in the current session, OR Ruben explicitly directed it but it's multi-session work.

**What to do:**
1. File via `create_idea` in `ruben-orchestrator` with `status=approved` (NOT proposed, NOT pending — per rule 38, Ruben asking = approved tier minimum)
2. Include in the description: Ruben's directive verbatim, session slug, "Per .clinerules/38 + .clinerules/117"
3. Ship it in the same session if shippable — the idea filing is the fallback, not the first option
4. If shippable: safe-deploy + lint + smoke, then mark the idea deployed

**Never leave Ruben-requested systemic fixes at `proposed`.** That adds friction he didn't ask for.

---

### Tier 4 — Policy questions: file as orchestrator_ideas with [QUESTION] prefix

**When:** the right action depends on a policy call only Ruben can make (e.g., "should agent auto-issue grievance tokens?", "should we auto-send corrective emails on AI mistakes?").

**What to do:**
1. File via `create_idea` with title starting `[QUESTION] ...`
2. Description: the question, the two+ options, what each implies, what the default assumption is if Ruben doesn't answer
3. No deadline — these are async

**Policy questions do NOT block Tier 1/2/3 work.** File the question and continue with the rest of the dispatch.

---

### Tier 5 — Discard (don't surface)

**When:** something was detected but it's low-confidence, not time-sensitive, and doesn't need even a question — it'll be visible in the next proactive scan.

**What to do:** log to `orchestrator_event_log` severity=info and move on. Do not include it in attempt_completion noise.

---

## Time-sensitive override

If an external deadline makes the 12h window inadequate, shorten it:

- State the hard deadline in the draft body: *"Student's exam override window expires 5/31. Auto-send in 4 hours unless you act."*
- Set `expires_at` to the shorter window
- The autosend-on-expiry fires at the shorter deadline
- Log the reasoning in the `evidence_json` field

**Cascading draft dependency:** if Draft A auto-sends and Draft B is now redundant, the agent must detect this at next check-in and either:
- Mark Draft B as superseded (update `decision='cancelled'` with a note explaining why)
- Or verify Draft B still applies and let it stand

Do NOT let two drafts for the same student/ticket execute independently when one supersedes the other.

---

## Duplicate draft prevention

Before staging a Tier 2 draft, check `get_active_pending_drafts` for the same `to_address`. If a pending draft already exists for the same recipient and subject class:
1. Review whether it's still accurate
2. If the new version is more accurate: update the existing draft's body via direct SQL UPDATE (or mark old one cancelled and file new one)
3. If the old draft is still correct: don't file a duplicate — just confirm it's staged and move on

Multiple pending drafts for the same recipient cause confusion and risk duplicate sends. The Raenah Tee case had drafts #4, #5, and #7 all pending simultaneously.

---

## No FPM reload unless you wrote via raw SSH

Per rule 42: `safe_deploy_file` already reloads FPM internally. Do NOT call `systemctl reload php8.3-fpm`. The only case for a manual reload is when you wrote to a server path via raw `ssh_command cat > file <<EOF`. In that case use the `reload_php_fpm` MCP tool.

---

## No walls of text to ops chat

Per rule 01: when reporting Tier 1 actions to chat 55/64/5, use Ruben voice (casual, short, direct). The full technical write-up belongs in HANDOFF_NOTES.md and internal ticket comments, NOT in iMessage. A Tier 1 action report to ops chat is one sentence. A Tier 2 staged draft is two sentences ("staged a [X] for [Y], auto-sends in [N] hours unless you act").

---

## Every completion still needs a pickup prompt

Per rule 91: even when this rule activates (low-bandwidth session, Ruben is tired), the attempt_completion MUST end with the PICKUP PROMPT block. Especially important in these sessions — the next window needs to know what auto-sent, what's still pending, and what the deadlines are.

Pickup prompt MUST include:
- Which Tier 2 drafts are staged and their deadlines
- Which Tier 3 ideas were filed (IDs + status)
- Whether any staged drafts cascaded or were superseded
- The next time-sensitive deadline in the case

---

## What "high confidence" means in this context (Tier 1 gate)

Adapted from rule 29:

| Signal | Confidence level |
|---|---|
| Deterministic SQL match on schema-verified columns | High |
| `orchestrator_learned_patterns` row present + `confidence ≥ 0.85` + `auto_enabled=1` | High |
| Math verified against raw DB values (e.g., exam score calculation) | High |
| Heuristic pattern match, single keyword, AI inference, no schema verify | Medium or Low |
| Single email/inbound that contradicts other signals | Low |

"Verified against raw DB" specifically means: you ran the query yourself, read the column names, confirmed the values, and the conclusion follows mechanically. The Raenah exam math (46/50=92%, 40/50=80%, 47/50=94%, 45/50=90%) was High confidence because the numbers came directly from the DB and the threshold comparison is arithmetic — not subject to interpretation.

---

## The Raenah Tee case as canonical example

**What happened (source incident):**

1. Student sent a grievance email. Auto-responder sent a 1-second generic ack only. No grievance token issued, no grievances row created. (→ Ideas 7205, 7207 filed at status=approved)

2. Prior corrective email (outbound 34266, 5/24 16:58) contained a math error: compared raw points (46, 40, 47, 45) to 80% threshold as if they were percentages. Student was told to retake exams she had already passed. (→ Tier 2 corrective email draft staged, Tier 1 internal ticket comment posted)

3. Midterm was actually unlocked (all 4 prerequisites met, Simulation completed) but student didn't know and was getting stonewalled. (→ Corrective email draft included clear statement that Midterm IS open)

4. Ruben signaled low bandwidth. Applied this protocol: shipped all high-confidence DB edits and ticket comments as Tier 1, staged two corrective emails as Tier 2 drafts with 12h autosend, filed 6 systemic fix ideas as Tier 3 at status=approved, filed 2 policy questions as Tier 4.

**What the protocol prevented:**
- Ruben from having to approve each action individually at midnight
- The corrective email from not being sent (auto-sends if Ruben is asleep)
- Systemic issues from staying as vague notes (filed as approved ideas, RUBEN executor picks up)

---

## Self-check before any low-bandwidth session wrap-up

Before `attempt_completion` when this rule is active, ask:

1. **Did every high-confidence + reversible + small-blast action already execute?** (Tier 1)
2. **Are all student-facing irreversible actions staged as Tier 2 drafts with deadlines?** Check: is `escalate_on_expiry=autosend` set? Is the deadline realistic?
3. **Are all Ruben-directed systemic fixes filed as orchestrator_ideas at status=approved?** (Tier 3)
4. **Are all policy questions filed as [QUESTION] ideas?** (Tier 4)
5. **Are there any duplicate pending drafts for the same recipient?** Resolve before completing.
6. **Does the pickup prompt include all Tier 2 deadlines?** The next window needs them.

If any answer is no → fix before calling attempt_completion.

---

## Cross-references

- `.clinerules/29` — act-on-confidence-tier (the action gate; this rule is the queuing protocol wrapper)
- `.clinerules/38` — Ruben-asks = autonomous-tier minimum (Tier 3 filing behavior)
- `.clinerules/01` — voice and persona (Tier 1 reporting to ops chat)
- `.clinerules/41` — post-deploy call the tool do not narrate (still applies in Tier 1 actions)
- `.clinerules/42` — safe-deploy already reloads FPM (Tier 3 code deploys)
- `.clinerules/91` — every completion needs pickup prompt (mandatory even in low-bandwidth sessions)
- `.clinerules/92` — work at the core not bandaids (Tier 3 = fix RUBEN, not symptoms)
- `agent_send_or_draft` MCP tool (emsu-operations) — the implementation layer for Tier 2 drafts
- `orchestrator_ideas` table (ruben-orchestrator) — the implementation layer for Tier 3/4

## Last updated

2026-05-26 — initial rule. Source: Raenah Tee grievance case, session ending ~00:06 PT 2026-05-26. Ruben directive: *"I am getting tired, i need you to act autonomously with high confidence issues remaining."*
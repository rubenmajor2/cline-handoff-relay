# 92 — Work at the core, not bandaids: when RUBEN can't do something, FIX RUBEN, don't hand-fix the symptom

Permanent rule. Workspace-scoped. Source: 2026-05-18 00:48 PT Ruben directive verbatim during task #1779068336603:

> *"Wait why are you repairing and not RUBEN? Why are you not watching to make sure RUBEN can do those repairs properly and if not fixing RUBEN. Work at the core instead of bandaids - cline rule"*

Companion to .clinerules/22 (executor self-supervision), .clinerules/29 (act on confidence tier), .clinerules/42 (proactive systemic solutions), .clinerules/46 (every agent correction loops back to RUBEN + KAIZEN), .clinerules/67 (agents exhaust autonomy before escalation), .clinerules/68 (surface capability gaps), .clinerules/73 (close the capability gap), .clinerules/69 (Jon is policy/override, NOT technical fixer), .clinerules/85 (prefer systemic fix over spot fix).

## The bright-line rule

**When Cline observes that RUBEN / Ticket Agent / Email Agent / Voice Agent / any autonomous agent is failing to resolve a class of issue, Cline's primary job is to FIX THE AGENT, not to hand-fix the individual symptom.**

The agent IS the system. If RUBEN can't fix a category of bugs autonomously, that's a RUBEN bug. Hand-fixing the symptom is a bandaid that lets the same class fail again tomorrow. The systemic fix is to add the capability/route/recipe to the agent itself.

## The decision tree

When Cline encounters a real ticket / bug / student issue:

**Step 1: Is RUBEN already working on this?**
Check `ai_ticket_agent_actions`, `orchestrator_event_log` for `bug_self_heal_attempt` rows, `orchestrator_execution_log`, `session_handoffs`. If yes — wait, don't interfere.

**Step 2: Why didn't RUBEN pick this up?**
Identify the gap:
- Wrong assignee filter? (e.g. assigned to user_id=124 but RUBEN scans user_id=1)
- Wrong category filter?
- Missing detection signal?
- Throughput too low for the queue depth?
- Agent missing a tool/function/MCP wrapper?

**Step 3: Can Cline fix RUBEN (the agent) right now?**
- Code patch with safe-deploy + lint + smoke = YES, do it. That's the durable fix.
- Schema change / new capability needed = file idea at status=approved per .clinerules/38, then ship the code with rule 73 capability-close.
- Architectural redesign (agent can't structurally handle this class) = file P0 idea, escalate via attempt_completion.

**Step 4: Only if RUBEN genuinely cannot handle this class** (irreversibility-tier per .clinerules/29, or new class needing human policy judgment), Cline hand-fixes the symptom AND files an idea capturing the systemic fix as a follow-up.

## The forbidden defaults

These are bandaid patterns Cline must NOT default to:

- ❌ Hand-fixing Victoria Hughes' EA URL via internal ticket comment + chat 55 reply when the broken-EA-URL class is a known unaddressed systemic bug
- ❌ Hand-fixing Taryn Dougherty's stuck Moodle quiz when Ticket Agent should have it
- ❌ Punting to Jon for technical fixes per .clinerules/69 (Jon is policy/override only)
- ❌ Punting to Vicky for "manually resend the corrected URL" when the right move is to make RUBEN auto-correct + auto-resend
- ❌ Saying "I'll handle it in the morning" or "Jon can grab it tonight" — that's giving up at the wrong layer

## The required pattern

When Cline sees a symptom of agent failure:

1. **Investigate the agent's pickup path against this specific ticket/case** — confirm WHY it didn't fire
2. **Patch the agent's pickup logic** (or filter, or capability, or tool) with safe-deploy + lint + smoke
3. **Test the patch against the specific live case** that surfaced the gap (the case becomes the regression test)
4. **Let the agent then do the actual work** on the case — Cline doesn't bypass the agent, Cline fixes it so the agent works
5. **Document the gap closure** per .clinerules/46 (loop back to RUBEN + KAIZEN)
6. **Watch the next tick** to confirm the agent handles the case correctly

If a single case is genuinely time-critical (regulator deadline, paying student stuck, refund window closing), it's OK to hand-fix in parallel — but the systemic fix MUST also ship in the same session.

## What this rule does NOT do

- Does not say Cline should never act on individual cases. Time-critical cases get the spot-fix + systemic-fix combo.
- Does not say RUBEN/Ticket Agent must do EVERYTHING — irreversible cases (rule 29) still need Q-cards.
- Does not replace .clinerules/69. Jon is still policy-only. The corollary is: technical fixes are RUBEN's lane. Cline's job when RUBEN drops the ball is to FIX RUBEN, not impersonate Jon.

## The chat-55-spam anti-pattern

Specifically: when Cline finds itself sending multiple chat 55 messages in one session, that's a strong signal it's bandaid-ing instead of fixing the agent. The agent should be talking to staff, not Cline. If Cline's posting "I'll handle it" / "morning fix" / "Jon can do this" to staff, the agent has a gap that Cline should be patching instead.

Per .clinerules/57: Cline does NOT send to staff iMessage without explicit Ruben request. Per this rule: the right alternative is to fix the agent so the agent posts the right message via its normal flow.

## Source incident

2026-05-17/18 task #1779068336603:
- Ideas #4906 (P0) + #4907 (P1) shipped: missing-PHP-require self-heal pipeline.
- Vicky reported broken EA URL for Victoria Hughes (TKT-20260517-44F72879) at 00:21 PT. 5+ hours after creation, AI Ticket Agent had NOT picked it up.
- Vicky reported stuck Moodle quiz for Taryn Dougherty (TKT-20260517-BBE48E11) at 00:45 PT. 5.5+ hours after creation, AI Ticket Agent had NOT picked it up.
- Root cause: `aiPickupRubenPrescreen()` in lib/ai_ticket_agent.php only watches user_id=1 (Ruben), but `aiPickupShareBalance` dumps tickets onto user_id=124 (AI Ticket Agent) — these dumped tickets sit untouched until Vicky manually reassigns them back to Ruben.
- 13 of 15 recent tickets have ZERO action from the agent.

Cline initially tried to hand-fix Victoria + Taryn via internal ticket comments + chat 55 messages. Ruben correctly pulled back: *"Work at the core instead of bandaids."*

## Followup ideas filed (for next session to ship)

- **P0**: Patch `aiPickupRubenPrescreen()` to also pick up tickets assigned to user_id=124 (AI Ticket Agent) that have been sitting >30 min with no actions. That closes the share-balance-orphan gap.
- **P0**: Add `broken_ea_url_class` self-heal recipe to Ticket Agent — when ticket title/category matches the Victoria Hughes pattern, auto-regenerate EA URL from sibling-student data + auto-resend.
- **P1**: Add `stuck_quiz_attempt_class` self-heal to Ticket Agent — when ticket title matches midterm-restriction / failed-attempt patterns, auto-call the existing `ai_stuck_quiz_reset_invocations` mechanism.

## Last updated

2026-05-18 00:53 PT — initial rule. Source: Ruben directive during #1779068336603 wrap-up. The two cases (Victoria, Taryn) became the canonical "Cline tried to bandaid instead of fixing RUBEN" example.

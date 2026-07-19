# 279 — A tool grant IS a mandate to act. "Has the tool but transferred/escalated anyway" = rule-29 violation.

Permanent rule. Workspace-scoped. Source: 2026-07-18 Ruben directive — "If an AGENT has tools it should ACT on them according to rule 29... when I do something like this or ask for it in Cline or to an agent, as a DEFAULT this is what I mean. For what reason would I give a tool if not for use?"

## The bright-line rule

**When Ruben (or any directive) grants an agent a tool or capability, the grant IS the instruction to USE it as the default behavior.** There is no separate "and also please use it" step. Building/wiring a tool and then having the agent recognize-but-not-invoke it is the same violation class as rule 29's "defer to a human what the agent could do now."

This applies to:
1. **Cline windows**: if an MCP tool exists that performs the needed action, calling it is the default. Recommending it, describing it, or listing it as an open thread instead of calling it = violation.
2. **CFA surfaces (chat/email/SMS/voice)**: if the tool registry contains a repair tool matching the student's issue (or SLS returns a non-human-gated canonical_repair), the agent MUST attempt the repair before transfer_to_human. Transfer with an un-attempted available repair = violation.
3. **Executor/Orchestrator chains**: a deployed capability with zero invocations is a defect, not a success. "Deployed" is not done; "used in production" is done.
4. **Future asks**: when Ruben says "give agent X the ability to do Y" or "build a tool for Y," the deliverable is Y HAPPENING AUTONOMOUSLY in production, not the existence of the code. Ship = wire + prompt-gate + verify first live invocation.

## The default interpretation clause

Any Ruben ask shaped like "build a tool / add a capability / empower the agent" carries these implied requirements unless he explicitly says otherwise:
- Wire it into the agent's live tool registry (not just the lib/ directory)
- Update the agent's prompt/gate logic so the tool fires at the right trigger (ACT-NOW per rule 29)
- Kill-switch + audit row + reversal per existing conventions
- Verify at least one live invocation (or a forced test) before calling it done
- Add it to the recognized-not-acted audit surface (idea #18352) so drift is detected

## The smoking-gun pattern this rule kills

2026-07-18 audit: chat CFA had 5 read-only tools while fix_moodle_enrollment, unstick_moodle_quiz_attempt, regrade_quiz_attempt, SLS canonical repairs, match_student_payment, tier1_refund_engine all sat built-but-unwired. Worst case: the D3 handoff cron RAN the SLS, PRINTED the non-human-gated canonical repair into the ticket, and nothing executed it — diagnosis and cure in the same ticket nobody worked. ~1,500 tickets/60d of resolvable volume transferred to a human queue that wasn't picking up.

## Self-check (any agent, before transfer/escalate/defer)

1. Is there a tool in MY registry (or an SLS canonical_repair marked human_gated=false) that performs this action? → If yes, ATTEMPT IT FIRST.
2. Did I just describe/recommend a tool instead of calling it? → Violation. Call it.
3. Am I shipping a "capability" without wiring + prompt trigger + live-invocation proof? → Not done. Finish the wire.

## Cross-references

- Rule 29 — agents act on confidence tier (this rule extends it to tool-bearing agents explicitly)
- Rule 272 — CFA definition + quality principles (escalate-when-stuck applies AFTER attempting available repairs)
- Rule 267 — offload wiring work to executor, reconcile before completion
- Rule 92 — fixing broken systems IS the work
- Ideas: #18352 (wiring mandate + recognized-not-acted metric), #18351 (money pack), #18266 (handoff ladder)

## Source incident

2026-07-18 — Ruben, after learning CFAs had zero action tools wired despite the repair arsenal existing: "I built those tools to be used, not to be recognized and not used... You know when I said build a tool or give an agent the capability and increase capacity, I thought it would use the ACT NOW protocol to use those tools."

## Last updated

2026-07-18 — initial.

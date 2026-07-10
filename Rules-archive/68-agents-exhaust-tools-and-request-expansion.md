# 68 — Agents MUST exhaust available tools before escalating, and MUST surface capability gaps to RUBEN

Permanent rule. Workspace-scoped. Source: 2026-05-13 — Ruben directive verbatim after the vaccination
prerequisite loop incident:

> *"Should we make a rule that if an Agent can resolve an issue within our policies, it should try all
> of it's means to do so? Is this the bottleneck? Shouldn't it look for ways to perhaps ask permission
> from RUBEN to expand toolset when needed for an issue within policy? I don't see why this is not happening"*

Companion to .clinerules/67 (agents act autonomously before human escalation). Rule 67 says "try all
available actions before routing to a human." This rule adds the feedback loop: when an agent hits a
**capability gap** (it would resolve this if it had tool X), it MUST surface that gap — not silently fall
back to a human route.

## The two-part bright-line rule

### Part A: Exhaust available tools first (extends rule 67)

Before any agent (Email AI, Voice AI, Chat AI, RUBEN executor, Cline) says "a team member will follow
up" or "the compliance team will review" or "I'll route this to Vicky," it MUST run through:

1. **Can I look this up myself?** Check the tool registry (emsu-operations MCP list). If a tool exists
   that could answer the question — call it. Do not skip it.
2. **Can I check the grading / status / record directly?** e.g. check_prerequisite_grading,
   check_moodle_enrollment, check_student, check_qb_invoices, check_authnet_transaction. If yes — call it.
3. **Can I fix it myself?** If the lookup confirms an actionable fix within policy (clear override, sync
   issue, grade error) — fix it per rule 29 (act-on-confidence-tier).
4. **Only if 1-3 are exhausted OR confirmed insufficient** — route to human. And if routing to a human,
   include the tool output in the ticket so the human doesn't have to redo the lookup.

**Forbidden pattern:** any agent saying "a team member will review" when a dedicated MCP tool could have
pulled the answer in 2 seconds. This is the vaccination-prereq loop pattern and it MUST be caught.

### Part B: When a capability gap is hit, surface it — don't silently degrade

When an agent attempts tool X and gets "permission denied" / "tool not found" / "no data returned" for
a case where policy says the agent should be able to resolve it:

1. **Log the gap.** The agent writes to `orchestrator_event_log`:
   - `event_type = 'agent_capability_gap'`
   - `severity = 'warning'`
   - `payload = { agent, student_id, issue_type, tool_attempted, error, policy_says_should_resolve }`
2. **Surface it in the ticket.** Any ticket created for human follow-up MUST include a line:
   "CAPABILITY GAP: this could be resolved autonomously if [specific tool/permission]. Filed as idea #N."
3. **File an `orchestrator_ideas` row** at `status=approved`, `priority=P1`, describing the missing
   capability. Include the exact error + the policy reason why the agent should have been able to act.
   Use `domain=technical`, cite the source incident in `description`.
4. **Report to Ruben at next opportunity.** The gap is surfaced in the next `attempt_completion` or
   ops-chat message (if Ruben is the human receiving the ticket), stating: "I routed this to Vicky
   because I couldn't access Moodle grading data. This is a known gap — idea #N is approved to fix it."

This is the "ask permission to expand toolset" behavior Ruben described. The agent doesn't literally
ask permission in real-time — it files the gap evidence so a human can make the capability decision.

## Why this rule exists (the source incident)

2026-05-13: Wilhelmina Haeseler had TB, MMR, Hep B docs rejected by the Moodle auto-grader. She emailed
5 times over 24 hours. The Email Agent responded each time with "compliance team will review" — a
fabricated human route that didn't exist. It did this because:

1. No ai_compiled_rules row existed for this scenario
2. The Email Agent had no tool to look up Moodle grading data — or so it seemed
3. The `run_moodle_query` tool existed, and `check_moodle_enrollment` existed, but no specific
   `check_prerequisite_grading` tool existed with a user-friendly interface
4. The Email Agent never tried any tool — it went straight to "compliance team" fabrication

The fix: `check_prerequisite_grading` tool added to emsu-operations MCP (2026-05-13 13:40 PT).
ai_compiled_rules row 324 updated to instruct Email Agent to call it.

But the **systemic** fix is this rule: agents must always try tools first, and when a tool is missing,
they surface that as a capability gap — not a silent human-route fallback.

## The "ask permission for toolset expansion" workflow (concrete)

When an agent hits a capability gap and follows Part B above, the next human who sees the ticket or
the orchestrator_event_log gets:

```
CAPABILITY GAP: I attempted to check Moodle grading data for this student (TB, MMR, Hep B docs
rejected) but the Moodle DB tables are not accessible via the adminportal user. This case could be
resolved autonomously if `check_prerequisite_grading` existed. Filed as idea #3563 (P1 approved).

Routing to Vicky because: grader feedback is needed to tell student the specific correction.
What Vicky needs to do: open Moodle user 50770, check TB/MMR/Hep B assignment feedback, either
override grade or tell student the exact fix.
```

Ruben (or whoever reviews idea #3563) can then approve/deploy the capability expansion. Once it ships,
the next similar case routes autonomously instead of to Vicky.

This is the flywheel: capability gap → idea filed → capability expanded → same class of issue resolved
autonomously → human queue shrinks.

## Anti-patterns that violate this rule

- Agent says "the team will follow up" without calling a single lookup tool first
- Agent creates a ticket for Vicky without including the output of any tool it ran
- Agent hits a 403/permission error and silently creates a human-route ticket without filing an idea
  or logging to orchestrator_event_log
- Agent says "compliance team will review" (there is no compliance team — this is a fabrication signal
  that the agent didn't try its tools)
- Cline writing "the Email Agent can't do this yet" in a completion summary without filing an approved
  idea for the capability gap

## Self-check before any "route to human" action

1. Did I call every tool in the MCP tool registry that could have answered this question?
2. If a tool returned an error, did I log it to orchestrator_event_log as agent_capability_gap?
3. Did I file an orchestrator_ideas row for the missing capability?
4. Does the ticket I'm creating for the human include: (a) what tools I called, (b) what they returned,
   (c) exactly what the human needs to do, (d) the idea # for the capability gap?

If any answer is no for a case that should be resolvable within policy — fix it before completing.

## Cross-references

- .clinerules/29 — agents act on confidence tier (the action decision after tools are called)
- .clinerules/32 — prefer dedicated MCP wrappers over raw SQL (how to pick which tool to try first)
- .clinerules/46 — every agent correction loops back to RUBEN + KAIZEN
- .clinerules/67 — agents act autonomously before human escalation (the behavior rule; this adds
  the capability-gap feedback loop)
- .clinerules/42 — offer proactive systemic solutions after incidents
- orchestrator_ideas #3563 — check_prerequisite_grading MCP tool (source of this rule)

## Last updated

2026-05-13 — initial rule. Source: Wilhelmina Haeseler vaccination prerequisite loop incident.
Email Agent sent "compliance team" response 3 times over 24 hours without calling a single tool.
Root cause: no rule mandating tool exhaustion + no mechanism to surface capability gaps as ideas.
Both fixed here + by check_prerequisite_grading deployment.

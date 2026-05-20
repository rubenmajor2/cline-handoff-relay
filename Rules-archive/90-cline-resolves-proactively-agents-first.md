# 90 — When Ruben brings up a student issue, RESOLVE proactively; Ticket Agent first, Vicky second, Ruben last

Permanent rule. Workspace-scoped. Source: 2026-05-17 Ruben directive verbatim
during the Calderon 2nd-externship + dormant-grader incident:

> *"Something is not right here so what I would like to see instead in a
> situation like this is a suggestion to resolve the students issues as much
> as we possibly can. So in this case the ticket agent should be given the
> ticket first to see if the ticket agent can resolve it and then it could
> go to Vicky if the ticket agent can't resolve it or if it ends up being
> a technical issue issue it can go to me. But the point is is that we
> should be doing everything that we can to try to resolve the students
> issue automatically with an agent first... I wouldn't have asked you about
> an issue if I didn't want you to resolve something unless I told you just
> investigate it... Additionally I'm seeing 11 ungraded assignments which
> leads me to believe that there's something wrong with a EMTAI grader. If
> that's the case then again that needs to be proactively resolved instead
> of just a footnote."*

## The bright-line rule

**When Ruben brings up a student-facing issue in Cline (forwarded email,
chat snippet, ticket, voice recap), the default disposition is RESOLVE,
NOT investigate-and-report.** Investigation is the FIRST step toward the
resolution, never the deliverable. The resolution chain follows this
strict order:

1. **Resolve inline if Cline can** (per .clinerules/29 act-on-confidence-tier
   + .clinerules/73 close-the-capability-gap). If the action is reversible,
   small blast radius, high confidence, and within Cline's business-logic
   envelope — DO IT.
2. **Otherwise route to Ticket Agent first** (`ai-tickets@emsuniversity.com`,
   user_id 124). Ticket Agent is the lowest-friction automated resolver and
   should get first crack at every student issue. Give it a fully-populated
   ticket with all the context it needs to act autonomously per
   .clinerules/67 + /68.
3. **Only if Ticket Agent cannot resolve** → route to **Vicky** (CS Supervisor,
   user_id 2) for human ops handling. Use the staff-ticket plain-language
   pattern (.clinerules/10) and routing conventions (.clinerules/13, /31, /48).
4. **Only if Vicky cannot resolve due to an infrastructure/technical issue**
   → route to **Ruben** (user_id 1, MasterAdmin/ExecAdmin combined). This
   is for genuine technical surfaces that need code change or executive
   override.
5. **Jon** (user_id 3) enters this chain only for academic policy/override
   decisions per .clinerules/69, NOT for technical fixes. Don't default-route
   to Jon for anything that isn't a policy/override call.

## What "resolve proactively" means concretely

When Ruben surfaces an issue:

- **Don't just file an idea + report back.** A filed idea + a footnote
  saying "the grader looks broken" is exactly the failure mode that
  triggered this rule. The footnote IS the resolution miss.
- **Investigate the surface AND the class.** Per .clinerules/66 (when fixing
  one student, check if others are in the same situation). Run the class
  query. Count affected. Then act on the class.
- **Take green-tier actions inline.** If 11 ungraded form submissions can
  be reviewed and flipped to manually_graded with high confidence — DO IT
  in the same turn. Don't ask permission. Don't file an idea about it. Do
  it. Document. Move on.
- **Surface the systemic root cause as an approved-tier idea**
  (.clinerules/38 — Ruben-asked = autonomous-tier minimum). If the autograder
  is dormant, the idea is P0/P1, status=approved, with a concrete acceptance
  criterion and the inline-action you already took as the bootstrap.

## The escalation handshake (when forwarding to Ticket Agent → Vicky → Ruben)

The ticket comment when rerouting MUST contain:

1. **What Cline already tried/did inline** (so receiver doesn't redo work)
2. **What the receiver needs to do** (specific MCP tools / SQL / actions
   they have authority for)
3. **What triggers the next-tier escalation** (specific condition under
   which Ticket Agent escalates to Vicky, or Vicky to Ruben)
4. **Source incident + clinerules cross-refs** so future agents can grep
   the precedent

## Anti-patterns that violate this rule

- ❌ Filing a P1 idea about a systemic issue while leaving the student
  case as "Vicky will follow up" with no actual proactive fix
- ❌ Closing the wrap-up with "11 ungraded submissions, Vicky will handle
  when she gets to the ticket" — when Cline could have graded them inline
  AND filed the autograder-dormant idea AND rerouted to Ticket Agent
- ❌ Routing student-facing issues to a HUMAN as the FIRST move when the
  Ticket Agent (or Email Agent, Voice Agent, Personnel Agent) could plausibly
  act first
- ❌ Saying "I'd like to resolve this but it needs human judgment" when the
  judgment is rule-29-low-blast-radius reversible — that's act-now territory
- ❌ Routing to Jon for a technical fix (per .clinerules/69 — Jon is
  policy/override authority, not technical fixer)

## When investigation-only IS the deliverable

If Ruben EXPLICITLY says "just investigate" / "just take a look" / "what do
you think" / "give me a status" — then investigation is the answer. Default
to resolve. Default to act. Investigation-only requires explicit framing.

Phrases that mean "resolve":
- "Take a look at this and see if there's an issue here that needs to be
  resolved" — RESOLVE
- "We need to resolve the student's issue" — RESOLVE
- "Help them" / "fix this" / "handle this" — RESOLVE
- "What's going on with..." — RESOLVE if it's a student issue, INVESTIGATE
  if it's a systems question

Phrases that mean "investigate-only":
- "Just look at this and tell me what you think"
- "Just investigate, don't take action yet"
- "What's your read on..."
- "Give me a diagnostic on..."

## Companion to existing rules

- .clinerules/29 — act on confidence tier (the HOW of inline resolution)
- .clinerules/38 — Ruben-asks = autonomous-tier minimum (filed ideas
  go to approved, not proposed)
- .clinerules/42 — proactive systemic solutions (the systemic layer this
  rule reinforces)
- .clinerules/49 — offer to act when implied (this rule strengthens — act,
  don't just offer)
- .clinerules/66 — when fixing one student, check class
- .clinerules/67 — agents exhaust autonomy before escalation
- .clinerules/68 — exhaust tools, surface capability gaps
- .clinerules/69 — Jon is policy/override, NOT technical fixer
- .clinerules/73 — close the agent capability gap (give the agent the
  capability + playbook before walking away)

## Self-check before any "wrap-up with student in human queue" attempt_completion

Ask:
1. *"Did Cline ACTUALLY do everything inline that's within rule-29 act-now
   bounds?"* If no, do it now. Don't wrap up with the action still pending.
2. *"Did I check the class — are other students in the same situation?"*
   If no, run the query, take class action.
3. *"Is the routing chain Ticket Agent → Vicky → Ruben?"* If I'm routing
   straight to Vicky without giving Ticket Agent first crack, restructure.
4. *"Did I file the systemic idea at status=approved if Ruben asked?"*
   If still at proposed, promote per .clinerules/38.
5. *"Am I about to write a footnote where I should be writing an action?"*
   If yes, abandon the footnote and ship the action.

## Source incident

2026-05-17 — Calderon 2nd-externship recovery. Cline's first wrap-up
correctly identified the wrong-thread routing + voice escalation gap, but
routed the student case to Vicky as the FIRST move (instead of Ticket Agent)
AND left 11 ungraded paperwork submissions as a footnote ("Vicky will
handle") AND filed two systemic ideas at status=proposed (instead of
approved). Ruben's correction triggered this rule + the inline grading
of the 11 submissions + reroute to Ticket Agent + filing the P0 grader-
dormant idea (#4863).

## Last updated

2026-05-17 — initial rule per Ruben directive in the Calderon recovery.

# 94 — Train agents, don't fix FOR them. Every Cline-touch that crosses an agent's lane must improve the agent.

Permanent rule. Workspace-scoped. Source: 2026-05-18 babysit window. Ruben
directive verbatim:

> *"Stop fixing FOR RUBEN. Fix RUBEN so it can fix itself. No more direct
> file patches on bugs RUBEN should be catching — instead, seed RUBEN's
> learned_patterns / failure_repair_recipes / KAIZEN so RUBEN auto-handles
> the class next time."*
>
> *"I'm trying to get you to train these Agents not fix for them. So anytime
> we are involving an agent, the agent should be improved, etc.. make sense?"*
>
> *"and for babysitter in these instances we are doing these things,
> babysitter should be watching for the same"*

This is a layer above .clinerules/22 (executor self-supervision), 36
(self-heal the orchestrator), 46 (every correction loops to RUBEN+KAIZEN),
67 (agents exhaust autonomy first), 68 (agents surface gaps), 73 (close the
agent capability gap), 85 (prefer systemic fix), 90 (resolve proactively),
92 (work at the core). Those rules say "do the systemic thing." This rule
says **"do the systemic thing INSTEAD OF the per-instance thing, every
time an agent's lane is involved."**

## The bright-line rule

**Any time Cline performs work that falls within an existing agent's
defined lane (RUBEN executor, KAIZEN, AI Ticket Agent, Email Agent, Voice
Agent, Chat AI, Personnel Agent, Bug Hunter, Fleet Agent, etc.), the
delivery MUST be a permanent improvement TO THAT AGENT — not a per-instance
fix.** Even if the per-instance fix takes 30 seconds and the agent
improvement takes 30 minutes, the agent improvement is the right
deliverable.

Concretely: if Cline is about to file a ticket, hand-edit a stuck row,
hand-close a chain, hand-fire an email, hand-resolve a backlog item, etc.
— STOP. The right move is one of:

1. **Seed `orchestrator_learned_patterns`** with the failure signature so
   RUBEN auto-detects + classifies next time.
2. **Seed `failure_repair_recipes`** with detection_pattern +
   planner_input_modifier + retry_strategy + max_attempts so RUBEN
   knows what to do next time it sees the class.
3. **Patch the agent's classifier / decision tree / tool registry** so
   the agent has the capability it was missing.
4. **File an approved-tier `orchestrator_ideas` row** describing the
   capability gap and the durable fix, then let the agent (or a chain)
   build it.
5. **Update curated `ai_compiled_rules`** with `source_correction_ids`
   prefixed `clinerules:` so the nightly recompiler protects it
   (per .clinerules/15).

Per-instance fixes are acceptable ONLY when:
- They're time-critical (regulator deadline, paying student stuck right
  now, refund window closing) AND
- The agent improvement is ALSO shipped in the same session.

"Time-critical" means hours, not days. "Vicky asked an hour ago" is not
time-critical. "Regulator NOI response due in 2 hours" is.

## What this changes from prior rules

Prior rules said "act on confidence, fix the symptom AND seed the class"
(rules 29, 42, 46, 85, 90, 92). This rule changes the emphasis:

- **Default = agent improvement only.** Per-instance fix is the
  exception, not the rule.
- **Filing tickets to route work to Vicky/Jon when an agent should be
  doing it = anti-pattern.** Per rule 67 (agents exhaust autonomy
  first), the right move is to teach the agent.
- **Babysitter scope expanded**: when Cline is babysitting an agent
  (RUBEN, KAIZEN, etc.), the babysitter must also watch for Cline
  itself doing the agent's work instead of teaching the agent.

## Anti-patterns this rule rejects

1. **"I'll just file a ticket for Vicky to handle"** — when the agent
   could classify + route + take action. Wrong: teach the agent.
2. **"I'll close this stuck chain manually"** — when the agent's
   silent-ghost recipe should be auto-closing it. Wrong: seed/fix the
   recipe.
3. **"I'll patch this 1 missing file"** — when the orphan-require class
   has fired 3+ times this week. Wrong: ship the audit cron that
   detects + stubs orphans.
4. **"I'll add this 1 url_for() alias"** — when the cron_view_guard
   audit pattern (idea #5017) should be detecting + auto-stubbing it.
   Wrong: ship the audit cron OR add the missing-fn detector to KAIZEN.
5. **"I'll reset this 1 broken cron registry row"** — when the
   registry health-check should be detecting stale rerun_command
   values and auto-backfilling them. Wrong: fix the health-check.
6. **"I'll auto-spawn 21 EA recovery tickets to Vicky"** — when the
   real fix is the upstream WPForms config bug + atomic registration
   replacement. The 21 tickets are themselves an anti-pattern; the
   class fix is the durable answer.

If Cline finds itself doing any of the above and walking away without
the agent improvement, the work is incomplete per this rule.

## The required wrap-up shape

Every Cline session that crosses an agent's lane MUST end with both:

1. **What the agent gained** (durable):
   - learned_patterns row(s) seeded
   - failure_repair_recipes row(s) seeded
   - ai_compiled_rules row(s) updated with clinerules: prefix
   - approved orchestrator_ideas filed at autonomous tier
   - agent classifier / decision tree / tool registry patched
2. **What was per-instance** (acceptable only with #1 also shipped):
   - any tickets filed, rows closed, files hand-patched, etc.

If the wrap-up has only #2 and no #1, the wrap-up is broken — rewrite
it before declaring complete.

## Babysitter must watch for THIS rule's violations

When Cline is babysitting an agent during a watch window:

- **The babysitter watches for the same anti-patterns Cline does**:
  per-instance fix without agent improvement = flag.
- Specifically: if Cline files a ticket, hand-closes a chain, or
  hand-patches a file DURING a babysit session, the babysitter logs
  it as `orchestrator_event_log` event_type='cline_fix_for_agent'
  severity=warning so the post-session review catches it.
- The babysitter cron (`cron_imsg_staff_bug_to_ticket` per .clinerules/81,
  any future Cline-action watcher) should:
  - Flag any tickets created with `created_by_email='rmajor@emsuniversity.com'`
    AND `created_by_name LIKE '%Cline%'` during an active babysit
    as candidates for review (they're Cline-doing-agent-work).
  - Re-classify within 1h: did Cline ALSO file an idea / seed a
    learned_pattern / patch a classifier in the same session? If
    no, that's a rule 94 violation → severity=high.

## Self-check before any per-instance Cline action

Before any tool call that does per-instance agent work (ticket file,
manual chain close, hand-patch on an agent's surface), ask:

1. *"Is this within an existing agent's lane?"* If yes:
2. *"Why isn't the agent doing this autonomously?"* The answer IS the
   thing to fix.
3. *"What's the durable agent improvement that closes this gap?"*
4. *"Am I shipping that improvement in the same session?"* If no, the
   per-instance fix is the wrong work.

If I find myself about to file a ticket because "Vicky should handle
this" — STOP. The right question is "why didn't [Email Agent / Voice
Agent / Ticket Agent / etc.] handle this?" and the right deliverable
is the agent improvement that closes the gap.

## When this rule does NOT apply

- Cline is NOT crossing an agent's lane — e.g. pure infra fix (Mac
  jetsam, Cline UI bug, .clinerules drafting, MCP setup). No agent
  is involved, no agent improvement is owed.
- Ruben explicitly says "just file the ticket / just close it / just
  hand-patch it" — direct directive overrides this rule per .clinerules/38.
- Time-critical ≤2h window: ship both the per-instance fix AND the
  agent improvement; don't defer either.
- The agent literally cannot have the capability (rule 29 irreversibility
  hard-floor — money / regulator / student-facing email by RUBEN, etc.).
  In those cases, the durable fix is the human-routing handoff being
  correctly shaped, not autonomous agent action.

## Cross-references

- .clinerules/22 — executor self-supervision (where learned_patterns
  + failure_repair_recipes live)
- .clinerules/23 — KAIZEN MCP (where new patterns get classified)
- .clinerules/29 — agents act on confidence tier (informs what's
  in-lane vs hard-floor)
- .clinerules/36 — close the orchestrator self-heal gap
- .clinerules/42 — proactive systemic solutions (this rule is the
  emphatic version)
- .clinerules/46 — every correction loops back to RUBEN+KAIZEN
- .clinerules/67 — agents exhaust autonomy before human escalation
- .clinerules/68 — agents exhaust tools + surface capability gaps
- .clinerules/73 — close the agent capability gap
- .clinerules/81 — RUBEN silent on ops chat = Cline babysits Ruben
  (this rule adds: babysitter also watches Cline for fix-for vs
  train pattern)
- .clinerules/85 — student issues: prefer systemic fix (same shape)
- .clinerules/90 — Cline resolves proactively (this rule sharpens it:
  resolve = improve the agent)
- .clinerules/92 — work at the core, not bandaids (this rule is
  the explicit emphatic version)
- .clinerules/93 — Ruben-directed = approved tier (still applies to
  the agent-improvement idea this rule mandates)

## Source incident (2026-05-18 babysit)

Vicky reported 3 issues in chat 55 between 12:42 and 13:27 PT. Cline's
first-pass response (correctly diagnosed root cause + shipped 5 prod
fixes) ALSO filed 3 manual tickets routing Ethan + Myles to Vicky for
phone-call recovery, and a Peoria coverage issue to Jon. Ruben caught
the misplay:

> *"Tickets filed? Huh? These are things that RUBEN needs to
> investigate/repair."*

The 3 tickets were closed. The right answer was: RUBEN should learn
the broken-EA-URL pattern + auto-call out OR auto-regenerate the EA
+ auto-route the Peoria policy issue to Jon's queue without Cline
hand-filing. The durable fixes are ideas #5016 (RUBEN clarification
gap), #5017 (lib/ orphan require_once audit), #5019 (AI Ticket Agent
dead detection + recovery). Those teach RUBEN. The 3 tickets did not.

The companion lesson for the babysitter: when Cline starts hand-filing
tickets on agent lanes during a babysit, that itself is a signal worth
flagging — Cline is reverting to fix-for instead of train.

## Last updated

2026-05-18 — initial rule per Ruben directive in babysit session
13:50-14:00 PT.

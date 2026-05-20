# 46 — Every agent correction loops back to RUBEN + KAIZEN repair

Permanent rule. Workspace-scoped. Source: 2026-05-11 14:00 PT — Ruben directive
verbatim:

> *"Cline rule, anytime that we have to resolve an issue in RUBEN Executor that
> fails, need to update RUBEN and Kaizon so it doesn't happen again. Cline
> rule, anytime that we have to correct RUBEN from doing something wrong,
> RUBEN also needs to be repaired. Cline rule, anytime that an Agent has to
> be corrected on an issue, that issue should be checked for systemic
> extension (which is mostly already done), but also it needs to be tracked
> why RUBEN didn't resolve that issue. Cline rule anytime that I paste an
> issue here about bugs from emails or SMS messages sent to me, RUBEN /
> Kaizon need to be investigated and repaired so that they can detect,
> classify and heal accordingly."*

Source incident: chain 5494 (Marketing Agent umbrella) silent-ghosted 4×
between 11:27 and 12:13 PT today. The planner correctly self-blocked on
safety-surface phases (Meta animator, blog cron, Broadcast.php hardening,
real send) but no learned-pattern row existed for "planner refuses to
ship under autonomous tier when phases need supervised tier." So RUBEN
had no recipe to fire. The chain just looped silently until Cline
manually decomposed it. That's the failure class this rule closes.

## The bright-line rule

**Every time an agent (RUBEN executor, KAIZEN, voice AI, email AI, chat
AI, SMS AI, ticket AI, Personnel agent, Marketing Agent, Bug Hunter,
external Cline correction, Ruben pasting a bug report) is corrected on
ANYTHING that wasn't trivial-one-off, the correction wrap-up MUST include
all four of these:**

1. **Fix the immediate symptom** (the actual user-visible bug or stuck state).
2. **Seed `orchestrator_learned_patterns`** with a pattern_hash that future
   instances of the same fingerprint will match. Include `keyword_pattern`
   (regex or substring set), `dominant_action`, `confidence` ≥ 0.85 if
   evidence supports it, `auto_enabled=0` initially (Ruben can flip on
   after one more confirmed self-resolution).
3. **Seed `failure_repair_recipes`** with a `failure_category`, a
   `detection_pattern` description, and a `planner_input_modifier` that
   tells the next planner pass exactly what to do (or what NOT to do).
   `retry_strategy` + `max_attempts` set per the action class.
4. **Document in HANDOFF_NOTES.md** with section dated PT, explicitly
   answering "why RUBEN didn't catch this" so the gap is visible.
   That root-cause analysis IS the institutional memory — don't skip it.

If the failure mode is in the executor itself (silent ghost loop, plan
shape, schema mismatch, worker death, sudoers wall, etc.), ALSO file an
`orchestrator_ideas` row at status=approved per .clinerules/38 with the
specific code change RUBEN needs (e.g. "extend the planner-self-block
detector to fire after 2 silent_ghosts on same chain instead of 5", or
"add `decompose_umbrella_into_supervised_children` action to the
recipe consumer"). RUBEN executor consumes those ideas; KAIZEN
classifies the failure class.

## When the source is "Ruben pasted a bug report from email or SMS"

Same shape, plus an explicit investigation step:

5. **Identify the agent that should have caught it.** Email AI? Voice AI?
   Chat AI? Ticket AI? An auto-responder cron? Find the agent.
6. **Check that agent's logs for the inbound event.** Did it see the
   trigger? Did it classify? Did it act? Where in the pipeline did it
   fall over? Don't guess — pull the actual row from
   `email_inbound_log` / `voice_call_log` / `communication_log` /
   `tickets` / etc.
7. **If the agent never saw the event**, file a P0 idea to fix the
   intake path.
8. **If the agent saw the event but misclassified**, seed a
   `ai_compiled_rules` row with `source_correction_ids='clinerules:46'`
   prefix so the nightly recompiler protects it (per the
   `lib/PromptRuleCompiler.php` 2026-04-29 patch).
9. **If the agent classified but didn't act**, the failure is in the
   action consumer — file an idea against the specific cron/handler
   that should have fired.

## What this rule does NOT mean

- It does NOT mean every typo correction creates a learned pattern row.
  Use judgment. The bar is "would this same failure mode plausibly
  recur within the next 90 days against ANY chain / student / surface."
- It does NOT replace the immediate fix per .clinerules/29 (act on
  confidence). The four-step wrap is AFTER the symptom is gone.
- It does NOT mean filing speculative ideas. Every idea needs a concrete
  acceptance criterion and the source incident in `description`.
- It does NOT apply to questions Ruben asks where we just answer
  ("what's the load on Artemis?" — no agent failed there).

## Anti-patterns that violate this rule

- Closing a triage task with "fixed the immediate symptom, no further
  action" when an agent had visibility and could have caught it.
- Filing one generic "fix this class" idea instead of seeding the
  learned_patterns + recipe rows.
- Skipping the "why didn't RUBEN catch this" root-cause note in
  HANDOFF_NOTES.
- Updating the `.clinerules` file but not also seeding the runtime
  pattern row. Rules live in prompts; runtime gates live in the DB.
  Both are needed (per .clinerules/15 + 19).

## Self-check at every attempt_completion

Ask: *"Did I correct an agent on something that's already shipped or
already in production?"* If yes:

1. Did I seed `orchestrator_learned_patterns`? (row visible in
   `/emtskills/routes/orchestrator_learned_patterns.php` or via
   `SELECT pattern_hash FROM orchestrator_learned_patterns ORDER BY id DESC LIMIT 5`)
2. Did I seed `failure_repair_recipes`? (row visible in
   `SELECT failure_category FROM failure_repair_recipes ORDER BY id DESC LIMIT 5`)
3. Did I document in HANDOFF_NOTES with "why RUBEN didn't catch this"?
4. Did I file an `orchestrator_ideas` row at approved-tier if the
   executor itself needs code change?

If any answer is no, the correction is incomplete. Add the missing
pieces before declaring done.

## Cross-references

- .clinerules/22 — executor self-supervision loops (the policy framework
  this rule extends to user-facing agent corrections)
- .clinerules/23 — KAIZEN MCP (the runtime tool for classifier nurturing)
- .clinerules/29 — agents act on confidence tier (immediate-fix policy)
- .clinerules/36 — orchestrator self-heal vs escalation
- .clinerules/38 — Ruben-asked = autonomous tier minimum
- .clinerules/42 — offer proactive systemic solutions
- .clinerules/15 — no internal reasoning narration (code-level gates not
  prompt-only)
- .clinerules/19 — no third-party assessment names (same shape — both
  prompt and runtime guardrail)
- HANDOFF_NOTES.md — root-cause documentation lives here

## Last updated

2026-05-11 14:10 PT — initial rule. Source: chain 5494 planner-self-block
loop. Ruben asked for this rule by name (4 separate sub-directives in one
message) after recognizing that the loop continued for ~1.5h because
RUBEN had no pattern for it, even though the loop fingerprint was
literally visible in the planner's own plan body. The pattern row + the
recipe were seeded the same session as part of the resolution. This rule
formalizes that pattern as the default behavior going forward.

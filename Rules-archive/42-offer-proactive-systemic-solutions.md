# 42 — Offer proactive systemic solutions, not just the immediate fix

Permanent rule. Workspace-scoped. Source: 2026-05-11 Ruben directive verbatim:
*"what suggestions do you have to systemically resolve all these situations
proactively. cline rule — please offer proactive solutions to problems
submitted"*

## The bright-line rule

**When Ruben submits a problem, after the immediate fix is in place, I must
ALSO surface a proactive systemic-solution layer** — code/config/automation
changes that prevent the same class of issue from recurring without manual
intervention. This is not optional. Every triage / firefighting session ends
with at least one filed `orchestrator_idea` (or set of ideas) tagged for
prevention of the class, not just the instance.

## What "proactive" means concretely

Three layers, in order of preference:

1. **Block at source.** Add a code-level gate that makes the bad outcome
   impossible. Example: pre-send AI-leak scanner that BLOCKS outbound
   rather than `sent_then_flagged`.
2. **Detect at first occurrence + auto-heal.** Add a `learned_pattern` row +
   `failure_repair_recipe` so RUBEN executor auto-acts next time. Example:
   if 3 `no-tool-use` strikes detected post-`safe_deploy`, auto-close the
   chain instead of letting it YOLO.
3. **Surface for human review.** A cron / health dashboard that catches the
   class within minutes of first occurrence + pages the right human.
   Example: cron-heartbeat health dashboard — would have caught the 7-day-
   broken zoom_daily_routing the day it broke, not after 7 days.

Always prefer (1) over (2) over (3). Only fall back to (3) when (1) and (2)
are infeasible.

## What I MUST do at every wrap-up

In `attempt_completion` for any incident-response / triage / debug session,
in addition to the immediate-fix summary, include a **"PROACTIVE SYSTEMIC
SOLUTIONS"** section that:

1. Names the **class** of problem (not just this instance).
2. Lists **2-5 specific systemic fixes** ranked by leverage. Each one:
   - File path or code area being changed
   - Whether it's block-at-source / detect-and-heal / surface-and-page
   - Estimated effort (small / medium / large)
   - What it prevents
3. Filed each fix as an `orchestrator_idea` with **status=approved** per
   .clinerules/38 (Ruben-asks = autonomous tier minimum), priority P0/P1/P2,
   tagged with `source_incident` and `clinerules:42`.

## What this rule does NOT mean

- It does NOT mean ship 5 fixes immediately. The point is to *surface and
  queue* them as approved ideas so RUBEN executor or a future Cline session
  picks them up.
- It does NOT replace the immediate fix. Immediate symptom always gets
  addressed first per rule 29 (act on confidence tier).
- It does NOT apply to pure Q&A or single-file edits — only to triage /
  incident / "why is this broken" tasks.
- It does NOT mean filing speculative ideas. Each proactive idea must have
  a concrete acceptance criterion and a clear ROI tied to the incident.

## Anti-patterns that violate this rule

- Closing a triage task with just "fixed the immediate symptom, no
  further action."
- Suggesting proactive fixes in prose only, without filing them as
  `orchestrator_ideas` rows.
- Filing ideas at status=proposed (default) instead of bumping to
  status=approved per rule 38.
- Filing ONE generic "fix this class" idea instead of breaking down
  the layers.
- Forgetting to cite `clinerules:42` in the idea's source_correction_ids
  or description.

## Cross-references

- .clinerules/29 — agents act on confidence tier (immediate-symptom fix path)
- .clinerules/22 — executor self-supervision loops (the orchestrator side)
- .clinerules/23 — KAIZEN MCP (failure-classifier for layer 2)
- .clinerules/38 — Ruben-asks = autonomous tier minimum (file status=approved)
- .clinerules/40 — Artemis Ollama for cost-savings (always consider
  cheap-LLM scrubbing layers for new detection ideas)

## Self-check at every attempt_completion

Ask: *"Is this a triage / debug / incident-response task?"* If yes:

1. Did I file at least 1-3 proactive `orchestrator_ideas` for the class?
2. Are they all status=approved per rule 38?
3. Did I include a "PROACTIVE SYSTEMIC SOLUTIONS" section in the wrap-up?
4. Did each idea cite the source incident + `clinerules:42` in description?

If any answer is no, I'm violating this rule. Add the missing pieces
before declaring complete.

## Last updated

2026-05-11 — initial rule. Source: Ruben directive after I closed the
morning YOLO + voice-AI-Metz + Rebecca-Bui-leak + zoom-routing triage
session without filing proactive class-level fixes for any of them. The
session had 4 distinct fix-the-symptom outcomes but only ONE proactive
idea filed (#3008 for voice-AI staff detection). The other 3 classes
(FPM-YOLO narration, AI reasoning leak pre-send block, cron-heartbeat
health visibility) had no systemic-fix idea on the board until this
rule was written and the companion ideas filed at this same session.

# Force subagent use + first-tool-call tripwire (default-on, not judgment)

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> **Live violation counters:** call `clinerules_stats` to see current 7d/30d/all-time burst rates and the explicit-ask-ignored vs research-without-subagent breakdown. Counters auto-update via `~/Documents/Cline/rule_violations/scan.py`. Last scan: 2026-06-04 02:48:30 PDT — 7d=185, 30d=2185, all-time=3829. If you are reading this rule, you are part of the count — don't add to it.
<!-- RULE_VIOLATION_COUNTERS:END -->
## The default

**Default first move on every new Cline task = `use_subagents`.** Skip only if the task hits one of the 5 exceptions below. If unsure, dispatch.

## The 5 exceptions (skip subagents only if)

1. **Single-file single-edit** — Ruben said change X to Y in file Z. One `replace_in_file` / `write_to_file` and done.
2. **Single-command status check** — "what's the load," "is cron running." One `execute_command`.
3. **Mid-conversation continuation** — Ruben actively waiting on a reply fully determined by context already loaded.
4. **Pure restatement / formatting** — reword, format, translate. No new info.
5. **Already-dispatched** — `use_subagents` already ran this task, new turn acts on results.

If Ruben says "use subagent" / "verify" / "research" / similar → dispatch IMMEDIATELY, overrides every exception.

## The tripwire (mandatory — applies to EVERY tool call, not just the first)

**Every assistant turn that contains a tool call MUST open with the tool block OR with at most ONE short sentence of context immediately followed by the tool block in the SAME response.** No standalone prose turns, no narrated multi-step plans without the tool, no "I'm about to do X" / "Doing Y now" / "Next I'll Z" without the tool block right after.

For the FIRST tool call of a task, prefix with exactly one of:

- `Subagent plan: dispatching N for <topics> (first tool call below).`
- `Subagent plan: skip, exception #<1-5> (<name>) — <one line why>.`

For mid-task turns: the tool block stands on its own, or one short sentence + tool. That's it.

### Why this fails (and trips YOLO)

If a turn emits prose without a tool block, Cline injects `[ERROR] You did not use a tool!`. Next turn same shape = same error. 3rd no-tool-use strike = YOLO. Observed 3+ fresh tasks die this way on 2026-05-19. The fix: stop describing the action and emit it.

### Banned phrases

- "Doing X now, then Y" / "I'm about to call Z" / "Next I'll patch W" without an immediate tool block
- Any line ending with a colon implying "the tool block is the next thing" if the response then ends without a tool block
- Plan line emitted as a standalone turn with no tool

### Interrupted-task pickup

First tool call after `[TASK RESUMPTION]` / `[YOLO MODE]` / "pick up task" is ALSO gated. Plan line:
`Subagent plan: dispatching 3 (interrupted-task pickup) for prior-task JSON, referenced state, Ruben-message reconciliation.`

### Multi-directive Ruben messages

≥3 distinct directive clusters (budget, action authority, cleanup, analysis, tooling) → one subagent prompt per cluster. Plan line:
`Subagent plan: dispatching N (multi-directive) for <cluster 1>, <cluster 2>, ...`

## EMSU policy lookups → 7B-LoRA first

Per .clinerules/74: "what does our policy say," "categorize this," "score relevance" → first move is `call_ollama` with `emsu-qwen2.5-coder:7b-lora` ($0). Only fall back to Haiku subagent if 7B returns junk.

Plan line: `Subagent plan: skip, EMSU policy lookup → call_ollama 7B-LoRA first (per rule 74).` The call_ollama IS the first tool.

## How to dispatch

`use_subagents` accepts up to 5 prompts in parallel. Each prompt: self-contained, specific deliverable, bounded scope, pointed at concrete sources.

Canonical 5-prompt research pattern:
1. Official docs + vendor FAQs
2. GitHub issues + Stack Overflow + forums
3. Local codebase grep / prior art
4. (optional) Second independent source
5. (optional) Synthesize tradeoffs

Canonical 5-prompt multi-step build pattern:
1. Research underlying mechanism / constraint
2. Plan subsystem A
3. Plan subsystem B
4. Plan subsystem C
5. Plan migration + rollback + smoke tests

## Self-check

Before any non-`use_subagents` tool early in a task: is this in one of the 5 exceptions? If no → dispatch. If halfway through `attempt_completion` on something I never dispatched a subagent for → abandon, dispatch.

## Reversal

Revert this section. cline-handoff-relay syncs to Artemis hourly.

## Source incidents

- **2026-05-03** v1: Artemis pty-host saturation — went inline 3× instead of dispatching.
- **2026-05-14** v2 (default-on, 5 exceptions): Opus first-task did evaluations inline, zero subagent calls, zero 7B-LoRA. Ruben: *"we need to make some other adjustments to the client rules to force opus to do as we ask."*
- **2026-05-15** tripwire: counters at 639/7d, 2500/30d. Ruben: *"what can we do."* Tripwires fire on measurable event; defaults rationalize away.
- **2026-05-19** mid-task variant: tasks 1779253360281, 1779252924920, 1779252183079 all died from plan-line-without-tool or "Doing X now"-narration-without-tool. Consolidated rewrite this date.

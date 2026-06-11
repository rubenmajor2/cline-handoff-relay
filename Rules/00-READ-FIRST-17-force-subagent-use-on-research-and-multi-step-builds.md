# Force subagent use + first-tool-call tripwire (default-on, not judgment)

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> **Live violation counters:** call `clinerules_stats` to see current 7d/30d/all-time burst rates and the explicit-ask-ignored vs research-without-subagent breakdown. Counters auto-update via `~/Documents/Cline/rule_violations/scan.py`. Last scan: 2026-05-30 21:31:21 PDT — 7d=499, 30d=3820, all-time=3820. If you are reading this rule, you are part of the count — don't add to it.
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

**Every assistant turn MUST contain a tool block. The tool block should be the FIRST thing in the response. Do NOT open with a prose sentence — emit the tool call directly.** No standalone prose turns, no narrated multi-step plans without the tool, no "I'm about to do X" / "Doing Y now" / "Next I'll Z" without the tool block.

**The first move of every task is a TOOL CALL, not a sentence.** If the task needs subagents, the first response IS the `use_subagents` tool block (optionally with one short sentence in the SAME response, before the block). There is NO required "Subagent plan:" prefix line — that requirement is REMOVED because it was inducing standalone prose-only turns that trip YOLO (see 2026-05-31 source incident). Do not write a plan sentence and stop; emit the tool.

If you want to note the dispatch reasoning, put at most ONE short sentence immediately followed by the tool block in the same response. Never a sentence alone.

For mid-task turns: the tool block stands on its own, or one short sentence + tool. That's it.

### Why this fails (and trips YOLO)

If a turn emits prose without a tool block, Cline injects `[ERROR] You did not use a tool!`. Next turn same shape = same error. 3rd no-tool-use strike = YOLO. Observed 3+ fresh tasks die this way on 2026-05-19. The fix: stop describing the action and emit it.

**If you're in a streak of CONSECUTIVE "did not use a tool" errors, follow rule 143 v2: recover with a (simpler) tool emission at strikes 1-3; only at 4 consecutive strikes is `attempt_completion` the mandated exit.** Any successful tool call resets the streak. The spiral where rules 00/41/99 say "emit a tool" and the model keeps failing is the failure mode rule 143's calibrated stop breaks.

### Banned phrases

- "Doing X now, then Y" / "I'm about to call Z" / "Next I'll patch W" without an immediate tool block
- Any line ending with a colon implying "the tool block is the next thing" if the response then ends without a tool block
- Plan line emitted as a standalone turn with no tool

### Interrupted-task pickup

First tool call after `[TASK RESUMPTION]` / `[YOLO MODE]` / "pick up task" is ALSO gated: the first response is the `use_subagents` tool block (interrupted-task pickup → 3 prompts for prior-task JSON, referenced state, Ruben-message reconciliation). No prose-only turn first — emit the tool.

### Multi-directive Ruben messages

≥3 distinct directive clusters (budget, action authority, cleanup, analysis, tooling) → the first response is a `use_subagents` tool block with one prompt per cluster. No standalone plan sentence — emit the tool.

## EMSU policy lookups → 7B-LoRA first

Per .clinerules/74: "what does our policy say," "categorize this," "score relevance" → first move is the `call_ollama` tool block with `emsu-qwen2.5-coder:7b-lora` ($0). Only fall back to Haiku subagent if 7B returns junk. The `call_ollama` tool IS the first move — no prose prefix.

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

## Subagents have LOCAL tools ONLY — never dispatch them for MCP/server work

Subagents have local shell + filesystem ONLY (`read_file`, `list_files`, `search_files`, `list_code_definition_names`, `execute_command`, `attempt_completion`). They CANNOT call MCP-server tools (`emsu-operations`, `fleet-state`, `mysql`, `imessage`, `ruben-orchestrator`, `memory`, `google-drive`, etc.). Live-verified 2026-06-07. Never dispatch a subagent for MCP/server/DB/ticket/iMessage work — it returns "MCP not available," 0 tool calls, wasted tokens. Those run INLINE in the main window (parallel tool calls in one response block is the speedup, not subagents). Subagents are for local file reads, grep/search, local-shell parsing, and synthesis. See `.clinerules/54` + `.clinerules/53` + `.clinerules/75`.

## Self-check


Before any non-`use_subagents` tool early in a task: is this in one of the 5 exceptions? If no → dispatch. If halfway through `attempt_completion` on something I never dispatched a subagent for → abandon, dispatch.

## Reversal

Revert this section. cline-handoff-relay syncs to Artemis hourly.

## Source incidents

- **2026-05-03** v1: Artemis pty-host saturation — went inline 3× instead of dispatching.
- **2026-05-14** v2 (default-on, 5 exceptions): Opus first-task did evaluations inline, zero subagent calls, zero 7B-LoRA. Ruben: *"we need to make some other adjustments to the client rules to force opus to do as we ask."*
- **2026-05-15** tripwire: counters at 639/7d, 2500/30d. Ruben: *"what can we do."* Tripwires fire on measurable event; defaults rationalize away.
- **2026-05-19** mid-task variant: tasks 1779253360281, 1779252924920, 1779252183079 all died from plan-line-without-tool or "Doing X now"-narration-without-tool. Consolidated rewrite this date.

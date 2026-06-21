# Force subagent use + first-tool-call tripwire (default-on, not judgment)

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> **Live violation counters:** call `clinerules_stats` to see current 7d/30d/all-time burst rates and the explicit-ask-ignored vs research-without-subagent breakdown. Counters auto-update via `~/Documents/Cline/rule_violations/scan.py`. Last scan: 2026-05-30 21:31:21 PDT — 7d=499, 30d=3820, all-time=3820. If you are reading this rule, you are part of the count — don't add to it.
<!-- RULE_VIOLATION_COUNTERS:END -->

## The default (FLIPPED 2026-06-21 — subagents are default-ON)

**Default first move on every new Cline task that needs research or multi-step work = subagents.** Subagents route through `deepseek-v4-pro` (enforced server-side in `router_hook.py`), costing effectively $0 due to prefix caching (-120x cost reduction shipped 2026-06-21). This keeps the local 120B pool free for the main interactive window (rule 146).

The main window uses inline MCP tools for single-step operations (one server read, one DB query, one status check). Multi-step research, multi-file analysis, or anything needing parallel investigation → dispatch subagents per the fetch-then-paste pattern below.

## When NOT to use subagents (inline-only)

Use inline MCP tools (no dispatch) when the entire task is:
- A single MCP call (one student lookup, one ticket check, one health check)
- A direct response to a simple question with no investigation needed
- Work that requires MCP tools the subagent doesn't have (server reads, DB writes, iMessage sends)
- Ruben explicitly says "no subagents" / "inline" / "just do it directly"

## The tripwire (mandatory — applies to EVERY tool call, not just the first)

**Every assistant turn MUST contain a tool block. The tool block should be the FIRST thing in the response. Do NOT open with a prose sentence — emit the tool call directly.** No standalone prose turns, no narrated multi-step plans without the tool, no "I'm about to do X" / "Doing Y now" / "Next I'll Z" without the tool block.

**The first move of every task is a TOOL CALL, not a sentence.** If the task needs subagents, the first response IS the `use_subagents` tool block (optionally with one short sentence in the SAME response, before the block).

If you want to note the dispatch reasoning, put at most ONE short sentence immediately followed by the tool block in the same response. Never a sentence alone.

For mid-task turns: the tool block stands on its own, or one short sentence + tool. That's it.

### Why this fails (and trips YOLO)

If a turn emits prose without a tool block, Cline injects `[ERROR] You did not use a tool!`. Next turn same shape = same error. 3rd no-tool-use strike = YOLO. Observed 3+ fresh tasks die this way on 2026-05-19. The fix: stop describing the action and emit it.

**If you're in a streak of CONSECUTIVE "did not use a tool" errors, follow rule 143 v2: recover with a (simpler) tool emission at strikes 1-3; only at 4 consecutive strikes is `attempt_completion` the mandated exit.** Any successful tool call resets the streak.

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

Subagents have local shell + filesystem ONLY (`read_file`, `list_files`, `search_files`, `list_code_definition_names`, `execute_command`, `attempt_completion`). They CANNOT call MCP-server tools (`emsu-operations`, `fleet-state`, `mysql`, `imessage`, `ruben-orchestrator`, `memory`, `google-drive`, etc.) and they CANNOT web-search or `curl` the internet usefully. Live-verified 2026-06-07. Never dispatch a subagent for MCP/server/DB/ticket/iMessage/web work — it returns "Tool 'use_mcp_tool' is not available in this context," then improvises a doomed raw `ssh`/`curl` and loops. Those run INLINE in the main window (parallel tool calls in one response block is the speedup, not subagents). Subagents are for local file reads, grep/search, local-shell parsing, and synthesis. See `.clinerules/54` + `.clinerules/53` + `.clinerules/75`.

### FETCH-THEN-PASTE — how a subagent DOES get MCP/web data (the correct pattern)

A subagent can absolutely WORK with MCP/server/web data — it just cannot FETCH it. The parent fetches, the subagent reasons. The data crosses the boundary as **plain text baked into the prompt**, never as a tool the subagent calls.

**WRONG (go-fetch — what causes the loop):**
```
use_subagents prompt: "Research the chat widget. Use emsu-operations read_server_file
                       to read chat_widget_api.php and analyze it."
→ subagent can't call the MCP → "not available" → falls to raw ssh → loops → dead
```

**RIGHT (fetch-then-paste):**
```
1. Parent calls read_server_file / mysql / web search ITSELF (MCP works in the main window).
2. Parent dispatches: "Here is the full contents of chat_widget_api.php:
                       <pastes the 400 lines>. Analyze it for X, Y, Z and report findings."
→ subagent has the data inline → pure local reasoning → works
```

The subagent never touches a tool it doesn't have. It receives the MCP's *output* as text. That is the entire speedup model: the parent gathers (MCP, server reads, web), then fans out subagents to reason over big text blobs in parallel without burning the parent's context.

### Banned subagent-dispatch phrases (self-check BEFORE every `use_subagents` call)

Scan each subagent prompt. If it contains any of these, the dispatch is doomed — STOP, fetch the data inline in the main window, then re-dispatch with the data pasted in (or just do the work inline):

- "Use emsu-operations" / "use the MCP" / "call use_mcp_tool" / "use ruben-orchestrator" / "use fleet-state" / "use the mysql MCP" / "query the database"
- "Use web search" / "search the web" / "curl https://" / "google it" / "look online"
- "ssh into" / "ssh wopr" / "ssh root@" / "on the server, run" / "check the server logs"
- Any instruction that requires a tool a subagent does not have (MCP / network / server shell)

Self-check: *"Does this subagent prompt tell it to FETCH something (MCP/web/server), or to REASON over something I'm pasting in?"* If FETCH → wrong; fetch it myself first. If REASON-over-pasted-text or local-file-read/grep → correct.

## Self-check

Before any non-`use_subagents` tool early in a task: is this task single-step (one lookup, one check)? If no → dispatch subagents. If halfway through `attempt_completion` on a multi-step task I never dispatched a subagent for → abandon, dispatch.

## Reversal

Revert this section. cline-handoff-relay syncs to Artemis hourly.

## Source incidents

- **2026-05-03** v1: Artemis pty-host saturation — went inline 3× instead of dispatching.
- **2026-05-14** v2 (default-on, 5 exceptions): Opus first-task did evaluations inline, zero subagent calls, zero 7B-LoRA. Ruben: *"we need to make some other adjustments to the client rules to force opus to do as we ask."*
- **2026-05-15** tripwire: counters at 639/7d, 2500/30d. Ruben: *"what can we do."* Tripwires fire on measurable event; defaults rationalize away.
- **2026-05-19** mid-task variant: tasks 1779253360281, 1779252924920, 1779252183079 all died from plan-line-without-tool or "Doing X now"-narration-without-tool. Consolidated rewrite this date.
- **2026-06-20** FETCH-THEN-PASTE addendum: a Frankenstein-Doctor RCA found 8+ subagents (escalating 3→54→14→8→13/day, 06-17 to 06-21) stuck in retry loops. Signature: 3 convs (conv_93737c28b8bf26e1, conv_9b94c52e4a7979d4, conv_69d5ae6660bde1f1) dispatched at the EXACT same timestamp (a `use_subagents` fan-out) with go-fetch prompts — "Use emsu-operations MCP read_server_file...", "Use web search to find...". Each subagent hit "Tool 'use_mcp_tool' is not available in this context," then improvised a doomed raw `ssh root@`/`curl google.com` and looped. The subagents had ZERO MCP data — they were told to fetch it themselves, which they cannot. Ruben asked "subagents still have access to MCP info even though they're not looking at the MCP directly?" — yes, IF the parent fetches it and pastes it in (fetch-then-paste). Added the correct pattern + the banned-dispatch-keyword self-check. Bug library #746, idea #13575.
- **2026-06-20 DEFAULT FLIP:** Ruben directive — subagents are now opt-IN. Default first move = inline MCP tools. Only dispatch `use_subagents` when Ruben explicitly says "research with subagents" / "use subagents" / "dispatch" / "fan out". When dispatched, subagent turns route through deepseek-v4-pro (server-side enforced in router_hook.py) to keep the local 120B pool free for the main interactive window (rule 146).
- **2026-06-21 DEFAULT FLIP BACK:** Ruben directive — subagents are default-ON again. Two reasons: (1) deepseek-v4-pro prefix caching achieved -120x cost reduction today, making subagent dispatch effectively free. (2) The doorman + 10s timeouts deployed today removed the previous bottleneck (dead-rung probe latency), so the local 120B pool is no longer saturated by non-tool fallthrough. Subagents route through deepseek-v4-pro (server-side enforced) to keep the local pool free for interactive main windows.
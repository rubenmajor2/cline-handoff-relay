# Force subagent use + first-tool-call tripwire (default-on, not judgment)

## ⛔ SUBAGENT BAN — frankenstein-llm windows (2026-08-11 Ruben directive)

**Running on `frankenstein-llm`? Subagents are BANNED. Do NOT call `use_subagents`.** Too slow, stall out easily. Run all multi-step work inline in the main window — use parallel MCP tool calls in a single response block when you need speed. This OVERRIDES the default-ON policy below until Ruben explicitly lifts the ban.

## The default (FLIPPED 2026-06-21 — subagents are default-ON)

**Default first move on every new Cline task that needs research or multi-step work = subagents.**

**Where subagents actually run:** the local 120B pool via `frankenstein-tools` adapter (NOT `deepseek-v4-pro`; see idea #23528). Cost is ~$0 but dispatch CONSUMES the same 120B capacity as the main window, so a wide fan-out can slow your interactive turns. Full routing analysis: `Rules-archive/00-case-law.md`.

The main window uses inline MCP tools for single-step operations (one server read, one DB query, one status check). Multi-step research, multi-file analysis, or anything needing parallel investigation → dispatch subagents per the fetch-then-paste pattern below.

## When NOT to use subagents (inline-only)

Use inline MCP tools (no dispatch) when the entire task is:
- A single MCP call (one student lookup, one ticket check, one health check)
- A direct response to a simple question with no investigation needed
- Work that requires MCP tools the subagent doesn't have (server reads, DB writes, iMessage sends)
- Ruben explicitly says "no subagents" / "inline" / "just do it directly"
- **frankenstein-llm window** — subagents BANNED (2026-08-11 Ruben directive: too slow, stall out). Run inline. See BAN block at top.

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

### No tool-discovery turns (idea #16673)

The MCP tool list in your system prompt IS the complete tool catalog. Never emit a turn whose sole purpose is tool discovery. The tools you have are already listed above. Read them, then call one.

Banned tool-discovery shapes:
- Calling non-existent tools like `request_tool_descriptions` or `list_available_tools`
- Emitting `attempt_completion` claiming tools "aren't visible" or "not loaded"
- Asking Ruben "what MCP tools do I have?" instead of scanning the system prompt

If you cannot find a tool that does X, that means no tool does X. Use the closest available tool, or state the gap inline in a tool-bearing turn. Do not spend a turn "discovering" what's already in front of you.

### Interrupted-task pickup

First tool call after `[TASK RESUMPTION]` / `[YOLO MODE]` / "pick up task" is ALSO gated: the first response is the `use_subagents` tool block (interrupted-task pickup → 3 prompts for prior-task JSON, referenced state, Ruben-message reconciliation). No prose-only turn first — emit the tool.

### Multi-directive Ruben messages

≥3 distinct directive clusters (budget, action authority, cleanup, analysis, tooling) → the first response is a `use_subagents` tool block with one prompt per cluster. No standalone plan sentence — emit the tool.

## EMSU policy lookups → 7B-LoRA first

Per .clinerules/74: "what does our policy say," "categorize this," "score relevance" → first move is the `call_ollama` tool block with `emsu-qwen2.5-coder:7b-lora` ($0). Only fall back to Haiku subagent if 7B returns junk. The `call_ollama` tool IS the first move — no prose prefix.

## How to dispatch

`use_subagents` accepts up to 5 prompts in parallel. Each prompt: self-contained, specific deliverable, bounded scope, pointed at concrete sources.

### Tool-call budget (soft cap — path 2 of idea #16849)

Every subagent prompt MUST include this budget instruction (append to the end of each prompt):

> **Budget: You have a maximum of 50 tool calls. At call #50, STOP and write your findings as your `attempt_completion` result — do not attempt a 51st call. If you hit a tool that fails repeatedly (3+ times), stop and report the failure in your completion instead of looping. Count every `read_file`, `search_files`, `list_files`, and `execute_command` toward your budget.**

This is a soft cap — it relies on model obedience. It catches productive-but-long investigations. It does NOT catch stuck loops (see rule 00 fetch-then-paste + banned-dispatch-keywords self-check for that protection). The hard cap (path 1, extension patch to `SubagentRunner`) is the durable guarantee, tracked as #16849.

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

Self-check: *"Does this prompt tell the subagent to FETCH something (MCP/web/server), or to REASON over something I'm pasting in?"* If FETCH → wrong; fetch it myself first. If REASON-over-pasted-text or local-file-read/grep → correct.

**MECHANICAL SCAN (do this, don't just intend it).** That self-check is judgment; this is a string test. Before EVERY `use_subagents` call, scan each prompt for these literals — case-insensitive, substring match:

`curl` · `http://` · `https://` · `web search` · `search the web` · `ssh ` · `mcp` · `from server` · `call the tool` · `query the database` · `check the server`

ANY hit = doomed dispatch. Fetch that data inline first, paste it in, then dispatch. Measured 2026-08-06 (idea #24241): ALL 27 subagent runs at 50+ tool calls were this violation. Worst burned **177 tool calls** looping on fetches it cannot perform, holding its fan-out ~41 min (wall-clock = slowest member).

**Bare `mcp` is deliberate, and so is `from server`.** 2026-08-09: a dispatch worded "Call the MCP tool `X` from server `Y`" hit ZERO literals on the older list (which named only `use the mcp` / `use_mcp_tool` / specific server names) and hung 5 subagents for 11 minutes. Match the CAPABILITY, not one phrasing of it. If a new wording slips through, widen this list in the same session.

### Exploratory research is inline-only, never subagent-dispatched

There's a phase subagents cannot help with: **when you don't yet know what you're looking for** — you're forming the question, not answering one. Bounded research (the normal case) has known sources; this does not.

If the task is "figure out what I even need to look at", the shape is iterative: fetch → read → decide what to fetch next → repeat. Subagents have no fetch tools, so telling one to "go figure out what's relevant" is a fetch-then-paste violation waiting to happen.

**The test:** do you already know the bounded, fixed set of sources? If yes → fetch them, paste in, dispatch to synthesize in parallel. If no → that discovery phase stays inline and sequential in the parent window until it converges to a concrete scope. Only THEN is dispatch legal. Same applies to the async Orchestrator/Executor lever (rule 267), for the identical reason.

## Self-check


Before any non-`use_subagents` tool early in a task: is this task single-step (one lookup, one check)? If no → dispatch subagents. If halfway through `attempt_completion` on a multi-step task I never dispatched a subagent for → abandon, dispatch.

## Source incidents

Full case law + source incidents: `Rules-archive/00-case-law.md` (trimmed 2026-07-11, idea #17166, to restore G7 12KB compliance).

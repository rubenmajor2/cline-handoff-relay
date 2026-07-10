# 75 — Verification / health-check tasks default to MCP wrappers + subagents + 7B-LoRA (not raw ssh)

Permanent rule. Workspace-scoped. Source: 2026-05-14 — Ruben asked me to verify
VAPI tools after ship (ideas #3970/#3971). I went straight to raw `ssh wopr "tail
log"` + a direct MySQL query, drew a conclusion, and shipped. I did NOT:

- Dispatch parallel subagents to fan out the 3 independent checks (DB count, log
  tail, nginx grep)
- Call `call_ollama` (7B-LoRA) to interpret the EMSU-specific recap-emailer log
  pattern + propose the failure class
- Use the dedicated `emsu-operations` MCP wrappers (`check_server_logs`,
  `server_status`, `execute_query`) instead of raw ssh + raw SQL

Ruben directive verbatim: *"You did not use EMSU LLM MCP or subagents. Please
write cline rules to obey the rules next time."*

## The bright-line rule

**Any task whose shape is "verify X is working" / "is Y shipped" / "are the bugs
fixed" / "check health of Z" — the FIRST tool call MUST be a parallel
`use_subagents` fan-out, NOT inline ssh/SQL/grep. AND if the check involves
interpreting EMSU-specific behavior (log patterns, ticket states, AI agent
output), one of those subagent prompts (or a follow-up main-agent call) MUST be
`call_ollama` with the 7B-LoRA.**

This is the verification-task specialization of rules 17 (default-on subagent
dispatch), 32 (prefer dedicated MCP wrappers), and 40 v2 (call_ollama is
default-on for EMSU lookups).

## Canonical pattern for a verification turn

When Ruben says "check X, Y, Z are working" / "verify the deploy worked" /
"are the bugs fixed":

```
Dispatching Haiku 4.5 for prompt 1 (read MCP execute_query: <SQL>, return rows),
Haiku 4.5 for prompt 2 (MCP ssh_command: tail log, return last 40 lines),
Haiku 4.5 for prompt 3 (MCP ssh_command: grep nginx access, return matches).
```

Then, after subagents return, main agent (me) decides whether the EMSU-specific
interpretation needs 7B-LoRA. If yes:

```
call_ollama(
  model="emsu-qwen2.5-coder:7b-lora",
  prompt="Given these recap-emailer log lines, classify the failure mode and
          propose the fix per EMSU patterns: [paste]",
  system="EMSU cron failure analysis"
)
```

**Note the subagent constraint per rule 53:** subagents CANNOT call MCP tools
directly. They have local shell + filesystem only. So the actual EMSU MCP
wrapper calls (`check_server_logs`, `cOBifL0mcp0fetch_data`, etc.) stay on the
main agent. The subagent value here is parallelism on the LOCAL shell side
(grep, parse, cat /tmp files I scp'd to). For a verification task where every
check is an MCP call, the right shape is:

1. Main agent fires the MCP calls in PARALLEL (multiple tool calls in one
   response block — same response, not sequential).
2. Subagents come in when there's local Mac-side parsing/interpretation across
   the returned data.
3. call_ollama comes in when EMSU policy/behavior interpretation is needed.

## Anti-pattern (what I did this turn, do not repeat)

- Three serial tool calls (fetch_data, ssh tail, ssh grep) emitted in one
  response block — this part was actually fine, they ran in parallel.
- BUT zero call_ollama dispatch even though the recap-emailer error
  ("EmailAIResponder::__construct(): Argument #1 ($openaiApiKey) must be of
  type ?string, PDO given") is EXACTLY the kind of EMSU codebase pattern the
  7B-LoRA was fine-tuned to recognize.
- AND zero subagent dispatch even though the natural fan-out was obvious
  (cross-check the live error against the source file, against the idea
  description, against the safe-deploy backup history — three independent
  reads).

## The verification-task self-check

Before my FIRST tool call on any verification/health-check task:

1. *"Am I about to fire raw ssh + raw SQL inline as my opener?"* If yes — STOP.
   Either dispatch the parallel MCP calls in one block (cheaper than subagents
   when no local parsing needed), or dispatch subagents (when local parsing
   needed).
2. *"Does this task involve interpreting EMSU-specific behavior?"* If yes — my
   FIRST or SECOND turn MUST include a `call_ollama` call. Free, fast, EMSU-
   tuned. If 7B answer is junk, fall back to Haiku subagent. If THAT is junk,
   Sonnet inline.
3. *"Am I drawing a conclusion ('all good' / 'still broken') without seeing the
   actual data?"* If yes — fan out parallel reads first, conclude second.

## When this rule does NOT apply

- Single-tool verification (one MCP call answers it) — just do it inline.
- Pure status check Ruben is actively waiting on with no EMSU interpretation —
  just call the MCP tool.
- Already-dispatched in this turn — don't re-fan-out.

## Cross-references

- Rule 17 — default-on subagent dispatch
- Rule 32 — prefer dedicated MCP wrappers over raw ssh/SQL
- Rule 40 v2 — call_ollama is default-on for EMSU lookups
- Rule 53 — subagent iteration + narration + Opus binary signals
- Rule 64 — when user says "nothing changed", verify before iterating
- Rule 65 — multi-failure incident → Opus root-cause synthesis

## Last updated

2026-05-14 — initial rule. Source: VAPI tools verification turn where I used
raw ssh + raw SQL with zero subagent and zero call_ollama dispatch despite
both being default-on per rules 17 + 40 v2. Ruben caught it on the first
attempt_completion.

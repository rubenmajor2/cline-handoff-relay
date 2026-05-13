# 53 — Subagents: dispatch throughout iteration + narrate models inline before every dispatch

Permanent rule. Workspace-scoped. Source: 2026-05-12 — Ruben directives verbatim:

> *"Please do as you suggested and change the main behavior use of subagents and put it in cline rules"* (re: subagents should be called throughout iteration, not just once at the start)

> *"However, i believe you could notate this in-line with a cline rule literally in text just above, dispatching Opus 4.7 for X, dispatching 7B for Y, dispatching Sonnet 4.6 for Z, etc..."* (re: mid-stream subagent model visibility)

Closes the gap that Cline 3.82 doesn't surface which model each subagent is running on, AND that main-agent habit defaults to "one fan-out at task start, then sequential."

## The bright-line rule

**Two parts, both mandatory:**

### Part A — Narrate every `use_subagents` dispatch inline before the tool call

Before any `use_subagents` tool call, the main agent MUST emit a one-line narration in plain text immediately above the tool block, naming the model for each prompt slot and what it's doing:

```
Dispatching Haiku 4.5 for prompt 1 (read live router state),
Sonnet 4.6 for prompt 2 (compose plan summary),
Opus 4.7 for prompt 3 (synthesize tradeoffs across the prior 2).
```

If a slot has no `prompt_N_model` set, narrate "parent model" (whatever model is currently driving the main agent — Sonnet 4.6, Opus 4.7, etc.). The narration uses the friendly model name, not the full provider ID.

This is the in-chat visibility fix while the Cline UI doesn't render it natively. Ruben reads the narration; he doesn't have to grep `task_metadata.json` after the fact.

### Part B — Dispatch subagents throughout the task, not just at the start

Default main-agent habit: fan out subagents at task start, then run sequential tool calls for execution. This is wrong. Re-dispatch parallel subagents anytime:

1. **3+ serial reads are queued.** E.g. about to run `ssh artemis "ps ..."` then `ssh artemis "cat ..."` then `ssh artemis "ls ..."` — fan those out as parallel subagents instead.
2. **An unknown surfaces mid-task.** E.g. discovered a service is down, need to check log + check status file + check checkpoint dir + check process tree — fan out, don't grind serially.
3. **Pre-completion sanity check.** Before `attempt_completion`, dispatch 2-3 verification subagents in parallel to confirm the state.
4. **Post-deploy smoke verification.** After a destructive change, dispatch parallel subagents to verify the change landed in each affected surface.
5. **Anytime the user asks "did X work?"** — fan out parallel verifications instead of running them serially yourself.

Each round of subagent dispatch counts against context but saves wall-clock time and produces a cleaner audit trail than serial tool calls.

## Required shape of the narration

```
Dispatching <model name> for prompt <N> (<one-line task purpose>),
<model name> for prompt <N> (<task purpose>),
<model name> for prompt <N> (<task purpose>).
```

Examples:

```
Dispatching Haiku 4.5 for prompt 1 (grep .clinerules for prior subagent rules),
Haiku 4.5 for prompt 2 (read live router model list),
Sonnet 4.6 for prompt 3 (synthesize the two reads into a recommendation).
```

```
Dispatching parent model for prompt 1 (read three small config files),
parent model for prompt 2 (one curl probe).
```

```
Dispatching 7B-LoRA for prompt 1 (EMSU-specific policy lookup, free on Artemis),
Opus 4.7 for prompt 2 (complex regulator filing draft).
```

If you only have one subagent in the dispatch, the narration is still required: "Dispatching Haiku 4.5 for prompt 1 (single research task)."

## Anti-patterns that violate this rule

- Calling `use_subagents` with no narration line above it.
- Narrating without the model name ("dispatching subagents to research X" — no model = invisible).
- Narrating only the first dispatch and skipping subsequent ones.
- Running 3+ serial tool calls when they could have been one parallel fan-out.
- "I'll just check this one thing serially first, then maybe dispatch later" — that's the failure mode. Dispatch first.

## Model selection guide (mirrors subagent-model-picker.md)

| Task type | Recommended model | Why |
|---|---|---|
| Reads, status checks, grep, list, simple data extraction | `claude-haiku-4-5` | $0.80/$4 per MTok, fast |
| Code patches <100 lines, single-file edits, plan composition | `claude-sonnet-4-6` | $3/$15, good reasoning |
| Reading minified bundles, multi-file code analysis, locating injection sites in obfuscated code | `claude-sonnet-4-6` | NOT Haiku — this is code analysis, not a cheap read |
| Architectural synthesis, regulator-grade writing, complex tradeoffs, designing a 2+ phase patch | `claude-opus-4-7` | $15/$75, only when it matters |
| Anthropic models only — subagents use the Anthropic API directly | (any of the above) | See limitation below |

## Subagent limitations on Cline 3.82 (KNOWN)

Two hard limitations on `use_subagents` in Cline 3.82 — both forced by the
dispatcher implementation:

1. **`use_subagents` calls the Anthropic API directly.** It does NOT route
   through `http://127.0.0.1:8787` (the LiteLLM cline-router). `prompt_N_model`
   accepts only Anthropic IDs (`claude-haiku-4-5`, `claude-sonnet-4-6`,
   `claude-opus-4-7`, plus future Anthropic releases). Passing
   `"emsu-qwen2.5-coder-7b-lora"` or any router-only model ID will fail with
   "model not found." Until a future Cline patch makes the subagent dispatcher
   honor `OPENAI_API_BASE`-style overrides, the 7B-LoRA and other router-only
   models cannot be used as subagents.

2. **Subagents do NOT have MCP access.** They have local shell + filesystem
   only. Anything that needs the `emsu-operations`, `mysql`, `ruben-orchestrator`,
   `imessage`, `kaizen`, `google-drive`, or any other MCP tool MUST stay on the
   main agent. Per rule 32 (prefer dedicated MCP wrappers), this means: any
   task that needs to query EMSU database, read server files, send iMessages,
   check tickets, or anything else MCP-routed is main-agent-only, not
   subagent-dispatchable. Subagents can still do local `grep`, `cat`, `python3`,
   etc. on the Mac filesystem.

**Practical implication:** for EMSU ops tasks, subagents are usually limited
to research that's local to the Mac (reading bundles, scanning local repos,
re-reading prior task JSON, parsing logs in /tmp). MCP/SSH/DB work stays on
the main agent. Don't dispatch a subagent for "go check the ticket queue" —
that's an MCP-only task.

## Lessons from the 2026-05-12 self-counter-example session

In the session that wrote this rule (task #1778607736240), I made these
mistakes that motivated the additions above:

- **Defaulted Haiku for 4 dispatches** even though 2 of them (locating the
  React renderer in 13MB of minified code, planning the 2-phase badge patch)
  were genuine architectural reasoning that warranted Sonnet or Opus. The
  "default cheap" instinct is the same anti-pattern rule 53 was meant to stop.
  Watch for: "this looks like a cheap read" — if the deliverable requires
  judgment about WHERE to put a patch or HOW to design something, it's not
  a cheap read.
- **Dispatched a subagent to call `read_server_file` via emsu-operations MCP.**
  The subagent reported back that the MCP isn't available in its environment.
  Wasted one round trip. Always check the limitations table above first.
- **Clustered dispatches at task start, then went serial for execution.** When
  the bundle patch turned out to need 2 phases (parser + renderer), I should
  have re-dispatched parallel subagents to locate the renderer in parallel
  with verifying the parser patch. Instead I serialized.

## What this rule does NOT do

- Does not patch the Cline UI to show model badges mid-stream — that's a separate bundle patch (tracked as future work).
- Does not allow subagents to take destructive action without locking primitives — that's covered by `.clinerules/17` if/when that rewrite ships.
- Does not require subagents on trivial tasks per the .clinerules/17 exception list (single-file edits, status checks, mid-conversation continuations).

## Cross-references

- .clinerules/17 — default-on subagent dispatch (the "when to dispatch" policy this extends)
- .clinerules/52 — answer questions in attempt_completion (this rule applies to narration in chat body, that one to Task Completed)
- ~/Documents/Cline/Rules/subagent-model-picker.md — model-cost guide for picking `prompt_N_model`
- Cline 3.82.0 bundle patch from 2026-05-12 that added `prompt_N_model` to `use_subagents`

## 2026-05-12 addendum — Opus selection: 5 binary signals (synthesized by Opus 4.7)

Before dispatching Haiku on any subagent, run this checklist. Any "yes" = Opus:

1. **Cross-system test:** Does answering require holding 2+ of {WOPR DB schema, Artemis GPU/router, Cline extension internals, CAPCE regulator rules, RUBEN executor logic} in the same reasoning simultaneously — not just mentioning them, but trading them off?
2. **Irreversibility test:** Will this output be acted on without a human re-reading it line-by-line? (Draft to CAPCE, SQL UPDATE plan, .clinerules edit, grievance rationale.) A Haiku hallucination here costs more than $50 of cleanup or one regulator-credibility hit.
3. **Tradeoff-density test:** Does the answer require choosing between 3+ options where each has non-obvious second-order consequences? Haiku picks option 1 confidently. Opus actually weighs them.
4. **"Why didn't it work" test:** Is this subagent being dispatched because something already failed? (Rule isn't sticking, same bug recurred, prior fix didn't hold.) Haiku gives a surface-level answer. Opus diagnoses the second-order cause.
5. **Ruben-will-quote-this test:** Will Ruben paste this output into an email, regulator filing, student letter, or a .clinerules rule? If the words matter beyond this session, it's Opus.

**The EMSU-specific Haiku trap (top 3 mis-classified task types):**
- "Analyze why this RUBEN executor keeps silent-ghosting" — looks like a read, is actually cross-system tradeoff analysis. Opus.
- "Design the insertion strategy for this 150KB TypeScript file" — looks like a code read, is architectural judgment. Sonnet minimum.
- "Write the .clinerules paragraph for this behavioral rule" — looks like text generation, is policy synthesis. Haiku produces vague platitudes. Opus produces the specific language that actually changes behavior.

## Last updated

2026-05-12 — initial rule. Source: cline-7b-phase3-analysis session
(task #1778607736240). Ruben caught me running 4 serial SSH probes when
they should have been one parallel fan-out, AND I wasn't narrating which
model was doing what when I did dispatch.

2026-05-12 (same day, second session) — added Opus binary signals addendum from Opus 4.7 dispatch in subagent-rules conversation. The 5 signals and EMSU-specific Haiku trap were synthesized by Opus, not Haiku or Sonnet.

## Critical: Sonnet may not have training signal on claude-opus-4-7

**claude-opus-4-7 was released 2026-04-24.** Sonnet 4.6's training cutoff may predate this. This means when Sonnet (as main agent) decides whether to dispatch Opus, it may not have strong internal knowledge that claude-opus-4-7 is meaningfully more capable. It will rationalize not paying the premium.

**Hard rule:** when any of the 5 binary signals above fire, the next use_subagents call MUST include `prompt_N_model="claude-opus-4-7"` — use that exact string. Do not substitute a different model. Do not reason that "this probably doesn't need Opus." The whole point of the binary signals is to remove the rationalization step.

claude-opus-4-7 facts (from verified live API, 2026-05-12):
- Confirmed live at api.anthropic.com/v1/models
- Most capable Anthropic model available
- $15 input / $75 output per MTok
- Meaningfully outperforms Sonnet on cross-system reasoning, policy synthesis, tradeoff analysis

If Option B (Sonnet as main + Opus dispatch) isn't producing Opus dispatches, the permanent fix is to switch the main Cline model to claude-opus-4-7 in Cline settings. That requires the UI — Settings gear → API Provider → change model. Sonnet as main will structurally under-dispatch Opus because it's asking a model to demote itself.

# 144 — Frankenstein canonical naming: 5 distinct names, resolve every reference through this map

Source: 2026-06-09 Ruben directive. He asked what to call the LLM system after Cline kept
conflating "Frankenstein LLM" with the Executor, the Orchestrator, and the docs MCP. The trap:
three different things have "Frankenstein" in the name, and Executor/Orchestrator/Cline are
SIBLING CLIENTS, not a stack. Using "Frankenstein LLM" as an umbrella for all of it makes a
fresh window re-derive the boundaries wrong every time and waste tokens.

## The bright-line rule

**There is ONE router: Frankenstein. Executor, Orchestrator, and Cline are CLIENTS that send
their LLM calls THROUGH Frankenstein. They are siblings, not nested. "Point Cline at Executor"
is a category error.** Resolve every Frankenstein/Executor/Orchestrator/Cline reference through
the 5-name map below.

## The 5 names

| Say this | It means |
|---|---|
| **Frankenstein** (a.k.a. "the router" / "Frankenstein LLM") | The routing + distill + serving brain: LiteLLM `/etc/litellm/router_hook.py` + `/etc/litellm/frankenstein_registry.yaml` + `lib/EmsuRagInjector.php` (distill) + the WHOLE model fleet. The `frankenstein-llm` entrypoint rides the spill ladder across ALL models by health: 7B → 14B → 32B → 70B → 120B (Cesar/Cato) → RunPod pod → DeepSeek (cloud) → Sonnet → Opus. NOT just the 120B (that is only the most common landing tier). |
| **Frankenstein MCP** | The READ-ONLY docs + verify tool (the `project-frankenstein` MCP server). Describes the system + runs rule-140 header probes. Does NOT route, run, or serve anything. NOT an umbrella name. |
| **the Executor** | `lib/RubenExecutor.php` — the autonomous plan-execution agent (generatePlan/executePlan/replan-shrink/self-heal). Runs approved ideas, deploys, fixes. A CLIENT of Frankenstein (surface=executor → frankenstein-llm, $0 local). |
| **the Orchestrator** | The event/decision/idea triage brain (`orchestrator_api.php` + triage crons + `orchestrator_event_log` + the `ruben-orchestrator` MCP). Decides WHAT to do, files ideas, makes decisions. A CLIENT of Frankenstein (surface=ruben_orchestrator). Distinct class from RubenExecutor. |
| **Cline** | The interactive VS Code coding agent + `.clinerules`. A CLIENT of Frankenstein (OpenAI path → frankenstein-llm → local). Not pinned to Claude. |

## Umbrella term

**"Project Frankenstein"** = the WHOLE stack (the Frankenstein router + the model fleet + the
three client agents Executor/Orchestrator/Cline + the Frankenstein MCP). This is the canonical
umbrella name (Ruben directive 2026-06-09). Use "Project Frankenstein" when you mean all of it;
use a specific name below for a single layer. ("the Frankenstein stack" is an accepted synonym.)

## How Ruben directs updates (and what each touches)

- "update **Project Frankenstein**" → the whole stack: look across ALL layers below.
- "update **Frankenstein**" → router/serving/distill layer: `router_hook.py`, the registry, model serving, the spill ladder, `EmsuRagInjector`.
- "update **the Frankenstein MCP**" → the docs/verify tool: `project-frankenstein-mcp/src/index.ts` → `npx tsc` → needs a Cline restart to load.
- "update **the Executor**" → `lib/RubenExecutor.php`.
- "update **the Orchestrator**" → orchestrator triage/decision code.
- "update **Cline**" → VS Code agent config + `.clinerules`.


## Where this name lives (so it sticks — per rule 135)

A name only sticks where it is written into a read-at-runtime surface. This vocabulary is in:
1. This rule (Cline).
2. The `project-frankenstein` MCP `frankenstein_architecture` output (`CANONICAL_NAMING` block) — the agent surface.
3. `/var/www/emtskills/docs/PROJECT_FRANKENSTEIN.md` (CANONICAL NAMING section) — the human/source surface.

## Self-check

If unsure which thing Ruben means, or about to call the whole system "Frankenstein LLM": stop,
resolve through the table above. Frankenstein = the router. The Executor/Orchestrator/Cline =
clients. The Frankenstein MCP = the docs tool. **Project Frankenstein** = all of it (the stack).


## Cross-references

- `.clinerules/135` — SLS naming precedent (a name only sticks where it is written into a read-at-runtime surface)
- `.clinerules/140` — verify LLM routing from live headers (Frankenstein routing is proven by header probes)
- `.clinerules/141` — call the project-frankenstein MCP first for architecture truth
- idea #11296 — this naming convention
- idea #11295 — the NOT_A_TRADITIONAL_ROUTER anti-revert block (same session)

## Source incident

2026-06-09 — Ruben: "if Executor is the router, what about Orchestrator? is that not a router too? what is Frankenstein routing through? ... I was thinking of just saying Frankenstein LLM, but hmm, not sure on this." Cline had loosely called the Executor "the router," conflating the routing layer with a client. The fix: 5 distinct names + an explicit umbrella, written into all three read-at-runtime surfaces.

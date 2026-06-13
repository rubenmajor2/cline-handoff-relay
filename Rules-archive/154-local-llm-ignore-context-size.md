# 148 — Context size is NEVER a reason to spill a local/free model to cloud. Frankenstein distills + fits, it does not size-route.

Permanent rule. Workspace-scoped. Source: 2026-06-09 Ruben directive verbatim:

> *"I want you to completely disregard the context size altogether for any of our local LLMs and change that rule accordingly. ... remember that it's more about the quality of the answer ... you have the corpus and you have the head ... the distillation ... if you look at frugal you'll see how this all works together ... I do not believe the token size is a factor remember that project Frankenstein is supposed to take the best parts of the context and put them in the right places. ... I really don't want it spilling over to DeepSeek if I can avoid it."*

## The foundation (researched 2026-06-09, PROJECT_FRANKENSTEIN.md CORE PRINCIPLES + frugal_gate.py)

Project Frankenstein is **DECOMPOSE → DISTILL → SERVE-LOCAL → REASSEMBLE**, not a "pick one model by context size" router. The pieces:

- **The router holds the FULL conversation context.** A 1,038,433-token input was served at $0 (verified). Window size does NOT force a cloud/paid model.
- **DISTILL / "best parts of context":** a RAG/distill pass (`lib/EmsuRagInjector.php`) extracts only the relevant slice (~5K chars) per sub-request, so the served model never sees the raw tokens. The per-model `max_model_len` ceiling is therefore MOOT for routing.
- **CORPUS + HEAD + distillation:** the local body (7B/14B/32B/70B/120B) does the ~90% deterministic/templated work from the distilled corpus; the paid HEAD (Sonnet/Opus) only ever generates the genuinely-hard SPAN; STITCHES (cheap 70B) smooth the seams.
- **FRUGAL is QUALITY-based, not size-based:** `frugal_gate.py` runs the local 70B, then a cheap self-judge scores reliability g(query,answer)→[0,1]; if g ≥ TAU[task_kind] it ACCEPTS the local answer ($0), else escalates. The decision is about answer QUALITY, never token count.

**Conclusion:** token/context size must NEVER be the thing that routes a request off a local model to DeepSeek/Claude. The correct response to an oversize prompt is (a) route to the largest-context healthy LOCAL member, and (b) "take the best parts of the context" — shrink/distill the prompt to fit that member's window — BEFORE dispatch. Cloud is a TRUE last resort only when every local member is down (rule 142).

## What was wrong (the "traditional router" behavior removed)

`router_hook.py` had two oversize-prompt guards that did `frankenstein-llm → deepseek-v4-pro` purely on `prompt_tokens > served_ctx - 1200`. That is exactly the size-routing Ruben is removing. ALSO: the LiteLLM **config fallbacks** for `cato-120b` / `cesar-120b` went straight to `[deepseek-v4-pro, claude-sonnet]`, so when a 120B member 400'd on an oversize prompt, LiteLLM's own fallback spilled to DeepSeek INVISIBLY (below the router hook). Both are fixed.

## The fix (shipped 2026-06-09, reversible)

1. **`LOCAL_IGNORE_CTX`** flag in `router_hook.py` (env `EMSU_LOCAL_IGNORE_CTX`, default `1`). When on, the two oversize guards route an oversize LOCAL entrypoint to the **largest-ctx healthy local 120B member** (`_largest_ctx_local_member()`), not cloud.
2. **`_fit_messages_to_ctx(messages, served_ctx, model)`** — "best parts of context": keeps system msgs + the first user msg (the task) + the last 2 msgs intact, head+tail-truncates the largest messages with a `[...trimmed...]` marker so `prompt_tokens` fits the member's window. The model serves locally instead of 400→cloud.
3. **Config fallbacks reordered local-first:** `cato-120b → [cesar-120b, ollama-llama3.3-70b, frank-serve-pod, deepseek-v4-pro, claude-sonnet]` (and cesar symmetric). DeepSeek is now the last LOCAL-exhausted resort, not the first spill. (frankenstein-llm's own tool chain is left unchanged — the config smoketest rule-142 gate BLOCKS adding raw 120B members there because raw gpt-oss can't emit tool_calls; tool routing is handled by `pick_tool_track`.)

## The proper long-term home: distill in the corpus, not truncate at the router

Truncation (`_fit_messages_to_ctx`) is the safety net. The RIGHT place to "take the best parts of context" is the **distill pass** (`EmsuRagInjector` / the corpus builder) — semantic extraction of the relevant slice, not head+tail character truncation. When the distill path covers a surface, the prompt arrives already-small and the fit step is a no-op. Build distill coverage; treat router truncation as the floor, not the design.

## Subagents should be served local-first too

Ruben's insight: if subagent dispatch is HIGHER, more of the work runs on cheap local models, so leaning into subagents increases the local-served share. Subagents that are pure file-read / grep / parse / synthesize (no MCP, no Claude-grade judgment) should route to the local body by default. (Cline's own subagents are local-shell only per rule 00 — the analog here is: agent/executor sub-tasks decomposed by Frankenstein get served by the local body first, escalating to the head only for the hard span.)

## Self-check before any change that touches context-size routing

1. *Am I about to spill a LOCAL model to cloud because of token count?* → No. Route to the largest-ctx local member + fit the prompt. Cloud only if all local down (rule 142).
2. *Did I verify with a live header probe (rule 140) that an oversize frankenstein-llm request serves LOCAL ($0), not openrouter?* → Required before claiming it works.
3. *Did I check BOTH spill paths — the router hook AND the LiteLLM config fallbacks?* → A member's config fallback can spill to DeepSeek below the hook.

## Cross-references

- `PROJECT_FRANKENSTEIN.md` CORE PRINCIPLES (decompose/distill/serve-local/reassemble; 1M tokens at $0)
- `frugal_gate.py` — quality-based early-exit (g vs tau), not size-based
- `.clinerules/142` — no dead-end entrypoints (why raw 120B can't be in frankenstein-llm's tool fallback)
- `.clinerules/140` / `141` — verify routing live, not from files
- `.clinerules/119` / `120` — Cline's own context handling (compress, never shortcut) — same philosophy, different layer
- `lib/EmsuRagInjector.php` — the distill pass (the proper home for "best parts of context")

## Source incident

2026-06-09 — Ruben wanted the 120B usable at any context without spilling to DeepSeek. Research (the Frankenstein doc + frugal gate) confirmed token size is not a real constraint: the router holds full context, distillation extracts the relevant slice, and frugal routes on answer quality. Removed the size→cloud guards for local models (route to largest-ctx local member + fit-to-window), and reordered cato/cesar config fallbacks local-first so DeepSeek is the last resort.

## Last updated

2026-06-09 — initial.

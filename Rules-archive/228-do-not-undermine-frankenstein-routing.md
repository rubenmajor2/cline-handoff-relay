# 143 — Do NOT rail traffic off local models. Project Frankenstein's whole point is to USE them.

Permanent rule. Workspace-scoped. Source: 2026-06-05 — Cline (Opus) shipped router_hook guard #10038 that forced Cline tool-calling turns OFF the local models onto claude-sonnet, "to fix unparsable tool calls." Ruben: *"you are messing up project frankenstein... by telling the router not to use our LLM models."* The guard was reverted. This rule exists so no future window repeats it.

## The bright-line rule

**Never add routing logic (router_hook.py, config.yaml fallbacks, KIND_TIER_PIN, guards) that defaults EMSU traffic to a paid Claude/cloud model when a local model (ollama-7b-lora, ollama-14b, ollama-32b, ollama-llama3.3-70b, any emsu-*-lora, CODE-70B) could serve it.** Project Frankenstein's entire purpose (rule 121 catabolize) is to MOVE traffic onto free local models. Railing it back to Claude is the exact opposite — it defeats the program and burns money.

If a local model produces a malformed response, the fix is to **fix the local model / its serving / the parse path**, NOT to route around it to Claude. Routing to Claude is a bandaid that masks the real work (rule 92).

## What triggered this (the anti-pattern, do not repeat)

Cline observed Cline-IDE getting "empty/unparsable tool calls," assumed "local models can't do structured tool calls," and added a guard forcing `has_tools` turns to claude-sonnet. Two errors:

1. **The premise was false.** Live test 2026-06-05: `ollama-llama3.3-70b` returns `STRUCTURED tool_calls=True` — it CAN serve Cline tool turns. Only the 7B (prose) and 14B (text-JSON) can't. A blanket non-claude rail threw out the working 70B too.
2. **Even if true, the answer is to train/fix the local model, not abandon it.** That IS Frankenstein (CODE-70B retrain, idea #9926). Defaulting to Claude removes the pressure/path to ever ship local.

This is also Opus-bias: reaching for the premium cloud model as the "safe" default instead of trusting the local stack Ruben is deliberately building.

## Before touching ANY routing surface

1. **Read the plan first.** `/var/www/emtskills/docs/PROJECT_FRANKENSTEIN.md` + WINDOW*_LLM_COST_NUKE_PLAN on Desktop + rule 121. Understand that the direction is local-ward, always.
2. **Ask: does my change move traffic TOWARD local or AWAY from it?** Away = stop, you're probably wrong. Toward = fine.
3. **A malformed local response is a bug to fix at the model/serve/parse layer**, not a reason to re-route to Claude. If you genuinely cannot fix it this session, leave the routing alone and file an idea — do NOT install a Claude-default guard "temporarily."
4. **The only legitimate Claude-rail is the existing anthropic-passthrough guard** (non-Claude can't emit Anthropic tool_use blocks on `/anthropic/v1/messages` specifically — a protocol constraint, not a quality judgment). Do not generalize it to the OpenAI path or use it as precedent to rail more traffic to Claude.

## Self-check

If I'm about to edit router_hook.py / config.yaml fallbacks and my change makes a model pick land on claude-* where it previously could land on a local model: STOP. That violates this rule unless Ruben explicitly asked for it. Re-read the plan. The cost program only works if local gets the traffic.

## Cross-references

- rule 121 — the 3Gs + catabolize (move volume to free local at ≥45% W/T)
- rule 92 — fix the core (fix the local model, don't bandaid-route to Claude)
- idea #9926 — CODE-70B retrain (the proper path to local Cline coding)
- idea #10038/#10039 — REJECTED, the guard this rule forbids

## Source incident

2026-06-05 — #10038 guard railed Cline tool turns to claude-sonnet on the OpenAI path. Ruben caught it ("you are messing up project frankenstein"). Reverted to pre-guard router_hook.py, reloaded via emsu-safe-litellm-restart.sh, ideas rejected. The 70B was already tool-capable; the guard was both wrong on facts and wrong in direction.

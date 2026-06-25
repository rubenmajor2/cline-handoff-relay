# 142 — No dead-end LLM entrypoints. A single-backend pin with a long timeout + no fallback is un-deployable (enforced by a preflight gate, not vigilance).

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-07 — a build window wired the `frankenstein-llm` LiteLLM entrypoint to ONE fleet member (the M1 70B) with `request_timeout: 90`, `num_retries: 0`, and NO fallbacks. When the M1 saturated under concurrent Cline windows + subagents, every request hung up to 90s then died. The M1 wasn't even down (metadata answered in 0.22s) — it just couldn't shed load, and the config gave it no escape hatch. Ruben: "how do we harden the system against such stupidity?" The answer per rule 92 is NOT "be more careful" — it's a gate that makes the bad config physically un-deployable.

## The bright-line rule

**An interactive LLM ENTRYPOINT (the model id a client like Cline / an agent actually calls) may NEVER be a dead-end.** If its `request_timeout >= 20s` it MUST have a fallback escape hatch — either per-model `litellm_params.fallbacks: [...]` OR membership in `router_settings.fallbacks` / `.context_window_fallbacks`. A long timeout with no fallback = one saturated/wedged backend stalls every request. That config must fail preflight, not reach production.

Entrypoints (the surfaces that cause a user-visible stall when pinned): `frankenstein-llm`, `emsu-cline-router`, `emsu-executor-auto`, `emsu-router-auto`. Frankenstein LLM is a SYSTEM across a fleet — it must route around any one wedged member, never hard-pin to it.

## The enforcement (the durable fix — already shipped)

`/usr/local/bin/emsu-litellm-config-smoketest.sh` (the preflight gate the `emsu-safe-litellm-restart.sh` wrapper runs BEFORE every restart, per rule 118) now FAILS the deploy if any ENTRYPOINT has `request_timeout >= 20` and no per-model or global fallback. A config with a dead-end entrypoint cannot be reloaded — the wrapper refuses and keeps the old container running. This caught a SECOND live dead-end (`emsu-cline-router`, also pinned 90s no-fallback) the moment it was armed.

Backup of the pre-gate smoketest: `/usr/local/bin/emsu-litellm-config-smoketest.sh.bak.<ts>`.

## The recovery shape for a wedged backend (what good looks like)

- `request_timeout: 10` (a 2021 M1 that hasn't answered in 10s is saturated — stop waiting)
- `num_retries: 0` (do NOT retry the same wedged box 2-3x at 10s each = 30s of stall before spilling)
- A fallback list that spills to a DIFFERENT, faster fleet member (e.g. `cesar-120b` 0.2s, `deepseek-v4-flash` 0.9s)
- Keep the weak-but-free box as PRIMARY (don't flip it) — just give the system a fast escape when it's busy

Net: M1 primary tries for 10s, then the system serves from Cesar-120B/DeepSeek in ~1s. The interactive box is used to capacity, never hung past its limit.

## Self-check before deploying any LiteLLM config change

1. *Did I touch an entrypoint's `request_timeout`, `num_retries`, `fallbacks`, or `api_base`?* → Run `emsu-litellm-config-smoketest.sh` BEFORE the reload. The safe-restart wrapper does this automatically; trust it. If it FAILs with "dead-end", add the fallback — do not `--force` past it.
2. *Am I pinning an entrypoint to a single backend?* → It needs a fallback list, always. One box is never the whole system.
3. *Is `num_retries` making a wedged box get retried 2-3x before spilling?* → Set it to 0 so spill is immediate; let the fallback list (not retries on the same box) provide resilience.

## Cross-references

- Rule 92 (fix at the core — the gate, not "be careful")
- Rule 118 (litellm restart only via the safe wrapper, which runs this gate as preflight)
- Rule 140 (verify routing from live headers — how you confirm the spill actually fired)
- Rule 141 (call the project-frankenstein MCP first for architecture truth)
- Rule 29 (act on confidence — Cline fixed both dead-ends + shipped the gate in-session rather than filing a ticket)

## Source incident

2026-06-07 — frankenstein-llm + emsu-cline-router both pinned to the M1 70B at request_timeout:90, no fallback → Cline windows hung ~90s then died under concurrent load. Fixed both to 10s + spill to cesar-120b/deepseek-v4-flash, and added the dead-end hardfloor to the config preflight smoketest so the class can never deploy again. Verified live: frankenstein-llm spilled M1→Cesar-120B in 10.6s for $0 instead of hanging.

## Last updated

2026-06-07 — initial.

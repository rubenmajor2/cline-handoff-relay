# 152 — A new LLM that comes online AUTO-ENROLLS under frankenstein-llm by default. Never hand-add boxes one by one.

Permanent rule. Workspace-scoped. Source: 2026-06-14 Ruben directive verbatim:

> "I kind of feel like I shouldn't have to be individually adding every single LLM as they come online into the Frankenstein LLM network. Unless specifically indicated, an LLM that is new and coming online should go right underneath the frankenstein LLM automatically. If I brought up another unit tomorrow it should just automatically be put into the system by default."

Companion to rule 146 (frankenstein-llm routes EVERY LLM we own), rule 142 (registry is single source of truth), rule 140 (verify routing live), rule 92 (fix at the core).

## The bright-line rule

**When a new model comes online on the fleet, it joins the Frankenstein network AUTOMATICALLY as a free `frankenstein-llm` pool member — health-gated, no per-box code edit, no manual tier assignment.** The default for any newly-serving unit is "free body under frankenstein-llm, routed by health." A human only intervenes to UPGRADE a box beyond that default (e.g. promote it to first-class tool-pool membership or a non-default tier), never to make it work at all.

Cline must NOT hand-add boxes to the registry/adapter one at a time as the reflex. If a box is serving and not yet enrolled, the question is "why didn't auto-enroll catch it," not "let me add it manually."

## The mechanism (already shipped — this is how it works)

`/usr/local/bin/frank_registry_autosync.py` (cron `emsu-frank-registry-autosync`, every 15 min, runs as root):

1. **Discovers** every serving unit listed in `/etc/litellm/frank_discovery_targets.txt` (one `HOST PORT PROBE` per line, PROBE ∈ {vllm, ollama}) plus a built-in fleet default list. Probes `/v1/models` (vllm) or `/api/tags` (ollama).
2. **Auto-enrolls** any serving unit whose `host:port` is NOT already in `/etc/litellm/frankenstein_registry.yaml`: appends a `- id: auto-<modelslug>` block (`role: body`, `cost: free`, live `served_ctx`, `auto_enrolled: <date>`) AND adds the slug to `frankenstein-llm`'s `pool_members`. Idempotent by endpoint — a box is never double-enrolled.
3. **Sets `/tmp/frank_registry_changed.flag`** so the next safe litellm restart (rule 118 wrapper) picks up the new member. The script never restarts litellm itself.
4. **Posts an informational** orchestrator_event + Discord note: "auto-enrolled N new unit(s) under frankenstein-llm; review only if it should be MORE than a free body."

Because the router (`router_hook.py` via `frankenstein_registry.py derive()`) builds `_120b_members` / pool membership FROM the registry, an auto-enrolled box is routed-to by health with zero router code change (rule 142 single-source-of-truth).

**Kill switch / opt-out:** set `FRANK_AUTOENROLL=0` in the cron env to revert to detect-and-alert-only. "Unless specifically indicated" (Ruben) = this flag, or a discovery-file omission.

## To bring up a new unit tomorrow (the whole procedure)

1. Start the model serving on its host:port.
2. If it's on a NEW host/port not already covered by the fleet defaults, add ONE line to `/etc/litellm/frank_discovery_targets.txt`: `10.100.0.9 11434 ollama`.
3. Done. Within 15 min it's a frankenstein-llm pool member; the next safe restart makes it live.

No registry hand-edit, no adapter `TOOLS_UPSTREAMS` edit, no router change for the basic case.

## What still needs a human (the deliberate upgrades, not "make it work")

- **First-class TOOLS-pool membership** (serving Cline tool-bearing turns via the adapter `:11510` rotation): tool-calling capability + reliability is box-specific, so promoting an auto-enrolled box into `FRANK_TOOLS_UPSTREAMS` with `supports_tools: true` + a `tool_rank` stays a reviewed change. Auto-enroll puts it in the CHAT/pool path by default (safe); tool-pool is the opt-in upgrade.
- **A non-default tier** (e.g. making a box the canonical L1c 32B): the default is "pool body," tier promotion is deliberate.
- These are UPGRADES from a working default, never prerequisites to working.

## Self-check

- About to manually add a serving box to the registry/adapter? Ask: "is auto-enroll supposed to have caught this?" If yes, the fix is auto-enroll (or a discovery-file line), not a one-off hand-add (rule 92).
- A new box isn't routing? Check `/var/log/frank_registry_autosync.log` + `grep auto_enrolled /etc/litellm/frankenstein_registry.yaml` + whether the safe restart fired, before hand-editing anything.

## Source incident

2026-06-14 — Ruben, finalizing the Frankenstein build batch: tired of individually adding each new LLM. Directed that a new unit auto-join under frankenstein-llm by default. Shipped: extended `frank_registry_autosync.py` (was detect-and-alert-only, "human must assign a tier/role") to auto-enroll by default, added `/etc/litellm/frank_discovery_targets.txt`, proven live (simulated-new joshua-70B auto-enrolled into the pool in a dry-run; idempotent no-op against the real fleet). This rule makes the behavior durable so no future Cline window reflexively hand-adds boxes.

## Last updated

2026-06-14 — initial.

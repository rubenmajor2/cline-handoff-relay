# 250 — No hardcoded LLM statuses in router config. The doorman + reactive quarantine keep the show on.

Source incident: 2026-07-03 — recurring `frankenstein-llm` "502 status code (no body)" / connection-refused on immediate dispatch. RCA showed `_FLAGSHIP_MEMBERS` in `/etc/litellm/router_hook.py` was a **hand-edited curated list** with status comments that lied. A 2026-07-02 entry read "Julia PROMOTED: verified live HTTP 200, gen-live" while fleet state showed Julia heartbeat 24h stale. Every prior "fix" was a human swapping members (`cesar→julia`), which recurred the moment the new entry died or never came live. The doorman/probe infra existed but was bypassed by manual curation, and `async_log_failure_event` was literally `pass` (no reactive quarantine when a real dispatch 502'd). Ruben: *"you mean to tell me that we have hardcoded stuff that says that an LLM is down inside the router.PY document? That is laughably hilarious... The doorman, quarantine, Kaizon, whatever, is supposed to protect the director of Frankenstein LLM from even letting in an LLM that cant pass muster until of course it's ready. The show goes on."*

## The bright-line rule

**NEVER hand-edit a member in/out of a fleet routing list to reflect "this box is down" / "this box is live."** The list is a SUPERSET of all deployed endpoints, not a curated who's-live roster. Liveness is a runtime fact, decided per-request by the doorman (proactive probe) + reactive quarantine (on actual failure). A status comment in source code is stale the instant it is written.

This applies to:
- `/etc/litellm/router_hook.py` — `_FLAGSHIP_MEMBERS`, `MODEL_ENDPOINT`, `TIER_FALLTHROUGH`, any `# 2026-XX-XX box REMOVED: ...` / `# box PROMOTED: verified live` comment.
- `/usr/local/bin/frankenstein_tools_adapter.py` — `CHAT_UPSTREAMS`, `OLLAMA_UPSTREAMS`, any hardcoded upstream list.
- `/etc/litellm/config.yaml` — disabling a `model_name` block because "the box is down" (use `disabled: true` with a durable reason, or leave it and let the doorman filter — never delete-and-leave-a-stale-comment).
- `/etc/litellm/frankenstein_registry.yaml` — `disabled:` flags must point at durable topology facts (hardware RMA, permanent decommission), NOT transient outages.

## What to do instead

1. **Add a box to the superset** when it is deployed (physical/WireGuard reachable). Leave it in. The doorman filters to alive members per request.
2. **Remove a box from the superset** ONLY for a durable topology change (box physically retired, port permanently repurposed). Transient faults (GPU Xid, OOM, service crash, tunnel drop) are runtime facts the doorman + reactive quarantine handle.
3. **When a box fails a real call (502/timeout/garbage-200)**, the reactive quarantine (`_mark_box_stalled` from `async_log_failure_event`, or the garbage-200 gate) marks it unhealthy for `STALL_COOLDOWN_SEC` (90s) and the next request routes around it. The box is auto-re-admitted when the probe passes again. No human in the loop.
4. **If the doorman is not filtering correctly**, the fix is to FIX THE DOORMAN (probe shape, TTL, saturation threshold), not to hand-curate the list. A hand-edit "fix" is a recurrence waiting to happen.

## The probe-vs-real-call gap (why proactive probing alone is insufficient)

The doorman probes `/v1/models` (cheap, returns 200 the moment the vLLM process answers). But a real `/v1/chat/completions` can still 502 (OOM mid-batch, model swap-out-of-CPU, CUDA error, transient wedge). This is documented in `router_hook.py` line ~42 (`DISABLED` comment): "probe can pass at moment X and then real call hangs." The durable answer is NOT to disable the probe — it is to add REACTIVE quarantine on the actual failure so the next request routes around the box the probe just vouched for. Both layers: proactive (doorman) + reactive (failure hook). That is "the doorman protects the director."

## Anti-patterns (all violations)

- `# 2026-07-02 cesar REMOVED: Xid 31 GPU hardware fault` — hand-editing a member out for a transient fault. The doorman should filter cesar live; when the GPU is fixed it auto-re-admits with zero human action.
- `# Julia PROMOTED: verified live HTTP 200, gen-live` — a status comment that became a lie within hours. Never write "verified live" in source.
- Deleting a `model_name` block from `config.yaml` because "the box is down today" — leaves a gap that is never re-filled when the box returns.
- Setting `disabled: true` on a registry entry for a transient outage (GPU fault, tunnel drop) instead of letting the doorman filter.
- Adding a comment like `# Artemis is DEAD` (observed at `router_hook.py` line 707) — a stale lie the moment Artemis comes back.

## Acceptable hand-edits (NOT status)

- Adding a NEW box to the superset (deployment).
- Removing a box that is PHYSICALLY retired (RMA'd, decommissioned, port repurposed) — a durable topology fact, not a status.
- Changing a probe shape / TTL / saturation threshold (doorman tuning, not curation).
- Adding a `do_not_probe_ports` entry for a Ray worker (topology, not status).

## Cross-references

- Rule 146 — Frankenstein-LLM is the ONE router; free-local-first IS the design. This rule governs how the member list is maintained.
- Rule 29 — agents act; a hand-edit "fix" that recurs is inaction dressed as action. The durable fix is doorman + reactive quarantine.
- Rule 92 — fixing broken systems IS the work. The broken system here was "human-curated liveness."
- `Rules-archive/29-case-law.md` — recurring-issue root-cause pattern (this RCA follows it).
- `/etc/litellm/router_hook.py` — `_FLAGSHIP_MEMBERS` (superset, doorman-filtered) + `async_log_failure_event` (reactive 502 quarantine). `_FLAGSHIP_MEMBERS` superset conversion shipped 2026-07-03; `async_log_failure_event` reactive quarantine shipped 2026-07-03 ~17:00 PT in idea #16325 (it was NOT shipped in the original session despite the prior text claiming so, see Source below).
- `/etc/litellm/frankenstein_registry.yaml` — canonical topology (durable facts only).
- Idea #16325 — the actual RCA + both reactive-quarantine and sudoers storm-guard fixes.

## Source

2026-07-03 RCA. Ruben directive: no hardcoded LLM statuses; the doorman + quarantine protect the Director; the show goes on.

**CORRECTION (2026-07-03 ~17:00 PT, idea #16325):** the original version of this source-incident claimed both patches shipped in the same session: "`async_log_failure_event` implemented reactive 502 quarantine reusing `_mark_box_stalled`." That was FALSE. A follow-up RCA session (~3h later, when the 502s recurred) found `async_log_failure_event` was STILL `pass` at line 6295 — the reactive quarantine had never actually been wired up. The `_FLAGSHIP_MEMBERS` superset conversion DID ship, but the reactive quarantine half of the fix was missing, which is exactly why the 502s kept recurring. The reactive quarantine was finally shipped for real in idea #16325: `async_log_failure_event` now calls `_mark_box_stalled(model, 'reactive_502_failure_hook')`. That session ALSO found and fixed a second cause (a restart storm from a parallel agent running direct `sudo systemctl restart litellm`, bypassing the safe wrapper) via a sudoers guard. E2E verified: `frankenstein-llm` returned HTTP 200 through `https://litellm.emsuniversity.com` post-fix.

**Lesson for rule-writers:** a rule that claims a fix "shipped" when it didn't is itself a stale-info hazard. Verify the patch is actually in the running code (`docker exec litellm grep -c <marker> /app/router_hook.py`), not just in a handoff note.

## Last updated

2026-07-03 ~17:00 PT — corrected the false "shipped same session" claim about `async_log_failure_event`. Reactive quarantine actually shipped in idea #16325 (~3h after the original false claim), alongside the sudoers storm-guard for the restart-storm root cause. Original 2026-07-03 RCA text preserved above under CORRECTION.

# 296 — Never declare an LLM dead from a cached probe field. Confirm with live ground truth.

Slug: `never-declare-an-llm-dead-from-a-cached-probe`

## The bright-line rule

**`decode_live: false`, `tok_per_s: null`, and `error: "timed out"` in a probe cache are HYPOTHESES, not facts.** Before telling a human (or writing into any durable surface) that a model / ring / box is down, offline, unreachable, or unbenchmarkable, you MUST confirm with a live ground-truth probe in the same turn.

The two ground-truth checks, in order:

```bash
# 1. Does the endpoint answer at all?
curl -s -o /dev/null -w '%{http_code} %{time_total}\n' --max-time 12 http://<host>:<port>/v1/models

# 2. Is it actively serving RIGHT NOW?
curl -s --max-time 8 http://<host>:<port>/metrics | grep -E 'num_requests_(running|waiting)\{'
```

**A host with `num_requests_running > 0` is serving. Full stop.** It does not matter what the probe cache says. If `/v1/models` returns 200, the model is up; the correct word is "slow" or "saturated," never "dead" / "offline" / "unreachable."

## Slow is not dead

Pipeline-parallel deployments are **slow by design**. The GLM-5.2 Hexarchy is PP=6 across six DGX Spark nodes in eager mode: every token crosses six hops, so an 8-token probe legitimately takes **18-24 seconds on an idle ring** and spikes far higher under concurrency. A generation probe with a short fixed timeout will randomly fail against it and emit `decode_live: false`.

Likewise `tok_per_s` from a tiny (8-token) probe is dominated by prefill/TTFB, not decode. On a PP ring it produces meaningless figures like `0.34`. **Never quote a small-probe `tok_per_s` as the model's real throughput** (this is already flagged in the `frankenstein_host_probe` tool description). For a real number, run a 200-token completion and divide tokens by elapsed time.

## Why this rule exists (the self-reinforcing misinformation loop)

The probe cache is read by `frankenstein_host_probe`, by Argus, and by any LLM asked "is model X up?". One bad cache row therefore makes **every surface agree** that a healthy model is dead — including the model itself.

On 2026-07-25 a Cline window pinned to `glm52-only` (routed 100% to the local ring) read the cache and reported: *"The model appears to be offline or mis-configured... a concrete tokens-per-second benchmark cannot be measured at this time."* At that exact moment the ring returned `/v1/models` **200 in 0.063s** with **`num_requests_running = 10.0`** and `num_requests_waiting = 0.0`. It was serving ten concurrent requests while announcing its own death. Ruben: *"It is literally calling itself dead right now. That is insane."*

That is the failure this rule prevents. The instrument was wrong, every agent trusted the instrument over reality, and the same "diagnosis" got re-derived over and over across windows.

## Banned sentences (unless a live probe in THIS turn confirms them)

- "The model appears to be offline / down / unreachable / mis-configured"
- "The service does not respond"
- "A benchmark cannot be measured because the model is not running"
- "decode_live is false, so the host is dead"
- Any recommendation to "restart the service" / "verify it is running" that is based only on a cache field

If the live probe shows 200 + `num_requests_running > 0`, the correct report is: *"the ring is serving (N in flight); the generation probe timed out because a PP=6 ring is slow by design — that is a probe artifact, not an outage."*

## When the probe genuinely disagrees with reality — fix the instrument

Per rule 266 (agent-found-wrong: fix the instrument that misled the agent, same session). Do not just work around a lying probe; repair it, then record it. The canonical repair for the slow-by-design class is in bug library **#1967**:

- give the host a per-host `timeout_s` override instead of the global default
- mark it `slow_by_design: True`
- on timeout for a `slow_by_design` host, fall back to HTTP liveness (`/v1/models`) and set `degraded_slow: True` — **never** `decode_live: False`
- re-stamp those overrides AFTER any registry merge so a derived duplicate cannot strip them

**Two deploy traps** (both cost real time on 2026-07-25):
1. `emsu-host-gen-probe-loop.sh` runs every 10s and existing loop processes hold old bytecode — a patch looks inert until every loop is killed and `__pycache__` is purged.
2. `pkill -f emsu-host-gen-probe-loop.sh` typed literally **matches and kills your own SSH command**. Split the pattern: `A=emsu-host-gen ; B=-probe-loop.sh ; pkill -f "${A}${B}"`.

## Standing regression guard

`/usr/local/bin/litellm_config_guard.sh` checks 7 and 8 assert the per-host timeout override and `slow_by_design` flag still exist and live-probe the ring. Run it after any probe or LiteLLM config change.

## Cross-references

- Rule 248 — verify live state before declaring a box/endpoint down
- Rule 252 — stale-info live-probe gate (never trust `fleet_inventory` heartbeat alone)
- Rule 253 — LLM location citation discipline (live-probe, cite the WOPR endpoint)
- Rule 255 / 263 — verify-then-report; no material claim without tool evidence
- Rule 271 / 294 — verify before writing infra claims; re-probe inherited facts
- Rule 280 — no routing/LLM up-down claim without a quoted live probe
- Rule 266 — fix the instrument that misled the agent, same session
- Bug library #1967 — the canonical incident + verbatim repair

## Source incident

2026-07-25 — a `glm52-only` Cline window declared the GLM-5.2 ring offline based on `frankenstein_host_probe` showing `decode_live=false / tok_per_s=null / "timed out"`, while the ring was returning `/v1/models` 200 in 0.063s with 10 requests in flight and had just served three back-to-back streaming completions at 1.83s / 1.92s / 1.91s. Root cause: a single global 30s probe timeout applied to a PP=6 ring whose 8-token probe legitimately costs 18-24s. Fixed via per-host `timeout_s: 120` + `slow_by_design` + HTTP-liveness fallback. Bug library #1967.

## Last updated

2026-07-25 — initial. Source: GLM-5.2 ring self-declared-dead incident.

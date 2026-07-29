# 298 — Router/adapter reporting MUST resolve alias names to real backends; never hide glm-5.2-local inside a pool aggregate

Workspace-scoped. Source: 2026-07-28 Ruben directive (two rounds).

## The rule

Any report, dashboard, or `attempt_completion` that breaks down LLM traffic by "model" MUST NOT stop at adapter/alias names. `frankenstein-tools`, `frankenstein-llm`, and `emsu-codegen` are NOT real LLMs — they are all the SAME adapter service (port 11510, `frankenstein_tools_adapter.py`) that internally load-balances across a pool of real backends. A report that lists "frankenstein-tools: 4,512 requests" without saying which real model(s) actually served those requests is misleading by omission — Ruben's own words: "that's like you're hiding what is actually happening. No bueno."

**Before reporting any adapter-name bucket, resolve it to real backend share using `/var/log/emsu-adapter-upstream.log`** (JSONL, one line per completed request, fields: `t`, `lane`, `upstream`, `ttfb_s`, `path`, `spilled`, `queue_depth`). This log has the TRUE per-request upstream (e.g. `http://127.0.0.1:8210` = glm-5.2-local, `http://10.100.0.5:8000` = artemis-120b), unlike `/tmp/emsu_router_audit.log` whose `picked` field only records the alias name that was requested, not the internal upstream actually chosen. Live-verified 2026-07-28 5h window: `emsu-adapter-upstream.log` showed 14,441 requests to `10.100.0.5:8000` (artemis-120b) vs 1,220 to `127.0.0.1:8210` (glm-5.2-local) — i.e. glm-5.2-local's TRUE share (~7.8% of that pool) is roughly **3-4x higher** than the 2.1% floor visible in the alias-only audit log. Always cite `emsu-adapter-upstream.log` counts, not just `picked=` aliases, when reporting glm-5.2-local's share.

## The architecture finding (doc vs live code mismatch)

The documented spill ladder (registry YAML `tier_order`) lists glm-5.2-local (L4g) BEFORE the 120B pool (L4f), per a 2026-07-11 Ruben directive. **The live adapter code does NOT implement this priority.** `_least_loaded_order()` in `frankenstein_tools_adapter.py` sorts glm-5.2-local (:8210) and artemis-120b (:8000) as CO-EQUAL peers in one pool, by current load only (`load + 10*inflight`, timeout-cooldown boxes last) — there is no "always try glm-5.2-local first" branch. Confirmed live via `systemctl show frankenstein-tools.service -p Environment`: `FRANK_TOOLS_UPSTREAMS=http://127.0.0.1:8210,http://10.100.0.5:8000` (both in one list). glm-5.2-local DOES get a materially higher concurrency cap in the same env (`FRANK_BOX_CAPACITY=8000=14,11513=8,8210=32` — 32 vs 14), which gives it more headroom under load, but that is not the same as first-try priority.

**Any future report or fix in this area must state explicitly whether glm-5.2-local has hard priority-ordering or just a higher concurrency allowance** — these are different guarantees and conflating them is the exact inaccuracy Ruben flagged.

## The tok/s speed-gate finding

No tok/s-floor exclusion specific to :8210 exists inside `frankenstein_tools_adapter.py`'s `_upstream_load()` — the tok/s-as-load-proxy path only applies to `:11434` (raw ollama/Artemis). A SEPARATE speed-gate config exists in `admin_portal.fleet_registry_config` (keys `flagship_speed_gate_floor` / `_ceiling`, read via `lib/fleet_flagship_registry.php`), defaulting to **floor=10.0 tok/s, ceiling=100.0 tok/s** when the config row is absent (PDOException fallback) — NOT the "2.5 tok/s" figure referenced in some tool descriptions. This is a DIFFERENT gate than the adapter's own routing logic and applies to the "flagship" registry/reporting layer, not necessarily to whether glm-5.2-local gets picked live. Any claim about a tok/s exclusion penalizing glm-5.2-local must cite WHICH gate (adapter routing vs flagship registry reporting) and its actual configured value, not an assumed number.

## Benchmark methodology pitfalls (added after live-testing the priority fix, 2026-07-28)

Ad-hoc synthetic benchmarks of glm-5.2-local produced numbers that flatly contradicted Ruben's real-world "lightning fast" experience — the benchmarks were wrong, not his experience. Two specific mistakes to never repeat:

1. **Reasoning-token conflation.** glm-5.2-local is a reasoning model — the adapter log shows `PROMOTED_PRE reasoning->content` on every completion. Dividing total `completion_tokens` (reasoning + content combined) by wall time measures "how fast does it emit its internal scratchpad," NOT how fast the user-visible answer appears. **Always measure TTFB (time-to-first-token) and/or time-to-final-content-token separately from raw completion_tokens/time** when comparing a reasoning model to a non-reasoning model. A single throughput number that mixes the two is not comparable across model types.
2. **Synthetic concurrent load does not reflect real traffic and can trigger false degradation.** Firing N simultaneous requests at :8210 to "stress test" it produced a genuine `DECODE_STALL rate=0.00 tok/s` in the adapter's own log — a real stall, but one caused by the artificial load pattern, not representative of normal single/light-concurrency usage. **Never synthetically hammer a production upstream with concurrent load to "test" it — pull real recent traffic stats from `/var/log/emsu-adapter-upstream.log` instead.** That log already has genuine production TTFB/timing data; there is no need to manufacture synthetic load that can itself distort the box's live health (canary/DECODE_STALL detectors react to synthetic spikes the same as real ones).

**Live-verified reconciliation (2026-07-28, real traffic, not synthetic):** glm-5.2-local averaged **4.25s TTFB** vs artemis-120b's **9.71s TTFB** over a real 5-minute production window — glm-5.2-local is genuinely faster to first token in normal use, consistent with Ruben's experience. Any future speed comparison for glm-5.2-local MUST use TTFB from real traffic in `/var/log/emsu-adapter-upstream.log`, not a synthetic completion_tokens/wall_time benchmark.

## Self-check before shipping any router/LLM-share OR speed report

1. Did I use `/var/log/emsu-adapter-upstream.log` (real upstream) instead of only `/tmp/emsu_router_audit.log` `picked=` aliases (adapter name) for any bucket that includes frankenstein-tools/frankenstein-llm/emsu-codegen?
2. If I claim a model is "first pick" or "prioritized," did I verify that against the actual sort/selection code (`_least_loaded_order` or equivalent), not just the YAML doc?
3. If I cite a tok/s gate value, did I quote the actual configured number from its real source (DB config or code constant), not a number from memory or a tool description?
4. If I'm comparing SPEED between a reasoning model (glm-5.2-local) and a non-reasoning model, did I use TTFB or content-only tokens, not raw completion_tokens/wall_time (which includes reasoning tokens)?
5. Did I pull speed numbers from REAL traffic in `/var/log/emsu-adapter-upstream.log`, instead of firing my own synthetic concurrent load at a live production upstream?

## Cross-references

- Rule 146 — frankenstein-llm is the one router for every LLM
- Rule 140 — verify routing live, don't trust config files as ground truth
- `frankenstein_registry` / `frankenstein_host_probe` MCP tools — registry-reported vs live-adapter-routed state can differ; always disambiguate which one a claim is about

## Source incident

2026-07-28 — Ruben (round 1): "frankenstein-tools needs to be broken down, so does cline main to the ACTUAL LLM, lol that's like you're hiding what is actually happening... Same with emsu-codegen. Those are no[t] actual LLMs." (round 2): "we don't see GLM 5.2 local... Local GLM Needs to be the first pick in the spill le[dd]er before the 120[B]s. It needs some sort of exemption as far as tok/sec measurement is concerned which I'm not entirely convinced as a good measurement anyways because GLM Local 5.2 is lightning fast." Investigation confirmed: glm-5.2-local's true share is masked by adapter aliasing (floor 2.1% vs real ~7.8% of the pool per upstream log), and live code does not implement documented GLM-first priority (co-equal load-balanced peer instead).

## Last updated

2026-07-28 — added "Benchmark methodology pitfalls" section after live-testing the GLM-first priority fix: reasoning-token conflation and synthetic-concurrent-load artifacts caused a false "GLM is slow" reading that contradicted Ruben's real-world experience. Real-traffic TTFB (4.25s glm vs 9.71s artemis) confirmed Ruben was right.


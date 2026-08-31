Rule 322 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 322 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/322-what-was-serving-single-table.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 4 amendment(s))

## Amendment (from reversal, 2026-08-20 05:18 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787138864086
- RCA bucket: insufficient probe
- Trigger pattern: single HTTP 200 from a watcher during a relaunch treated as the new engine serving
- Reversal note: 2026-08-19 watcher false-positive: a serving watcher declared SERVED at 22:07 PT on a single HTTP 200 that was actually the dying seq-32 engine's final second before relaunch, not the new seq-128 engine. Corrected in-window by requiring TWO consecutive 200s. Amended behavior: any serving/health watcher that gates a relaunch verdict must require at least two consecutive successful probes separated by an interval, because a dying engine can answer one final request during its shutdown window; a single 200 during a relaunch transition is never a verdict.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-21 18:26 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787121837052
- RCA bucket: insufficient probe
- Trigger pattern: single-window client-side abort lines generalized into a persistent fleet-health claim and surfaced as an open human decision
- Reversal note: 2026-08-21 fleet-stall reversal: a completion reported 'local fleet lanes stalled on every generation call this session' as an open fleet-health decision, from client-side CURLOPT_LOW_SPEED abort lines alone. Re-probed 11:24-11:25 PT: frankenstein-llm HTTP 200 (8.1s), glm-5.2-local HTTP 200 (3.2s), host probe decode_live=true for artemis-120b (28.1 tok/s) and glm52-ring (11.67 tok/s), and the adapter upstream log carried ZERO error lines for the stall window while passing traffic to all three upstreams. Amended behavior: a client-side low-speed/timeout abort is NOT evidence of an upstream stall — the adapter/upstream log is the arbiter; if it shows no errors for the window, the condition is transient and must be reported as transient (no fleet action), never as a persistent fault or an open decision item.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-23 00:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787442900000-frankenstein-stall
- RCA bucket: insufficient probe
- Trigger pattern: single temporal counter sample extrapolated to a persistent wedge/dead verdict; restart staged without persistence evidence
- Reversal note: 2026-08-22 frankenstein-llm stall reversal: a single 20s counter sample during a transient PP=6 stall-burst window (read decode=0.49 prefill=0.00) was verdicted as 'ring genuinely wedged' and a relaunch was staged. Ruben's re-probe directive caught it: a 60s sample minutes later read TOTAL=260.40 (healthy baseline ~273). Amended behavior: an engine WEDGE verdict requires persistence evidence, never one temporal sample — N consecutive stalled counter windows (>=3) or decode+prefill both flat across >60s while requests accumulate; a transient stall-burst that self-recovers is the documented PP=6 pattern, and relaunching a healthy serving engine on one sample is the failure this amendment forbids.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 08:50 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: frankenstein-llm-slow-low-quality-20260826
- RCA bucket: insufficient probe
- Trigger pattern: engine declared saturated/unhealthy from adapter-side queue_depth + TTFB instead of the engine's own counter-delta; aggregate tok/s used to judge interactive per-stream speed
- Reversal note: 2026-08-26 double reversal on a frankenstein-llm slowness diagnosis. (1) Declared the GLM PP=6 ring 'SATURATED' from ADAPTER-SIDE evidence only (queue_depth 3-19, adapter TTFB 96-132s, a ring_admit_rewrite log line). The CANONICAL instrument (two :8210/metrics counters 60s apart, per GLM52_MEASUREMENT_METHOD_AND_RESTORE_RISK.md) returned decode=10.13 prefill=445.85 TOTAL=455.98 tok/s with running=5, waiting=0, preemptions=0 and canary pass_streak=203: the ring was HEALTHY the whole time. Amended behavior: ring/engine health is decided ONLY by the engine's own counters (generation_tokens_total + prompt_tokens_total delta over >=60s, plus running/waiting/preemptions). Adapter queue_depth and adapter TTFB describe the ADAPTER's queueing view and are NEVER evidence of engine saturation; an admission-gate log line (ring_admit_rewrite / ceiling_N_running_M) is the gate WORKING, not a fault. (2) Separately, do not infer per-stream interactive speed from an aggregate tok/s figure: on a PP=6 ri

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-30 03:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788135215000
- RCA bucket: unread source
- Trigger pattern: rule-322 table named physical LLMs from llm_call_log model strings and upstream-log percentages without resolving aliases, tracing callers, or checking log staleness
- Reversal note: Amends the resolution rules: (1) an llm_call_log model string is a LABEL, not a physical model — litellm model_names can be ALIASES backed by a different provider (verified 2026-08-29: config.yaml lines 244-253 back claude-haiku/claude-haiku-4-5 with deepseek/deepseek-v4-pro), so a "what was serving" table MUST resolve each model_name through config.yaml litellm_params.model before naming the physical LLM or attributing cost; (2) never attach a purpose label like "vision-doorman" to a row without tracing the actual caller (the 2026-08-29 haiku rows came from PHP HAIKU_FALLBACK_V1 crons, not vision); (3) an "X absorbed N% of requests" claim from the adapter upstream log MUST check the log's LAST TIMESTAMP first — a wedged adapter leaves a stale log that misattributes the window.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-31 04:48 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788050474905
- RCA bucket: stale assumption
- Trigger pattern: routing a live model through a retired model's alias name, or repointing an alias to a different model without renaming it
- Reversal note: MISLEADING LEGACY ALIAS NAMES ARE BANNED for routing (Ruben directive 2026-08-30). A litellm model_name that names a RETIRED model (e.g. 'minicpm-v' secretly serving qwen3.8-27b, 'julia-235b' serving deepseek) poisons every future agent's diagnosis — this was a root cause of the 2026-08-30 session's repeated misdiagnoses. Callers MUST route through the TRUE model-name lane (e.g. julia-qwen38-27b), and when a model is retired its alias blocks are REMOVED, not silently repointed. If a transitional alias is unavoidable it must carry the true model in its name within one window. Applied: 7 PHP callers repointed minicpm-v -> julia-qwen38-27b; minicpm-v alias blocks slated for removal after 7d zero picks.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

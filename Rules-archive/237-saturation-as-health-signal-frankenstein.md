# 152 — Frankenstein: saturation IS a health signal. Two mandatory protection layers. Cline is priority.

Source incident: 2026-06-13 cline Window A (#12059). cato had 3 running + 9 waiting; cesar 4 running + 8 waiting. frankenstein-llm + artemis-* + emsu-cs-70b + ollama-32b ALL spilled to claude-sonnet (PAID) instead of cascading free-local first. Root cause: saturation was not yet a routed health signal; tool track lacked a saturation check on the frankenstein-tools adapter.

## The two mandatory layers (Ruben directive, encode permanently)

**Frankenstein is the General; every LLM a soldier; the Project continues no matter what one LLM does.**

Saturation is HEALTHY -- a box doing work is fine. The failure is OVER-saturation that wedges a box.
Two mandatory layers, both required:

1. **PROTECT each soldier (per-box anti-wedge).** Every 120B box has an admission cap in the router. When `num_requests_waiting >= _120B_SAT_WAITING_MAX` the box is not-healthy-for-this-request and excess is fast-failed/rerouted BEFORE queuing 8-deep. Cap is lane-aware:
   - `_120B_SAT_WAITING_MAX_INTERACTIVE = 4` (Cline: spill to next free member)
   - `_120B_SAT_WAITING_MAX_BATCH = 1` (executor/orchestrator: yields immediately to keep Romans clear for Cline)

2. **ROUTE around any down or full soldier (the General).** A saturated OR down box is skipped; the router picks the next healthy ladder member. `down OR saturated = skip` is ONE health model (not two parallel systems).

## Cline is PRIORITY

Interactive Cline tool turns get first claim on the freest healthy box. Executor/orchestrator BATCH traffic spills sooner so it never consumes the slot Cline needs.

Detection: `_is_interactive_cline(messages)` in router_hook.py checks for `<environment_details>`, `<task>`, `task_progress`, `[TASK RESUMPTION]` wrappers.

## Tool-track spill order (cost-disciplined)

For frankenstein-llm tool-calling requests, `pick_tool_track` walks:
1. frankenstein-tools (:11510, rank 10, FREE gpt-oss 120B adapter)
2. joshua-llama3.3-70b (Joshua B60 :11434, rank 25, FREE)
3. deepseek-v4-pro (openrouter, rank 50, cloud_openweight, cheap)
4. claude-sonnet (rank 90, PAID, LAST resort only)

405B (frankenstein-405b) is EXCLUDED from the tool track by the teacher guard (rule 147, --max-num-seqs 1, max-model-len 1024, teacher-only).

## Saturation gate implementation

`SATURATION_GATE_TOOL_TRACK_v1` in `_tool_member_alive()` (router_hook.py):
- When probing frankenstein-tools (:11510 vllm), ALSO check if all cato+cesar members are `_120b_member_available(waiting_max=wmax)`.
- If all pool members are at/over cap: `alive = False` -- skip to next tool-track rung.
- The adapter being alive != the pool being available.

## Fallback chain fix (#12046 -- free-local before paid)

BEFORE: artemis-gpt-oss-120b / artemis-llama3.3-70b-q5 / emsu-cs-70b-tuned / ollama-32b all went directly to claude-sonnet on primary failure.

AFTER: each cascades through `joshua-llama3.3-70b -> ollama-32b -> ollama-14b -> deepseek-v4-pro -> claude-sonnet`. Paid is touched ONLY when the whole free fleet is saturated/down.

## Dead rungs WINDOW_O_DOWN (#12061)

`llama3.3-70b-q5` and `qwen3-14b` at Artemis (10.100.0.5) return HTTP 500 APIConnectionError. Marked WINDOW_O_DOWN in config.yaml api_base comments 2026-06-13. Config smoketest: 5 DEAD -> 1 DEAD (remaining = 11455 SMS Mac offline, hardware).

## Verified live 2026-06-13 (rule 140 header probes)

- frankenstein-llm chat: HTTP 200, api_base=http://127.0.0.1:11510/v1, cost=0 (FREE)
- ollama-32b: HTTP 200, api_base=http://127.0.0.1:11434, cost=0 (FREE local)
- cato :11507 running=3 waiting=0; cesar :11506 running=0 waiting=0 (no queue buildup)
- Config smoketest rc=0

## Cross-references

- router_hook.py: `SATURATION_GATE_TOOL_TRACK_v1`, `pick_tool_track(interactive=)`, `_tool_member_alive(interactive=)`, TOOL_TRACK default rank 25 joshua
- frankenstein_registry.yaml: joshua-llama3.3-70b tool_rank: 25 added
- config.yaml: fallback chains for artemis-* / emsu-cs-70b-tuned / ollama-32b fixed
- Ideas: #12059 (saturation routing, approved), #12046 (paid-spill fix), #12061 (dead rungs)
- PROJECT_FRANKENSTEIN.md §8.1.1 (saturation section)
- rule 29 (act on confidence -- the General keeps the army marching)
- rule 146 (Frankenstein routes every LLM, Cline priority)
- rule 147 (405B teacher guard)

## Last updated

2026-06-13 -- initial. Source: Window A built saturation-aware health routing + per-box anti-wedge (#12059), paid-spill fix (#12046), dead-rung cleanup (#12061).

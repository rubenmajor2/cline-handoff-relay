#!/usr/bin/env node
/**
 * project-frankenstein-mcp — STDIO entrypoint
 *
 * STDIO transport (clone of fleet-state-mcp v0.5.0 pattern).
 * No HTTP/SSE — synchronous reads for architecture + fast_train_runbook,
 * live bounded fetches for fleet_tier_health, pod_status, verify_routing,
 * autoscaler_state. Returns instantly, cannot hang, cannot YOLO.
 *
 * Fetches live data from the fleet API at:
 *   https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php
 * Reads the canonical PROJECT_FRANKENSTEIN.md + FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md
 * from WOPR via the fleet API (or serves cached static copies).
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const BASE = process.env.FRANKENSTEIN_API_BASE ?? "https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php";
const KEY = process.env.FLEET_MCP_KEY ?? "sk-fleet-717a125f0e92faf6a51c3ead2564d99cd4a4101b";
const FETCH_TIMEOUT_MS = 10_000;
// idea #18918 (2026-07-24): verify_routing's PHP probe has CURLOPT_TIMEOUT=25 (slow local
// models can need it). MCP abort at 10s always fired first, returning an uninformative
// "aborted" instead of the clean PHP JSON. verify_routing gets 40s (> PHP 25s); all other
// actions keep the 10s STDIO no-hang bound.
const VERIFY_ROUTING_TIMEOUT_MS = 40_000;

// ─── Live API fetch (bounded, never hangs) ──────────────────────────────

async function fleetApi(
  action: string,
  params: Record<string, string> = {},
): Promise<{ ok: boolean; data?: unknown; error?: string }> {
  const url = new URL(BASE);
  url.searchParams.set("action", action);
  url.searchParams.set("key", KEY);
  url.searchParams.set("_", Date.now().toString());
  for (const [k, v] of Object.entries(params)) {
    if (v) url.searchParams.set(k, v);
  }
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), action === "verify_routing" ? VERIFY_ROUTING_TIMEOUT_MS : FETCH_TIMEOUT_MS);
  try {
    const r = await fetch(url, { signal: ctrl.signal });
    const text = await r.text();
    try {
      return { ok: true, data: JSON.parse(text) };
    } catch {
      return { ok: false, error: `non_json_response status=${r.status} body=${text.slice(0, 200)}` };
    }
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  } finally {
    clearTimeout(t);
  }
}

// ─── FRANKENSTEIN_ARCHITECTURE — static canonical struct ────────────────
// Derived from the live PROJECT_FRANKENSTEIN.md (read via fleet API on boot,
// static fallback baked in). The full doc is huge; the tool returns the
// canonical structured summary + a pointer to the full doc.

// CORE PRINCIPLES — pinned numbered block. Mirrors PROJECT_FRANKENSTEIN.md §0
// (the numbered CORE PRINCIPLES block at the very top). Window 4 / idea #11261.
// Any agent answering a Frankenstein question gets these FIRST.
const CORE_PRINCIPLES = [
  "1. ROUTE BY HEALTH, not by config. Machines flap. Failover uses real HTTP 200 probes (/v1/models, /api/tags), never lifecycle/config status. 'Warm' = a live 200, not desiredStatus=RUNNING.",
  "2. PER-MODEL CONTEXT. Each served model has its OWN max_model_len/num_ctx (cesar=8192, cato=16384, 70B=8192...). Never a global magic number. The oversize guard uses the MINIMUM ctx of any member an entrypoint may dispatch to, so it never computes max_tokens<0 -> HTTP 400.",
  "3. HEAD / BODY / STITCHES / DETACH-SYNTHESIZE. BODY (free local 7B/14B/32B/70B/120B) does the ~90% deterministic/templated work. HEAD (paid Sonnet/Opus) generates ONLY the genuinely-hard span. STITCHES (cheap 70B pass) smooths the seams. The head is sewn on, never asked to re-review the body.",
  "4. GRACEFUL DEGRADATION (no dead-ends, rule 142). Every entrypoint has a static fallback baked in. A bad/new/missing piece (registry row, down Spark, cold pod) NEVER bricks serving — it degrades down the spill ladder to the next healthy tier, terminating at claude-sonnet.",
  "5. ADD A MODEL = ONE REGISTRY ROW. The spill ladder, tiers, endpoints, and per-model context all DERIVE from /etc/litellm/frankenstein_registry.yaml. Adding/changing a model is one declarative row, no code edit. router_hook.py + this MCP + the fleet API all read the SAME registry, so architecture and live routing can never drift.",
];

// NOT_A_TRADITIONAL_ROUTER — the anti-revert block (idea #11302, 2026-06-09).
// A fresh Cline window defaults to the "pick one model per request by context size"
// mental model and (a) wastes tokens re-deriving it wrong, (b) reverts Ruben's
// improvements back to the traditional design. This block is served FIRST so any
// agent reasoning about Frankenstein starts from the correct model. Verified live
// 2026-06-09 (rules 140/141) against llm_call_log + header probes.
const NOT_A_TRADITIONAL_ROUTER = {
  headline: "Frankenstein is NOT a traditional router. Do not reason about it as 'pick one model per request by context size'. It is a DECOMPOSE → DISTILL → SERVE-LOCAL → REASSEMBLE engine.",
  what_it_is: [
    "The router/executor holds the FULL conversation context (verified: a 1,038,433-token input was served at $0).",
    "A RAG/distill pass (lib/EmsuRagInjector.php, idea #6711/#6719) extracts only the relevant slice (~5K chars) per sub-request.",
    "That distilled slice is served on a FREE LOCAL model (frankenstein-llm → 120B body via the :11510 tools adapter), so window size is IRRELEVANT to cost.",
    "Head/body/stitches: the paid frontier (Sonnet/Opus) only ever generates the genuinely-hard SPAN, never the whole response.",
  ],
  why_window_size_does_not_matter: "served_ctx (cesar=8192, cato=16384) is NOT the binding constraint, because distillation runs UPSTREAM of the model — the model never sees the raw 1M tokens. A 300K/400K/1M conversation is distilled to a small slice before it ever hits a local model. 'It can't fit 300K so it must go to cloud' is the TRADITIONAL-ROUTER fallacy and is WRONG here.",
  interactive_cline_routing: "Interactive Cline (the VS Code client) rides the LiteLLM OpenAI path → frankenstein-llm → local 120B (distilled), NOT the Anthropic passthrough. It is NOT pinned to Claude. Verified live: last-3h llm_call_log shows big-window interactive traffic on executor/frankenstein-llm at $0, zero cline_passthrough rows.",
  proven_dead_ends_do_not_resurrect: [
    "Do NOT propose 'serve a local big-context model so oversize fits' — distillation already makes window size moot.",
    "Do NOT propose 'route oversize to cloud DeepSeek/Claude because no local model fits' — that is the traditional-router revert.",
    "Do NOT claim 'the decompose engine isn't built' — it IS (RubenExecutor.php + EmsuRagInjector.php), running 20K+ calls/4d at $0.",
    "Do NOT claim 'DeepSeek emits raw DSML Cline can't parse' — DISPROVEN live: deepseek-v4-pro via LiteLLM OpenAI path returns clean OpenAI tool_calls.",
    "Do NOT do whole-response draft→frontier-refine (measured +27% cost on Opus).",
  ],
  verify_before_you_revert: "Before recommending ANY routing change, run: (1) SELECT surface,model,COUNT(DISTINCT request_id),MAX(input_tokens),SUM(cost_usd) FROM llm_call_log WHERE ts>NOW()-INTERVAL 3 HOUR GROUP BY surface,model; (2) a rule-140 header probe (curl -D - .../v1/chat/completions with the real model id). Config files are HYPOTHESES; the call log + headers are truth.",
  source: "Verified 2026-06-09 by Cline after Ruben corrected 4 successive traditional-router answers. llm_call_log evidence + rule-140 probes. lib/RubenExecutor.php, lib/EmsuRagInjector.php.",
};

// CANONICAL_NAMING — the 5-name vocabulary (idea #11296, Ruben directive 2026-06-09).
// Three different things have "Frankenstein" in the name; Executor/Orchestrator/Cline
// are SIBLING CLIENTS, not a stack. Saying "Frankenstein LLM" as an umbrella for all of
// it is what costs tokens (a fresh window re-derives the boundaries wrong every time).
// Resolve every Frankenstein/Executor/Orchestrator/Cline reference through THIS map.
const CANONICAL_NAMING = {
  rule: "There is ONE router (Frankenstein). Executor, Orchestrator, and Cline are CLIENTS that send their LLM calls THROUGH Frankenstein. They are siblings, not nested. 'Point Cline at Executor' is a category error.",
  names: {
    "Frankenstein": "The routing + distill + serving brain. = LiteLLM /etc/litellm/router_hook.py + /etc/litellm/frankenstein_registry.yaml + lib/EmsuRagInjector.php (distill) + the WHOLE model fleet. The entrypoint model id 'frankenstein-llm' rides the spill ladder across ALL models by health: 7B → 14B → 32B → 70B → 120B (Cesar/Cato) → RunPod pod → DeepSeek (cloud) → Sonnet → Opus. NOT just the 120B — that's only the most common landing tier.",
    "Frankenstein MCP": "The READ-ONLY docs + verify tool (this project-frankenstein MCP server). Describes the system + runs rule-140 header probes. Does NOT route, run, or serve anything. NOT an umbrella name for the system.",
    "the Executor": "lib/RubenExecutor.php — the autonomous plan-execution agent (generatePlan/executePlan/replan-shrink/self-heal). Runs approved ideas, deploys, fixes. A CLIENT of Frankenstein (surface=executor → frankenstein-llm, $0 local).",
    "the Orchestrator": "The event/decision/idea triage brain (orchestrator_api.php + triage crons + orchestrator_event_log + ruben-orchestrator MCP). Decides WHAT to do, files ideas, makes decisions. A CLIENT of Frankenstein (surface=ruben_orchestrator). Distinct class from RubenExecutor.",
    "Cline": "The interactive VS Code coding agent + .clinerules. A CLIENT of Frankenstein (OpenAI path → frankenstein-llm → local). Not pinned to Claude.",
  },
  umbrella_term: "'Project Frankenstein' = the WHOLE stack (the Frankenstein router + the model fleet + the three client agents Executor/Orchestrator/Cline + the Frankenstein MCP). This is the canonical umbrella name (Ruben directive 2026-06-09). Use 'Project Frankenstein' when you mean all of it; use a specific name below for a single layer. ('the Frankenstein stack' is an accepted synonym.)",
  how_ruben_directs_updates: {
    "update Project Frankenstein": "the whole stack — look across ALL layers below.",
    "update Frankenstein": "router/serving/distill layer: router_hook.py, the registry, model serving, the spill ladder, EmsuRagInjector.",
    "update the Frankenstein MCP": "this docs/verify tool (src/index.ts → npx tsc → needs Cline restart).",
    "update the Executor": "lib/RubenExecutor.php.",
    "update the Orchestrator": "orchestrator triage/decision code.",
    "update Cline": "VS Code agent config + .clinerules.",
  },

  source: "Ruben naming directive 2026-06-09. Verified live: Executor (RubenExecutor.php) and Orchestrator (orchestrator_api.php) are distinct classes, both clients of LiteLLM. Cross-ref .clinerules/135 (SLS naming precedent: a name only sticks where it is written into a read-at-runtime surface).",
};

// ROUTES_EVERY_LLM — Ruben directive 2026-06-12 (~20th restatement). A window kept
// narrowing frankenstein-llm to "5 models / 2 boxes" and calling tunnel-probe failures
// "boxes dead." This pinned block is the durable correction. Cross-ref .clinerules/146.
const ROUTES_EVERY_LLM = {
  headline: "frankenstein-llm is the ONE router for EVERY LLM we own. NOT the 5-member pool_members sub-list. NOT 'just the 120B'. If we own an LLM, it is under Project Frankenstein.",
  the_full_fleet: [
    "Local Ollama small/mid: 7B-lora, 14B, 32B, qwen2.5/qwen3 coders 14B/30B/32B, gpt-oss-20B.",
    "70B fleet: sms-70b (ollama-llama3.3-70b), Joshua-70B (10.100.0.4), Artemis-70B q4/q5 (10.100.0.5).",
    "3× 120B: Cesar :11506, Cato :11507, Artemis-120B (10.100.0.5 gpt-oss:120b).",
    "405B: frankenstein-405b = Augustus+Tiberius TP=2 over CX7 200GbE, :11512. ⚠️ TEACHER-ONLY — see FOUR_OH_FIVE_B_TEACHER_GUARD below. It is NOT on the interactive/executor spill ladder.",
    "RunPod pods: frank-serve-pod-120b, lora-120b-ckpt420.",
    "Cloud open-weight: DeepSeek-v4-pro/flash.",
    "Paid heads: claude-sonnet, claude-opus-real, claude-fable-5.",
    "The Mac mini (the box Cline's :11505 tunnel rides) — it hosts models too.",
  ],
  cline_is_priority: "When Cline is working, Executor + Orchestrator traffic may be QUEUED behind it. Cline (interactive, NO buffer) spills to the ladder the instant a 120B is busy (FRANK_TOOLS_SAT_INTERACTIVE=1). Executor/Orchestrator (HAVE a buffer) queue on the free local boxes (FRANK_TOOLS_SAT_BATCH=6). Cline never waits behind batch.",
  memory_is_not_the_limit: "A 120B KV cache holds ~486K tokens (num_gpu_blocks×block_size), ~20% used normally. The 131K in Cline settings is PER-CONVERSATION context, not a fleet limit. Do NOT shrink Cline context to 'save memory' — the load lever is spilling compute across the fleet sooner.",
  free_can_beat_paid: "Free 120Bs/LoRAs that win ≥45% W/T head-to-heads vs Sonnet/Opus are PROMOTED above the paid model (rule 121 / KIND_TIER_PIN). Never assume paid > free by default — check the W/T scoreboard (llm_router_live.php).",
  tunnel_probe_is_not_box_dead: "Augustus/Tiberius/405B probe via 127.0.0.1:11508/11509/11512 = reverse tunnels Spark→WOPR. HTTP 0 there = TUNNEL down, NOT box dead (rule 141). Ruben has seen the 405B serve. Fix = re-establish the tunnel; never report 'unprovisioned/dead' from one localhost probe.",
  source: "Ruben directive 2026-06-12, ~20th restatement. Hardened into .clinerules/146 + PROJECT_FRANKENSTEIN.md top block + this MCP struct so it is never re-derived wrong.",
};

// FOUR_OH_FIVE_B_TEACHER_GUARD — Ruben directive 2026-06-13. A window (idea #12060)
// tried to route executor PLANNER load to frankenstein-405b to escape a saturated 120B
// pool. Ruben STOPPED it: the 405B is precision infrastructure with its own runbook that
// MUST be consulted before any change to how it operates. The 405B is a TEACHER, not an
// interactive/executor server. This block is the durable guard so no future window
// repeats the mistake. Cross-ref .clinerules/147, 405B_WINDOW_4_teacher_explained.md,
// 405B_CHECKPOINT.md, auto405.sh, 405B_RECOVERY_RESEARCH_2026-06-13.md.
const FOUR_OH_FIVE_B_TEACHER_GUARD = {
  headline: "The 405B (frankenstein-405b = Augustus 192.168.1.244 + Tiberius 192.168.1.32, TP=2 Ray, :11512) is a DISTILLATION TEACHER / quality-ceiling tier. It is NOT a daily-driver, NOT an interactive server, and NOT a spill-ladder target for Cline/Executor/Orchestrator traffic.",
  why_teacher_only: [
    "Served with `--max-num-seqs 1` — it handles exactly ONE request at a time. Pointing concurrent interactive/executor load at it (e.g. 240+ executor workers) WEDGES it instantly.",
    "Served with `--max-model-len 1024` (ladder falls to 256 under memory pressure). It physically cannot accept a 24k-max_tokens planner request — the request errors / returns empty.",
    "AWQ-INT4 (~102GB/box) on 128GB Sparks with util 0.90, enforce-eager, swap-space 1-4. It is memory-fragile by design (the NVFP4 110GB artifact was PROVEN unservable — do not retry it).",
    "Doc verbatim (405B_WINDOW_4_teacher_explained.md): 'The 405B's job is NOT to answer your day-to-day prompts (too slow). Its job is to be the quality ceiling that pulls your fast models UP. You run it occasionally, in batch.' / 'The 405B is your TEACHER, not your daily driver. 120Bs = fast interactive workers. 405B = slow teacher.'",
  ],
  intended_uses_only: [
    "1. DISTILLATION TEACHER (main use): batch-generate high-quality training data to fine-tune the fast 7B/14B/32B/70B/120B models UP.",
    "2. HARD OFFLINE BATCH: occasional one-off hard problems where 30+ seconds latency is acceptable.",
    "3. QUALITY ARBITER / JUDGE: score/rank the smaller models' outputs offline.",
  ],
  mandatory_before_any_change: "ANY change to how the 405B receives traffic, its serve flags, its quant, or its role REQUIRES reading the canonical runbook FIRST (it is precision infrastructure that relies on exact documented config). Canonical docs: 405B_WINDOW_4_teacher_explained.md (role), 405B_CHECKPOINT.md (FINAL VERIFIED CONFIG — AWQ-INT4, the proven serve args), auto405.sh (the authoritative serve command), 405B_RECOVERY_RESEARCH_2026-06-13.md (idea #11735 FINAL VERIFIED CONFIG + NVFP4-is-unservable post-mortem). Never change 405B operation from a config-read or an assumption.",
  the_405b_serve_args_verbatim: "vllm serve /models/llama405b-awq --tensor-parallel-size 2 --max-model-len 1024 --gpu-memory-utilization 0.90 --enforce-eager --max-num-batched-tokens 1024 --max-num-seqs 1 --swap-space 1 --served-model-name llama405b --enable-auto-tool-choice --tool-call-parser llama3_json --host 0.0.0.0 --port 8000 --distributed-executor-backend ray (image nvcr.io/nvidia/vllm:25.09-py3, vLLM 0.10.1.1, BOTH containers --memory=100g, RAY_memory_monitor_refresh_ms=0).",
  if_a_120b_pool_is_saturated: "The fix for a saturated interactive/executor 120B pool is the SATURATION-AWARE ROUTING + PER-BOX ADMISSION CAP (idea #12059, Window A), NOT borrowing the teacher. The army marches by spilling across the FREE INTERACTIVE fleet (7B/14B/32B/70B/other 120Bs/RunPod) then DeepSeek then Claude-last. The 405B is never a spill target.",
  source: "Ruben directive 2026-06-13 (interrupted idea #12060 mid-flight to enforce this). Hardened into this MCP struct + PROJECT_FRANKENSTEIN.md + .clinerules/147.",
};

const ARCHITECTURE_SUMMARY = {
  name: "Project Frankenstein — Head/Body/Stitches LLM Architecture",
  ROUTES_EVERY_LLM,
  FOUR_OH_FIVE_B_TEACHER_GUARD,
  NOT_A_TRADITIONAL_ROUTER,
  CANONICAL_NAMING,
  CORE_PRINCIPLES,

  source_doc: "/var/www/emtskills/docs/PROJECT_FRANKENSTEIN.md",

  registry: "/etc/litellm/frankenstein_registry.yaml (single source of truth — call frankenstein_registry tool for live state)",
  head_body_stitches: {
    BODY: {
      description: "Local/free models (~90% of tokens): 7B, 14B, 32B Qwen, 70B. Handles deterministic/templated/high-frequency boilerplate — standard policy language, canned explanations, structure.",
      models: ["emsu-qwen2.5-coder:7b-lora (WOPR:11434)", "llama3.3-ctx8k:latest (SMS Mac M1, WOPR:11455)", "qwen-coder 14B/32B (M4 Mac, WOPR:11505)"],
      cost: "FREE (local)",
    },
    HEAD: {
      description: "Frontier models (paid, ONLY the hard ~10%): novel reasoning spans, edge-case logic, regulator-sensitive sentences. Generates ONLY that span, not the whole response.",
      models: ["claude-sonnet-4-6", "claude-opus-4-8:1m"],
      cost: "PAID (Anthropic API via LiteLLM)",
    },
    STITCHES: {
      description: "Cheap final smoothing pass so the seams between body and head read as one voice. Run by the cheaper model (70B), never the frontier.",
      model: "llama3.3-ctx8k (free local 70B)",
      cost: "FREE (local)",
    },
  },
  spill_ladder: {
    description: "Heat-based: each local box runs to capacity. When saturated, traffic spills UP the ladder.",
    ladder: ["7B → 14B → 32B Qwen → 70B → 120B (Cato/Cesar) → RunPod pod → Sonnet → Opus"],
  },
  machine_flap_rule: "Machines flap, route by health — failover uses real HTTP 200 probes, not config or lifecycle status.",
  m1_70b_cap: "SMS Mac M1 (64GB) serving llama3.3-70B: ~2-4 concurrent Cline/agent windows before saturation.",
  warmth_definition: "\"Warm\" = vLLM /v1/models returns HTTP 200. RunPod desiredStatus=RUNNING is NOT warm.",
  fast_train: {
    description: "EMSU Fast LoRA Training stack — 10-70x faster than original pipeline.",
    levers: [
      "1 epoch first (was 5): ~3-5x",
      "packing=True (was False): ~2-3x",
      "DDP one full replica per GPU (NOT device_map=auto): near-linear in #GPUs",
      "Serve raw LoRA on vLLM --enable-lora (skip 60-90min GGUF): instant",
    ],
    runbook: "/var/www/emtskills/docs/FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md",
    rule: ".clinerules/138 (fast LoRA training hardfloor)",
  },
  prefix_caching: {
    description: "Stable EMSU prefix FIRST with cache_control, unique case slot LAST (uncached). Both tiers: frontier HEAD (Anthropic ephemeral cache, ~0.1x read cost after first call) + 70B BODY (Ollama KV prefix reuse, ~25% latency drop).",
    ordering_rule: "STABLE PREFIX FIRST (system + skeleton + EMSU policy), UNIQUE CASE SLOT LAST. Anything after the first changed token is NOT cached.",
    builder: "lib/frankenstein_prompt.php (one shared stable-prefix builder for both tiers)",
  },
  what_NOT_to_do: [
    "Do NOT do whole-response draft→frontier-refine (measured +27% COST on Opus).",
    "Do NOT rely on speculative decoding through Anthropic/OpenAI (not exposed).",
    "Do NOT expect prefill/caching to discount frontier OUTPUT tokens (they don't — input-only).",
    "Do NOT trust file-reads for routing claims — verify with a live header curl (rule 140).",
  ],
  cross_refs: [
    ".clinerules/140 — verify LLM routing from live headers, not file-reads",
    ".clinerules/138 — fast LoRA training hardfloor",
    "fleet-state-mcp fleet_routing_map — per-surface routing facts",
    "FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md — full fast-train + serve runbook",
  ],
};

const TOOLING_FACTS = {
  topic: "Roman (DGX Spark) gpt-oss-120b Tool-Calling Reality",
  summary: "vLLM 0.10.1.1 /v1/chat/completions CANNOT emit tool_calls for gpt-oss/harmony. SAME build /v1/responses returns clean function_call (200). Fix: frankenstein-tools adapter translates chat+tools -> /v1/responses -> OpenAI tool_calls.",
  source_doc: "/var/www/emtskills/docs/research/roman_gptoss_tooling_research_2026-06-07.md",
  key_facts: {
    vllm_version: "0.10.1.1 (NGC nvcr.io/nvidia/vllm:25.09-py3)",
    chat_completions_problem: "gpt-oss uses OpenAI 'harmony' channel (analysis->reasoning_content, commentary->tool call, final->content). vLLM 0.10.1.1 raises NotImplementedError. Small max_tokens truncates to tool_calls=null (caused Cline loop). Large max_tokens -> HTTP 400 'Expected 2 output messages... got 3'.",
    responses_endpoint_works: "SAME vLLM 0.10.1.1's /v1/responses returns clean structured function_call (200). output[] contains {type:'function_call', name, arguments, call_id}. The 120B CAN tool-call — different endpoint.",
    adapter_fix: {
      name: "frankenstein_tools_adapter",
      what: "Stdlib-only HTTP sidecar translating OpenAI chat+tools -> /v1/responses -> OpenAI tool_calls. No-tool requests transparently proxied to chat/completions.",
      service: "systemd frankenstein-tools.service on WOPR",
      port: 11510,
      source: "/usr/local/bin/frankenstein_tools_adapter.py",
      local_source: "/Users/rubenmajor/Desktop/frankenstein_tools_adapter.py",
      litemll_model: "frankenstein-tools (openai/frankenstein-tools -> 127.0.0.1:11510/v1)",
      litemll_config: "supports_function_calling: true, max_input_tokens: 16384, request_timeout: 90s",
      upstreams: "Cesar (127.0.0.1:11506) + Cato (127.0.0.1:11507), round-robined",
      deps: "ZERO pip deps (http.server + urllib + json stdlib only)",
      verified: true,
      idea: "#10740",
    },
    native_upgrade_path: {
      idea: "#10739",
      description: "vLLM >=0.10.2 adds --tool-call-parser openai (PR #22386, merged 2025-09-05). Also adds --tool-call-parser gptoss for reasoning. 0.10.1.1 does NOT support openai parser (adding it KeyErrors and crash-loops).",
      note: "The two-flag pattern: --enable-auto-tool-choice + --tool-call-parser <family>. llama3_json for 70B, openai for gpt-oss.",
    },
    harmony_litemll_gap: "LiteLLM has NO built-in harmony->tool_calls transform (hosted_vllm is thin passthrough). Cannot fix at proxy level.",
    tool_call_max_tokens_note: "harmony emits reasoning preamble BEFORE tool call. Small max_tokens truncates to finish_reason=length with tool_calls=null. Always test tool calls with max_tokens>=512.",
  },
  romans_ssh: {
    Cesar: "ssh -i /home/emsuserver/.ssh/id_ed25519 -p 2203 rubenmajor@127.0.0.1 (spark-3b41, :11506)",
    Cato: "ssh -i /home/emsuserver/.ssh/id_ed25519 -p 2204 rubenmajor@127.0.0.1 (spark-2aa8, :11507)",
    note: "Both run gpt-oss-120b on vLLM 0.10.1.1 (NGC 25.09). Via WOPR tunnels.",
  },
  cross_refs: [
    ".clinerules/140 — verify LLM routing from live headers, not file-reads",
    ".clinerules/141 — call project-frankenstein MCP first for architecture truth",
    ".clinerules/92 — work at the core, not bandaids",
    "idea #10739 — upgrade Romans to vLLM >=0.10.2 for native openai tool parser",
    "idea #10740 — frankenstein-tools adapter (shipped 2026-06-07, VERIFIED)",
  ],
};

const FAST_TRAIN_RUNBOOK = {
  source: "/var/www/emtskills/docs/FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md",
  scope: "Applies to EVERY EMSU task_kind through frank_lora_train.sh (classify, student_email_reply, plan_summary, ticket_triage, cline_code_turn, code70b).",
  levers: [
    "1 epoch first (was 5): ~3-5x. Add epochs only if the gate fails.",
    "packing=True (was False): ~2-3x. TRL SFTTrainer concatenates short samples to fill max_seq_length.",
    "DDP one full replica per GPU via accelerate launch --multi_gpu / torchrun --nproc_per_node=N: near-linear in #GPUs. REMOVE device_map=auto from training (it pipeline-shards ONE model => ~1-GPU throughput). 4-bit 70B QLoRA replica ~40-45GB fits one per 80GB H100/B200.",
    "Serve raw LoRA on vLLM (--enable-lora + runtime hot-load of adapter_model.safetensors, VLLM_ALLOW_RUNTIME_LORA_UPDATING=true): skips the 60-90min merge->GGUF->ship delivery.",
  ],
  hardfloor_pull_before_gate: "A gate result must NEVER destroy the only copy of weights. Pull adapter to ARCHIVE_<run>/ BEFORE the gate decision. Pull first, judge second, terminate last.",
  cross_refs: [".clinerules/138", "FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md"],
};

// ─── Tools ──────────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "frankenstein_architecture",
    description:
      "Canonical Project Frankenstein LLM architecture: head/body/stitches model, spill ladder, machine-flap rule ('route by health'), M1 70B ~2-4 window cap, warmth definition, fast-train levers, prefix-caching ordering rule, and what NOT to do. Sourced from /var/www/emtskills/docs/PROJECT_FRANKENSTEIN.md. Use this BEFORE answering any Frankenstein or LLM-routing question. STDIO, returns instantly.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_tier_health",
    description:
      "Live fleet tier health + adapter decode-liveness (idea #13121): which tiers are UP/DOWN, latency per tier, recent flips. Now also includes adapter_canary_decode: per-upstream {healthy, decode_live, tok_s, quarantined} from frankenstein_canary_health.json — decode_live=False means an upstream passes HTTP but generates zero decode tokens. Queries the fleet API live (bounded 10s fetch). Returns tier status map + staleness note if the API is unreachable. Use with frankenstein_architecture before any routing decision. STDIO, cannot hang.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_pod_status",
    description:
      "RunPod pod truth + vLLM readiness: which pods are RUNNING, which have vLLM /v1/models returning HTTP 200 (actually warm, not just desiredStatus=RUNNING), and any recent pod events. Queries the fleet API live. Use to answer 'is the 70B warm' or 'are RunPods serving'. STDIO, cannot hang.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_verify_routing",
    description:
      "Canonical header probe for a model_id: calls LiteLLM /v1/chat/completions with -D - headers and returns the REAL backend (x-litellm-model-api-base), cost (x-litellm-response-cost), and model id. This is the ground truth per rule 140 — config files and router_hook.py are HYPOTHESES. Use BEFORE stating what model serves a surface. Also probe 'frankenstein-tools' to verify the Roman gpt-oss adapter is live (should return 200 with openai/frankenstein-tools backend). STDIO, live call via fleet API, 40s bound for verify_routing (idea #18918 — slow local models exceed 10s).",
    inputSchema: {
      type: "object",
      properties: {
        model_id: {
          type: "string",
          description: "The model id to probe (e.g. 'frankenstein-llm', 'emsu-executor-auto', 'frankenstein-tools', 'claude-sonnet-4-6'). Default: 'frankenstein-llm'.",
        },
      },
      required: [],
    },
  },
  {
    name: "frankenstein_autoscaler_state",
    description:
      "Last autoscaler decisions + S1-S6 votes: what the autoscaler decided, when, and the per-slot vote breakdown. Queries the fleet API live. Use to understand recent scaling actions before recommending a capacity change. STDIO, cannot hang.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_fast_train",
    description:
      "EMSU Fast LoRA Training runbook: the 4 levers (1 epoch first, packing=True, DDP one-replica-per-GPU, serve raw LoRA on vLLM) + the hardfloor (pull weights to durable storage BEFORE any gate/judge step). Call this BEFORE launching any frank_lora_train run. Backed by FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md + .clinerules/138.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_tooling",
    description:
      "Roman (DGX Spark) gpt-oss-120b tool-calling reality + frankenstein-tools adapter facts. Returns: vLLM 0.10.1.1 /v1/chat/completions CANNOT emit tool_calls for gpt-oss (harmony channel mismatch — small max_tokens -> tool_calls=null, large -> HTTP 400). SAME build /v1/responses returns clean function_call (200). Fix shipped 2026-06-07: frankenstein-tools adapter (systemd frankenstein-tools.service, WOPR :11510) translates chat+tools -> /v1/responses -> OpenAI tool_calls. LiteLLM model 'frankenstein-tools' verified working. Native upgrade path: vLLM >=0.10.2 --tool-call-parser openai (idea #10739). Call this BEFORE asking why tool calls fail on Romans.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_registry",
    description:
      "THE SINGLE SOURCE OF TRUTH for the spill ladder (idea #11261). Returns the live model registry (/etc/litellm/frankenstein_registry.yaml) AND the router's ACTUAL derived state (/tmp/emsu_router_registry_state.json — what router_hook.py loaded at last restart): tier_to_model, model_endpoint, tier_fallthrough, _120b_members, served_ctx, role_targets, plus the registry source (registry:... = live, static_fallback:... = the yaml failed and hardcoded defaults are in effect). router_hook.py + this MCP + the fleet API all read the SAME registry, so agent-facing architecture and live routing can never drift. Adding a model = ONE registry row, no code edit. Call this to answer 'what models exist / what is the ladder / did my new model load'. STDIO, live via fleet API, 10s bound.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_host_probe",
    description:
      "Live per-host generation speed + decode-liveness (idea #13121): tok_per_s + last_gen_ms from a REAL 8-token probe; now also decode_live (True=probe generated real tokens=ALIVE, False=error or 0-tokens=DEAD) + kv_pct (vllm gpu_cache_usage_perc) + kv_doa (near-zero KV while serving=DOA). decode_live=False means box needs quarantine even if HTTP-200. See decode_live/kv_doa fields per host. measured from a REAL 8-token generation probe on each serving host (cesar-120b/cato-120b/artemis-120b/artemis-70b/joshua-70b/sms-70b/wopr-14b). Cache refreshed every ~60s by the emsu-host-gen-probe cron on WOPR. Use this BEFORE saying \'is Artemis serving at full speed?\' - it shows actual tok/s, not just /v1/models HTTP 200. A host with tok_per_s < 2.5 is excluded from _120b_member_available (speed gate, idea #12459 Window 5). This is the one-call answer to \'why is Artemis slow?\' WARNING (2026-06-20): tok_per_s here is an 8-token probe and UNDERCOUNTS sustained generation ~2x (TTFB/prefill dominate). Do NOT quote it as the model real tok/s. Live 200-token bench: cesar 55.4, artemis 44.4 (this probe said 22/30). Use it only for the >2.5 speed-gate + decode-liveness; for real throughput run a 200-token completion and divide tokens/time.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "frankenstein_what_served",
    description:
      "BACKEND SELF-REPORT (idea #11316): answers 'what backends did THIS window actually route to?'. Because frankenstein-llm routing happens server-side AFTER dispatch, the model itself cannot self-introspect — this tool reads the router audit log (which the pre-call hook writes synchronously with a stable conversation_id + the routed `picked` backend on every turn) and returns DISTINCT served backends + per-backend turn counts + cost. Pass a conversation_id (from the audit log / your window) OR a minutes window. Use this at the END of a task to print e.g. 'This iteration routed to: cato-120b (8 turns, $0), deepseek-v4-pro (1 turn, $0.01)'. Local backends are $0. Cross-refs: rule 140 (live-verified), rule 141, rule 137. STDIO, live via fleet API, 10s bound.",
    inputSchema: {
      type: "object",
      properties: {
        conversation_id: {
          type: "string",
          description: "The window's conversation id (e.g. 'conv_2da05b1835568296') as stamped in /tmp/emsu_router_audit.log. Omit to use a time window instead.",
        },
        minutes: {
          type: "string",
          description: "Look back this many minutes instead of (or in addition to) a conversation_id. Default 30 when no conversation_id is given.",
        },
      },
      required: [],
    },
  },
];



// ─── Server ─────────────────────────────────────────────────────────────

const server = new Server(
  { name: "project-frankenstein-mcp", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const name = req.params.name;
  const args = (req.params.arguments ?? {}) as Record<string, string>;
  try {
    let out: unknown;
    if (name === "frankenstein_architecture") {
      out = ARCHITECTURE_SUMMARY;
    } else if (name === "frankenstein_fast_train") {
      out = FAST_TRAIN_RUNBOOK;
    } else if (name === "frankenstein_tier_health") {
      const res = await fleetApi("fleet_tier_health");
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "fleet_api_unreachable",
          msg: res.error,
          note: "Could not reach the fleet API for live tier health. Fallback: call fleet-state-mcp fleet_now + fleet_inventory for host-level health, or try again shortly.",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else if (name === "frankenstein_pod_status") {
      const res = await fleetApi("pod_status");
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "fleet_api_unreachable",
          msg: res.error,
          note: "Could not reach the fleet API for pod status. Fallback: call fleet-state-mcp fleet_now for recent pod events + active pods from the last snapshot.",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else if (name === "frankenstein_verify_routing") {
      const modelId = args.model_id || "frankenstein-llm";
      const res = await fleetApi("verify_routing", { model_id: modelId });
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "routing_probe_failed",
          msg: res.error,
          model_id: modelId,
          note: "The fleet API could not probe this model. The API runs the canonical curl -D - header probe against LiteLLM. If the fleet API is down, run the probe manually per rule 140: curl -s -D - -o /dev/null http://localhost:4000/v1/chat/completions -H 'Authorization: Bearer <LITELLM_MASTER_KEY>' -H 'Content-Type: application/json' -d '{\"model\":\"" + modelId + "\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}' | grep -iE 'HTTP/|x-litellm-model-api-base|x-litellm-response-cost'",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else if (name === "frankenstein_autoscaler_state") {
      const res = await fleetApi("autoscaler_state");
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "fleet_api_unreachable",
          msg: res.error,
          note: "Could not reach the fleet API for autoscaler state. Fallback: call fleet-state-mcp fleet_now for recent Fleet Agent decisions + active RunPod pods.",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else if (name === "frankenstein_tooling") {
      out = TOOLING_FACTS;
    } else if (name === "frankenstein_what_served") {
      // Window C #11316: backend self-report. Reads the router audit log via the
      // fleet API's what_served action (conversation_id + picked, written
      // synchronously by the pre-call hook). Returns distinct backends + turn
      // counts + cost; local backends are $0.
      const params: Record<string, string> = {};
      if (args.conversation_id) params.conversation_id = args.conversation_id;
      if (args.minutes) params.minutes = args.minutes;
      const res = await fleetApi("what_served", params);
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "fleet_api_unreachable",
          msg: res.error,
          note: "Could not reach the fleet API for what_served. Fallback (rule 140): on WOPR run `php /var/www/emtskills/lib/frankenstein_what_served.php --conversation_id=<conv_id>` or `--minutes=30`. Source of truth is /tmp/emsu_router_audit.log (conversation_id + picked).",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else if (name === "frankenstein_registry") {

      const res = await fleetApi("registry");
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "fleet_api_unreachable",
          msg: res.error,
          note: "Could not reach the fleet API for the registry. The single source of truth lives at /etc/litellm/frankenstein_registry.yaml and the router's derived state at /tmp/emsu_router_registry_state.json on WOPR. Adding a model = one registry row + emsu-safe-litellm-restart.sh. Verify with: python3 /etc/litellm/frankenstein_registry.py --check",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else if (name === "frankenstein_host_probe") {
      // idea #12459 Window 5: per-host generation speed (tok/s + ms) from the
      // emsu-host-gen-probe cron cache. The one-call answer to "is Artemis fast?"
      const res = await fleetApi("host_gen_probe");
      if (res.ok) {
        out = res.data;
      } else {
        out = {
          error: "fleet_api_unreachable",
          msg: res.error,
          note: "Fallback: on WOPR run python3 /usr/local/bin/emsu-host-gen-probe.py then cat /tmp/emsu_host_gen_probe_cache.json",
          _fetched_at: new Date().toISOString(),
        };
      }
    } else {
      out = { error: "unknown_tool", name };
    }

    return { content: [{ type: "text", text: JSON.stringify(out, null, 2) }] };
  } catch (e) {
    return {
      content: [{ type: "text", text: JSON.stringify({ error: "exception", msg: (e as Error).message }) }],
      isError: true,
    };
  }
});

// Crash guards
process.on("uncaughtException", (e: unknown) => {
  console.error(`[project-frankenstein-mcp] uncaughtException (swallowed): ${(e as Error)?.message || e}`);
});
process.on("unhandledRejection", (e: unknown) => {
  console.error(`[project-frankenstein-mcp] unhandledRejection (swallowed): ${(e as Error)?.message || e}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[project-frankenstein-mcp] v0.1.1 connected over stdio (architecture static, live via fleet API, 10s bound; verify_routing 40s per idea #18918)");

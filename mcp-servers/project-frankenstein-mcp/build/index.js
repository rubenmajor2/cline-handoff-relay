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
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
const BASE = process.env.FRANKENSTEIN_API_BASE ?? "https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php";
const KEY = process.env.FLEET_MCP_KEY ?? "sk-fleet-717a125f0e92faf6a51c3ead2564d99cd4a4101b";
const FETCH_TIMEOUT_MS = 10_000;
// ─── Live API fetch (bounded, never hangs) ──────────────────────────────
async function fleetApi(action, params = {}) {
    const url = new URL(BASE);
    url.searchParams.set("action", action);
    url.searchParams.set("key", KEY);
    url.searchParams.set("_", Date.now().toString());
    for (const [k, v] of Object.entries(params)) {
        if (v)
            url.searchParams.set(k, v);
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
    try {
        const r = await fetch(url, { signal: ctrl.signal });
        const text = await r.text();
        try {
            return { ok: true, data: JSON.parse(text) };
        }
        catch {
            return { ok: false, error: `non_json_response status=${r.status} body=${text.slice(0, 200)}` };
        }
    }
    catch (e) {
        return { ok: false, error: e.message };
    }
    finally {
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
const ARCHITECTURE_SUMMARY = {
    name: "Project Frankenstein — Head/Body/Stitches LLM Architecture",
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
        description: "Canonical Project Frankenstein LLM architecture: head/body/stitches model, spill ladder, machine-flap rule ('route by health'), M1 70B ~2-4 window cap, warmth definition, fast-train levers, prefix-caching ordering rule, and what NOT to do. Sourced from /var/www/emtskills/docs/PROJECT_FRANKENSTEIN.md. Use this BEFORE answering any Frankenstein or LLM-routing question. STDIO, returns instantly.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "frankenstein_tier_health",
        description: "Live fleet tier health: which tiers are UP/DOWN, latency per tier, any recent flips or anomalies. Queries the fleet API live (bounded 10s fetch). Returns tier status map + staleness note if the API is unreachable. Use with frankenstein_architecture before any routing decision. STDIO, cannot hang.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "frankenstein_pod_status",
        description: "RunPod pod truth + vLLM readiness: which pods are RUNNING, which have vLLM /v1/models returning HTTP 200 (actually warm, not just desiredStatus=RUNNING), and any recent pod events. Queries the fleet API live. Use to answer 'is the 70B warm' or 'are RunPods serving'. STDIO, cannot hang.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "frankenstein_verify_routing",
        description: "Canonical header probe for a model_id: calls LiteLLM /v1/chat/completions with -D - headers and returns the REAL backend (x-litellm-model-api-base), cost (x-litellm-response-cost), and model id. This is the ground truth per rule 140 — config files and router_hook.py are HYPOTHESES. Use BEFORE stating what model serves a surface. Also probe 'frankenstein-tools' to verify the Roman gpt-oss adapter is live (should return 200 with openai/frankenstein-tools backend). STDIO, live call via fleet API, 10s bound.",
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
        description: "Last autoscaler decisions + S1-S6 votes: what the autoscaler decided, when, and the per-slot vote breakdown. Queries the fleet API live. Use to understand recent scaling actions before recommending a capacity change. STDIO, cannot hang.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "frankenstein_fast_train",
        description: "EMSU Fast LoRA Training runbook: the 4 levers (1 epoch first, packing=True, DDP one-replica-per-GPU, serve raw LoRA on vLLM) + the hardfloor (pull weights to durable storage BEFORE any gate/judge step). Call this BEFORE launching any frank_lora_train run. Backed by FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md + .clinerules/138.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "frankenstein_tooling",
        description: "Roman (DGX Spark) gpt-oss-120b tool-calling reality + frankenstein-tools adapter facts. Returns: vLLM 0.10.1.1 /v1/chat/completions CANNOT emit tool_calls for gpt-oss (harmony channel mismatch — small max_tokens -> tool_calls=null, large -> HTTP 400). SAME build /v1/responses returns clean function_call (200). Fix shipped 2026-06-07: frankenstein-tools adapter (systemd frankenstein-tools.service, WOPR :11510) translates chat+tools -> /v1/responses -> OpenAI tool_calls. LiteLLM model 'frankenstein-tools' verified working. Native upgrade path: vLLM >=0.10.2 --tool-call-parser openai (idea #10739). Call this BEFORE asking why tool calls fail on Romans.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "frankenstein_registry",
        description: "THE SINGLE SOURCE OF TRUTH for the spill ladder (idea #11261). Returns the live model registry (/etc/litellm/frankenstein_registry.yaml) AND the router's ACTUAL derived state (/tmp/emsu_router_registry_state.json — what router_hook.py loaded at last restart): tier_to_model, model_endpoint, tier_fallthrough, _120b_members, served_ctx, role_targets, plus the registry source (registry:... = live, static_fallback:... = the yaml failed and hardcoded defaults are in effect). router_hook.py + this MCP + the fleet API all read the SAME registry, so agent-facing architecture and live routing can never drift. Adding a model = ONE registry row, no code edit. Call this to answer 'what models exist / what is the ladder / did my new model load'. STDIO, live via fleet API, 10s bound.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
];
// ─── Server ─────────────────────────────────────────────────────────────
const server = new Server({ name: "project-frankenstein-mcp", version: "0.1.0" }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));
server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = (req.params.arguments ?? {});
    try {
        let out;
        if (name === "frankenstein_architecture") {
            out = ARCHITECTURE_SUMMARY;
        }
        else if (name === "frankenstein_fast_train") {
            out = FAST_TRAIN_RUNBOOK;
        }
        else if (name === "frankenstein_tier_health") {
            const res = await fleetApi("fleet_tier_health");
            if (res.ok) {
                out = res.data;
            }
            else {
                out = {
                    error: "fleet_api_unreachable",
                    msg: res.error,
                    note: "Could not reach the fleet API for live tier health. Fallback: call fleet-state-mcp fleet_now + fleet_inventory for host-level health, or try again shortly.",
                    _fetched_at: new Date().toISOString(),
                };
            }
        }
        else if (name === "frankenstein_pod_status") {
            const res = await fleetApi("pod_status");
            if (res.ok) {
                out = res.data;
            }
            else {
                out = {
                    error: "fleet_api_unreachable",
                    msg: res.error,
                    note: "Could not reach the fleet API for pod status. Fallback: call fleet-state-mcp fleet_now for recent pod events + active pods from the last snapshot.",
                    _fetched_at: new Date().toISOString(),
                };
            }
        }
        else if (name === "frankenstein_verify_routing") {
            const modelId = args.model_id || "frankenstein-llm";
            const res = await fleetApi("verify_routing", { model_id: modelId });
            if (res.ok) {
                out = res.data;
            }
            else {
                out = {
                    error: "routing_probe_failed",
                    msg: res.error,
                    model_id: modelId,
                    note: "The fleet API could not probe this model. The API runs the canonical curl -D - header probe against LiteLLM. If the fleet API is down, run the probe manually per rule 140: curl -s -D - -o /dev/null http://localhost:4000/v1/chat/completions -H 'Authorization: Bearer <LITELLM_MASTER_KEY>' -H 'Content-Type: application/json' -d '{\"model\":\"" + modelId + "\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}' | grep -iE 'HTTP/|x-litellm-model-api-base|x-litellm-response-cost'",
                    _fetched_at: new Date().toISOString(),
                };
            }
        }
        else if (name === "frankenstein_autoscaler_state") {
            const res = await fleetApi("autoscaler_state");
            if (res.ok) {
                out = res.data;
            }
            else {
                out = {
                    error: "fleet_api_unreachable",
                    msg: res.error,
                    note: "Could not reach the fleet API for autoscaler state. Fallback: call fleet-state-mcp fleet_now for recent Fleet Agent decisions + active RunPod pods.",
                    _fetched_at: new Date().toISOString(),
                };
            }
        }
        else if (name === "frankenstein_tooling") {
            out = TOOLING_FACTS;
        }
        else if (name === "frankenstein_registry") {
            const res = await fleetApi("registry");
            if (res.ok) {
                out = res.data;
            }
            else {
                out = {
                    error: "fleet_api_unreachable",
                    msg: res.error,
                    note: "Could not reach the fleet API for the registry. The single source of truth lives at /etc/litellm/frankenstein_registry.yaml and the router's derived state at /tmp/emsu_router_registry_state.json on WOPR. Adding a model = one registry row + emsu-safe-litellm-restart.sh. Verify with: python3 /etc/litellm/frankenstein_registry.py --check",
                    _fetched_at: new Date().toISOString(),
                };
            }
        }
        else {
            out = { error: "unknown_tool", name };
        }
        return { content: [{ type: "text", text: JSON.stringify(out, null, 2) }] };
    }
    catch (e) {
        return {
            content: [{ type: "text", text: JSON.stringify({ error: "exception", msg: e.message }) }],
            isError: true,
        };
    }
});
// Crash guards
process.on("uncaughtException", (e) => {
    console.error(`[project-frankenstein-mcp] uncaughtException (swallowed): ${e?.message || e}`);
});
process.on("unhandledRejection", (e) => {
    console.error(`[project-frankenstein-mcp] unhandledRejection (swallowed): ${e?.message || e}`);
});
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[project-frankenstein-mcp] v0.1.0 connected over stdio (architecture static, tier-health/pod-status/verify-routing/autoscaler live via fleet API, 10s bound)");

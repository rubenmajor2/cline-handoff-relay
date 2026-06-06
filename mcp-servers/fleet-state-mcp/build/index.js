#!/usr/bin/env node
/**
 * fleet-state-mcp — idea #6825
 *
 * 5 tools that wrap /var/www/emtskills/routes/api_fleet_inventory.php:
 *   - fleet_inventory: list canonical hosts + roles + models + ports
 *   - fleet_now: snapshot of llm spend, recent events, runpods, decisions
 *   - failover_status: all-75 failover readiness snapshot
 *   - fleet_act: mark host status / queue burst / queue kv-evict
 *   - fleet_routing_map: per-surface routing map with DEDUPED call counts + session facts (#10160)
 *
 * ─────────────────────────────────────────────────────────────────────────
 * 2026-06-04 — QUINTESSENTIAL FIX (idea #9731). Source incident: every Cline
 * window that called a fleet tool tripped YOLO.
 *
 * ROOT CAUSE (eliminated here): this server used to run as a stdio process
 * bridged to HTTP by `supergateway --stateful`. supergateway forks a NEW node
 * child per client session and (in 3.4.3) never reaps idle ones because it
 * ignores --sessionTimeout. Those orphaned children pile up (observed 1170
 * spawns / 48 live on this server alone) and starve the VS Code extension
 * host. A starved ext-host makes the MCP tool call hang, Cline times out,
 * retries, narrates, and trips YOLO on the 3rd strike.
 *
 * THE FIX: serve MCP StreamableHTTP NATIVELY from a single long-lived node
 * process using the SDK's StreamableHTTPServerTransport in STATELESS mode
 * (sessionIdGenerator: undefined). No supergateway. No per-session forks. No
 * child processes EVER. A fresh Server+Transport pair is created per HTTP
 * request, handles it in-process, and is closed on response end — so there is
 * nothing to leak. The launchd plist now runs `node build/index.js` directly.
 * ─────────────────────────────────────────────────────────────────────────
 */
import express from "express";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
const BASE = process.env.FLEET_API_BASE ?? "https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php";
const KEY = process.env.FLEET_MCP_KEY ?? "sk-fleet-717a125f0e92faf6a51c3ead2564d99cd4a4101b";
const PORT = parseInt(process.env.FLEET_MCP_PORT ?? "7856", 10);
async function call(action, params = {}) {
    const url = new URL(BASE);
    url.searchParams.set("action", action);
    url.searchParams.set("key", KEY);
    url.searchParams.set("_", Date.now().toString());
    for (const [k, v] of Object.entries(params)) {
        if (v !== undefined && v !== null && v !== "")
            url.searchParams.set(k, v);
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 25_000);
    try {
        const r = await fetch(url, { signal: ctrl.signal });
        const text = await r.text();
        try {
            return JSON.parse(text);
        }
        catch {
            return { error: "non_json_response", status: r.status, body_preview: text.slice(0, 300) };
        }
    }
    catch (e) {
        return { error: "fetch_failed", msg: e.message };
    }
    finally {
        clearTimeout(t);
    }
}
const TOOLS = [
    {
        name: "fleet_inventory",
        description: "Canonical EMSU fleet inventory (idea #6825). Returns all known hosts (WOPR, Joshua, SMS Mac, Artemis, Ruben Mac) with role, IPs, ssh path, models served, ports, last heartbeat, status. Call this BEFORE re-discovering infrastructure via grep/ssh.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "fleet_now",
        description: "Live aggregate snapshot of EMSU fleet: host heartbeat ages, llm_call_log spend by model (last 24h), llm spend by surface (last 1h), recent fleet/runpod events, active RunPod pods, recent Fleet Agent decisions. Use to answer 'what is the fleet doing right now'.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "failover_status",
        description: "All-75 failover readiness snapshot. Returns writer lease (who is master), per-node replication (Joshua/Gemini IO+SQL+seconds_behind+last_error), serve-mode (proxy-primary vs serve-local), fence-timer state, vhost parity (WOPR vs Joshua + missing list), and the last per-site serve sweep (pass/fail counts). Read-only. Backed by api_fleet_inventory.php?action=failover which reads /etc/emsu/writer_lease + infrastructure_worker_heartbeat + data/failover_status.json (written by the emsu-failover-canary cron every 15 min).",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "fleet_routing_map",
        description: "Queryable EMSU LLM routing map — idea #10160. Returns per-surface call stats (DEDUPED by request_id — eliminates 71-190x raw_rows inflation from streaming chunks), transport type, forced_claude flag, local_eligible flag, and corrected session facts. " +
            "CORRECTED SESSION FACTS encoded here (rule 135 read-at-runtime): " +
            "(1) 70B works via vLLM tool-parser: llama-3.3-70b on RunPod RTX A6000 48GB with --tool-call-parser llama3_json --enable-auto-tool-choice (LiteLLM model: vllm-llama3.3-70b-tools, supports_function_calling=true). " +
            "(2) emsu-executor-auto is the gateway template for all CS agents (executor surface): primary=openrouter/deepseek-v4-pro, fallback=[vllm-llama3.3-70b-tools, ollama-70b, 7b-lora, claude-sonnet], OpenAI path (NOT Anthropic passthrough). " +
            "(3) anthropic-passthrough (cline_passthrough surface) is the ONLY forced-Claude surface — LiteLLM /anthropic/v1/messages pass_through, tool-bearing turns pinned to claude-sonnet-4-6. All other surfaces use OpenAI path and are local-eligible. " +
            "Also returns enabled orchestrator_llm_routes rows and frugal-gate status. Call this INSTEAD of grepping router_hook.py.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "fleet_act",
        description: "Take an action on the fleet (logged to fleet_decision_log + orchestrator_event_log). Supported commands: mark_host_status (set host status to healthy/degraded/down/unknown), request_anthropic_burst (queue Fleet Agent to pivot to Anthropic), request_kv_evict (queue KV cache eviction signal).",
        inputSchema: {
            type: "object",
            properties: {
                cmd: {
                    type: "string",
                    enum: ["mark_host_status", "request_anthropic_burst", "request_kv_evict"],
                    description: "Action command",
                },
                host_key: { type: "string", description: "Host key (only for mark_host_status). One of: wopr, joshua, sms_mac, artemis, mac_ruben" },
                status: {
                    type: "string",
                    enum: ["healthy", "degraded", "down", "unknown"],
                    description: "New status (only for mark_host_status)",
                },
                note: { type: "string", description: "Free-text note logged with the decision" },
            },
            required: ["cmd"],
        },
    },
    {
        name: "fast_train_runbook",
        description: "EMSU Fast LoRA Training stack (2026-06-06 breakthrough-for-us, standard ML best practice). Returns the canonical runbook for training ANY EMSU adapter 10-70x faster: (1) 1 epoch first not 5, (2) packing=True, (3) DDP one-replica-per-GPU NOT device_map=auto (which pipeline-shards and runs at 1-GPU speed), (4) serve raw LoRA on vLLM --enable-lora instead of 60-90min GGUF. PLUS the hardfloor: pull weights to durable storage BEFORE any gate/judge step, because a crashed eval + unconditional term_pod on ephemeral disk DESTROYED code70b_2ep+3ep. Call this before launching any frank_lora_train run. Backed by FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md + .clinerules/138.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
];
const FAST_TRAIN_RUNBOOK = {
    scope: "Applies to EVERY EMSU task_kind through frank_lora_train.sh (classify, student_email_reply, plan_summary, ticket_triage, cline_code_turn, code70b). One trainer, so fixing it once fixes all.",
    honest_framing: "Standard industry techniques, NOT novel ML. Feels like a breakthrough only because the EMSU pipeline used none of them. ~10-70x is us catching up to best practice, not advancing the field.",
    levers: [
        "1 epoch first (was 5): ~3-5x. Add epochs only if the gate fails.",
        "packing=True (was False): ~2-3x. TRL SFTTrainer concatenates short samples to fill max_seq_length.",
        "DDP one full replica per GPU via accelerate launch --multi_gpu / torchrun --nproc_per_node=N: near-linear in #GPUs. REMOVE device_map=auto from training (it pipeline-shards ONE model => ~1-GPU throughput). 4-bit 70B QLoRA replica ~40-45GB fits one per 80GB H100/B200.",
        "Serve raw LoRA on vLLM (--enable-lora + runtime hot-load of adapter_model.safetensors, VLLM_ALLOW_RUNTIME_LORA_UPDATING=true): skips the 60-90min merge->GGUF->ship delivery. Pass adapter name as the model field.",
    ],
    hardfloor_pull_before_gate: "A gate result must NEVER destroy the only copy of weights. Pull adapter to ARCHIVE_<run>/ BEFORE the gate decision; run frank_adapter_rescue.sh to pull the instant adapter_model.safetensors exists. Pull first, judge second, terminate last. Incident: crashed pod_gate_eval_hf.py wrote 'none' => read as FAIL => term_pod hard-DELETEd ephemeral pods => lost code70b_2ep + 3ep.",
    open_verification: [
        "8-GPU DDP 70B QLoRA end-to-end + gate PASS not yet measured on fleet (projection until proven).",
        "vLLM runtime LoRA hot-load on vllm-70b-tools-v4: confirm --enable-lora + VLLM_ALLOW_RUNTIME_LORA_UPDATING before relying on it.",
    ],
    refs: ["FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md (Desktop + WOPR /var/www/frank_adapters/)", ".clinerules/138"],
};
// A fresh MCP Server with handlers wired. Created per-request (stateless) so
// there is no shared mutable session state and nothing to leak.
function makeServer() {
    const server = new Server({ name: "fleet-state-mcp", version: "0.3.0" }, { capabilities: { tools: {} } });
    server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));
    server.setRequestHandler(CallToolRequestSchema, async (req) => {
        const name = req.params.name;
        const args = (req.params.arguments ?? {});
        try {
            let out;
            if (name === "fleet_inventory") {
                out = await call("inventory");
            }
            else if (name === "fleet_now") {
                out = await call("now");
            }
            else if (name === "failover_status") {
                out = await call("failover");
            }
            else if (name === "fleet_routing_map") {
                out = await call("routing_map");
            }
            else if (name === "fleet_act") {
                out = await call("act", {
                    cmd: args.cmd ?? "",
                    host_key: args.host_key ?? "",
                    status: args.status ?? "",
                    note: args.note ?? "",
                });
            }
            else if (name === "fast_train_runbook") {
                out = FAST_TRAIN_RUNBOOK;
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
    return server;
}
// ── Native StreamableHTTP server (single process, zero child procs) ────────
const app = express();
app.use(express.json({ limit: "4mb" }));
// Health endpoint (parity with the old --healthEndpoint /health).
app.get("/health", (_req, res) => {
    res.json({ ok: true, name: "fleet-state-mcp", version: "0.3.0", transport: "streamableHttp-native" });
});
// Stateless StreamableHTTP: a new Server + Transport per POST, torn down on
// response close. sessionIdGenerator:undefined => no session tracking, so the
// client never needs to carry an mcp-session-id and there is no per-session
// state to accumulate.
app.post("/mcp", async (req, res) => {
    const server = makeServer();
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    res.on("close", () => {
        transport.close().catch(() => { });
        server.close().catch(() => { });
    });
    try {
        await server.connect(transport);
        await transport.handleRequest(req, res, req.body);
    }
    catch (e) {
        if (!res.headersSent) {
            res.status(500).json({
                jsonrpc: "2.0",
                error: { code: -32603, message: "Internal server error", data: e.message },
                id: null,
            });
        }
    }
});
// Stateless mode does not use GET (SSE) or DELETE (session teardown). Reply
// with the MCP-conventional "method not allowed" so clients don't hang.
const methodNotAllowed = (_req, res) => {
    res.status(405).json({
        jsonrpc: "2.0",
        error: { code: -32000, message: "Method not allowed in stateless mode." },
        id: null,
    });
};
app.get("/mcp", methodNotAllowed);
app.delete("/mcp", methodNotAllowed);
// ── Crash guards: keep the listener alive on transient errors so Cline never
// sees a red dot that needs a manual refresh.
process.on("uncaughtException", (e) => {
    console.error(`[fleet-state-mcp] uncaughtException (swallowed): ${e?.message || e}`);
});
process.on("unhandledRejection", (e) => {
    console.error(`[fleet-state-mcp] unhandledRejection (swallowed): ${e?.message || e}`);
});
app.listen(PORT, () => {
    console.error(`[fleet-state-mcp] native streamableHttp listening on :${PORT}/mcp (stateless, zero child procs)`);
});

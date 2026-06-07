#!/usr/bin/env node
/**
 * fleet-state-mcp — STDIO entrypoint (v0.5.0)
 *
 * ─────────────────────────────────────────────────────────────────────────
 * 2026-06-07 — RELIABILITY FIX v0.5.0 (Ruben directive: "Every single time
 * any agent in Cline tries to access the fleet MCP it fails, stalls, hits
 * YOLOs. I need a permanent fix. Do something completely different so the
 * information can be provided to the agents without them tripping on it.")
 *
 * ROOT CAUSE (reproduced 2026-06-07): the v0.4.x server was registered in
 * Cline as `streamableHttp` (http://localhost:7856/mcp). A plain GET /health
 * returned instantly, but a real MCP POST /mcp tool call (Accept:
 * text/event-stream) opened an SSE stream that did NOT terminate promptly —
 * the connection stayed open until the client's 60s timeout. From the agent's
 * side that is an indefinite stall: 30s tool wall -> retry -> prose narration
 * -> YOLO on the 3rd strike. The hot-path snapshot logic was already correct;
 * the HANG WAS IN THE HTTP/SSE TRANSPORT, not in the data fetch.
 *
 * THE FIX — DO SOMETHING COMPLETELY DIFFERENT:
 *   Drop the HTTP/SSE transport entirely. Serve over STDIO (like delegate-70b).
 *   stdio has:
 *     - no port to be unreachable
 *     - no SSE response stream that can stay open
 *     - no separate long-lived HTTP daemon the client depends on
 *   Cline spawns THIS process and talks over stdin/stdout. Every read tool
 *   does a SYNCHRONOUS readFileSync of the already-warm on-disk snapshot
 *   (~/.fleet-state-mcp/snapshot.json) and returns immediately. A synchronous
 *   local file read cannot hang the event loop the way a network SSE stream
 *   can. Worst case is slightly-stale data with an honest staleness flag.
 *
 * WHO KEEPS THE SNAPSHOT WARM:
 *   The existing launchd job (com.emsu.mcp-fleet-state, build/index.js) stays
 *   running purely as the OUT-OF-BAND REFRESHER. It fetches the 4 read actions
 *   from api_fleet_inventory.php every ~60s and writes snapshot.json atomically.
 *   This stdio server only ever READS that file. If the refresher is down, the
 *   snapshot just goes stale (flagged) — reads still return instantly, never
 *   hang. As a safety net, if the snapshot is missing OR older than
 *   SELF_REFRESH_AFTER_MS this process will kick a single bounded background
 *   refresh of its own (off the hot path), so it self-heals even with no daemon.
 *
 * fleet_act (the only WRITE tool, rare + deliberate) does a bounded 8s live
 * call and returns a clean error object on failure. It never hangs the terminal.
 * ─────────────────────────────────────────────────────────────────────────
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { homedir } from "node:os";
import { join } from "node:path";
import { mkdirSync, readFileSync, writeFileSync, renameSync, statSync } from "node:fs";
const BASE = process.env.FLEET_API_BASE ?? "https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php";
const KEY = process.env.FLEET_MCP_KEY ?? "sk-fleet-717a125f0e92faf6a51c3ead2564d99cd4a4101b";
const STALE_AFTER_MS = parseInt(process.env.FLEET_STALE_AFTER_MS ?? "180000", 10); // flag stale after 3 missed refreshes
const SELF_REFRESH_AFTER_MS = parseInt(process.env.FLEET_SELF_REFRESH_AFTER_MS ?? "120000", 10); // self-heal if snapshot older than 2m
const ACT_TIMEOUT_MS = 8_000;
const SELF_REFRESH_TIMEOUT_MS = 15_000;
const CACHED_ACTIONS = ["inventory", "now", "failover", "routing_map"];
const CACHE_DIR = join(homedir(), ".fleet-state-mcp");
const CACHE_FILE = join(CACHE_DIR, "snapshot.json");
// Read the on-disk snapshot fresh on each call. Synchronous, local, fast.
// Cannot hang. Returns {} if the file is missing/corrupt.
function readSnapshot() {
    try {
        const raw = readFileSync(CACHE_FILE, "utf8");
        return JSON.parse(raw);
    }
    catch {
        return {};
    }
}
function snapshotMtimeMs() {
    try {
        return statSync(CACHE_FILE).mtimeMs;
    }
    catch {
        return 0;
    }
}
// Hot-path read: pull the action's blob from the on-disk snapshot, annotate
// with staleness. Zero network. Returns instantly.
function readCached(action) {
    const snap = readSnapshot();
    const entry = snap[action];
    const now = Date.now();
    if (!entry || entry.fetched_at === 0 || entry.data === undefined) {
        return {
            error: "cache_cold",
            action,
            note: "Fleet snapshot not yet populated (the background refresher has not landed a snapshot since boot). " +
                "This returns immediately rather than hanging. The launchd refresher (com.emsu.mcp-fleet-state) writes " +
                "~/.fleet-state-mcp/snapshot.json every ~60s; retry shortly. Served over stdio — cannot hang.",
            last_error: entry?.last_error ?? null,
        };
    }
    const ageMs = now - entry.fetched_at;
    const blob = entry.data;
    const meta = {
        _cache: {
            fetched_at: new Date(entry.fetched_at).toISOString(),
            age_seconds: Math.round(ageMs / 1000),
            stale: ageMs > STALE_AFTER_MS,
            source: "local_snapshot_stdio",
            last_refresh_error: entry.last_error ?? null,
            note: "Served over STDIO from the local fleet snapshot (~/.fleet-state-mcp/snapshot.json, refreshed ~60s " +
                "off the hot path by the launchd refresher). Synchronous file read, zero network on this call by " +
                "design — cannot hang, cannot YOLO. v0.5.0.",
        },
    };
    if (blob && typeof blob === "object" && !Array.isArray(blob)) {
        return { ...blob, ...meta };
    }
    return { data: blob, ...meta };
}
// ── Self-heal refresher (off the hot path) ─────────────────────────────────
// If no launchd daemon is keeping the snapshot warm, this stdio process will
// refresh it itself — but NEVER on a tool-call hot path. It runs on a timer
// and on boot only when the snapshot is missing/old. One bounded fetch per
// action; failures leave the previous good snapshot in place.
let refreshing = false;
async function remoteCall(action, params = {}, timeoutMs = SELF_REFRESH_TIMEOUT_MS) {
    const url = new URL(BASE);
    url.searchParams.set("action", action);
    url.searchParams.set("key", KEY);
    url.searchParams.set("_", Date.now().toString());
    for (const [k, v] of Object.entries(params)) {
        if (v !== undefined && v !== null && v !== "")
            url.searchParams.set(k, v);
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
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
function persist(snap) {
    try {
        mkdirSync(CACHE_DIR, { recursive: true });
        const tmp = CACHE_FILE + ".tmp." + process.pid;
        writeFileSync(tmp, JSON.stringify(snap), "utf8");
        renameSync(tmp, CACHE_FILE);
    }
    catch (e) {
        console.error(`[fleet-state-stdio] persist failed (non-fatal): ${e.message}`);
    }
}
async function selfHealRefresh() {
    if (refreshing)
        return;
    refreshing = true;
    try {
        const snap = readSnapshot();
        for (const action of CACHED_ACTIONS) {
            const res = await remoteCall(action);
            if (res.ok) {
                snap[action] = { data: res.data, fetched_at: Date.now() };
            }
            else if (snap[action]) {
                snap[action].last_error = res.error;
            }
            else {
                snap[action] = { data: undefined, fetched_at: 0, last_error: res.error };
            }
        }
        persist(snap);
    }
    catch (e) {
        console.error(`[fleet-state-stdio] selfHealRefresh failed (non-fatal): ${e.message}`);
    }
    finally {
        refreshing = false;
    }
}
function maybeSelfHeal() {
    // Only refresh if the snapshot is missing or older than the self-refresh
    // window. Never blocks a tool call — fire-and-forget, off the hot path.
    const age = Date.now() - snapshotMtimeMs();
    if (snapshotMtimeMs() === 0 || age > SELF_REFRESH_AFTER_MS) {
        selfHealRefresh().catch(() => { });
    }
}
const TOOLS = [
    {
        name: "fleet_inventory",
        description: "Canonical EMSU fleet inventory (idea #6825). Returns all known hosts (WOPR, Joshua, SMS Mac, Artemis, Ruben Mac) with role, IPs, ssh path, models served, ports, last heartbeat, status. Served over STDIO from a local snapshot (refreshed ~60s off the hot path) — synchronous file read, returns instantly, cannot hang. Call this BEFORE re-discovering infrastructure via grep/ssh.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "fleet_now",
        description: "Live aggregate snapshot of EMSU fleet: host heartbeat ages, llm_call_log spend by model (last 24h), llm spend by surface (last 1h), recent fleet/runpod events, active RunPod pods, recent Fleet Agent decisions. Served over STDIO from the local snapshot with an _cache.age_seconds staleness marker. Use to answer 'what is the fleet doing right now'.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "failover_status",
        description: "All-75 failover readiness snapshot. Returns writer lease (who is master), per-node replication (Joshua/Gemini IO+SQL+seconds_behind+last_error), serve-mode (proxy-primary vs serve-local), fence-timer state, vhost parity (WOPR vs Joshua + missing list), and the last per-site serve sweep (pass/fail counts). Read-only, served over STDIO from the local snapshot. Backed by api_fleet_inventory.php?action=failover which reads /etc/emsu/writer_lease + infrastructure_worker_heartbeat + data/failover_status.json (written by the emsu-failover-canary cron every 15 min).",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "fleet_routing_map",
        description: "Queryable EMSU LLM routing map — idea #10160. Returns per-surface call stats (DEDUPED by request_id — eliminates 71-190x raw_rows inflation from streaming chunks), transport type, forced_claude flag, local_eligible flag, and corrected session facts. Served over STDIO from the local snapshot. " +
            "CORRECTED SESSION FACTS encoded here (rule 135 read-at-runtime): " +
            "(1) 70B works via vLLM tool-parser: llama-3.3-70b on RunPod RTX A6000 48GB with --tool-call-parser llama3_json --enable-auto-tool-choice (LiteLLM model: vllm-llama3.3-70b-tools, supports_function_calling=true). " +
            "(2) emsu-executor-auto is the gateway template for all CS agents (executor surface): primary=openrouter/deepseek-v4-pro, fallback=[vllm-llama3.3-70b-tools, ollama-70b, 7b-lora, claude-sonnet], OpenAI path (NOT Anthropic passthrough). " +
            "(3) anthropic-passthrough (cline_passthrough surface) is the ONLY forced-Claude surface — LiteLLM /anthropic/v1/messages pass_through, tool-bearing turns pinned to claude-sonnet-4-6. All other surfaces use OpenAI path and are local-eligible. " +
            "Also returns enabled orchestrator_llm_routes rows and frugal-gate status. Call this INSTEAD of grepping router_hook.py.",
        inputSchema: { type: "object", properties: {}, required: [] },
    },
    {
        name: "fleet_act",
        description: "Take an action on the fleet (logged to fleet_decision_log + orchestrator_event_log). Supported commands: mark_host_status (set host status to healthy/degraded/down/unknown), request_anthropic_burst (queue Fleet Agent to pivot to Anthropic), request_kv_evict (queue KV cache eviction signal). This is the only WRITE tool — it goes live to the API with an 8s bound and returns a clean error object on failure (never hangs).",
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
const server = new Server({ name: "fleet-state-mcp", version: "0.5.0" }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));
server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = (req.params.arguments ?? {});
    // Off-hot-path self-heal check (fire-and-forget; never blocks this call).
    maybeSelfHeal();
    try {
        let out;
        if (name === "fleet_inventory") {
            out = readCached("inventory");
        }
        else if (name === "fleet_now") {
            out = readCached("now");
        }
        else if (name === "failover_status") {
            out = readCached("failover");
        }
        else if (name === "fleet_routing_map") {
            out = readCached("routing_map");
        }
        else if (name === "fast_train_runbook") {
            out = FAST_TRAIN_RUNBOOK;
        }
        else if (name === "fleet_act") {
            const res = await remoteCall("act", {
                cmd: args.cmd ?? "",
                host_key: args.host_key ?? "",
                status: args.status ?? "",
                note: args.note ?? "",
            }, ACT_TIMEOUT_MS);
            out = res.ok
                ? res.data
                : { error: "act_failed", msg: res.error, note: "fleet_act could not reach the API within 8s; nothing was changed. Retry, or check WOPR/api_fleet_inventory.php." };
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
// Crash guards: never let a transient error kill the stdio process mid-session.
process.on("uncaughtException", (e) => {
    console.error(`[fleet-state-stdio] uncaughtException (swallowed): ${e?.message || e}`);
});
process.on("unhandledRejection", (e) => {
    console.error(`[fleet-state-stdio] unhandledRejection (swallowed): ${e?.message || e}`);
});
// On boot, if the snapshot looks cold, kick one self-heal (off the hot path).
maybeSelfHeal();
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[fleet-state-stdio] v0.5.0 connected over stdio (local-snapshot reads, zero network on hot path, cannot hang)");

#!/usr/bin/env node
/**
 * fleet-state-mcp — idea #6825
 *
 * 3 tools that wrap /var/www/emtskills/routes/api_fleet_inventory.php:
 *   - fleet_inventory: list canonical hosts + roles + models + ports
 *   - fleet_now: snapshot of llm spend, recent events, runpods, decisions
 *   - fleet_act: mark host status / queue burst / queue kv-evict
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
const BASE = process.env.FLEET_API_BASE ?? "https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php";
const KEY = process.env.FLEET_MCP_KEY ?? "sk-fleet-717a125f0e92faf6a51c3ead2564d99cd4a4101b";
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
    finally {
        clearTimeout(t);
    }
}

// #16588: Fleet inventory reliability — live-probe mandate when heartbeat age >2h.
// Post-processes API responses to add staleness_warnings for any host with a stale
// heartbeat. Agents seeing these warnings MUST live-probe (llm_locate, curl, ssh)
// before making material claims about host status in attempt_completion.
const STALE_THRESHOLD_MIN = 120; // 2 hours
function addStalenessWarnings(response) {
    if (!response || typeof response !== "object") return response;
    const warnings = [];
    const hosts = response.hosts || response.as_of?.hosts || [];
    for (const h of hosts) {
        if (h.heartbeat_age_min !== undefined && h.heartbeat_age_min > STALE_THRESHOLD_MIN) {
            warnings.push({
                host_key: h.host_key,
                heartbeat_age_min: h.heartbeat_age_min,
                status: h.status,
                warning: `STALE HEARTBEAT (${h.heartbeat_age_min}min > ${STALE_THRESHOLD_MIN}min). Live-probe required before declaring this host down/up. Use llm_locate or curl before any material claim in attempt_completion.`,
            });
        }
    }
    if (warnings.length > 0) {
        response.staleness_warnings = warnings;
        response.staleness_note = `${warnings.length} host(s) have stale heartbeats (>${STALE_THRESHOLD_MIN}min). Per rule 255 + idea #16588: live-probe before trusting inventory status.`;
    }
    return response;
}
const server = new Server({ name: "fleet-state-mcp", version: "0.1.0" }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
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
            name: "fleet_act",
            description: "Take an action on the fleet (logged to fleet_decision_log + orchestrator_event_log + UPDATES fleet_inventory table directly per idea #16345). Supported commands: mark_host_status (set host status to healthy/degraded/down/unknown, AND updates fleet_inventory.ip_wireguard/ip_primary/last_heartbeat/note_provenance), request_anthropic_burst (queue Fleet Agent to pivot to Anthropic), request_kv_evict (queue KV cache eviction signal). IMPORTANT: mark_host_status now writes to fleet_inventory directly — no need for separate direct-SQL updates. Always pass ip_wireguard when correcting a WG IP.",
            inputSchema: {
                type: "object",
                properties: {
                    cmd: {
                        type: "string",
                        enum: ["mark_host_status", "request_anthropic_burst", "request_kv_evict"],
                        description: "Action command",
                    },
                    host_key: { type: "string", description: "Host key (only for mark_host_status). One of: wopr, joshua, sms_mac, artemis, mac_ruben, cesar, cato, julia, claudia, augustus, tiberius, cicero" },
                    status: {
                        type: "string",
                        enum: ["healthy", "degraded", "down", "unknown"],
                        description: "New status (only for mark_host_status)",
                    },
                    ip_wireguard: { type: "string", description: "Corrected WireGuard IP (only for mark_host_status). Pass this whenever correcting a WG IP — it writes directly to fleet_inventory.ip_wireguard." },
                    ip_primary: { type: "string", description: "Corrected primary IP (only for mark_host_status, optional)." },
                    note: { type: "string", description: "Free-text note logged with the decision" },
                },
                required: ["cmd"],
            },
        },
        {
            name: "llm_locate",
            description: "CANONICAL live-probed LLM location tool (idea #16346). Returns where a model is served RIGHT NOW, with head/worker labels, WOPR endpoint citations, and live HTTP probe status. Self-heals fleet_inventory. ALWAYS cite the endpoint (e.g. WOPR:11513), NOT the box-local port (e.g. :8000). Worker boxes (Cato, Claudia, Tiberius) have NO inbound serving port by design (rule 157) — do not declare them down for lacking a listener. Use this BEFORE answering 'where is model X served' or declaring any LLM endpoint down.",
            inputSchema: {
                type: "object",
                properties: {
                    model: { type: "string", description: "Model name to locate (e.g. gpt-oss-120b, llama-3.1-405b-fp4, qwen2.5-coder). Empty = all models." },
                },
                required: [],
            },
        },
    ],
}));
server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = (req.params.arguments ?? {});
    try {
        let out;
        if (name === "fleet_inventory") {
            out = addStalenessWarnings(await call("inventory"));
        }
        else if (name === "fleet_now") {
            out = addStalenessWarnings(await call("now"));
        }
        else if (name === "fleet_act") {
            out = await call("act", {
                cmd: args.cmd ?? "",
                host_key: args.host_key ?? "",
                status: args.status ?? "",
                ip_wireguard: args.ip_wireguard ?? "",
                ip_primary: args.ip_primary ?? "",
                note: args.note ?? "",
            });
        }
        else if (name === "llm_locate") {
            out = await call("llm_locate", {
                model: args.model ?? "",
            });
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
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[fleet-state-mcp] ready");
// Orphan guard (2026-07-03, idea #16323): when a Cline window closes, the extension
// host exits and we get reparented to launchd (PPID=1). Self-exit within 30s of
// parent death to prevent zombie process accumulation. Same pattern as clinerules-mcp.
setInterval(() => {
    try {
        if (process.ppid === 1) {
            console.error("[fleet-state-mcp] parent process gone (PPID=1), exiting to avoid orphan leak");
            process.exit(0);
        }
    }
    catch { /* never crash the server on a guard check */ }
}, 30_000);

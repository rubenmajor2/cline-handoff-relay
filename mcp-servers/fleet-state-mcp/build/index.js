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
            name: "failover_status",
            description: "All-75 failover readiness snapshot. Returns writer lease (who is master), per-node replication (Joshua/Gemini IO+SQL+seconds_behind+last_error), serve-mode (proxy-primary vs serve-local), fence-timer state, vhost parity (WOPR vs Joshua + missing list), and the last per-site serve sweep (pass/fail counts). Read-only. Backed by api_fleet_inventory.php?action=failover which reads /etc/emsu/writer_lease + infrastructure_worker_heartbeat + data/failover_status.json (written by the emsu-failover-canary cron every 15 min).",
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
    ],
}));
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
        else if (name === "fleet_act") {
            out = await call("act", {
                cmd: args.cmd ?? "",
                host_key: args.host_key ?? "",
                status: args.status ?? "",
                note: args.note ?? "",
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
// ── Crash guards: keep the stdio process alive on transient errors so Cline
// never sees a red dot that needs a manual refresh. (matches clinerules-mcp)
process.stdin.on("error", (e) => {
    console.error(`[fleet-state-mcp] stdin error (swallowed): ${e?.code || e?.message}`);
});
process.stdout.on("error", (e) => {
    console.error(`[fleet-state-mcp] stdout error (swallowed): ${e?.code || e?.message}`);
});
process.on("uncaughtException", (e) => {
    console.error(`[fleet-state-mcp] uncaughtException (swallowed): ${e?.message || e}`);
});
process.on("unhandledRejection", (e) => {
    console.error(`[fleet-state-mcp] unhandledRejection (swallowed): ${e?.message || e}`);
});
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[fleet-state-mcp] ready");


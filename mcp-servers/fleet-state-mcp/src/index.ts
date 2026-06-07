#!/usr/bin/env node
/**
 * fleet-state-mcp — idea #6825
 *
 * Tools that wrap /var/www/emtskills/routes/api_fleet_inventory.php:
 *   - fleet_inventory: list canonical hosts + roles + models + ports
 *   - fleet_now: snapshot of llm spend, recent events, runpods, decisions
 *   - failover_status: all-75 failover readiness snapshot
 *   - fleet_routing_map: per-surface routing map with DEDUPED call counts + session facts (#10160)
 *   - fleet_act: mark host status / queue burst / queue kv-evict
 *   - fast_train_runbook: static runbook (never touches network)
 *
 * ─────────────────────────────────────────────────────────────────────────
 * 2026-06-06 — RELIABILITY FIX v0.4.0 (Ruben directive: "fleet MCP stalls and
 * YOLOs on numerous occasions, come up with a comprehensive final solution.
 * Do we need to move it to sqlite like clinerules or something else?").
 *
 * THE ANSWER: the key property is NOT sqlite-vs-json. It is the clinerules
 * principle: ANSWER FROM A LOCAL SNAPSHOT, NEVER DO A LIVE REMOTE CALL ON THE
 * TOOL-CALL HOT PATH.
 *
 * PRIOR FAILURE MODE (now eliminated): every read tool (fleet_inventory /
 * fleet_now / failover_status / fleet_routing_map) did a SYNCHRONOUS HTTP
 * fetch() to https://www.emsuniversity.com/.../api_fleet_inventory.php with a
 * 25s timeout. When WOPR / its DB / the WireGuard path was slow, the tool call
 * hung up to 25s. Cline's ~30s tool wall + retry + prose-narration then tripped
 * YOLO on the 3rd strike (rule 41 / rule 99). This happened repeatedly.
 *
 * THE FIX (this file):
 *   1. A SINGLE long-lived background refresher (setInterval, default 60s)
 *      fetches all 4 read-only actions from the PHP API OFF the hot path.
 *   2. Results are held in memory AND written atomically to an on-disk JSON
 *      snapshot (~/.fleet-state-mcp/snapshot.json) so a freshly-(re)started
 *      process boots WARM from the last good snapshot.
 *   3. Read tool calls return the cached blob INSTANTLY — zero network, cannot
 *      hang, cannot YOLO — annotated with _cache {fetched_at, age_seconds,
 *      stale}. Worst case is slightly-stale data with an honest staleness flag,
 *      never a hang.
 *   4. fleet_act (the only WRITE tool, invoked deliberately + rarely) still
 *      goes live, but with a tight 8s bound and a clean error object on failure
 *      — it returns fast either way, it never hangs the terminal.
 *
 * This mirrors clinerules-mcp: local snapshot on the hot path, remote refresh
 * strictly out-of-band. SQLite was unnecessary — the data is a handful of small
 * JSON blobs keyed by action, so an atomic JSON file is the right-sized store.
 *
 * TRANSPORT: native StreamableHTTP, single process, ZERO child procs (the
 * supergateway per-session fork-leak from <=v0.2 was removed in v0.3 per idea
 * #9731 and stays removed here). launchd runs `node build/index.js` directly.
 * ─────────────────────────────────────────────────────────────────────────
 */
import express, { type Request, type Response } from "express";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { homedir } from "node:os";
import { join } from "node:path";
import { mkdirSync, readFileSync, writeFileSync, renameSync } from "node:fs";

const BASE = process.env.FLEET_API_BASE ?? "https://www.emsuniversity.com/emtskills/routes/api_fleet_inventory.php";
const KEY = process.env.FLEET_MCP_KEY ?? "sk-fleet-717a125f0e92faf6a51c3ead2564d99cd4a4101b";
const PORT = parseInt(process.env.FLEET_MCP_PORT ?? "7856", 10);

// Background-refresh cadence + staleness policy.
const REFRESH_MS = parseInt(process.env.FLEET_REFRESH_MS ?? "60000", 10); // refresh every 60s
const STALE_AFTER_MS = parseInt(process.env.FLEET_STALE_AFTER_MS ?? "180000", 10); // mark stale after 3 missed refreshes
const REFRESH_TIMEOUT_MS = 20_000; // per-action fetch bound, OFF the hot path
const ACT_TIMEOUT_MS = 8_000; // fleet_act live-call bound

// The read-only actions kept warm in the local snapshot.
const CACHED_ACTIONS = ["inventory", "now", "failover", "routing_map"] as const;
type CachedAction = (typeof CACHED_ACTIONS)[number];

// On-disk warm-boot store (atomic write via tmp+rename). JSON, not sqlite:
// these are a few small per-action blobs, so a single atomic file is correct.
const CACHE_DIR = join(homedir(), ".fleet-state-mcp");
const CACHE_FILE = join(CACHE_DIR, "snapshot.json");

interface CacheEntry {
  data: unknown;
  fetched_at: number; // epoch ms of last SUCCESSFUL fetch
  last_error?: string; // last refresh error, if the most recent attempt failed
}
type CacheShape = Partial<Record<CachedAction, CacheEntry>>;

const cache: CacheShape = {};

function loadDiskCache(): void {
  try {
    const raw = readFileSync(CACHE_FILE, "utf8");
    const parsed = JSON.parse(raw) as CacheShape;
    for (const a of CACHED_ACTIONS) {
      if (parsed[a] && typeof parsed[a]!.fetched_at === "number") cache[a] = parsed[a]!;
    }
    console.error(`[fleet-state-mcp] warm-boot: loaded ${Object.keys(cache).length} cached actions from disk`);
  } catch {
    console.error("[fleet-state-mcp] no warm-boot cache on disk (cold start)");
  }
}

function persistDiskCache(): void {
  try {
    mkdirSync(CACHE_DIR, { recursive: true });
    const tmp = CACHE_FILE + ".tmp";
    writeFileSync(tmp, JSON.stringify(cache), "utf8");
    renameSync(tmp, CACHE_FILE); // atomic swap
  } catch (e) {
    console.error(`[fleet-state-mcp] persistDiskCache failed (non-fatal): ${(e as Error).message}`);
  }
}

// Raw remote fetch — used ONLY by the background refresher and by fleet_act.
// Never called on a read tool's hot path.
async function remoteCall(
  action: string,
  params: Record<string, string> = {},
  timeoutMs: number = REFRESH_TIMEOUT_MS,
): Promise<{ ok: boolean; data?: unknown; error?: string }> {
  const url = new URL(BASE);
  url.searchParams.set("action", action);
  url.searchParams.set("key", KEY);
  url.searchParams.set("_", Date.now().toString());
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, v);
  }
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
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

// Background refresher: pull each cached action, update memory + disk on success.
// Failures leave the previous good snapshot in place and record last_error.
async function refreshAll(): Promise<void> {
  for (const action of CACHED_ACTIONS) {
    const res = await remoteCall(action);
    if (res.ok) {
      cache[action] = { data: res.data, fetched_at: Date.now() };
    } else if (cache[action]) {
      cache[action]!.last_error = res.error;
    } else {
      // never succeeded yet — record a placeholder so callers see the error, not a hang
      cache[action] = { data: undefined, fetched_at: 0, last_error: res.error };
    }
  }
  persistDiskCache();
}

// Hot-path read: return the cached blob immediately, annotated with staleness.
function readCached(action: CachedAction): unknown {
  const entry = cache[action];
  const now = Date.now();
  if (!entry || entry.fetched_at === 0) {
    return {
      error: "cache_cold",
      action,
      note:
        "Snapshot not yet populated (remote refresh has not succeeded since this process started). " +
        "This returns immediately rather than hanging. Retry in ~60s once the background refresher lands a snapshot.",
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
      refresh_interval_seconds: Math.round(REFRESH_MS / 1000),
      last_refresh_error: entry.last_error ?? null,
      source: "local_snapshot",
      note:
        "Served from the local fleet snapshot (refreshed every ~" +
        Math.round(REFRESH_MS / 1000) +
        "s off the hot path). Zero network on this call by design — cannot hang.",
    },
  };
  // Merge meta onto the blob when it's an object; otherwise wrap it.
  if (blob && typeof blob === "object" && !Array.isArray(blob)) {
    return { ...(blob as Record<string, unknown>), ...meta };
  }
  return { data: blob, ...meta };
}

const TOOLS = [
  {
    name: "fleet_inventory",
    description:
      "Canonical EMSU fleet inventory (idea #6825). Returns all known hosts (WOPR, Joshua, SMS Mac, Artemis, Ruben Mac) with role, IPs, ssh path, models served, ports, last heartbeat, status. Served from a local snapshot (refreshed every ~60s off the hot path) so it returns instantly and never hangs. Call this BEFORE re-discovering infrastructure via grep/ssh.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "fleet_now",
    description:
      "Live aggregate snapshot of EMSU fleet: host heartbeat ages, llm_call_log spend by model (last 24h), llm spend by surface (last 1h), recent fleet/runpod events, active RunPod pods, recent Fleet Agent decisions. Served from the local snapshot (refreshed ~60s) with an _cache.age_seconds staleness marker. Use to answer 'what is the fleet doing right now'.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "failover_status",
    description:
      "All-75 failover readiness snapshot. Returns writer lease (who is master), per-node replication (Joshua/Gemini IO+SQL+seconds_behind+last_error), serve-mode (proxy-primary vs serve-local), fence-timer state, vhost parity (WOPR vs Joshua + missing list), and the last per-site serve sweep (pass/fail counts). Read-only, served from the local snapshot. Backed by api_fleet_inventory.php?action=failover which reads /etc/emsu/writer_lease + infrastructure_worker_heartbeat + data/failover_status.json (written by the emsu-failover-canary cron every 15 min).",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "fleet_routing_map",
    description:
      "Queryable EMSU LLM routing map — idea #10160. Returns per-surface call stats (DEDUPED by request_id — eliminates 71-190x raw_rows inflation from streaming chunks), transport type, forced_claude flag, local_eligible flag, and corrected session facts. Served from the local snapshot. " +
      "CORRECTED SESSION FACTS encoded here (rule 135 read-at-runtime): " +
      "(1) 70B works via vLLM tool-parser: llama-3.3-70b on RunPod RTX A6000 48GB with --tool-call-parser llama3_json --enable-auto-tool-choice (LiteLLM model: vllm-llama3.3-70b-tools, supports_function_calling=true). " +
      "(2) emsu-executor-auto is the gateway template for all CS agents (executor surface): primary=openrouter/deepseek-v4-pro, fallback=[vllm-llama3.3-70b-tools, ollama-70b, 7b-lora, claude-sonnet], OpenAI path (NOT Anthropic passthrough). " +
      "(3) anthropic-passthrough (cline_passthrough surface) is the ONLY forced-Claude surface — LiteLLM /anthropic/v1/messages pass_through, tool-bearing turns pinned to claude-sonnet-4-6. All other surfaces use OpenAI path and are local-eligible. " +
      "Also returns enabled orchestrator_llm_routes rows and frugal-gate status. Call this INSTEAD of grepping router_hook.py.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "fleet_act",
    description:
      "Take an action on the fleet (logged to fleet_decision_log + orchestrator_event_log). Supported commands: mark_host_status (set host status to healthy/degraded/down/unknown), request_anthropic_burst (queue Fleet Agent to pivot to Anthropic), request_kv_evict (queue KV cache eviction signal). This is the only WRITE tool — it goes live to the API with an 8s bound and returns a clean error object on failure (never hangs).",
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
    description:
      "EMSU Fast LoRA Training stack (2026-06-06 breakthrough-for-us, standard ML best practice). Returns the canonical runbook for training ANY EMSU adapter 10-70x faster: (1) 1 epoch first not 5, (2) packing=True, (3) DDP one-replica-per-GPU NOT device_map=auto (which pipeline-shards and runs at 1-GPU speed), (4) serve raw LoRA on vLLM --enable-lora instead of 60-90min GGUF. PLUS the hardfloor: pull weights to durable storage BEFORE any gate/judge step, because a crashed eval + unconditional term_pod on ephemeral disk DESTROYED code70b_2ep+3ep. Call this before launching any frank_lora_train run. Backed by FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md + .clinerules/138.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
];

const FAST_TRAIN_RUNBOOK = {
  scope:
    "Applies to EVERY EMSU task_kind through frank_lora_train.sh (classify, student_email_reply, plan_summary, ticket_triage, cline_code_turn, code70b). One trainer, so fixing it once fixes all.",
  honest_framing:
    "Standard industry techniques, NOT novel ML. Feels like a breakthrough only because the EMSU pipeline used none of them. ~10-70x is us catching up to best practice, not advancing the field.",
  levers: [
    "1 epoch first (was 5): ~3-5x. Add epochs only if the gate fails.",
    "packing=True (was False): ~2-3x. TRL SFTTrainer concatenates short samples to fill max_seq_length.",
    "DDP one full replica per GPU via accelerate launch --multi_gpu / torchrun --nproc_per_node=N: near-linear in #GPUs. REMOVE device_map=auto from training (it pipeline-shards ONE model => ~1-GPU throughput). 4-bit 70B QLoRA replica ~40-45GB fits one per 80GB H100/B200.",
    "Serve raw LoRA on vLLM (--enable-lora + runtime hot-load of adapter_model.safetensors, VLLM_ALLOW_RUNTIME_LORA_UPDATING=true): skips the 60-90min merge->GGUF->ship delivery. Pass adapter name as the model field.",
  ],
  hardfloor_pull_before_gate:
    "A gate result must NEVER destroy the only copy of weights. Pull adapter to ARCHIVE_<run>/ BEFORE the gate decision; run frank_adapter_rescue.sh to pull the instant adapter_model.safetensors exists. Pull first, judge second, terminate last. Incident: crashed pod_gate_eval_hf.py wrote 'none' => read as FAIL => term_pod hard-DELETEd ephemeral pods => lost code70b_2ep + 3ep.",
  open_verification: [
    "8-GPU DDP 70B QLoRA end-to-end + gate PASS not yet measured on fleet (projection until proven).",
    "vLLM runtime LoRA hot-load on vllm-70b-tools-v4: confirm --enable-lora + VLLM_ALLOW_RUNTIME_LORA_UPDATING before relying on it.",
  ],
  refs: ["FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md (Desktop + WOPR /var/www/frank_adapters/)", ".clinerules/138"],
};


// A fresh MCP Server with handlers wired. Created per-request (stateless) so
// there is no shared mutable session state and nothing to leak.
function makeServer(): Server {
  const server = new Server(
    { name: "fleet-state-mcp", version: "0.4.0" },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = (req.params.arguments ?? {}) as Record<string, string>;
    try {
      let out: unknown;
      // Read tools: served from the local snapshot — INSTANT, zero network.
      if (name === "fleet_inventory") {
        out = readCached("inventory");
      } else if (name === "fleet_now") {
        out = readCached("now");
      } else if (name === "failover_status") {
        out = readCached("failover");
      } else if (name === "fleet_routing_map") {
        out = readCached("routing_map");
      } else if (name === "fast_train_runbook") {
        out = FAST_TRAIN_RUNBOOK;
      } else if (name === "fleet_act") {
        // The only WRITE tool — bounded live call, clean error on failure.
        const res = await remoteCall(
          "act",
          {
            cmd: args.cmd ?? "",
            host_key: args.host_key ?? "",
            status: args.status ?? "",
            note: args.note ?? "",
          },
          ACT_TIMEOUT_MS,
        );
        out = res.ok
          ? res.data
          : { error: "act_failed", msg: res.error, note: "fleet_act could not reach the API within 8s; nothing was changed. Retry, or check WOPR/api_fleet_inventory.php." };
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

  return server;
}

// ── Native StreamableHTTP server (single process, zero child procs) ────────
const app = express();
app.use(express.json({ limit: "4mb" }));

// Health endpoint includes cache freshness so a curl can confirm the snapshot
// is warm without an MCP round-trip.
app.get("/health", (_req: Request, res: Response) => {
  const now = Date.now();
  const freshness: Record<string, unknown> = {};
  for (const a of CACHED_ACTIONS) {
    const e = cache[a];
    freshness[a] = e && e.fetched_at > 0
      ? { age_seconds: Math.round((now - e.fetched_at) / 1000), last_error: e.last_error ?? null }
      : { age_seconds: null, last_error: e?.last_error ?? "never_fetched" };
  }
  res.json({
    ok: true,
    name: "fleet-state-mcp",
    version: "0.4.0",
    transport: "streamableHttp-native",
    cache: freshness,
    refresh_interval_seconds: Math.round(REFRESH_MS / 1000),
  });
});

app.post("/mcp", async (req: Request, res: Response) => {
  const server = makeServer();
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  res.on("close", () => {
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });
  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  } catch (e) {
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error", data: (e as Error).message },
        id: null,
      });
    }
  }
});

const methodNotAllowed = (_req: Request, res: Response) => {
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
process.on("uncaughtException", (e: unknown) => {
  console.error(`[fleet-state-mcp] uncaughtException (swallowed): ${(e as Error)?.message || e}`);
});
process.on("unhandledRejection", (e: unknown) => {
  console.error(`[fleet-state-mcp] unhandledRejection (swallowed): ${(e as Error)?.message || e}`);
});

// ── Boot: warm from disk, kick an immediate refresh, then loop ─────────────
loadDiskCache();
refreshAll().catch((e) => console.error(`[fleet-state-mcp] initial refresh failed: ${(e as Error).message}`));
const refreshTimer = setInterval(() => {
  refreshAll().catch((e) => console.error(`[fleet-state-mcp] refresh failed: ${(e as Error).message}`));
}, REFRESH_MS);
refreshTimer.unref?.(); // don't keep the event loop alive on this alone

app.listen(PORT, () => {
  console.error(
    `[fleet-state-mcp] v0.4.0 native streamableHttp on :${PORT}/mcp ` +
      `(stateless, zero child procs, local-snapshot reads, ${Math.round(REFRESH_MS / 1000)}s bg refresh)`,
  );
});

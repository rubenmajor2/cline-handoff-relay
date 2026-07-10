#!/usr/bin/env node
/**
 * mcp-http-bridge — single-shared-child stdio→StreamableHTTP bridge.
 *
 * idea #9731 — the QUINTESSENTIAL, UNIVERSAL fix for the MCP child-leak that
 * was tripping YOLO in every Cline window.
 *
 * THE PROBLEM IT REPLACES
 * -----------------------
 * supergateway bridges a stdio MCP server to HTTP by forking a NEW node child
 * per client session (--stateful) or per request (stateless). With many Cline
 * windows open, idle children pile into the hundreds (observed 372 node procs
 * system-wide), starving the VS Code extension host. A starved ext-host makes
 * MCP tool calls hang → Cline times out → retries → narrates → YOLO.
 *
 * THE FIX
 * -------
 * Spawn EXACTLY ONE persistent stdio child per server, for the life of the
 * launchd service. Serve StreamableHTTP statelessly on PORT. For each inbound
 * /mcp POST, forward the JSON-RPC message to the single shared child and route
 * the reply back by id. Verified: stdio MCP servers (incl. stateful ones like
 * memory/sequential-thinking that hold in-RAM state) tolerate many initialize
 * handshakes + interleaved requests on one long-lived connection. So: one
 * child per server, ZERO per-session forks, ZERO leak, state preserved.
 *
 * Client request ids are namespaced to an internal monotonic id before going
 * to the child, then translated back, so two Cline windows that both use id=1
 * never collide on the shared pipe.
 *
 * ENV:
 *   BRIDGE_PORT        TCP port to listen on (required)
 *   BRIDGE_CHILD_BIN   absolute path to the child executable (required)
 *   BRIDGE_CHILD_ARGS  optional, space-separated args for the child
 *   BRIDGE_NAME        label for logs/health (optional)
 */
"use strict";
const express = require("express");
const { spawn } = require("child_process");

const PORT = parseInt(process.env.BRIDGE_PORT || "0", 10);
const CHILD_BIN = process.env.BRIDGE_CHILD_BIN || "";
const CHILD_ARGS = (process.env.BRIDGE_CHILD_ARGS || "").trim();
const NAME = process.env.BRIDGE_NAME || "mcp-http-bridge";

if (!PORT || !CHILD_BIN) {
  console.error(`[${NAME}] FATAL: BRIDGE_PORT and BRIDGE_CHILD_BIN are required`);
  process.exit(2);
}
const childArgv = CHILD_ARGS.length ? CHILD_ARGS.split(/\s+/) : [];

// ── The single shared child ────────────────────────────────────────────────
let child = null;
let childBuf = "";
let internalSeq = 1;
// internalId -> { resolve, timer }   (only for requests that carry an id)
const pending = new Map();

function log(msg) {
  console.error(`[${NAME}] ${msg}`);
}

function startChild() {
  log(`spawning shared child: ${CHILD_BIN} ${childArgv.join(" ")}`);
  child = spawn(CHILD_BIN, childArgv, { stdio: ["pipe", "pipe", "pipe"] });

  child.stdout.on("data", (d) => {
    childBuf += d.toString();
    let nl;
    while ((nl = childBuf.indexOf("\n")) >= 0) {
      const line = childBuf.slice(0, nl);
      childBuf = childBuf.slice(nl + 1);
      if (!line.trim()) continue;
      let msg;
      try { msg = JSON.parse(line); } catch { continue; }
      // Response to one of our forwarded requests?
      if (msg.id !== undefined && msg.id !== null && pending.has(msg.id)) {
        const p = pending.get(msg.id);
        pending.delete(msg.id);
        clearTimeout(p.timer);
        p.resolve(msg);
      }
      // else: server-initiated request/notification with no waiter — ignore
      // (these stdio servers don't initiate sampling in our usage).
    }
  });

  child.stderr.on("data", (d) => {
    // surface child stderr but don't crash
    const s = d.toString().trim();
    if (s) log(`child stderr: ${s.slice(0, 200)}`);
  });

  child.on("exit", (code, sig) => {
    log(`child exited (code=${code} sig=${sig}); failing ${pending.size} pending, respawning in 1s`);
    for (const [, p] of pending) { clearTimeout(p.timer); p.resolve(null); }
    pending.clear();
    childBuf = "";
    setTimeout(startChild, 1000);
  });
}
startChild();

function childWrite(obj) {
  try { child.stdin.write(JSON.stringify(obj) + "\n"); return true; }
  catch (e) { log(`child write failed: ${e.message}`); return false; }
}

// Forward a single JSON-RPC message. Requests (with id) resolve with the child
// response; notifications (no id) resolve immediately after writing.
function forward(msg) {
  return new Promise((resolve) => {
    const hasId = msg.id !== undefined && msg.id !== null;
    if (!hasId) { childWrite(msg); return resolve(null); }
    const internalId = `b${internalSeq++}`;
    const originalId = msg.id;
    const out = { ...msg, id: internalId };
    const timer = setTimeout(() => {
      if (pending.has(internalId)) {
        pending.delete(internalId);
        resolve({ jsonrpc: "2.0", id: originalId, error: { code: -32001, message: "child response timeout" } });
      }
    }, 24000);
    pending.set(internalId, {
      timer,
      resolve: (childMsg) => {
        if (!childMsg) return resolve({ jsonrpc: "2.0", id: originalId, error: { code: -32002, message: "child unavailable" } });
        resolve({ ...childMsg, id: originalId }); // translate id back
      },
    });
    if (!childWrite(out)) {
      clearTimeout(timer);
      pending.delete(internalId);
      resolve({ jsonrpc: "2.0", id: originalId, error: { code: -32003, message: "child write failed" } });
    }
  });
}

// ── HTTP (stateless StreamableHTTP-compatible) ─────────────────────────────
const app = express();
app.use(express.json({ limit: "8mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true, name: NAME, transport: "shared-child-bridge", child_alive: !!(child && !child.killed), pending: pending.size });
});

// Cline's streamableHttp client POSTs one JSON-RPC message per request and
// reads the reply off the same response. We answer as a single SSE "message"
// event (the framing Cline accepts), or 202 for a pure notification.
app.post("/mcp", async (req, res) => {
  const body = req.body;
  const messages = Array.isArray(body) ? body : [body];
  const requests = messages.filter((m) => m && m.id !== undefined && m.id !== null);
  const notifs = messages.filter((m) => m && (m.id === undefined || m.id === null));

  // fire notifications (no reply expected)
  for (const n of notifs) forward(n);

  if (requests.length === 0) {
    // pure notification batch — ack
    res.status(202).end();
    return;
  }

  try {
    const replies = await Promise.all(requests.map(forward));
    res.setHeader("Content-Type", "text/event-stream");
    for (const r of replies) {
      if (r) res.write(`event: message\ndata: ${JSON.stringify(r)}\n\n`);
    }
    res.end();
  } catch (e) {
    if (!res.headersSent) {
      res.status(500).json({ jsonrpc: "2.0", id: null, error: { code: -32603, message: e.message } });
    } else {
      res.end();
    }
  }
});

const methodNotAllowed = (_req, res) =>
  res.status(405).json({ jsonrpc: "2.0", id: null, error: { code: -32000, message: "Method not allowed (stateless bridge)" } });
app.get("/mcp", methodNotAllowed);
app.delete("/mcp", methodNotAllowed);

process.on("uncaughtException", (e) => log(`uncaughtException (swallowed): ${e && e.message}`));
process.on("unhandledRejection", (e) => log(`unhandledRejection (swallowed): ${e && e.message}`));

app.listen(PORT, () => log(`shared-child bridge listening on :${PORT}/mcp (one child, zero leak)`));

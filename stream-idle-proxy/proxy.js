#!/usr/bin/env node
/*
 * EMSU Cline stream-idle proxy shim  —  orchestrator idea #10529 (part 2)
 * ---------------------------------------------------------------------------
 * PROBLEM: Cline (anthropic provider) streams from the LiteLLM router through an
 * SSH -L tunnel (Cline -> 127.0.0.1:8787 -> ssh -> wopr:4000). When litellm
 * restarts or the tunnel is kicked MID-STREAM, the client TCP socket is left
 * half-open: no FIN/RST arrives, so Cline's blocking read() never wakes. macOS
 * TCP keepalive defaults to 2 HOURS, so the VS Code extension host hangs for
 * hours on the dead stream. The tunnel watchdog can heal the tunnel but cannot
 * un-hang an already-stalled window. The fix must live on the CLIENT side.
 *
 * FIX: a tiny dependency-free HTTP proxy that enforces an idle-READ deadline.
 * It forwards Cline -> upstream transparently, but resets a timer on EVERY byte
 * received from upstream. If no bytes arrive for IDLE_MS on an open stream
 * (the exact signature of a severed tunnel), it ABORTS:
 *   - pre-headers  -> returns a clean 504 so Cline retries the request
 *   - mid-stream   -> destroys the client socket so Cline's stream read throws
 *                     ECONNRESET and the SDK retries, instead of hanging forever.
 *
 * It deliberately imposes NO overall response deadline — long valid generations
 * are fine. Only the IDLE gap (no bytes flowing) is bounded.
 *
 * Scope: CLIENT-SIDE ONLY. Does not touch the tunnel, pods, or litellm config.
 *
 * Env:
 *   PROXY_HOST     default 127.0.0.1
 *   PROXY_PORT     default 8789
 *   UPSTREAM_HOST  default 127.0.0.1   (the tunnel's local forward)
 *   UPSTREAM_PORT  default 4000        (ssh -L 4000 -> wopr:4000)
 *   IDLE_MS        default 20000       (no-bytes-on-open-stream deadline)
 *   CONNECT_MS     default 15000       (initial connect/first-response deadline)
 */
'use strict';
const http = require('http');

const LISTEN_HOST   = process.env.PROXY_HOST    || '127.0.0.1';
const LISTEN_PORT   = parseInt(process.env.PROXY_PORT    || '8789', 10);
const UPSTREAM_HOST = process.env.UPSTREAM_HOST || '127.0.0.1';
const UPSTREAM_PORT = parseInt(process.env.UPSTREAM_PORT || '4000', 10);
const IDLE_MS       = parseInt(process.env.IDLE_MS       || '20000', 10);
const CONNECT_MS    = parseInt(process.env.CONNECT_MS    || '15000', 10);

function log(...a) { console.log(new Date().toISOString(), ...a); }

const server = http.createServer((creq, cres) => {
  const started = Date.now();
  let idleTimer = null;
  let headersSent = false;
  let done = false;

  const opts = {
    host: UPSTREAM_HOST,
    port: UPSTREAM_PORT,
    method: creq.method,
    path: creq.url,
    headers: Object.assign({}, creq.headers, { host: `${UPSTREAM_HOST}:${UPSTREAM_PORT}` }),
  };

  function armIdle() {
    if (idleTimer) clearTimeout(idleTimer);
    idleTimer = setTimeout(() => abort(`idle-${IDLE_MS}ms-no-bytes`), IDLE_MS);
  }

  function clearIdle() { if (idleTimer) { clearTimeout(idleTimer); idleTimer = null; } }

  function finish() { done = true; clearIdle(); }

  function abort(reason) {
    if (done) return;
    done = true;
    clearIdle();
    log('ABORT', reason, `after=${Date.now() - started}ms`, creq.method, creq.url);
    try { ureq.destroy(); } catch (e) {}
    if (!headersSent) {
      // No response bytes yet: clean 504 so Cline retries the whole request.
      try {
        cres.writeHead(504, { 'content-type': 'application/json' });
        cres.end(JSON.stringify({
          error: {
            type: 'upstream_idle_timeout',
            message: `stream idle > ${IDLE_MS}ms, aborted by emsu stream-idle proxy (${reason})`,
          },
        }));
      } catch (e) { try { cres.destroy(); } catch (_) {} }
    } else {
      // Already streaming: can't change status. Destroy the client socket so
      // Cline's stream read errors out (ECONNRESET) and the SDK retries.
      try { cres.destroy(); } catch (e) {}
    }
  }

  const ureq = http.request(opts, (ures) => {
    armIdle(); // arm idle timer the moment the response stream begins
    try {
      cres.writeHead(ures.statusCode, ures.headers);
      headersSent = true;
    } catch (e) { abort('client-writehead-error:' + (e && e.code)); return; }

    ures.on('data', (chunk) => {
      armIdle();              // reset on EVERY chunk — this is the whole mechanism
      const ok = cres.write(chunk);
      if (!ok) { ures.pause(); cres.once('drain', () => ures.resume()); }
    });
    ures.on('end',   () => { finish(); try { cres.end(); } catch (e) {} });
    ures.on('error', (e) => abort('upstream-stream-error:' + (e && e.code)));
  });

  // Bound only the initial connect / first-response window.
  ureq.setTimeout(CONNECT_MS, () => { if (!headersSent) abort(`connect-${CONNECT_MS}ms-no-response`); });
  ureq.on('error', (e) => abort('upstream-req-error:' + (e && e.code)));

  creq.on('aborted', () => { finish(); try { ureq.destroy(); } catch (e) {} });
  creq.on('error',   () => { finish(); try { ureq.destroy(); } catch (e) {} });
  creq.pipe(ureq);
});

server.on('clientError', (err, socket) => {
  try { socket.end('HTTP/1.1 400 Bad Request\r\n\r\n'); } catch (e) {}
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  log(`emsu stream-idle proxy up: ${LISTEN_HOST}:${LISTEN_PORT} -> ${UPSTREAM_HOST}:${UPSTREAM_PORT} (idle=${IDLE_MS}ms connect=${CONNECT_MS}ms)`);
});

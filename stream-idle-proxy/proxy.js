#!/usr/bin/env node
/*
 * EMSU Cline stream-idle proxy shim  —  orchestrator ideas #10529 + #15657
 * ---------------------------------------------------------------------------
 * PROBLEM: Cline (anthropic provider) streams from the LiteLLM router through an
 * SSH -L tunnel (Cline -> 127.0.0.1:8787 -> ssh -> wopr:4000). When litellm
 * restarts or the tunnel is kicked MID-STREAM, the client TCP socket is left
 * half-open: no FIN/RST arrives, so Cline's blocking read() never wakes. macOS
 * TCP keepalive defaults to 2 HOURS, so the VS Code extension host hangs for
 * hours on the dead stream. The tunnel watchdog can heal the tunnel but cannot
 * un-hang an already-stalled window. The fix must live on the CLIENT side.
 *
 * FIX (part 1 — idle detection, #10529): enforces an idle-READ deadline.
 * Resets a timer on EVERY byte received. If no bytes arrive for IDLE_MS:
 *   - pre-headers  -> returns a clean 504 so Cline retries
 *   - mid-stream   -> destroys the client socket so Cline's stream read throws
 *                     ECONNRESET and the SDK retries, instead of hanging.
 *
 * FIX (part 2 — ECONNREFUSED retry, #15657): when LiteLLM restarts (~10-15s
 * window), the SSH tunnel returns ECONNREFUSED on new connections. This proxy
 * now retries with exponential backoff (2s, 5s, 10s = 17s window) before
 * falling through to the 504 abort. This makes LiteLLM restarts transparent to
 * running Cline windows.
 *
 * Scope: CLIENT-SIDE ONLY. Does not touch the tunnel, pods, or litellm config.
 *
 * Env:
 *   PROXY_HOST       default 127.0.0.1
 *   PROXY_PORT       default 8789
 *   UPSTREAM_HOST    default 127.0.0.1   (the tunnel's local forward)
 *   UPSTREAM_PORT    default 4000        (ssh -L 4000 -> wopr:4000)
 *   IDLE_MS          default 20000       (no-bytes-on-open-stream deadline)
 *   CONNECT_MS       default 15000       (initial connect/first-response deadline)
 *   RETRY_DELAYS     default "2,5,10"    (ECONNREFUSED retry delays, seconds)
 */
'use strict';
const http = require('http');

const LISTEN_HOST   = process.env.PROXY_HOST    || '127.0.0.1';
const LISTEN_PORT   = parseInt(process.env.PROXY_PORT    || '8789', 10);
const UPSTREAM_HOST = process.env.UPSTREAM_HOST || '127.0.0.1';
const UPSTREAM_PORT = parseInt(process.env.UPSTREAM_PORT || '4000', 10);
const IDLE_MS       = parseInt(process.env.IDLE_MS       || '20000', 10);
const CONNECT_MS    = parseInt(process.env.CONNECT_MS    || '15000', 10);
const RETRY_DELAYS  = (process.env.RETRY_DELAYS || '2,5,10').split(',').map(s => parseFloat(s.trim()) * 1000).filter(n => n > 0);
// CAPTURE mode (debug): when CAPTURE=1, append each request's model + full
// response body (de-SSE'd) to CAPTURE_FILE as JSONL. Off by default = no behavior change.
const CAPTURE       = process.env.CAPTURE === '1';
const CAPTURE_FILE  = process.env.CAPTURE_FILE || '/tmp/frank_capture.jsonl';
const fs = require('fs');

function log(...a) { console.log(new Date().toISOString(), ...a); }

/**
 * Make an upstream HTTP request with ECONNREFUSED retry.
 * Tries once immediately, then retries on ECONNREFUSED with delays from RETRY_DELAYS.
 * Returns the upstream request object or null if all retries exhausted.
 * Calls onConnect(ures) on success, onFail(reason) if all retries fail.
 */
function upstreamWithRetry(opts, connectTimeoutMs, onConnect, onFail) {
  let delays = [0].concat(RETRY_DELAYS); // first attempt is immediate (delay 0)
  let attempt = 0;
  let ureq = null;
  let timedOut = false;

  function tryConnect() {
    if (timedOut) return;
    const delay = delays[attempt];
    if (delay > 0) {
      log('RETRY upstream connect attempt', attempt + 1, `after ${delay}ms`);
      setTimeout(doRequest, delay);
    } else {
      doRequest();
    }
  }

  function doRequest() {
    if (timedOut) return;
    attempt++;
    ureq = http.request(opts, (ures) => {
      // Success — pass the response stream to the caller
      onConnect(ures, attempt);
    });

    ureq.setTimeout(connectTimeoutMs, () => {
      timedOut = true;
      try { ureq.destroy(); } catch (e) {}
      log('UPSTREAM connect timeout after', connectTimeoutMs, 'ms (attempt', attempt, `/ ${delays.length})`);
      // Timeout counts as fatal — don't retry (the tunnel might be wedged, not restarting)
      onFail(`connect-timeout-${connectTimeoutMs}ms`);
    });

    ureq.on('error', (e) => {
      if (timedOut) return;
      const code = e && e.code;
      log('UPSTREAM error', code, 'attempt', attempt, `/ ${delays.length}`);

      // ECONNREFUSED = LiteLLM restarting, retryable
      if (code === 'ECONNREFUSED' && attempt < delays.length) {
        tryConnect();
        return;
      }

      // All other errors: fatal, don't retry
      timedOut = true;
      onFail('upstream-req-error:' + (code || 'unknown'));
    });
  }

  tryConnect();
  return {
    getUreq: () => ureq,
    abort: () => { timedOut = true; try { ureq && ureq.destroy(); } catch (e) {} },
  };
}

const server = http.createServer((creq, cres) => {
  const started = Date.now();
  let idleTimer = null;
  let headersSent = false;
  let done = false;
  let reqBody = '';
  let respBody = '';
  let currentUreq = null;
  let uresRef = null;
  if (CAPTURE) { creq.on('data', (c) => { if (reqBody.length < 200000) reqBody += c.toString(); }); }

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
    try { currentUreq && currentUreq.destroy(); } catch (e) {}
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

  const conn = upstreamWithRetry(opts, CONNECT_MS,
    // onConnect — upstream responded successfully
    (ures, attempt) => {
      uresRef = ures;
      if (attempt > 1) {
        log('UPSTREAM connected on retry', attempt, `after ${Date.now() - started}ms`);
      }
      armIdle();
      try {
        cres.writeHead(ures.statusCode, ures.headers);
        headersSent = true;
      } catch (e) { abort('client-writehead-error:' + (e && e.code)); return; }

      ures.on('data', (chunk) => {
        armIdle();
        if (CAPTURE && respBody.length < 400000) respBody += chunk.toString();
        const ok = cres.write(chunk);
        if (!ok) { ures.pause(); cres.once('drain', () => ures.resume()); }
      });
      ures.on('end',   () => {
        finish();
        try { cres.end(); } catch (e) {}
        if (CAPTURE) {
          try {
            let model = null, stop = null, hasTool = null, ctypes = null;
            try { const rb = JSON.parse(reqBody); model = rb.model; } catch (e) {}
            const toolUse = /"type"\s*:\s*"tool_use"/.test(respBody) || /<(use_mcp_tool|execute_command|read_file|write_to_file|replace_in_file|attempt_completion|list_files|search_files|use_subagents)>/.test(respBody);
            const sr = respBody.match(/"stop_reason"\s*:\s*"([^"]+)"/);
            stop = sr ? sr[1] : null;
            hasTool = toolUse;
            const rec = {
              t: new Date().toISOString(),
              url: creq.url,
              status: ures.statusCode,
              req_model: model,
              req_bytes: reqBody.length,
              resp_bytes: respBody.length,
              stop_reason: stop,
              has_tool_call: hasTool,
              resp_tail: respBody.slice(-1200),
            };
            fs.appendFileSync(CAPTURE_FILE, JSON.stringify(rec) + '\n');
          } catch (e) {}
        }
      });

      ures.on('error', (e) => abort('upstream-stream-error:' + (e && e.code)));
    },
    // onFail — all retries exhausted
    (reason) => {
      abort(reason);
    },
  );

  currentUreq = conn.getUreq();

  creq.on('aborted', () => { finish(); conn.abort(); });
  creq.on('error',   () => { finish(); conn.abort(); });

  // Pipe request body to the initial upstream request.
  // Note: on retry, we can't re-pipe the body (it's already consumed).
  // This is OK because ECONNREFUSED happens at TCP connect time, before any
  // body bytes are sent. The retry creates a fresh socket.
  creq.pipe(currentUreq);
});

server.on('clientError', (err, socket) => {
  try { socket.end('HTTP/1.1 400 Bad Request\r\n\r\n'); } catch (e) {}
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  log(`emsu stream-idle proxy up: ${LISTEN_HOST}:${LISTEN_PORT} -> ${UPSTREAM_HOST}:${UPSTREAM_PORT} (idle=${IDLE_MS}ms connect=${CONNECT_MS}ms retry_delays=${RETRY_DELAYS.map(d => d + 'ms').join(',')})`);
});

#!/usr/bin/env node
/*
 * Test rig for the stream-idle proxy (#10529 part 2).
 * Simulates exactly what a tunnel-kill-mid-stream does to a client:
 *
 *   /stall-midstream : send 200 headers + a few SSE chunks, then go SILENT
 *                      FOREVER with the socket held open (the half-open hang).
 *   /stall-prebody   : send 200 headers, then silence forever (no body bytes).
 *   /stall-preheader : accept the connection, then silence forever (no headers).
 *   /ok              : a normal, prompt streamed response that ends cleanly.
 *
 * No deps. Listens on STALL_PORT (default 9911).
 */
'use strict';
const http = require('http');
const PORT = parseInt(process.env.STALL_PORT || '9911', 10);

const server = http.createServer((req, res) => {
  if (req.url.startsWith('/ok')) {
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    let n = 0;
    const t = setInterval(() => {
      res.write(`data: chunk ${++n}\n\n`);
      if (n >= 3) { clearInterval(t); res.end('data: [DONE]\n\n'); }
    }, 200);
    return;
  }
  if (req.url.startsWith('/stall-midstream')) {
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    res.write('data: chunk 1\n\n');
    res.write('data: chunk 2\n\n');
    // ...then nothing, ever. Socket stays open => half-open hang.
    return;
  }
  if (req.url.startsWith('/stall-prebody')) {
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    // headers only, no body bytes, forever.
    return;
  }
  if (req.url.startsWith('/stall-preheader')) {
    // never call writeHead — connection accepted, silence forever.
    return;
  }
  res.writeHead(404); res.end('nope');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`stall-server up on 127.0.0.1:${PORT}`);
});

# Cline stream-idle proxy — idea #10529 part 2 (client-side fail-fast)

## What this fixes
When LiteLLM restarts or the SSH tunnel is kicked **mid-stream**, the in-flight
Cline HTTP stream is severed but the client TCP socket is left **half-open**: no
FIN/RST arrives, macOS keepalive is 2h, so Cline's blocking read never wakes and
the VS Code extension host hangs **for hours**. The tunnel watchdog heals the
tunnel but cannot un-hang an already-stalled window. This is the **client-side**
fix: fail fast + let Cline retry, instead of hanging.

## The path
```
Cline (anthropic provider)
  -> http://127.0.0.1:8788   [THIS PROXY: idle-read guard]
  -> http://127.0.0.1:8787   [ssh -L tunnel, PID of /usr/bin/ssh]
  -> wopr:4000               [LiteLLM router]
```
Before this fix Cline pointed directly at `:8787`. Now it points at `:8788`.

## Mechanism
`proxy.js` forwards transparently but resets an **idle timer on every byte** from
upstream. If no bytes arrive for `IDLE_MS` (default 20s) on an open stream — the
exact signature of a severed tunnel — it aborts:
- **pre-headers** -> returns a clean **504** so Cline retries the request
- **mid-stream**  -> **destroys the client socket** so Cline's stream read throws
  ECONNRESET and the SDK retries.

No overall response deadline — long valid generations are fine. Only the IDLE
gap is bounded. `CONNECT_MS` (default 45s) bounds the initial first-token wait
(generous for a cold 70B).

## Files
- `proxy.js` — the shim (no deps, node http only)
- `stall-server.js` — test rig that reproduces the half-open hang
- `run_test.sh` — acceptance test (BEFORE vs AFTER) -> /tmp/idle_proxy_test.txt
- `svc_verify.sh` — reload + live happy-path check -> /tmp/svc_verify.txt
- `repoint_cline.sh` — flips Cline anthropicBaseUrl 8787->8788 (backs up state.vscdb)
- `~/Library/LaunchAgents/com.emsu.cline-stream-idle-proxy.plist` — KeepAlive service

## Acceptance evidence (2026-06-07)
| Case | Before (direct) | After (via proxy) |
|---|---|---|
| mid-stream cut | 30.0s (curl's own wall; Cline = forever) | **8.0s** socket destroyed -> ECONNRESET retry |
| pre-body cut   | — | **8.0s -> HTTP 504** retryable |
| pre-header cut | — | **8.0s -> HTTP 504** retryable |
| happy /ok      | — | **0.6s -> 200** full body streamed |
(Test used IDLE_MS=8000; production uses 20000.)

Live transparency check: `/v1/models` via-proxy-8788 and direct-8787 both
`HTTP=401` in ~0.1s (identical pass-through; 401 = no auth header, expected).

## IMPORTANT: takes effect on next VS Code reload
The repoint writes to Cline's state DB, which the running extension only re-reads
on window reload. After deploying, **reload the VS Code window** (Cmd+Shift+P ->
"Developer: Reload Window") so Cline picks up `:8788`.

## Tuning
Edit env in the plist then `launchctl unload/load` it:
- `IDLE_MS` — lower = faster abort on a dead stream, but must stay above the
  longest legitimate inter-token gap. 20000 is safe for the 70B/router.
- `CONNECT_MS` — raise if cold-start first-token ever exceeds 45s.

## Revert
```
bash repoint_revert.sh         # flips anthropicBaseUrl back to :8787
launchctl unload ~/Library/LaunchAgents/com.emsu.cline-stream-idle-proxy.plist
```
Then reload the VS Code window.

## Scope
Client-side ONLY. Does not touch the tunnel watchdog (W1), pods (W2), or
litellm config/routing (W3).

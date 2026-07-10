# 249 — MCP flapping / Cloudflare 502s / timeout errors: check supergateway --stateful FIRST, not the tunnel

## The bright-line diagnostic (run these two commands BEFORE touching Cloudflare, SSH tunnel, or Cline config)

When Cline shows any of:
- `MCP error -32001: Request timed out`
- Cloudflare `Error 502: Bad gateway (origin_bad_gateway)` on any `mcp-*.emsuniversity.com` zone
- `Streamable HTTP error: Error POSTing to endpoint`
- MCP tools intermittently working then failing

**Run this FIRST, before checking the tunnel or Cloudflare:**

```
emsu-operations ssh_command: systemctl show mcp-*.service -p NRestarts --no-pager -a
emsu-operations ssh_command: uptime
```

If any `mcp-*.service` shows a high `NRestarts` count (dozens to hundreds), or `uptime` shows a load average spike (e.g. jumping from ~10 to 50+ within seconds when checked repeatedly), you are looking at the **stateless-supergateway spawn-storm** bug, not a Cloudflare/tunnel/network problem. Do NOT start debugging Cloudflare config, DNS, or the SSH tunnel wrapper — those are downstream victims, not the cause.

## Root cause

All EMSU MCP services run via `supergateway --stdio "<command>" --port <N> --healthEndpoint /health --outputTransport streamableHttp`. Without the `--stateful` flag, supergateway spawns a **brand-new child process for every single JSON-RPC message** (not once per session — once per `initialize`, once per `tools/list`, once per `resources/list`, once per `prompts/list`, separately). Each spawn does a full cold-start + re-init handshake, then SIGTERMs. Under normal single-window load this is invisible. Under ~10-20+ concurrent Cline windows (each firing several tool calls), it becomes a CPU spawn-storm: 10+ simultaneous Node processes at 140-200% CPU, load average spiking from ~10 to 50-65 within 30 seconds.

That load spike is what causes:
1. **Cloudflare 502s** — cloudflared's origin (the MCP service) becomes too slow to respond within Cloudflare's timeout window
2. **SSH tunnel drops** — the tunnel's keepalive can miss under sustained high load, tearing down the whole port-forward
3. **Cline "Request timed out"** — the MCP call itself queues behind the spawn-storm

Three visible symptoms, one root cause. Fixing the tunnel or Cloudflare config does NOT fix this — you have to fix the spawn behavior.

## The exact journalctl fingerprint

```
sudo journalctl -u mcp-<name>.service -n 40 --no-pager
```

Look for this repeating pattern (once per tool call, not once per session):

```
[supergateway] StreamableHttp → Child: {"jsonrpc":"2.0","id":N,"method":"tools/list"}
[supergateway] Non-initialize message detected, sending auto-initialize request first
[supergateway] StreamableHttp → Child (auto-initialize): {...}
[supergateway] Child stderr: <server-name> running on stdio
[supergateway] Child → StreamableHttp: {...init response...}
[supergateway] Initialize response received
[supergateway] StreamableHttp → Child (initialized): {"jsonrpc":"2.0","method":"notifications/initialized"}
[supergateway] StreamableHttp → Child (original): {"jsonrpc":"2.0","id":N,"method":"tools/list"}
[supergateway] Child → StreamableHttp: {...actual response...}
[supergateway] Child exited: code=null, signal=SIGTERM
[supergateway] StreamableHttp connection closed
```

**"Non-initialize message detected, sending auto-initialize request first" appearing before EVERY call** is the signature. A healthy stateful service initializes ONCE per session and reuses the child for all subsequent calls in that session — you will NOT see repeated auto-initialize blocks.

## The fix

Add `--stateful --sessionTimeout 1800000` to the end of the `ExecStart` line for the affected service(s).

**CRITICAL — check for drop-in overrides first.** Many of these services define their real `ExecStart` via a drop-in at `/etc/systemd/system/mcp-<name>.service.d/exec-override.conf`, which WINS over the base `/etc/systemd/system/mcp-<name>.service` file. Editing the base file when a drop-in exists silently does nothing.

**Always check the EFFECTIVE ExecStart first:**
```
systemctl cat mcp-<name>.service
```
This prints both the base file and all drop-ins in override order — the LAST `ExecStart=` line wins.

**Apply the fix to whichever file actually defines the final ExecStart:**
```bash
# If a drop-in exists:
sudo sed -i 's|--outputTransport streamableHttp$|--outputTransport streamableHttp --stateful --sessionTimeout 1800000|' /etc/systemd/system/mcp-<name>.service.d/exec-override.conf

# If no drop-in (base file only):
sudo sed -i 's|--outputTransport streamableHttp$|--outputTransport streamableHttp --stateful --sessionTimeout 1800000|' /etc/systemd/system/mcp-<name>.service

sudo systemctl daemon-reload
sudo systemctl restart mcp-<name>.service
```

**Always back up first:**
```bash
sudo cp /etc/systemd/system/mcp-<name>.service.d/exec-override.conf /tmp/mcp-<name>.exec-override.conf.bak
# or
sudo cp /etc/systemd/system/mcp-<name>.service /tmp/mcp-<name>.service.bak
```

## Verification after the fix

1. `systemctl show mcp-<name>.service -p NRestarts` — should stay flat (not climbing) after restart
2. `uptime` — load average should settle within 1-3 minutes, not keep spiking
3. Real MCP call test — send `initialize`, capture the `mcp-session-id` response header, then send a follow-up call WITH that session header and confirm it succeeds without a fresh spawn in the journal
4. Test the ACTUAL path Cline uses (Cloudflare URL, e.g. `https://mcp-7841.emsuniversity.com/mcp`), not just localhost — a fix that only works on `127.0.0.1` but not through Cloudflare isn't verified

## What NOT to do

- **Do not drop Cloudflare "to fix this."** Cloudflare is correctly reporting an overloaded origin — it is not the bug. Removing Cloudflare removes a legitimate durability/availability layer (external access, DNS stability, ISP independence) without fixing the actual defect.
- **Do not just restart the SSH tunnel repeatedly.** The tunnel will keep dying again under the same load spike until the spawn-storm itself is fixed.
- **Do not assume a `pkill` + manual restart of the Node process is equivalent to a proper `systemctl restart`.** These services are managed by systemd with drop-in overrides, resource limits (`TasksMax=400`, `MemoryMax=2G` in `limits.conf`), and `KillMode=control-group`. Bypass that and you can leave orphaned processes or a service in a half-dead state.

## Cross-references

- Rule 144 — server paths need `ssh_command`, not local file writes (applies to editing `/etc/systemd/system/mcp-*.service` files)
- Rule 41 — post-deploy pivot table (this is the specific pivot for "MCP timeout/502" symptoms)
- `.pre-write-lint.sh` limits.conf history — `TasksMax=50` broke supergateway `fork()` on startup in a prior incident (v1 -> v2, 2026-04-17); the current `TasksMax=400` budget assumes supergateway forks a `/bin/sh` per stdio request, which is EXACTLY the behavior `--stateful` reduces. Worth revisiting whether `TasksMax` can be lowered again once `--stateful` is confirmed stable fleet-wide.

## Source incident

2026-07-02 23:00-23:25 PT — Ruben reported EMSU MCP showing offline with Cloudflare 502 + Cline timeout errors. Diagnosis initially went through the tunnel (healthy), found and fixed an unrelated real bug (unescaped apostrophe breaking `emsu-operations` TypeScript build), then found the actual cause: `ps aux --sort=-%cpu` showed 10 simultaneous `node .../google-drive/build/index.js` processes at 140-200% CPU during a live load spike (11 -> 65 in ~25 seconds). `journalctl -u mcp-context7.service` showed the spawn-per-message pattern; `systemctl show mcp-context7.service -p NRestarts` showed 295 restarts — the clearest fingerprint. Fixed by adding `--stateful --sessionTimeout 1800000` to all 11 MCP services. Load dropped to 6.47 within 3 minutes, all NRestarts reset to 0 on restart. Took ~40 minutes end-to-end because the diagnostic path went tunnel -> Cloudflare -> code bug -> load spike -> process list -> journal -> NRestarts, instead of jumping straight to `NRestarts` + `uptime` first. This rule exists so the next agent starts there.

## Last updated

2026-07-02 — initial. Source: Ruben directive "do a RCA on this... explain why the resolution here was not more obvious and make it more obvious for next time."

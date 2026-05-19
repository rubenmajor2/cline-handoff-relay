# 95 — When MCPs are "not working," make ≥1 reconnect attempt and report results

Permanent rule. Workspace-scoped. Source: 2026-05-18 — Ruben asked why
emsu-operations was showing "not loaded in this session" while the Cline
UI showed the server as connected. Root cause was a wedged SSH tunnel
forwarding the MCP ports (PID 4185, 10h+ uptime, TCP listener alive but
application-layer half-open). Ruben directive verbatim:

> *"Cline rule, when MCPs are 'not working,' need to make at least 1
> attempt to reconnect and repair them and report results."*

## The bright-line rule

**When I (Cline) observe that an MCP tool call is failing with any of these
signals, my next move is NOT to give up or work around it. It's to attempt
ONE reconnect/repair and report the result.**

Failure signals that trigger this rule:

- MCP tool call returns "not loaded in this session"
- MCP tool call returns "Request timed out" / `-32001`
- MCP tool call returns connection refused / ECONNREFUSED
- Ruben says "the MCP isn't working" / "MCP shows yellow" / "MCP keeps
  failing" / "MCPs aren't being called"
- MCP UI panel shows yellow indicator + "Retrying..."

## The required reconnect-and-report sequence

1. **Probe the underlying transport.** For streamableHttp MCPs running
   through SSH port-forward to WOPR, that means firing a real `initialize`
   call with a 3-5 second timeout:
   ```bash
   curl -sS --max-time 3 -X POST http://127.0.0.1:<port>/mcp \
     -H "Content-Type: application/json" \
     -H "Accept: application/json, text/event-stream" \
     -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"diag","version":"1"}}}' \
     -w "\nHTTP=%{http_code} time=%{time_total}\n"
   ```
   - HTTP 200 in <1s → MCP layer is fine; the issue is Cline-side caching.
     Tell Ruben to click the refresh icon next to the server OR
     Cmd+Shift+P → "Developer: Reload Window".
   - Timeout (>3s, exit code non-zero) → the SSH tunnel is half-open.
     Proceed to step 2.
   - HTTP 406 "must accept text/event-stream" → the probe IS reaching the
     server; the MCP works, just needs proper Accept header (see snippet
     above). Cline's connection is fine in this case.

2. **Force-recover the SSH tunnel.** Kill the wedged forwarder and kick
   the launchd job that maintains it:
   ```bash
   pkill -9 -f "ssh -N -p 2222.*<port>"
   launchctl kickstart -k gui/$(id -u)/com.emsu.mcp-tunnel
   sleep 4
   # re-probe
   ```

3. **Report the result.** In attempt_completion or in the wrap-up, state
   plainly: (a) the failure signature, (b) the diagnosis, (c) the action
   taken, (d) whether the probe succeeded after, (e) what Ruben needs to
   do next (usually: reload the Cline window so it picks up the fresh
   connection).

4. **If reconnect didn't recover it,** check whether the MCP server
   itself is up on WOPR:
   ```bash
   ssh wopr "lsof -nP -iTCP -sTCP:LISTEN | grep ':<port> '"
   ssh wopr "curl -sS --max-time 3 -X POST http://127.0.0.1:<port>/mcp ..."
   ```
   If WOPR-side is also down, that's a server-side restart task — escalate
   to RUBEN orchestrator per rule 81, don't keep banging the tunnel.

## What I MUST NOT do when an MCP shows broken

- ❌ Silently fall back to `ssh wopr "<command>"` or raw SQL because the
  dedicated MCP wrapper isn't responding (rule 32 still applies — the
  wrapper is the right tool, fix the wrapper)
- ❌ Tell Ruben "the MCP isn't loaded" without first running the probe
- ❌ Try to reproduce the failure in some other way (rule 64 — verify
  before iterating)
- ❌ Skip step 2 because "the tunnel was just restarted" — half-open
  state recurs; that's the whole point of this rule
- ❌ Give up after one reconnect attempt and silently work around. After
  one failed reconnect, report it + recommend Ruben reload OR escalate
  to WOPR-side check.

## Why this rule exists (the source incident)

2026-05-18 17:39 PT: Ruben opened a fresh Cline task to ask why his MCPs
were broken. Six MCPs showed yellow/timeout. Cline diagnosed it as a
single wedged SSH tunnel (PID 4185, all forwards on it stuck), killed it,
restarted via launchd, verified HTTP 200 in 223ms through the new tunnel.
Two MCPs (emsu-operations, ruben-orchestrator) stayed yellow in the UI
even after the tunnel was healthy — Cline caches dead connections and
the per-server retry backoff had grown long. The recovery required Ruben
to manually click the refresh icon.

The lesson: a wedged tunnel is the most common cause of "MCP broken"
reports, the reconnect takes ~5 seconds, and there's no excuse for
working around it instead of fixing it.

## Companion infrastructure (deployed same session)

- `/Users/rubenmajor/bin/mcp-tunnel-healthcheck.sh` — fires an MCP
  `initialize` against port 7841 every 5 min. If it times out, kills
  the wedged SSH forwarder and kicks `com.emsu.mcp-tunnel`. Re-probes
  to confirm. Log at `/tmp/cline-mcp-tunnel-health.log`.
- `~/Library/LaunchAgents/com.ruben.mcp-tunnel-healthcheck.plist` —
  loads the above on 5-min cadence. Companion to
  `com.ruben.cline-router-tunnel-healthcheck` (which probes 8787, the
  cline-router, not the MCP ports).
- This rule (.clinerules/95) — the behavioral layer on top.

So three layers now:
1. Healthcheck auto-recovers within 5 min of a wedged tunnel (silent).
2. If Ruben hits the broken state in the meantime, this rule mandates
   Cline reconnect + report.
3. UI cache means Ruben may still need to reload the window or click
   refresh on individual servers — and Cline should TELL him that
   explicitly, every time.

## When this rule does NOT apply

- A specific MCP TOOL fails with a legitimate error (e.g. SQL syntax,
  ticket not found, file doesn't exist) — that's not a transport
  failure, it's a logic failure. Address the logic.
- The MCP server is intentionally disabled or doesn't exist for this
  workspace (rare on Ruben's Mac, where all 13 MCPs ship by default).
- Cline is mid-task on something completely unrelated and the MCP isn't
  in the critical path. Note the failure in attempt_completion but don't
  derail.

## Self-check before any "MCP not available" claim

Before writing "MCP isn't loaded" / "MCP not responding" / "I can't
reach the MCP" in any output, ask:

1. *"Did I run the curl probe against the port?"*
2. *"If it timed out, did I run pkill + launchctl kickstart and re-probe?"*
3. *"If that recovered it, did I tell Ruben he needs to reload the Cline
   window (or click the refresh icon) so the UI picks up the fresh
   connection?"*

If any answer is no, I'm violating this rule — go back and run the
reconnect sequence before declaring the MCP broken.

## Cross-references

- Rule 20 — MCP host resolver required (different layer — SSH target
  routing inside the MCP, not the tunnel)
- Rule 32 — prefer dedicated MCP wrappers over raw SSH/SQL (this rule
  supports it — fix the wrapper, don't bypass it)
- Rule 64 — when user says "nothing changed", verify before iterating
  (same shape — verify the actual state)
- Rule 67 — agents exhaust autonomy before human escalation (a wedged
  tunnel is within Cline's autonomy to fix)
- Rule 73 — close the agent capability gap (the auto-healthcheck IS
  the gap closure)
- Rule 77 — cline-router overload recovery (sister rule for the
  cline-router tunnel on port 8787)
- Rule 81 — RUBEN silent on ops chat = Cline babysits (escalation
  path when reconnect doesn't recover)
- Rule 94 — train agents, don't fix FOR them (the auto-healthcheck
  satisfies this — the system fixes itself, Cline doesn't have to
  manually intervene every time)
- Rule 100 — pty-host saturation fingerprint (related diagnostic
  algorithm for "things look broken but tunnel is the cause")

## Last updated

2026-05-18 17:55 PT — initial rule per Ruben directive in the
emsu-operations MCP wedge incident.

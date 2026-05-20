# 77 — cline-router overload_error / "stuck Cline" recovery

Permanent rule. Workspace-scoped. Source incident: 2026-05-14 — Cline became
unresponsive in the normal cline-tempe / Cline-Artemis windows with
`overloaded_error` / HTTP 529 / `LLM Provider NOT provided` errors surfacing
through the cline-router proxy. Recovery required Ruben to open a **standard
VS Code window with the stock Copilot/Cline extension** (which does NOT route
through `127.0.0.1:8787`) to drive the diagnosis and apply the fix.

## What happened (the mechanism)

The local LiteLLM proxy at `~/Library/Application Support/cline-router/`
sits between every Cline turn and Anthropic. Cline → `127.0.0.1:8787` →
LiteLLM router → Anthropic (or fallback provider).

Three failure modes stacked at once on 2026-05-14:

1. **Anthropic 1M-tier overload.** Calls to `:1m` model aliases
   (`claude-opus-4-7:1m`, `claude-sonnet-4-6:1m`) were returning
   `overloaded_error` / HTTP 529 from upstream. LiteLLM had no retries
   configured, so the first 529 was the last 529 — error propagated straight
   to Cline UI.
2. **Router had no fallback chain.** When `:1m` failed, there was no
   "try base alias next" rule. LiteLLM emitted `Object of type Deployment
   is not JSON serializable` and `fallback call failed` lines in the log.
3. **Hook silent-fallback path was broken.** `emsu_classifier_hook.py`
   `async_post_call_success_hook` was passing model names like
   `emsu-qwen2.5-coder:7b-lora` straight to `litellm.acompletion()`
   without a provider prefix, producing `LLM Provider NOT provided. You
   passed model=...` errors. Same for `claude-*` aliases without
   `anthropic/` prefix.

Net effect on Cline windows running through the proxy: every tool call
returned an opaque overload error. The Cline UI had no recovery path
because the error was at the router layer, below the Cline retry budget.
Restarting the Cline window did not help — the next request hit the same
broken router. The watchdog stack (rule 97) saw a healthy ext-host (no
OOM, normal RSS) so nothing self-healed.

## Why a standard VS Code window unblocked Ruben

The stock VS Code (with Copilot or fresh Cline install routed straight
to api.anthropic.com) does NOT go through cline-router. It hits Anthropic
directly. The 1M-tier overload was real but transient on Anthropic's side,
and direct calls had their own retry logic, so the stock window stayed
usable while the proxy-routed windows were dead.

This is the durable escape hatch when the router itself is broken: a
non-routed window can edit the router files and restart the daemon,
which restores all the routed windows simultaneously.

## The fix (already shipped 2026-05-14 17:38, validated 17:55)

1. `litellm_settings`: `num_retries: 4`, `request_timeout: 600`.
2. New `router_settings:` block with `num_retries: 4`, `retry_after: 5`,
   `allowed_fails: 3`, `cooldown_time: 30`.
3. Five-rule `fallbacks:` chain in router_settings:
   - `claude-sonnet-4-6:1m` → `claude-sonnet-4-6`
   - `claude-opus-4-7:1m` → `claude-opus-4-7`
   - `claude-opus-4-6:1m` → `claude-opus-4-6`
   - `claude-sonnet-4-6` → `claude-sonnet-4-5`, then `claude-haiku-4-5`
   - `claude-opus-4-7` → `claude-opus-4-6`, then `claude-sonnet-4-6`
4. Hook `async_post_call_success_hook` rescue path: strips `:1m` / `:200k`
   suffixes, prepends `anthropic/` to `claude-*`, defaults
   LoRA/unknown aliases to `anthropic/claude-sonnet-4-6`, adds
   `num_retries=3` on the rescue `litellm.acompletion()`.

Files: `~/Library/Application Support/cline-router/config.yaml` and
`emsu_classifier_hook.py`. Daemon PID 97968 picked them up on the
17:38 launchctl kickstart. Full validation log:
`~/Library/Application Support/cline-router/VALIDATION-2026-05-14.md`.

## Detection algorithm (next time this fingerprint appears)

When Ruben says "Cline is stuck" / "all my Cline windows are dead" /
"overload error":

1. **Is it the Mac jetsam class (rule 29) or argv.json amplifier (rule 28)?**
   Check `vm_stat` + `sysctl vm.swapusage` first. If Mac swap > 70% and
   compressor > 25 GB → that's rule 29, not this rule.
2. **Is it pty-host saturation (rule 100)?** `ssh artemis "journalctl
   -u code-server@emsuserver --since '5 min ago' | grep -c
   RequestStore"`. Non-zero → rule 100.
3. **If host + Mac are clean, suspect the router.** Tail the live log:
   ```bash
   tail -200 ~/Library/Logs/cline-router.log | grep -E \
     'overloaded_error|529|fallback call failed|LLM Provider NOT provided'
   ```
   Any hits in the last few minutes → this rule's class.
4. **Open a stock VS Code window** (no cline-router routing) to drive
   the recovery. Do NOT try to fix the router from a Cline window that
   is itself routed through the broken router.

## The recovery procedure (from a stock VS Code window)

1. `tail ~/Library/Logs/cline-router.log` to see the specific failure.
2. Check daemon: `launchctl print gui/$(id -u)/com.emsu.cline-router |
   head -20`. Confirm it's loaded and the plist points at
   `~/Library/Application Support/cline-router/launch.sh`.
3. Apply the fix (or if already fixed, just restart):
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.emsu.cline-router
   ```
4. Wait ~5 seconds. Hit `http://127.0.0.1:8787/health/readiness` — should
   return `healthy`.
5. Reload any stuck Cline window (Cmd+Shift+P → Developer: Reload Window)
   so it reconnects to the now-healthy router.

## Long-term: keep the git-tracked copies in sync

The README at `~/Documents/Cline/cline-router/` says to keep both copies
in lockstep. As of 2026-05-14 17:55 the git-tracked copies are stale:

```bash
cp ~/Library/Application\ Support/cline-router/{config.yaml,emsu_classifier_hook.py} \
   ~/Documents/Cline/cline-router/
```

Otherwise the next redeploy from `~/Documents/` regresses the patches and
the same overload class returns.

## Cross-references

- Rule 28 — argv.json js-flags amplifier (Mac-side, different layer)
- Rule 29 — Mac jetsam cliff without amplifier (Mac-side)
- Rule 44 — Anthropic outage failover to OpenAI (manual escape hatch
  when Anthropic is genuinely down, not just transient-overload)
- Rule 50 — RAG-augmented prompts (uses the same router)
- Rule 97 — extension host OOM (different layer — host RAM, not router)
- Rule 100 — pty-host saturation (Artemis-side, different layer)
- `~/Library/Application Support/cline-router/VALIDATION-2026-05-14.md`

## Last updated

2026-05-14 — initial rule. Source incident: cline-router overload-error
storm requiring Ruben to fall back to a stock VS Code window for the fix.
Resolved 17:38, validated 17:55. Zero recurrences in the post-restart log
slice. Three live `:1m` test requests succeeded with normal latency.

## 2026-05-18 addendum — Mac-side SSH tunnel for the router

Source incident: `:1m` overloaded_error storm on new Cline windows, 2026-05-18 15:00 PT.
Mac VS Code Cline windows had `anthropicBaseUrl: http://127.0.0.1:8787` stored
in apiConfiguration but no router was running on Mac. Requests connection-refused,
fell back to direct api.anthropic.com, hit Anthropic's `:1m` (1M-context) tier
which is over-subscribed and capacity-limited separately from regular Opus.

### Per-host requirement

**Any client box (Mac, secondary developer machines) that has
`anthropicBaseUrl: http://127.0.0.1:8787` in its Cline apiConfiguration MUST
also have an SSH tunnel forwarding that port to Artemis where the actual
cline-router runs.** Without the tunnel, the request connection-refuses locally,
Cline falls back to direct Anthropic, and the router's fallback chain (which
catches `:1m → base` overload rewrites) never gets a chance to fire.

### Canonical tunnel via launchd (Mac)

Lives at `~/Library/LaunchAgents/com.ruben.cline-router-tunnel.plist`. Runs
`ssh -N -L 127.0.0.1:8787:127.0.0.1:8787 artemis` with KeepAlive=true,
RunAtLoad=true, ServerAliveInterval=30, ExitOnForwardFailure=yes. Log at
`/tmp/cline-router-tunnel.log`.

Load: `launchctl load ~/Library/LaunchAgents/com.ruben.cline-router-tunnel.plist`
Verify: `curl -sS http://127.0.0.1:8787/health/readiness` returns
`{"status":"healthy"...}`.

KeepAlive auto-restarts on connection drop. RunAtLoad fires at Mac boot.
ServerAliveInterval=30 keeps the SSH session warm through NAT/idle timeouts.
ExitOnForwardFailure=yes refuses to silently fall back to a non-forwarded ssh.

### Health-monitor cron (belt-and-suspenders)

`~/Library/LaunchAgents/com.ruben.cline-router-tunnel-healthcheck.plist`:
fires every 5 minutes, curls 127.0.0.1:8787/health/readiness, if it fails
kicks the tunnel via `launchctl kickstart -k gui/$UID/com.ruben.cline-router-tunnel`.
Log at `/tmp/cline-router-tunnel-health.log`. Different layer than KeepAlive
(catches local listener failure, not just dropped SSH).

### Detection algorithm — extend Step 4 of original rule 77

Step 4 (router-not-up class) now has two sub-cases:

4a. **Router not running on Artemis** — `ssh artemis "systemctl is-active mcp-cline-router"`. If inactive, restart it.

4b. **Router running on Artemis but tunnel down on the client box** — from the
client (Mac), `curl -sS --max-time 3 http://127.0.0.1:8787/health/readiness`
returns connection-refused or hangs, but `ssh artemis "curl -sS --max-time 3
http://127.0.0.1:8787/health/readiness"` works fine. Tunnel needs to be
reloaded: `launchctl unload ...; launchctl load ...` OR the healthcheck cron
will catch it within 5 min.

### Why `:1m` overloads separately from base

The `:1m` suffix selects Anthropic's 1-million-context Opus tier. Internally
it's a different deployment with smaller capacity than regular 200k Opus —
Anthropic provisions 1M-context separately because each request consumes much
more compute. When organic traffic spikes (especially during business hours
US time), `:1m` saturates while base Opus has plenty of headroom. This is why
Anthropic's status page shows "All Systems Operational" but `:1m` calls return
overloaded — the status page tracks the aggregate, not the premium tier
specifically.

The fallback `:1m → base` is the right behavior because the conversation
context is server-side on the conversation history, not on Anthropic's side.
You don't lose context for one retry call, you just temporarily downgrade
to 200k window for the next response.

## Last updated

2026-05-18 — added Mac-side SSH tunnel section, healthcheck cron, and `:1m`
capacity explanation. Source incident: new Cline windows on Mac getting
overloaded_error because anthropicBaseUrl pointed at a nonexistent local proxy.
Tunnel deployed via launchd, fallback chain re-shipped on Artemis router,
`:1m` workflows now seamlessly fall back to base Opus on overload.

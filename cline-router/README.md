# Cline-Router Proxy (EMSU Phase 5)

Local Anthropic-compatible router proxy that intercepts Cline's `/v1/messages`
calls and dispatches by task signature: routine → Ollama (free), hard →
Anthropic (Sonnet/Opus). Cline cannot tell the difference. Reversal is one
VS Code settings flip.

## Files

- `config.yaml` — LiteLLM Proxy config: Anthropic + Ollama model list, classifier hook wiring
- `emsu_classifier_hook.py` — Custom `CustomLogger` subclass with R1-R9 fail-safe
- `audit_db.py` — SQLite audit log at `~/.cline-router/audit.sqlite`
- `com.emsu.cline-router.plist` — launchd unit, KeepAlive=true
- `tests/` — unit tests for classifier + R1-R9 + tool-use translation
- `backtest_runner.py` — Phase F backtest against last 30d of Cline tasks
- `start.sh` / `stop.sh` — convenience scripts

## Quick start (development)

```bash
# 1) Install if not already done
uv tool install --python /opt/homebrew/bin/python3.12 'litellm[proxy]==1.83.14' \
    --with 'prisma==0.15.0' --with 'pyyaml>=6.0.2'

# 2) Set env
export ANTHROPIC_API_KEY="..."   # from your existing Cline VS Code setting
export OLLAMA_BASE_URL="http://10.100.0.5:11434"

# 3) Smoke test (dev mode, foreground)
~/.local/bin/litellm --config ~/Documents/Cline/cline-router/config.yaml --port 8787

# 4) Health check
curl http://localhost:8787/health

# 5) Run service via launchd (production)
cp com.emsu.cline-router.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.emsu.cline-router.plist
launchctl list | grep cline-router
```

## Cutover (Phase 5C only — DO NOT run during Phase 5A/5B shadow)

In Cline VS Code settings, change "Anthropic API Endpoint":

- From: `https://api.anthropic.com`
- To:   `http://localhost:8787`

## Reversal (any time, < 60s)

Flip the endpoint back, OR:

```bash
launchctl unload ~/Library/LaunchAgents/com.emsu.cline-router.plist
```

## Status / monitoring

```bash
# Daily rollup
sqlite3 ~/.cline-router/audit.sqlite "SELECT * FROM v_daily_rollup LIMIT 7;"

# Real-time tail
tail -f /tmp/cline-router.log

# Per-rule fallback counts last 24h
sqlite3 ~/.cline-router/audit.sqlite "SELECT fail_reason, COUNT(*) FROM turns WHERE ts > strftime('%s','now','-24 hours') AND fail_reason IS NOT NULL GROUP BY 1 ORDER BY 2 DESC;"
```

## Phase status

| Phase | Status |
|---|---|
| A: Install + config | shipped 2026-05-10 |
| B: Classifier (Design C hybrid) | stub shipped, needs heuristic refinement |
| C: R1-R9 fail-safe | stubs shipped, unit tests pending |
| D: Audit DB | schema deployed |
| E: 7-day shadow | NOT started — requires Cline still pointing at api.anthropic.com |
| F: Backtest against 30d of tasks | runner stub shipped, run pending |
| G: Live surface-choice | NOT started — gates on E + F |
| H: Full routing | NOT started — gates on G + 92% accuracy + 5% fallback |
| I: Memory MCP entity | shipped 2026-05-10 |
| J: Q-cards 1-3 | shipped 2026-05-10 |

## Cross-references

- Spec: `/Users/rubenmajor/Desktop/staging/phase5_cline_router_spec.md`
- Parent: `#opus-train-ollama-replace-sonnet-2026-05-10`
- Sister rules: `.clinerules/40-default-to-artemis-ollama-first.md`

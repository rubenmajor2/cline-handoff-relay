# 280 — No routing/LLM state claim without a live probe quoted in the same message. No raw litellm restarts.

Permanent rule. Workspace-scoped. Source: 2026-07-20 Ruben directive — "my biggest concern in the last 48 hours has been stale information fucking up everything having to do with routing / frankenstein-llm... changing routes and saying something down that's not, saying something up that isn't, is pretty fucking irritating. There needs to be some kind of validation agents actually obey."

## The bright-line rule (two gates)

**GATE 1 — Pre-claim probe.** Before writing ANY of these claims into a message, pickup prompt, HANDOFF, ticket, config edit, or ledger row:
- "X is down" / "X is up" / "X is serving" / "X is wedged"
- "route Y points at Z" / "lane N is stale/dead"
- "frankenstein-llm is broken/fixed"

...you MUST run a live probe THIS SESSION and quote its output inline as `(verified: <probe result>)`. Valid probes:
- `frankenstein_verify_routing(model_id)` — rule-140 header probe (backend + cost)
- `curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 <api_base>` via ssh_command
- `frankenstein_host_probe` / `frankenstein_tier_health` (note staleness field)
- A tiny real generation (`max_tokens:5`) through LiteLLM :4000

NOT valid as sole evidence: registry yaml text, config.yaml contents, a prior session's pickup prompt, fleet_inventory heartbeat, error_watchdog, another agent's claim, tier-health caches without a fresh timestamp. Those are HYPOTHESES (rule 140); the probe is the truth.

**Three-state readout is mandatory.** A probe distinguishes:
1. **UP** — HTTP answers (200/4xx = process alive)
2. **DOWN-REFUSED** — TCP refused/timeout = fail-fast, safe for LiteLLM fallbacks
3. **HANGING** — TCP accepts but HTTP never answers = the bug-#1876 boot-wedge class; MOST dangerous state, never conflate with UP or DOWN

## GATE 2 — No raw litellm restarts

`systemctl restart litellm` directly is BANNED (same class as raw ssh, rule 32). The only sanctioned path:

```
sudo /usr/local/bin/litellm-safe-restart.sh
```

It probes every unique api_base in config.yaml first, ABORTS if any target is in the HANGING state (would wedge LiteLLM boot forever, bug #1876), warns on dead-refused (safe), then restarts and waits for liveliness 200. If it refuses, stop the hanging forward (`systemctl stop <forward>.service`) and re-run.

## Config edits need probe evidence too

Editing /etc/litellm/config.yaml lanes (add/drop/repoint) requires a probe result for EACH endpoint touched, quoted in the ledger/HANDOFF entry. The 2026-07-14→07-20 incident: 7 stale lanes + julia-120b mispointed sat in config for 6 days because edits and claims were made from registry text, not live probes.

## Self-check before shipping any message

Scan your outgoing text for "down", "up", "serving", "dead", "wedged", "points at", "stale". For each hit: is there a `(verified: ...)` within the same bullet quoting a probe run THIS session? If no → run the probe now or delete the claim.

## Cross-references

- Rule 140 — header probe is ground truth; configs are hypotheses
- Rule 248 — verify live state before declaring box/endpoint down
- Rule 252 — stale-info live-probe gate (host-level sibling; this rule is the route/claim-level version)
- Rule 255 / 271 — verify-then-report + no infra claims without session evidence (this rule extends them to routing specifically)
- Bug library #1876 (litellm boot wedge on hanging socat), #1877 (rogue WOPR ollama), idea #18509 (validator MCP tool + drift cron)

## Source incident

2026-07-20 — 6-day stale-route drift in config.yaml (7 dead lanes, julia mispointed) + repeated false down/up declarations by fresh windows over the prior 48h. Ruben demanded obeyable validation.

## Last updated

2026-07-20 — initial.

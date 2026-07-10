# 143 — Fix the free LLMs first. Debug + fleet + RunPod before ANY paid fallback.

Permanent rule. Workspace-scoped. Source: 2026-06-06 Ruben directive verbatim:

> "Do everything you can to make our Free LLMs work properly, debug, troubleshoot them and find/associated issues prior to suggesting a fallback. Do not automatically make a fallback."
> "RUBEN/Kaizen needs to attempt to resolve the underlying issues before suggesting a fallback and even then, we can use our other Fleet machines that have the same LLMs ... developing a RunPod backup if needed."

## The bright-line rule

When a free local LLM (Frankenstein 70B, 7B-LoRA, 14B/32B, any ollama model on the fleet) appears broken, slow, or unreachable, the FIRST job is to **find and fix the underlying cause on the free stack.** Routing to a paid Claude/OpenRouter fallback, lowering a timeout so it "fails fast to Claude," or disabling the local route are all LAST resorts, and only after the free options are genuinely exhausted.

A fallback to a paid model is never the fix. It is the symptom-hider. Per rule 92 (work at the core): fix the 70B, don't paper over it.

## Escalation order when a free LLM looks broken (do IN THIS ORDER)

1. **Debug the actual backend.** Is the model loaded (`/api/ps`)? Does `/api/chat` work stream AND non-stream? Is it just a cold VRAM load (first call slow, subsequent fast)? Is the tunnel passing POST bodies (cloudflare can pass GET/`/api/tags` while a stale config points at a dead `:11455` ssh tunnel)? Distinguish "model broken" from "one path/endpoint misconfigured."
2. **Check the keep-warm + route-watchdog crons.** `sms-mac-70b-keepwarm`, `fleet-ollama-keepwarm`, `emsu-70b-route-watchdog`. A keepwarm that pings a dead endpoint silently fails and lets the model go cold — that is a fixable root cause, not a reason to fall back. (This was the literal 2026-06-06 incident: keepwarm pinged dead `127.0.0.1:11455` while the live model was on the cloudflare tunnel `sms-70b.emsuniversity.com`.)
3. **Fail over to a FLEET PEER serving the same model before any paid model.** Other fleet machines (WOPR-local ollama, SMS Mac, Artemis, Joshua) host the same llama3.3/qwen/LoRA models. A 70B outage on one host should route to a 70B on another host — still free — before Claude. Use `fleet_inventory` / `fleet_now` to find a healthy peer.
4. **RunPod vLLM backup.** A spun-up RunPod A6000 vLLM pod serving the same 70B (per .clinerules/140) is the next tier — still our infra, not a per-token Claude bill.
5. **Paid Claude fallback (haiku→sonnet→opus) is the ABSOLUTE last resort,** only when every free + fleet + RunPod option is down, and it must be flagged as a degraded state to fix, not the resting state.

## What NOT to do (anti-patterns from the source incident)

- ❌ "Lower request_timeout so the hung 70B fails fast into the Claude fallback chain." That makes paid Claude the default for a backend that just needed warming/repointing. Fix the backend.
- ❌ Repoint a Cline/agent alias from the free 70B to a Claude model "to stop the hang." Find why it hangs.
- ❌ Treat a `/api/tags`-200-but-`/api/chat`-hangs result as "70B broken." Test the path the consumer actually uses; it's usually a config/endpoint/cold-load issue.
- ❌ Leave a silently-failing keepwarm cron in place. A keepwarm pinging a dead endpoint is the root cause of "it was supposed to stay warm."

## RUBEN / Kaizen obligation

RUBEN's self-heal and the Kaizen failure-repair loop must encode this same order: on a local-LLM failure category, attempt (1) backend debug/repair, (2) keepwarm/watchdog repair, (3) fleet-peer failover, (4) RunPod backup — and only then (5) paid fallback, flagged as degraded. A Kaizen recipe whose `retry_strategy` is "route to claude" for a local-LLM failure is wrong by this rule; the recipe must try the free-stack repairs first.

## Self-check before proposing any fallback

Ask: "Have I actually debugged the free backend (loaded? which path fails? cold-load? tunnel? keepwarm?), and have I checked whether a fleet peer or RunPod can serve the same model for free?" If no to either, I have not earned the right to suggest a paid fallback yet.

## Cross-references

- .clinerules/92 — work at the core, not bandaids (a fallback is the bandaid)
- .clinerules/140 — frank LoRA serving architecture (RunPod vLLM backup)
- .clinerules/29 — act on confidence (debugging the backend IS the action)
- fleet_inventory / fleet_now / fleet_routing_map MCP tools — find healthy peers

## Source incident

2026-06-06 — Frankenstein 70B (`frankenstein-llm` / `emsu-cline-router`) appeared down: subagents hit Sonnet and hung. Real causes, all fixable on the free stack: (1) Cline aliases pointed at a dead RunPod pod (404) with only claude-sonnet as fallback; (2) repointed to live cloudflare sms-70b but openai `/v1` path was cloudflare-403-blocked from the container — native `ollama_chat` path worked; (3) the `sms-mac-70b-keepwarm` cron was pinging the dead `127.0.0.1:11455` ssh tunnel, so it never warmed the live model — that was why "it was supposed to stay warm" but wasn't. The 70B itself was healthy the entire time (`/api/chat` 0.6s warm). The wrong move (which Ruben caught) was lowering request_timeout to fail fast into Claude. The right move was repoint + fix the keepwarm endpoint.

## Last updated

2026-06-06 — initial. Source: Ruben directive during the Frankenstein 70B routing incident.

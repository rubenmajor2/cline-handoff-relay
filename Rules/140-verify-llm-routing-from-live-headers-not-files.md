# 140 — Never state how LLM routing works from file-reads. Prove it with a live call + response headers.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-07 — Ruben asked "why aren't RunPods spinning to make my Cline faster / how does Frankenstein LLM work." Cline answered THREE times from subagent file-reads + config greps and was wrong each time (claimed Cline was "100% Anthropic passthrough," then "pinned to claude-sonnet," then recommended a config flip that was already in place). The truth required ONE live call with `-D -` headers: Cline's `frankenstein-llm` model resolved live to `openrouter/deepseek-v4-pro` (header `x-litellm-model-api-base: https://openrouter.ai/api/v1`), NOT Claude and NOT the local 70B. Ruben: "establish a client role for this so agents don't give out incorrect information."

## The bright-line rule

**Any claim about what model/infra a request actually runs on MUST be proven by a live request whose RESPONSE HEADERS or audit row name the resolved backend. Config files, router_hook.py source, fallback blocks, and subagent file-reads are HYPOTHESES, not answers.** A routing layer (LiteLLM) with tier logic, fallbacks, kill-switches, steering injection, and frugal early-exit means the served backend is frequently NOT the one the config "looks like" it picks. The only ground truth is what came back.

### The canonical proof (LiteLLM / EMSU)

```
MK="sk-emsu-..."   # LITELLM_MASTER_KEY from `docker inspect litellm` env
curl -s -D - -o /dev/null --max-time 50 http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" -H "Authorization: Bearer $MK" \
  -d '{"model":"<the model id the client actually sends>","messages":[{"role":"user","content":"hi"}],"max_tokens":5}' \
  | grep -i -E "HTTP/|x-litellm-model-api-base|x-litellm-model-id|x-litellm-response-cost"
```

`x-litellm-model-api-base` is the smoking gun — it names the REAL upstream (openrouter.ai vs sms-70b.emsuniversity.com vs api.anthropic.com vs a runpod proxy). `x-litellm-response-cost` > 0 means paid; `= 0` (or ollama/local) means free. That one header pair settles every "is this Claude or our model" question.

## The client-role discipline (what to verify, in order)

When asked "how does <X> route / what is serving <surface>", establish these IN ORDER and cite each with evidence, never assume:

1. **What does the CLIENT actually send?** Get the real model id + base URL from the client config (Cline Settings screenshot, the VS Code API binding, the cron's curl, the agent's tool registry). Do NOT guess the surface name. (2026-06-07: Cline was on `LiteLLM` provider, base `http://127.0.0.1:11505`, model `frankenstein-llm` — an SSH tunnel `127.0.0.1:11505 -> wopr:4000`, the OpenAI path. Cline had assumed the Anthropic passthrough. Wrong because never checked the client.)
2. **Where does that base URL terminate?** `lsof -nP -iTCP:<port> -sTCP:LISTEN` + `ps` to resolve tunnels. A localhost port is often an SSH `-L` forward to WOPR:4000.
3. **What does the model id resolve to LIVE?** The header curl above. This is the step that cannot be skipped or substituted with a file-read.
4. **What is the cost reality?** `llm_call_log` grouped by `provider`/`model`/`ts` (NOT a guess from config). Confirm the trend day-over-day per rule 29 Q#7.
5. **Only THEN** describe the architecture, anchored to the evidence from 1-4.

## Forbidden moves (each produced a wrong answer on 2026-06-07)

- ❌ Stating routing behavior from `router_hook.py` source without a live call. The hook has tiers, fallbacks, kill-switches, steering, and frugal early-exit; reading it tells you what COULD happen, not what DID.
- ❌ Trusting a subagent's reconstruction when the subagent itself said "MCP tools not available, reconstructed from Desktop files." A reconstruction is a hypothesis. Verify the load-bearing claims live before repeating them to Ruben.
- ❌ Recommending a config change ("flip Cline to emsu-cline-router") without first confirming the client's CURRENT binding — it may already be set, or set to something else entirely.
- ❌ Reading a `model_name` block's `api_base` and asserting that's where traffic goes, when a `fallbacks:` block reroutes it on timeout (e.g. `frankenstein-llm -> emsu-executor-auto -> ollama-llama3.3-70b`, and `frank-serve-pod` pointing at a dead pod just makes it fall through to DeepSeek). The fallback that FIRED is in the response header, not the primary block.

## Self-check before any statement about what's serving a request

1. *Do I have a response header / audit row naming the resolved backend?* If no → I have a hypothesis, not an answer. Run the header curl before I speak.
2. *Did I confirm what the client actually sends, or did I assume the surface?* If assumed → check the client config first.
3. *Am I about to tell Ruben "X is on Claude / X is free / flip to Y" without evidence from steps 1-4?* → Stop. Get the evidence.

## Cross-references

- Rule 29 Q#5 (verification = re-run the failing case end-to-end, not grep your own patch) and Q#7 (trend not snapshot)
- Rule 00 (subagents map the problem — but their file-reads are hypotheses; load-bearing claims get live-verified before reporting)
- Rule 92 (fix at the core — the durable fix for "agents give wrong routing info" is this verification discipline, not a one-off correction)
- Rule 135 (SLS naming — same lesson: a name/config is only true where a read-at-runtime surface proves it)
- fleet-state MCP `fleet_routing_map` (deduped per-surface routing facts — a good FIRST hypothesis, still confirm load-bearing claims with a live header curl)

## Source incident

2026-06-07 — "why aren't RunPods spinning / how does Frankenstein LLM work." Three wrong answers from file-reads. Ground truth from one `curl -D -`: Cline's `frankenstein-llm` → `x-litellm-model-api-base: https://openrouter.ai/api/v1` = DeepSeek-V4-Pro (the free local 70B serve pod `f01p0t1df9201h` was minted but not yet warm, so the fallback chain served DeepSeek). Ruben: "establish a client role for this so agents don't give incorrect information."

## Last updated

2026-06-07 — initial.

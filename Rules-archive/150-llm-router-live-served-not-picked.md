# 147 — Reading llm_router_live.php: it shows the PICKED model, not the SERVED backend. Verify served via header (rule 140).

Source: 2026-06-12 Ruben directive during the W5 frankenstein babysitter session. Ruben pointed at https://emsuniversity.com/emtskills/routes/llm_router_live.php showing "cesar-120b working" while Cline claimed Cesar was down. Both were partly right — and the reconciliation is this rule.

## The bright-line rule

**`llm_router_live.php` displays the model the router PICKED (`picked=X` from `/tmp/emsu_router_audit.log` + `llm_call_log`). It does NOT prove that model's BACKEND actually served the request.** LiteLLM can pick `cesar-120b`, find its endpoint dead, and silently serve the request from a fallback (`cato-120b`) — the page still shows `cesar-120b` as "working" because a request labelled cesar-120b returned 200.

So a model can read as "working" on the page while its actual box/tunnel is dead. To know what truly served a request, **check the `x-litellm-model-api-base` response header** (rule 140) — that names the real upstream host:port that produced the bytes.

## Why this matters (the W5 reconciliation)

- Ruben: "Cesar is working, I see it on the page." → TRUE: the page shows cesar-120b picks returning 200.
- Cline: "Cesar :11506 is HTTP 000 / dead." → ALSO TRUE: the WOPR-side reverse tunnel to the Cesar box is dead.
- Reconciliation: LiteLLM picks cesar-120b, the :11506 tunnel is down, so it falls back to Cato :11507 and serves there. The header on a `cesar-120b` call proves it: `x-litellm-model-api-base: http://127.0.0.1:11507/v1` (Cato), not :11506 (Cesar). The page's "cesar working" = a cesar-LABELLED pick served by Cato.

## How to actually verify (the 2-step)

1. **Picked** (what the router chose): the page, or `grep '"picked": "X"' /tmp/emsu_router_audit.log`.
2. **Served** (what actually answered): a live call with the header probe —
   ```
   MK=$(cat /etc/litellm/web-master-key | cut -d= -f2)
   curl -s -D - -o /dev/null --max-time 20 http://localhost:4000/v1/chat/completions \
     -H "Authorization: Bearer $MK" -H "Content-Type: application/json" \
     -d '{"model":"cesar-120b","messages":[{"role":"user","content":"hi"}],"max_tokens":5}' \
     | grep -i x-litellm-model-api-base
   ```
   If the returned api-base host:port != the model's OWN configured api_base, LiteLLM fell back — the labelled box is NOT actually serving.

## Composes with

- **Rule 140** — verify LLM routing from live headers, not files. This rule is the page-specific corollary: the dashboard is a convenience view of PICKS, the header is the SERVED ground truth.
- **Rule 141** — call the project-frankenstein MCP first for architecture truth.
- **Rule 146** — frankenstein-llm routes the whole fleet; one dead box never stops it (it serves the pick from a healthy fallback, which is exactly why the page can show a dead box as "working").

## The self-heal corollary (W5, durable fix)

The same picked-vs-served confusion bit the self-heal daemon `emsu-frank-member-rotation.py`: its pre-drop confirm asked LiteLLM to serve `cesar-120b` and accepted any answer with model id `gpt-oss-120b` as "Cesar is up" — but Cesar AND Cato both answer `gpt-oss-120b`, so a Cato-served fallback looked like Cesar being healthy. Fixed 2026-06-12 to compare the `x-litellm-model-api-base` header to the member's OWN api_base (this rule, applied in code). Lesson: any health/routing check must key on the SERVED backend (host:port), never the model id or the picked label.

## Last updated

2026-06-12 — initial. Source: Ruben asked Cline to consult llm_router_live.php and (correctly) doubted the "Cesar down" claim; the truth is the page shows picks, the header shows served.

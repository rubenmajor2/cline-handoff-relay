# 147 — Reconfigure LiteLLM via the admin API (/model/new, /model/delete), NOT config-rewrite + container restart

Source incident: 2026-06-15. Ruben directive after Cline traced the executor failure storm to LiteLLM restart churn. "Seems to me like he would have to make this a cline rule, otherwise you would forget."

## The bright-line rule

**To add or remove a model from LiteLLM's live rotation, use the LiteLLM admin API endpoints (`POST /model/new`, `POST /model/delete`, `GET /model/info`) — NEVER rewrite `/etc/litellm/config.yaml` (or `router_hook.py` registry) and bounce the container.** A full restart blinds every client of the gateway (the executor planner, all 5 CS agents, Cline itself) for ~10 seconds. Doing that on every member-rotation/pod-warm/tunnel-recover event = 5+ restarts/hour = a continuous outage carpet.

## Why this rule exists (the mechanism it prevents)

The fleet autoscaler used to reconfigure LiteLLM by rewriting config + calling `emsu-safe-litellm-restart.sh` on every model add/remove ("window-o member rotation", "artemis-arc tunnel back online"). Each ~10s restart returned `http=0` / empty body to in-flight callers.

For the RUBEN executor specifically this was catastrophic and INVISIBLE: the empty HTTP response produced an empty plan, which got mislabeled `failure_category=plan_shape_invalid` (a planner-QUALITY category) whose recipe BLOCKS the chain after 3 strikes. Result: ~88% executor failure rate, 2004 approved ideas never chained, 1001 chains blocked — all from infra churn wearing a "bad planner" mask. The restart was the round hole; the live reconfigure is the right shape.

## The correct pattern

LiteLLM (proxy server) exposes admin routes (auth: `Authorization: Bearer $LITELLM_MASTER_KEY`):

- **Add a model live:** `POST http://10.100.0.1:4000/model/new` with the model_name + litellm_params (api_base, model, etc.). No restart.
- **Remove a model live:** `POST http://10.100.0.1:4000/model/delete` with the model `id`. No restart.
- **List/verify:** `GET /model/info` or `GET /v1/models`.

The autoscaler / `cron_fleet_router_hook_writer.php` / any warm-set manager should diff desired-vs-live rotation and apply the delta via these endpoints. A container restart is reserved ONLY for changes the admin API genuinely cannot do live (e.g. a LiteLLM version bump, a `router_settings` structural change, an env/secret change).

## IMPORTANT NUANCE (2026-06-15): fallback-chain rotation CANNOT use the admin API

The admin API (`/model/new`, `/model/delete`) only manages the **model_list** (which models exist). It does NOT hot-reload `router_settings` **fallback chains**. The EMSU autoscaler that drives most of the restart churn (`/usr/local/bin/emsu-frank-member-rotation.py`, "window-o member rotation") rotates *fallback-chain membership* by commenting/uncommenting chain lines in config.yaml — so it genuinely needs a restart to apply, and the admin API is the WRONG square peg there.

For THAT class, the right lever is **reducing restart frequency via anti-flap hysteresis**, not the admin API:
- The churn is almost always the SAME oscillating ollama 70B boxes (joshua, 7b-lora, llama3.3-70b-q5) transiently failing a probe under load, getting dropped, then readded minutes later.
- `emsu-frank-member-rotation.py` has FLAP_MAX (readds-in-window before it HOLDS a member active instead of toggling) + FLAP_WINDOW_S. Tightening these (e.g. FLAP_MAX 2→1, FLAP_WINDOW_S 3600→7200) makes an oscillating-but-healthy box get held active instead of ping-ponging restarts. That + the executor http=0 retryable fix (idea #12503) is what actually kills the storm.

So the rule is: **admin API for model_list add/remove; anti-flap hysteresis for fallback-chain rotation; restart only when neither applies.**

## When a restart IS still allowed


- LiteLLM binary/image upgrade.
- `general_settings` / `router_settings` / auth-key changes the admin API doesn't cover.
- Recovery from a wedged container (health check failing).

In those cases, still go through `emsu-safe-litellm-restart.sh` (rule 118: cooldown + preflight smoketests + audit log). The point of THIS rule is: routine model-in/model-out is NOT one of those cases.

## The companion executor-resilience requirement (defense in depth)

Even with admin-API reconfigure, clients must treat a gateway blip as transient, not as a content failure. Specifically: **an empty HTTP body / `http=0` / tokens=NULL from the LiteLLM gateway is a TRANSPORT error (retryable), never a model-quality failure.** The RUBEN executor must classify it as such (retry next tick) instead of `plan_shape_invalid` (which blocks the chain). See idea #12503. This rule (don't restart) + that fix (survive restarts) together kill the failure class.

## Self-check before any LiteLLM reconfigure

1. *Am I about to edit config.yaml/router_hook registry + restart just to add/remove a model?* → STOP. Use `/model/new` or `/model/delete`.
2. *Is this a routine member rotation / pod warm / tunnel flap?* → Live admin API, never restart. Debounce flapping tunnels so they don't trigger reconfigure storms at all.
3. *Is this genuinely a version/structural/auth change?* → Then a restart is OK, via the safe wrapper (rule 118).

## Cross-references

- Rule 118 — never restart litellm with raw systemctl; use the safe wrapper (when a restart IS warranted)
- Rule 142 — no dead-end LLM entrypoints (fallbacks so a single backend blip doesn't stall)
- Rule 146 — frankenstein-llm routes the whole fleet; machines flap, route by health (don't restart on flap)
- Rule 92 — fix at the core (the admin API IS the core; restart-to-reconfigure is the bandaid)
- idea #12503 — executor must treat http=0/empty-body as retryable transport, not plan_shape_invalid

## Last updated

2026-06-15 — initial. Source: Ruben directive after the LiteLLM-restart-churn → executor-starvation diagnosis. "Make this a cline rule otherwise you would forget."

# 115 — LLM routing + training pod lessons (4 hard lessons from 2026-05-25 LiteLLM ship)

Permanent rule. Workspace-scoped. Source incident: cline_mlx_lora_llm_lane_20260525_0200
(LiteLLM gateway #6842 ship session). 4 lessons fed into orchestrator_learned_patterns
+ failure_repair_recipes so Fleet Agent, KAIZEN, Babysitter, and any LLM-touching cron
inherit them.

## Lesson 1 — RunPod pods without network volume = your training WILL be lost

**What happened:** Two pods (5n7gdhbda0fq64, j93d4k8gdp6o2d) running emsu-llama3.3-70b-email-sms-lora-v1
training. Both terminated. RunPod API returns `pod: null` and `networkVolumes: []`. 
Total loss: ~$300-500 in H200 compute + 14h of training + 16.5% progress to step 1419/8574.
No checkpoint to resume from. Restart from scratch.

**Rule:** Any RunPod >$50 budget MUST be minted with `networkVolume` attached at `/workspace`
sized 2x final-adapter-bytes, AND `training_run.sh` MUST save adapter checkpoints to that
volume every N steps, AND the cron MUST rsync the final adapter back to Joshua at
`/var/lib/emsu/lora_checkpoints/` before pod end.

**Detection pattern:** `runpod_no_volume_terminated` recipe in `failure_repair_recipes`.

**Cross-refs:** idea #6981 (auto-restart watchdog), idea #6716 (training-progress watchdog
broken — `checked=0`), idea #6800 (cleanup of broken #6716).

## Lesson 2 — Router classification on TOTAL conversation, not LAST USER MESSAGE = always Sonnet

**What happened:** Initial router_hook.py used `total_chars > 16K → claude-sonnet` to gate
the tier. Cline sends 200K+ chars of conversation history every turn. So every Cline call
routed to Sonnet, defeating the entire point of 7B/32B/70B fallback tiers.

**Rule:** Router classification rules MUST inspect the LAST user message size (`ulen`),
NOT total conversation chars. Anthropic prompt cache already covers the history. The
classifier only needs to decide what THIS turn's user message looks like.

**Detection pattern:** `router_total_ctx_misroute` recipe in `failure_repair_recipes`.

**Concrete shape** (router_hook.py pick_model):
```python
user = _last_user_text(messages)
ulen = len(user)
# ... classify on ulen, not total_chars
if ulen <= TRIVIAL_MAX_USER: return "ollama-7b-lora", "trivial_short"
```

**Cross-refs:** idea #6842 (LiteLLM ship), `/etc/litellm/router_hook.py`.

## Lesson 3 — Anthropic Opus 4.7 rejects `thinking.type.enabled` (400) — strip at proxy

**What happened:** Cline VS Code sends `thinking.type.enabled` + `budget_tokens` in
extended-thinking requests. Anthropic Opus 4.7 (released 2026-04-14) requires
`thinking.type.adaptive`. The 400 response killed at least one Cline window during
`condense`. Affects ALL responder agents if they pass through Cline's thinking blob.

**Rule:** LiteLLM router_hook.py pre_call_hook MUST rewrite
`data["thinking"]["type"] = "adaptive"` and pop `budget_tokens` for any
`claude-opus-4-7+` / `claude-sonnet-4-7+` model. For Ollama models, drop
`thinking` entirely (Ollama doesn't understand it).

**Detection pattern:** `anthropic_thinking_param_400` recipe.

**Cross-refs:** `/etc/litellm/router_hook.py:_strip_unsupported_thinking()`.

## Lesson 4 — Responder agents calling api.anthropic.com direct = no cache hit, no admin UI, no kill switch

**What happened:** `lib/EmailAIResponder.php` line 411 + `lib/SMSAIResponder.php` line 408
+ `lib/ai_ticket_agent.php` line 1671 all `curl_init('https://api.anthropic.com/v1/messages')`
direct with `x-api-key: ANTHROPIC_API_KEY`. They bypass the LiteLLM gateway entirely.
Cost leakage: ~$60-90/day in unused ephemeral cache discount. Plus no per-call admin UI,
no kill switch if Anthropic has outage.

**Rule:** ALL responder agents in `/var/www/emtskills/lib/` that call
`api.anthropic.com/v1/messages` MUST be swapped to `http://10.100.0.1:4000/anthropic/v1/messages`
with `x-api-key: LITELLM_MASTER_KEY`. LiteLLM exposes the Anthropic-native passthrough
wire-format-compatible — zero code changes needed beyond URL + header swap.

**Detection pattern:** `responder_anthropic_direct_curl` recipe.

**List of files needing migration** (verified 2026-05-25, surface in shipping):
- lib/EmailAIResponder.php
- lib/SMSAIResponder.php
- lib/ai_ticket_agent.php
- lib/AdaptiveGhostTriage.php
- lib/BBBComplaintAgent.php
- lib/ChargebackDetectionAgent.php
- lib/ClaudeVision.php
- lib/cline_task_rebase.php
- lib/CorrectionTriggerClusterer.php
- lib/DisputeResponseEngine.php
- lib/email_agent_vision.php
- lib/EmailAILearningPipeline.php
- lib/InstructorSMSAgent.php
- lib/ruben_questions_rebase.php
- (plus _reocr_* utilities — lower priority)

**Cross-refs:** idea #6978 (migration), idea #6842 (LiteLLM gateway shipped).

## How Fleet Agent / KAIZEN / Babysitter inherit these

All 4 lessons are now in:
- `orchestrator_learned_patterns` (4 rows, `auto_enabled=1`, `confidence=0.95`)
- `failure_repair_recipes` (4 rows, `enabled=1`, recipes named above)

Any executor that consults these tables before action will pick them up automatically.
Fleet Agent's `agent_send_or_draft` path + KAIZEN's classifier + Babysitter's
proactive-issue scanner all do this on every tick.

## Self-check before any RunPod mint / LiteLLM config change / responder edit

1. *Am I about to mint a RunPod pod without `networkVolume` attached?* → STOP, attach one first
2. *Am I writing a router rule that gates on `total_chars`?* → switch to `ulen` of last user msg
3. *Am I deploying a curl to api.anthropic.com when LiteLLM is up at 10.100.0.1:4000?* → swap to LiteLLM
4. *Am I passing through Cline's `thinking.type.enabled`?* → rewrite to `adaptive` at the proxy

## Last updated

2026-05-25 10:58 PT — Ruben directive: "Learn from this. Fleet Agent needs to learn from
these things. Same with Kaizon. Babysitter, etc..." Persisted as both .clinerules + DB rows
so the lessons live in both human-readable and machine-actionable form.

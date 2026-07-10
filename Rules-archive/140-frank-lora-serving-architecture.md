# 140 — Frankenstein LoRA experts ARE served (no "serving gap"). How routing actually works.

Source: 2026-06-05 — Cline wrongly told Ruben twice that frank-retrain LoRA adapters "have no serving path" and refused to flip a passing route. That was FALSE and cost two round-trips. This rule is the durable correction.

## The bright-line fact

**The frank-retrain pipeline DOES deliver and serve its LoRA experts.** When a frank LoRA passes its gate, the `blob_deliver.sh` / `deliver_after_dl.sh` pipeline merges + quantizes it to Q4_K_M and serves it on the **SMS Mac Ollama** behind the **cloudflare tunnel `https://sms-70b.emsuniversity.com`**. There is NO serving gap. Before claiming a model "can't be routed," CHECK what is actually being served:

```
curl -s https://sms-70b.emsuniversity.com/api/tags | python3 -c 'import json,sys;[print(m["name"]) for m in json.load(sys.stdin)["models"]]'
```

As of 2026-06-05 this tunnel serves (all 42.5GB Q4): `emsu-llama3.3-70b-classify-lora`, `emsu-llama3.3-70b-student_email_reply-lora`, `emsu-llama3.3-70b-ticket_triage-lora`, plus base `llama3.3-ctx8k`, `llama3.3-ctx32k`, `emsu-cs-70b`, and smaller qwen coders.

## To route a passing frank LoRA (the real, complete procedure)

1. **Confirm it's served**: `/api/tags` on the tunnel shows `emsu-llama3.3-70b-<kind>-lora:latest`.
2. **Add a litellm config block** in `/etc/litellm/config.yaml` (needs sudo). Mirror the existing `emsu-llama3.3-70b-classify-lora` block exactly:
   ```yaml
   - model_name: emsu-llama3.3-70b-<kind>-lora
     litellm_params:
       model: ollama_chat/emsu-llama3.3-70b-<kind>-lora
       api_base: https://sms-70b.emsuniversity.com
       request_timeout: 180
       num_retries: 1
       model_info:
         num_ctx: 8192
       extra_body:
         options:
           num_ctx: 8192
           keep_alive: "30m"
   ```
   Back up config.yaml first. Validate: `python3 -c "import yaml;yaml.safe_load(open('/etc/litellm/config.yaml'))"`.
3. **Set the route**: `UPDATE orchestrator_llm_routes SET primary_provider='litellm', primary_model='emsu-llama3.3-70b-<kind>-lora' WHERE task_kind='<surface>';`
4. **Safe-restart litellm** per rule 118: `sudo /usr/local/bin/emsu-safe-litellm-restart.sh --reason='...'`.
5. **Verify**: `/v1/models` (with master key) lists the model; smoke-test a chat completion.

## Capacity caveat (not a wiring fault)

A smoke test may return `"server busy, please try again. maximum pending requests exceeded"` from the SMS Mac Ollama when multiple 42GB models are loading or a blob is still streaming. That is TRANSIENT capacity, not a broken route. The litellm `emsu-router-auto` fallback chain (terminal `claude-sonnet`) covers the surface meanwhile. Re-test after load settles. Do NOT conclude the model is unservable from a busy response.

## The failover ladder (router_hook.py)

`L0 ollama-7b-lora (trivial/chat)` → `L1b ollama-llama3.3-70b (heavy local)` → `L2 claude-sonnet` → `L3 claude-opus`. Per-surface orchestrator_llm_routes experts (classify, email_ai, etc.) sit ABOVE Sonnet for their domain with Sonnet as the terminal fallback.

## Two distinct "results vs judge" surfaces — don't conflate

1. **fleet_v24_phase_d candidate sweep** → table `lora_eval_scores` (run_source='fleet_v24_phase_d'). Hosted API models (deepseek-v4-pro/flash, gpt-5-5-pro). ≥45% W/T = immediate reversible route flip, no serving step.
2. **frank-retrain LoRA gates** → `/var/www/frank_adapters/logs/GATE_RETRAIN_<kind>.txt` + retrain log `STAGE1 Sonnet:` lines. Local 70B LoRA experts. Sonnet (STAGE1) is the gating bar (0.45); Opus (STAGE2) is the stretch measurement; Sonnet-PASS + Opus-FAIL auto-launches `frank_continue_train.sh` Stage-2.

## DB-grounded surfaces can't be fixed by retraining

ticket_triage and plan_summary keep failing (0.25 / 0.15) because they need LIVE DB facts (student records, payment state, RUBEN-investigation references) a frozen LoRA can't memorize (#9728). The fix is tool-access/RAG to the DB, NOT more epochs. Don't keep retraining a surface whose gate is structurally unreachable.

## Last updated

2026-06-05 — initial. Source: Cline falsely claimed a serving gap and blocked a valid route flip for student_email_reply (Sonnet gate 0.55 PASS). The LoRA was already live on sms-70b.emsuniversity.com the whole time. Live router dashboard: https://emsuniversity.com/emtskills/routes/llm_router_live.php
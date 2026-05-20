# 89 — Ollama "broken" symptoms with HTTP 000 / 503: check cold-load timeout BEFORE declaring the service down

Permanent rule. Workspace-scoped. Source: 2026-05-18 cline_rag-continuation-2026-05-18.
I told Ruben three different times that the Artemis 7B-LoRA / 30B-LoRA / email-7b
inference endpoints were "broken" (HTTP 503, then HTTP 000 silent hang) and offered
to dispatch a subagent to fix it. A subagent investigation confirmed the models
were healthy the whole time — they were just cold-loading slower than my 15-second
curl timeout. Ruben asked for this rule so the misdiagnosis doesn't recur.

## The bright-line rule

**Before reporting "Ollama is broken" / "the LoRA tag is hung" / "503 on inference",
verify the symptom is not just cold-load latency exceeding the probe's timeout.**
Cold-loads on Artemis GPU stack take 5-18 seconds typical for these models. With
`stream:false` (default for the EMSU code path), Ollama writes zero bytes to the
socket until load+generate completes, so curl with `--max-time 15` will look
identical to a hung server (HTTP 000, 0 bytes received).

## How to actually test inference correctly

Use these knobs:

1. **Set `--max-time` to AT LEAST 60s** (180s if testing 30B+ tags). Cold-load alone
   can be 18s; you need headroom for the prompt to complete after that.
2. **Use stream:true if you want early-bytes-back signal** to distinguish "load
   hasn't completed yet" from "server is wedged." First token usually arrives within
   2-3 seconds after load finishes.
3. **Hit `/api/ps` first** to see what's currently warm in VRAM. If the target tag
   is listed there, subsequent calls won't have cold-load latency.
4. **Try a tiny non-LoRA base model in the same probe** (e.g. `qwen2.5-coder:7b`
   without `:lora`) to isolate "is it LoRA-specific" from "all inference is slow."
   Cold-loads affect non-LoRA tags too.
5. **Read journalctl -u ollama** for actual errors (CUDA OOM, model not found,
   adapter file missing). If no errors appear, the silence is just cold-load.

## Canonical diagnostic sequence

```bash
# Step 1: /api/tags works at all?
ssh artemis "curl -sS http://10.100.0.5:11434/api/tags --max-time 5 | head -c 200"
# If HTTP 200 with JSON, daemon is alive.

# Step 2: /api/ps to see what's warm
ssh artemis "curl -sS http://10.100.0.5:11434/api/ps --max-time 5 | python3 -m json.tool"

# Step 3: inference with generous timeout
ssh artemis "curl -sS -X POST http://10.100.0.5:11434/api/generate \
  -d '{\"model\":\"emsu-qwen2.5-coder:7b-lora\",\"prompt\":\"OK\",\"stream\":false,\"options\":{\"num_predict\":4}}' \
  --max-time 120 -w '\nHTTP=%{http_code} TIME=%{time_total}\n'"
# Read load_duration in the response JSON to know how long cold-load took.

# Step 4: only if step 3 truly times out at 120s, check service health
ssh artemis "systemctl status ollama --no-pager | head -20; journalctl -u ollama -n 50 --no-pager"
```

If step 3 returns HTTP 200 with a non-empty response and load_duration < probe
timeout, the service is healthy. Stop. Do not file a bug. Do not say "still broken."

## What I MUST do when I see HTTP 000 / silent hang on Ollama inference

Before saying "broken":

1. Re-run the probe with `--max-time 60` minimum (or `--max-time 180` for ≥30B).
2. Read `load_duration` and `eval_duration` from the response JSON.
3. If `load_duration > 5 seconds` AND response is non-empty → it was just cold-load.
4. If `--max-time 60` STILL gives HTTP 000 → then escalate, dispatch subagent, etc.

## Why this happened to me (the diagnostic mistake)

My 2026-05-18 probe used `--max-time 15` because that was the timeout setting in
the cline-router LiteLLM config I had been working in. 15s is way too short for
Artemis Ollama cold-loads. The subagent that re-probed with `--max-time 180`
got HTTP 200 in 18.21s on the 30B-LoRA, 5.35s on email-7b, 9.25s on a non-LoRA
qwen2.5-coder:7b. All healthy. The "silent hang" was just my client giving up
before the server finished loading.

## Anti-patterns that trigger this rule

- "503 on Ollama inference" without checking if the daemon is actually responding
  to /api/tags (which is fast)
- "HTTP 000 timeout" reported as a server problem without verifying client-side
  timeout was generous enough
- Recommending Ollama restart / systemd kick / VRAM clear when no actual errors
  appear in journalctl -u ollama
- Telling Ruben (or any operator) "it's still broken" when an upstream fix has
  shipped, without re-probing with appropriate timeout

## Cross-references

- .clinerules/40 — Artemis Ollama is the analysis baseline (this rule supports
  that policy by removing the false-broken signal that kept routing traffic away
  from local LoRAs)
- .clinerules/74 — Opus-main aggressive Haiku dispatch (the LoRA hang investigation
  this rule comes from used 3 Haiku subagents to figure out the right diagnostic)
- .clinerules/95 — Cline 30s tool wall (related shape: long-running operations
  need detached patterns, not synchronous probes with short timeouts)
- HANDOFF_NOTES entry 2026-05-18 (artemis 7B-LoRA cold-load timeout diagnosis)

## Last updated

2026-05-18 — initial rule per Ruben directive in cline_rag-continuation-2026-05-18.
Source incident: I incorrectly reported 7B-LoRA / 30B-LoRA / email-7b "broken" to
Ruben three times. Subagent re-probe with appropriate timeout (180s) confirmed all
three models healthy. Ruben directive verbatim: "Cline rule, notate this on the 7B
- Artemis 7B-LoRA verified WORKING. My earlier 'still broken' claim was wrong —
you were right. The models cold-load in 5-18s but my probe used a 15s curl
timeout, so the timeout fired before load completed."

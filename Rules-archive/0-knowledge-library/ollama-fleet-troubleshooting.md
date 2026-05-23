# Ollama Fleet Troubleshooting: EMSU LoRA Bigs (14B / 30B / 32B) + email-7b:lora-v2 503

Knowledge library entry. Workspace scope: Artemis Ollama host (10.100.0.5:11434) and any sibling boxes serving the EMSU LoRA fleet.
Author audience: Fleet Agent, Cline main, future subagents running cron_lora_fleet_collector.php smoke checks.
Last researched: 2026-05-22. Sources are real, all linked inline.

This file is the thing you reach for when the smoke test fails on 14B / 30B / 32B
or returns HTTP 503 on email-7b:lora-v2. Do not re-do the research. Read this,
apply the env vars, then move on.

## Problem 1: 14B / 30B / 32B Q4_K_M timing out at 120s on /api/generate, while 7B does not

### Confirmed root causes (in priority order)

1. **Cold-load disk-to-VRAM time exceeds the 120s curl timeout for a model that is not resident.**
   A 14B Q4_K_M file is roughly 8.4 GiB. A 30B / 32B Q4_K_M file is 18.5-19 GiB. With Flash
   Attention enabled and KV cache f16, the runner logs in ollama/ollama#13235 show that the
   llama runner itself reports "started in" times of 6.27s (32B on 3xRTX 3060) up to 14.37s
   when VRAM has to be evicted from a previously loaded model first. That is just the runner
   ready time. Add disk read of 18 GiB at typical NVMe rates, plus the "model layout did not
   fit, applying backoff" rebalance loop you see in that same issue, and a true cold load on
   a contended host can run 60-100s on enterprise NVMe and well past 120s on slower storage
   or first-load-after-reboot when the page cache is cold.
   Source: https://github.com/ollama/ollama/issues/13235 (logs show eviction + backoff loop).
   Source: existing rule .clinerules/89-ollama-cold-load-timeout-not-broken.md which already
   documented this for Artemis. Cold-load on 30B-LoRA there was clocked at 18.21s when the
   model was warm-able; first-after-reboot is multiples of that.

2. **OLLAMA_KEEP_ALIVE default is 5 minutes.** Smoke that runs every 30 minutes evicts
   the model between runs every single time. Every smoke for a big model is therefore a
   cold load. The 7B "doesn't time out" because either (a) it has been pinned by other
   traffic and stays warm, or (b) its 4-5 GiB Q4_K_M loads inside the 120s window.
   Source: https://github.com/ollama/ollama/blob/main/docs/faq.mdx lines 289-318.

3. **OLLAMA_MAX_LOADED_MODELS default is 3 \* GPU count, but it gates on whether VRAM
   actually fits.** On a single H100 80GB you can theoretically hold 7B + 14B + 30B
   concurrently. On a 24-48 GiB card you cannot. Loading the 14B silently evicts the 7B,
   then the next 7B call cold-loads (which is what hides the real issue: the operator sees
   "7B is slow now too" and blames the LoRA layer).
   Source: https://github.com/ollama/ollama/blob/main/docs/faq.mdx lines 326-336.
   Source: https://github.com/ollama/ollama/issues/13235 ("model requires more memory
   than is currently available, evicting a model to make space").

4. **Curl in cron_lora_fleet_collector.php is hard-coded to 120s.** Per rule
   .clinerules/89, the canonical probe needs `--max-time 240` for >=30B and `--max-time 180`
   for 14B-LoRA. If the smoke script still has `CURLOPT_TIMEOUT => 120` that is the bug,
   not Ollama.

### What this looks like on the wire

Symptoms that prove this is cold-load and not a broken model:

- `curl -w '%{time_total}'` returns near exactly the timeout limit (119.9s, 239.9s).
- Nothing in `journalctl -u ollama` shows CUDA OOM, model-not-found, or runner panic.
- `/api/ps` shows another model in VRAM that has to be evicted.
- A retry 30s later, while the load is still proceeding in the background, returns the
  full response in <10s because the model is now warm.

### Verification commands

```bash
# Daemon alive?
curl -sS http://10.100.0.5:11434/api/tags --max-time 5 | jq '.models[].name' | head

# What is actually warm right now?
curl -sS http://10.100.0.5:11434/api/ps --max-time 5 | jq

# Cold-load with realistic timeout. Read load_duration in response.
curl -sS -X POST http://10.100.0.5:11434/api/generate \
  -d '{"model":"emsu-qwen2.5-coder:14b-lora","prompt":"OK","stream":false,
       "options":{"num_predict":4},"keep_alive":"30m"}' \
  --max-time 240 -w '\nHTTP=%{http_code} TIME=%{time_total}\n'
```

`load_duration` in the JSON is nanoseconds. Divide by 1e9 for seconds. If
`load_duration > 30000000000` (30s) on a model that just loaded, the request was
spending almost all of its budget on the load and the smoke timeout is the cause.

## Problem 2: Recommended env vars for an Ollama host serving 7B (always-hot) + 14B/30B/32B (warm-on-demand)

Put these in `/etc/systemd/system/ollama.service.d/override.conf` (Linux systemd).

```ini
[Service]
# Keep models in VRAM for 24 hours by default. The 7B will effectively stay
# pinned because it gets hit constantly. The bigs will stay warm between
# the 30-minute smoke cycles instead of evicting every cycle.
Environment="OLLAMA_KEEP_ALIVE=24h"

# Allow up to 4 models resident at once. Set to whatever your VRAM math
# actually supports. Ollama still gates per-load on real VRAM availability,
# so this is a ceiling, not a guarantee.
Environment="OLLAMA_MAX_LOADED_MODELS=4"

# One request per model at a time. Raising this multiplies KV cache by N
# (a 2K context with NUM_PARALLEL=4 becomes 8K of KV), which on a 32B model
# eats 6-10 extra GiB. Keep at 1 unless you have real concurrent load on
# the same model and measured VRAM headroom.
Environment="OLLAMA_NUM_PARALLEL=1"

# Flash Attention reduces KV memory growth as context grows. Required if
# you also want quantized KV cache to take effect.
Environment="OLLAMA_FLASH_ATTENTION=1"

# Quantize KV cache to q8_0. Ollama docs explicitly recommend q8_0 as the
# default trade if you are not staying on f16. Cuts KV memory ~50% with no
# noticeable quality impact on most models. Avoid q4_0 with Qwen2.5 family
# because Qwen2.5 has high GQA count and is more sensitive to KV quant
# (called out in the FAQ).
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"

# Give cold loads enough time to finish before Ollama itself gives up on
# the runner. Default is 5m. Bump to 15m so first-after-reboot of 30B
# does not get killed.
Environment="OLLAMA_LOAD_TIMEOUT=15m"

# Queue depth. 503 "Server overloaded" fires only after the queue overflows
# this. Default 512 is fine for our fleet load. Note this for Problem 3.
Environment="OLLAMA_MAX_QUEUE=512"

# Bind. Standard.
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Apply:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
journalctl -u ollama -n 50 --no-pager | grep -i "server config"
```

Pre-warm the bigs immediately after restart so the first real smoke does not pay
the cold-load cost:

```bash
for M in emsu-qwen2.5-coder:7b-lora emsu-qwen2.5-coder:14b-lora \
         emsu-qwen2.5-coder:32b-lora email-7b:lora-v2; do
  curl -sS -X POST http://10.100.0.5:11434/api/generate \
    -d "{\"model\":\"$M\",\"prompt\":\"\",\"keep_alive\":-1}" \
    --max-time 600 -w "warm $M HTTP=%{http_code} TIME=%{time_total}\n" -o /dev/null
done
```

`keep_alive: -1` pins the model in VRAM until explicit eviction. Use sparingly:
only on models that genuinely need to stay hot.
Source: https://github.com/ollama/ollama/blob/main/docs/faq.mdx lines 297-318.

## Problem 3: When does Ollama return HTTP 503 and how to distinguish causes

The FAQ is explicit:

> If too many requests are sent to the server, it will respond with a 503 error
> indicating the server is overloaded. You can adjust how many requests may be
> queued by setting `OLLAMA_MAX_QUEUE`.

Source: https://github.com/ollama/ollama/blob/main/docs/faq.mdx lines 320-322.

But 503 is also observed in two other cases. Distinguish them this way:

| Variant | Trigger | Telltale signal | Fix |
|---|---|---|---|
| Queue overflow 503 | More than `OLLAMA_MAX_QUEUE` requests in flight at the same model | Body says "Server overloaded, please retry shortly" with a ref UUID | Retry with backoff. Reduce smoke concurrency. Raise `OLLAMA_MAX_QUEUE`. |
| Loading-state 503 | Request hit while model is mid-load and the runner has not bound the port yet | Body usually empty or "model is still loading"; `journalctl -u ollama` shows `waiting for server to become available` for that exact PID | Retry in 5-15s. Increase `OLLAMA_LOAD_TIMEOUT`. Pre-warm. |
| OOM / runner died 503 | CUDA OOM or `cudaMalloc failed: out of memory` during load, runner exits, requests bounce | `journalctl -u ollama` shows `cudaMalloc failed` and `model layout did not fit, applying backoff` followed by the runner exiting with a non-zero code | Reduce `OLLAMA_NUM_PARALLEL`. Reduce `OLLAMA_KV_CACHE_TYPE` to q8_0 or q4_0. Reduce context length on the modelfile. Evict other models. |

Sources for the queue overflow message format: https://github.com/ollama/ollama/issues/15934 (Server overloaded with ref UUID). For the OOM backoff pattern: https://github.com/ollama/ollama/issues/13235 ("model layout did not fit, applying backoff" repeats).

### Specifically for email-7b:lora-v2 returning HTTP 503

The 7B base loads in under 10s on Artemis. A persistent 503 on a 7B is almost never
queue overflow (the fleet does not generate that much load) and almost never cold-load
(7B loads fast). The two real causes:

1. **The LoRA adapter file referenced by the modelfile is missing or its sha256 does
   not match the blob on disk.** When Ollama goes to assemble the model, it pulls the
   base GGUF + adapter into the runner. If the adapter cannot be opened, the runner
   exits and the API returns 503 until the manifest is fixed. Diagnose with:

   ```bash
   ollama show email-7b:lora-v2 --modelfile
   ollama show email-7b:lora-v2 --parameters
   journalctl -u ollama -n 200 --no-pager | grep -iE "lora|adapter|email-7b"
   ```

   Look for "failed to load adapter" or "no such file or directory" referencing the
   adapter blob.

2. **The published GGUF for `:lora-v2` is corrupt.** See Problem 6 below for the
   exact signs.

If neither, fall through to the cold-load reasoning in Problem 1 and re-probe with
`--max-time 240`.

## Problem 4: A smoke-test pattern that does not cause its own timeouts

This is the replacement pattern for the current cron. Every rule here exists because
something else failed without it.

1. **Always send `"keep_alive": "30m"` on every smoke call.** This overrides the
   server default and keeps the model warm long enough to span the smoke interval
   plus headroom. Source: https://github.com/ollama/ollama/blob/main/docs/api.md#L59
   "keep_alive: controls how long the model will stay loaded into memory following
   the request (default: 5m)".

2. **Pre-warm with an empty request before the real probe.** Send a generate with
   `"prompt": ""` and `"keep_alive": "30m"`. This triggers the load without committing
   to a long inference. Use `--max-time 240`. Once it returns, immediately fire the
   real generate; that one will be hot.

   ```bash
   curl -sS -X POST http://10.100.0.5:11434/api/generate \
     -d '{"model":"emsu-qwen2.5-coder:30b-lora","prompt":"","keep_alive":"30m"}' \
     --max-time 240 -o /dev/null
   ```

3. **Hit `/api/show` first to confirm the tag actually exists.** This is a sub-second
   call and distinguishes "tag never published" from "tag exists but loading slow."

   ```bash
   curl -sS -X POST http://10.100.0.5:11434/api/show \
     -d '{"name":"emsu-qwen2.5-coder:30b-lora"}' --max-time 5 \
     -w '\nHTTP=%{http_code}\n' | head -c 400
   ```

4. **Stagger smoke runs across model sizes.** Do not fire 7B, 14B, 30B, 32B in the
   same second. The default `OLLAMA_MAX_LOADED_MODELS=3` (Ollama default) plus VRAM
   reality will force evictions that turn every subsequent call into a cold load.
   Sequence: 7B, sleep 5, 14B, sleep 15, 30B, sleep 30, 32B. Use longer sleeps if
   VRAM cannot hold all four concurrently.

5. **Tier the curl `--max-time` by model size.**
   - 7B: `--max-time 60`
   - 14B: `--max-time 180`
   - 30B / 32B: `--max-time 240`, or 300 on first-after-reboot

6. **Read `load_duration` and `eval_duration` from the response JSON, not just the
   HTTP status.** A 200 with `load_duration` near your timeout means you got lucky.
   A 200 with `load_duration` near zero means the model was warm. Use these to
   decide whether to extend keep_alive.

7. **Use `stream:true` when you want early-bytes-back detection.** A streaming
   request emits the first token chunk within 1-3s after load completes, which
   distinguishes "still loading" from "wedged." This is also the workaround in
   ollama/ollama#7685 for gateway timeouts where the connection would otherwise
   reset on non-streaming long requests.
   Source: https://github.com/ollama/ollama/issues/7685.

8. **Do not retry tighter than 5s on a 503 from a still-loading model.** Repeated
   fast retries just put more entries in the queue and inflate `OLLAMA_MAX_QUEUE`
   pressure for no benefit. Exponential backoff: 5s, 15s, 30s.

## Problem 5: Quantization choice for Qwen2.5-Coder 7B / 14B / 30B / 32B

The 2025-2026 working consensus from official sources:

**Q4_K_M is the official Qwen default for the public GGUF release.** The
Hugging Face card and Ollama tag for Qwen/Qwen2.5-Coder-14B-Instruct-GGUF
ship Q4_K_M as the default tag in every "use this model" code snippet on
the HF model page. Source: https://huggingface.co/Qwen/Qwen2.5-Coder-14B-Instruct-GGUF
("llama-server -hf Qwen/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M" appears as
the canonical command, and the listed quants are q2_K, q3_K_M, q4_0, q4_K_M,
q5_0, q5_K_M, q6_K, q8_0). Source: Ollama library tag listing at
https://ollama.com/library/qwen2.5-coder/tags which exposes
qwen2.5-coder:14b-instruct-q4_K_M alongside Q5_K_M and Q6_K but treats
Q4_K_M as the default 14b tag.

**Q5_K_M is the right step-up when you have VRAM and want a measurable quality
bump on code tasks.** It is what most code-focused tier-lists in 2025-2026
recommend when the user complains of subtle wrong-answers on Q4_K_M. Cost on
14B: roughly 10 GiB vs Q4_K_M's 8.4 GiB. Cost on 32B: roughly 23 GiB vs 19 GiB.

**Q6_K is overkill for coding tasks unless the model is being used as a judge.**
The marginal benefit over Q5_K_M is small for code and the VRAM cost is real.

**IQ4_XS is risky on Qwen-coder.** The Ollama FAQ flags Qwen2.5 family specifically
as sensitive to aggressive quantization of the KV cache because of high GQA count:
"Models that have a high GQA count (e.g. Qwen2) may see a larger impact on
precision from quantization than models with a low GQA count." That sensitivity
extends to the weight quant tier as well: IQ4_XS uses i-matrix calibration and
trades calibration-set-coverage for size. On a coding workload with long contexts,
the failure mode is "still answers, but instruction following degrades on
multi-step requirements." Default to Q4_K_M or Q5_K_M for Qwen2.5-Coder. Only
move to IQ4_XS if you have measured it on your eval set first.
Source: https://github.com/ollama/ollama/blob/main/docs/faq.mdx line 367.

**AWQ is for vLLM, not Ollama.** Ollama does not run AWQ natively. If the fleet
moves to vLLM in the future, AWQ-INT4 on Qwen2.5-Coder is a known-good combo. For
the current Ollama-based fleet, ignore AWQ.

### Concrete recommendation for the EMSU LoRA fleet

| Model | Use | Quant |
|---|---|---|
| 7B base + LoRA | Hot path, every request | Q4_K_M (default) or Q5_K_M if VRAM allows |
| 14B base + LoRA | Warm escalation | Q4_K_M |
| 30B / 32B base + LoRA | Cold escalation, judge, long-context | Q4_K_M, with `OLLAMA_KV_CACHE_TYPE=q8_0` |
| email-7b LoRA | Hot specialty | Q4_K_M |

Do not mix quants for the same logical model unless you are deliberately A/B testing.

## Problem 6: LoRA-on-merged-model gotchas and corrupt GGUF signs

The EMSU fleet builds GGUFs by merging the LoRA into the base then converting to GGUF
and pushing the single file as a new tag. Common failure modes:

### Signs of a corrupt GGUF that produce HTTP 503

1. **Truncated multi-part download.** Qwen 14B+ GGUFs are split across multiple files
   on Hugging Face (e.g. `qwen2.5-coder-14b-instruct-q4_k_m-00001-of-00002.gguf` +
   `-00002-of-00002.gguf`). If only one part landed during publish, Ollama refuses to
   load and the runner exits. Symptom on the wire: HTTP 503. In logs: "unexpected EOF"
   or "invalid magic" or "failed to read tensor". Confirmed format from the HF model
   page for Qwen/Qwen2.5-Coder-14B-Instruct-GGUF.

2. **Wrong tokenizer / chat template embedded in the GGUF.** The Qwen2.5 GGUF must
   carry the Qwen chat template. If the merge step stripped or replaced the template,
   the model loads but every generate returns garbage tokens or empty strings.
   Symptom: HTTP 200 with `response: ""` and `done: true` and non-zero `eval_count`.
   Not a 503 but easy to confuse with one.

3. **GGUF metadata mismatch on the architecture tag.** If you merged a LoRA trained
   on Qwen2.5 base into a GGUF that the converter labeled as `qwen2` instead of
   `qwen2.5`, some loaders accept it but the LoRA layers do not bind. Symptom:
   model loads, responds, but responses are indistinguishable from base (LoRA had
   no effect).

4. **SHA mismatch between the manifest blob and the file on disk.** Happens when
   the publish step uploaded a partial file then the manifest was committed before
   the rest finished. Ollama refuses to load. 503 with "blob not found" or
   "unexpected size" in journal.

### How to verify the published GGUF is not corrupt

```bash
# 1. Size check against the manifest.
ollama show email-7b:lora-v2 --modelfile

# 2. Blob inventory + size on disk.
ssh artemis 'ls -la /usr/share/ollama/.ollama/models/blobs/ | grep -i email'

# 3. Force a re-pull to compare hash.
ssh artemis 'ollama rm email-7b:lora-v2 && ollama pull email-7b:lora-v2'
# If pull fails with checksum error, the source registry has a bad blob.
# Republish from training pipeline.

# 4. Smallest possible probe to detect "loads but produces empty output":
curl -sS -X POST http://10.100.0.5:11434/api/generate \
  -d '{"model":"email-7b:lora-v2","prompt":"Subject: test\nBody:","stream":false,
       "options":{"num_predict":8},"keep_alive":"5m"}' \
  --max-time 60 | jq '{response, eval_count, done_reason, load_duration, eval_duration}'

# If eval_count > 0 and response == "" then it is the template/tokenizer issue,
# not corruption.
```

### How to republish correctly

Once corruption is confirmed, the canonical re-publish sequence on the training box:

```bash
# Merge LoRA into base.
python merge_lora.py --base Qwen/Qwen2.5-Coder-7B-Instruct \
                     --lora /artifacts/email-lora-v2 \
                     --out /tmp/email-7b-merged

# Convert to GGUF with the Qwen template intact.
python llama.cpp/convert_hf_to_gguf.py /tmp/email-7b-merged \
       --outfile /tmp/email-7b-v2.gguf --outtype f16

# Quantize.
llama.cpp/build/bin/llama-quantize /tmp/email-7b-v2.gguf \
       /tmp/email-7b-v2.Q4_K_M.gguf Q4_K_M

# Build Ollama modelfile that points at the new GGUF + the Qwen template.
cat > /tmp/Modelfile.email-7b-v2 << 'EOF'
FROM /tmp/email-7b-v2.Q4_K_M.gguf
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
{{ .Response }}<|im_end|>
"""
PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
EOF

ollama create email-7b:lora-v2 -f /tmp/Modelfile.email-7b-v2
ollama run email-7b:lora-v2 "say OK" --verbose
```

Then re-probe from Mac:

```bash
ssh artemis 'curl -sS -X POST http://localhost:11434/api/generate \
  -d "{\"model\":\"email-7b:lora-v2\",\"prompt\":\"OK\",\"stream\":false,
       \"options\":{\"num_predict\":4},\"keep_alive\":\"30m\"}" --max-time 60'
```

A 200 with non-empty `response` and `eval_count > 0` confirms the republish fixed it.

## Triage cheat sheet (for Fleet Agent when smoke fails)

```
SYMPTOM                          MOST LIKELY CAUSE          FIRST ACTION
==========================================================================
14B/30B/32B smoke times out at   Cold load > 120s          Re-probe with
exactly 120s, no journal error                              --max-time 240
                                                            and keep_alive 30m

Same as above + journal shows    OLLAMA_LOAD_TIMEOUT too    Set OLLAMA_LOAD_
"waiting for server to become    short                      TIMEOUT=15m,
available" then runner exited                               systemctl restart

503 with "Server overloaded"     Queue overflow             Backoff 30s,
ref UUID in body                                            check OLLAMA_MAX_
                                                            QUEUE, reduce
                                                            smoke concurrency

503 with empty body, journal     Model mid-load             Wait 10s, retry
shows runner just started                                   once

503 plus journal cudaMalloc      VRAM OOM                   Reduce
failed + backoff loop                                       OLLAMA_NUM_
                                                            PARALLEL=1,
                                                            evict other
                                                            models, lower
                                                            KV cache type

200 with empty response and      Wrong template / corrupt   Republish per
non-zero eval_count               GGUF                       Problem 6

200 with response matching       LoRA did not bind          Republish per
base model behavior                                         Problem 6 with
                                                            correct
                                                            architecture tag

7B suddenly slow at the same     14B/30B loaded and        Pre-warm 7B with
time bigs are tested              evicted 7B                 keep_alive: -1
```

## References

Ollama official documentation (versioned on main):
- https://github.com/ollama/ollama/blob/main/docs/faq.mdx (KEEP_ALIVE, MAX_LOADED_MODELS, NUM_PARALLEL, FLASH_ATTENTION, KV_CACHE_TYPE, MAX_QUEUE, 503 behavior)
- https://github.com/ollama/ollama/blob/main/docs/api.md (keep_alive parameter, load_duration, eval_duration fields)

Ollama GitHub issues used:
- https://github.com/ollama/ollama/issues/13235 (VRAM eviction when loading models one after another; logs of the backoff loop and the "model requires more memory than is currently available, evicting a model to make space" message)
- https://github.com/ollama/ollama/issues/7685 (streaming workaround for gateway timeouts; explains why stream:false hides cold-load latency from the client)
- https://github.com/ollama/ollama/issues/12027 (model switch not performed; OLLAMA_LOAD_TIMEOUT and OLLAMA_NEW_ESTIMATES context)
- https://github.com/ollama/ollama/issues/15934 (HTTP 503 "Server overloaded" body format with ref UUID)

Qwen2.5-Coder quantization:
- https://huggingface.co/Qwen/Qwen2.5-Coder-14B-Instruct-GGUF (Qwen ships Q4_K_M as canonical; lists the quant tier set q2_K through q8_0; documents the multi-part split GGUF format)
- https://ollama.com/library/qwen2.5-coder/tags (Ollama-side tag map confirming Q4_K_M is default for 7b/14b/32b)

Internal cross-references (read these too):
- /Users/rubenmajor/Documents/Cline/Rules-archive/89-ollama-cold-load-timeout-not-broken.md (the canonical Artemis-specific diagnostic from 2026-05-18; this knowledge library extends it for the multi-model fleet case)
- /Users/rubenmajor/Documents/Cline/Rules-archive/40-default-to-artemis-ollama-first.md (policy: Artemis Ollama is baseline)
- /Users/rubenmajor/Documents/Cline/Rules-archive/95-cline-30s-tool-wall-and-remote-long-running-work.md (related shape: long-running ops need detached patterns, not synchronous short-timeout probes)


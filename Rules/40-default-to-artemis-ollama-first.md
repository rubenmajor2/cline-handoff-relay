# 40 — Default to Artemis/WOPR Ollama first; fall back to Sonnet/Opus/Haiku only for hard floors

Permanent rule. Workspace-scoped. Source incident: 2026-05-10
#opus-train-ollama-replace-sonnet, Ruben directive 13:24 PT:
*"Can you put this in the MCP and once we are done as well as cline rules so
we are always analyzing our own Artemis LLM first, instead of defaulting to
Opus/Sonnet/Haiku always?"*

This rule is the policy layer for "before you reach for Anthropic, see if
local Ollama can do it." It pairs with .clinerules/35 (Artemis local LLM
cost-savings clause) and .clinerules/32 (prefer dedicated MCP wrappers).

## The bright-line rule

**For any new agent surface or prompt-call site that EMSU code is about to
ship — emails, ticket replies, classifications, plan summaries,
embeddings, idea scoring, summaries, file extracts, ad-hoc reasoning —
the DEFAULT first-try provider is Artemis or WOPR Ollama, NOT Anthropic.**
Anthropic is the fall-back when Ollama either (a) lacks the capability,
(b) fails parity in backtest, or (c) is on the hard-floor list below.

## The hard-floor list (Anthropic always)

These stay on Anthropic Sonnet/Opus regardless of Ollama capability:

1. **Student-facing email/SMS composition** — voice fidelity matters
   per .clinerules/02 (no apologies) + 15 (no internal-reasoning narration)
2. **Regulator filings** — counsel-grade posture per .clinerules/08
3. **Money-touching decisions** — refunds, charges, payment_suspensions per
   .clinerules/29 (irreversibility tier)
4. **Code patches >100 lines** — code_patch_large surface (Sonnet 4.6 stays)
5. **Grievance responses to students/regulators** — legal exposure
6. **Anything Ruben explicitly tags as "use Sonnet"**

## How to default to Ollama

For every NEW LLM call site, the implementer must:

1. **Check `lib/llm_router.php` for the right method.** Use:
   - `LlmRouter::fireOllamaChat($model, $messages, $system, ...)` — plain Ollama
   - `LlmRouter::fireOllamaChatWithRag($model, $messages, $system, $ragQuery, $topK, ...)` — Ollama with EMSU-corpus k-NN injection (Phase 2 of #opus-train-ollama-replace-sonnet)
2. **Read the model from `orchestrator_config`** — never hardcode. Default
   model selection should consult `$.ollama_default_model_for_<surface>`
   (e.g. `$.ollama_default_model_for_classify` = `qwen2.5-coder:14b` or
   `mistral-small:22b`).
3. **Wrap the call with a fallback path** to Sonnet/Haiku ONLY when:
   - Ollama returns `ok=false` (transport or HTTP 5xx)
   - JSON parse fails on the response (use `LlmRouter::extractJsonCandidate`)
   - The surface is on the hard-floor list AND the call is the user-facing
     compose stage (vs the pre-bake/classify stage)
4. **Audit row** in `llm_call_log` with `provider='ollama'` and `surface`
   tag. The cost rollup in `routes/llm_cost_dashboard.php` will show how
   much Anthropic spend each surface dodged.

## Where Ollama lives

| Box | GPU | Ollama Models |
|---|---|---|
| **WOPR** (10.100.0.1) | NVIDIA RTX PRO 2000 Blackwell 16 GB GDDR7 ECC, CUDA 13.1, FP4/FP6 Tensor cores | qwen2.5-coder:14b (loaded since 2026-05-06); LoRA training box |
| **Artemis** (10.100.0.5) | 2× Intel Arc Pro B70 Battlemage 64 GB GDDR6 ECC total | mistral-small:22b, qwen2.5-coder:32b, llama3.1:8b, nomic-embed-text |

For inference: prefer **WOPR localhost** (zero network hop to MySQL+PHP) for
small models (≤14B), or **Artemis** for larger (22B-32B+) where the 64 GB
VRAM matters. The `emsu_rag_ollama_endpoint` config flag controls which.

## When the default-Ollama call fails: graceful fallback

```php
$resp = LlmRouter::fireOllamaChatWithRag(
    LlmRouter::cfg('ollama_default_model_for_classify', 'qwen2.5-coder:14b'),
    $messages,
    $system,
    $ragQuery,
    /*topK*/ 5,
    /*maxTokens*/ 800,
    /*timeoutSec*/ 30
);
if (empty($resp['ok']) || (LlmRouter::extractJsonCandidate($resp['text']??'') === null)) {
    // Fall back to Anthropic Sonnet/Haiku
    error_log('[my_surface] Ollama failed, falling back to Sonnet');
    $resp = $myAnthropicCallFn($model='claude-sonnet-4-6', ...);
}
```

## Self-check before any new LLM call site

Before adding a new `curl https://api.anthropic.com/...` line OR a new
ad-hoc Anthropic SDK call, ask:

1. *"Does this surface fit a hard-floor?"* If no → Ollama default.
2. *"Have I tried Ollama in shadow mode at least once?"* If no →
   add a shadow_log entry, run 7-30 day shadow, then ship Ollama-first.
3. *"What's my fallback-to-Anthropic trigger?"* If unclear → don't ship
   yet. Define when Ollama is allowed to "give up" on this surface.

## Cross-references

- `.clinerules/35` — Artemis LLM cost-savings clause (this rule extends it)
- `.clinerules/22` — executor self-supervision loops (recipes can include
  "fall back to Sonnet" as a retry strategy)
- `.clinerules/32` — prefer dedicated MCP wrappers (similar default-first
  shape for tool selection)
- `lib/llm_router.php::fireOllamaChat()`, `fireOllamaChatWithRag()`
- `lib/EmsuRagRetriever.php` — k-NN over emsu_preference_corpus
- `orchestrator_config.config_json` flags: `ollama_endpoint`,
  `emsu_rag_ollama_endpoint`, `emsu_rag_enabled`,
  `emsu_rag_generation_model`, `ollama_prebuilder_model`,
  `ab_grader_provider`, `ruben_executor_provider` (post-LoRA)

## Last updated

2026-05-10 — initial. Source: Ruben directive after RTX PRO 2000 (WOPR) +
Intel Arc Pro B70 dual-GPU (Artemis) hardware reality came online during
#opus-train-ollama-replace-sonnet-2026-05-10. Phase 1+2 RAG infra shipped
that day; this rule locks in the policy posture for every future LLM call
site.
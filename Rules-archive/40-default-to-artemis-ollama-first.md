# 40 — Default to Artemis/WOPR Ollama as ANALYSIS BASELINE; surface a CHOICE when another provider is measurably better

Permanent rule. Workspace-scoped. Source: 2026-05-10 Ruben directive
13:24 PT → refined 14:02 PT: *"Default to Artemis LLM which will be LoRA soon
as an analysis, but if quality is better elsewhere needs stating. Don't just
be blind about it. Give choices when that occurs."*

Pairs with .clinerules/35 (Artemis local LLM cost-savings clause), .clinerules/32
(prefer dedicated MCP wrappers), .clinerules/37 (sink-or-swim, no dry-run).

## The bright-line rule (refined)

**For any new agent surface or prompt-call site that EMSU code is about to
ship — emails, ticket replies, classifications, plan summaries, embeddings,
idea scoring, summaries, file extracts, ad-hoc reasoning — start your
analysis by trying Artemis or WOPR Ollama FIRST. This is the analysis
baseline.**

**BUT: never blindly ship Ollama if it's measurably worse.** When Ollama
output falls below the surface's quality bar (or backtest evidence shows
Anthropic clearly wins for this surface), surface a CHOICE to the user with:

1. The measured quality delta (Ollama X% vs Anthropic Y% on N=...)
2. The cost delta (Ollama $0 vs Anthropic $Z/call)
3. The latency delta (Ollama Xms vs Anthropic Yms)
4. The recommendation with reasoning

Then let Ruben (or .clinerules-defined policy) make the call. Don't blind-default
to Ollama if it's a 30% solution; don't blind-default to Anthropic if it's a
98% solution where Ollama gives 97% at 1/100 the cost.

## The hard-floor list (Anthropic always — quality bar can't be measured cheaply enough to risk a miss)

These ALWAYS stay on Anthropic Sonnet/Opus regardless of Ollama capability:

1. **Student-facing email/SMS composition** — voice fidelity matters per
   .clinerules/02 (no apologies) + 15 (no internal-reasoning narration);
   a single off-tone email creates legal/PR exposure that dwarfs years of
   Ollama savings.
2. **Regulator filings** — counsel-grade posture per .clinerules/08.
3. **Money-touching decisions** — refunds, charges, payment_suspensions
   per .clinerules/29 (irreversibility tier).
4. **Code patches >100 lines** — code_patch_large surface; Sonnet 4.6 stays.
5. **Grievance responses** to students/regulators — legal exposure.
6. **Anything Ruben explicitly tags "use Sonnet"**.

## The "soft-floor" measurement protocol (when to default Ollama vs surface choice)

For everything NOT on the hard-floor list:

**Phase A — Analysis baseline (default).** Fire Ollama first. Capture:
- Output text
- Latency
- Cost ($0 vs Anthropic call cost)

**Phase B — Quality check (per surface).** Either:
- (a) **Backtest exists**: read shadow_log + ab_grader history. If Ollama
  ≥ Anthropic on agreement-vs-truth for this surface, ship Ollama. If
  Ollama < Anthropic by ≥10 points, surface the choice.
- (b) **No backtest yet**: shadow-fire Anthropic in parallel, log to
  `orchestrator_llm_shadow_log` for 7-30 days, then re-evaluate. Ship
  Ollama immediately ONLY if the surface is low-stakes (internal
  ticket categorization, idea scoring, embeddings) — i.e. wrong answer
  is recoverable by Cline or staff.

**Phase C — Surface the choice (when Ollama falls short).** In the
attempt_completion or HANDOFF or staff comm:
- "Ollama qwen-14b: 30% agreement vs Haiku on ab_grader (N=50)"
- "Anthropic Haiku: ground truth"
- "Cost: Anthropic $125/mo for 60k grades, Ollama $0"
- "Latency: Anthropic ~2s/grade, Ollama ~1.6s/grade"
- "Recommendation: KEEP on Haiku until Phase 3 LoRA closes the gap. The
  $125/mo isn't worth a 70-pt quality drop on a metric we use to grade
  every other LLM call."

Then let Ruben/policy decide.

## Post-LoRA reset

Once Phase 3 LoRA ships (qwen2.5-coder:14b-or-32b-emsu-lora adapter), this
rule's "Phase A baseline" model becomes the LoRA-tuned EMSU model, not
the base. Expectation: LoRA-tuned Ollama clears 85-95% parity on the
non-hard-floor surfaces, at which point most surfaces flip to "default ship".
The choice-surfacing step still applies for any surface where post-LoRA
backtest stays below the surface's quality bar.

## How to default to Ollama (when allowed)

For every NEW LLM call site, the implementer must:

1. **Check `lib/llm_router.php` for the right method:**
   - `LlmRouter::fireOllamaChat($model, $messages, $system, ...)` — plain
   - `LlmRouter::fireOllamaChatWithRag($model, $messages, $system, $ragQuery, $topK, ...)` — RAG-augmented (after Phase 2 ships)
2. **Read the model from `orchestrator_config`** — never hardcode. Default
   model selection consults `$.ollama_default_model_for_<surface>` (e.g.
   `$.ollama_default_model_for_classify` = `qwen2.5-coder:14b-emsu-lora`
   once Phase 3 lands; base `qwen2.5-coder:14b` before that).
3. **Wrap with fallback path** to Anthropic ONLY when:
   - Ollama returns `ok=false` (transport or HTTP 5xx)
   - JSON parse fails (use `LlmRouter::extractJsonCandidate`)
   - The surface is on the hard-floor list AND the call is user-facing compose
4. **Audit row** in `llm_call_log` with `provider='ollama'` and `surface`
   tag. Cost rollup in `routes/llm_cost_dashboard.php` shows how much
   Anthropic spend each surface dodged.

## Where Ollama lives

| Box | GPU | Role | Ollama Models |
|---|---|---|---|
| **WOPR** (10.100.0.1) | NVIDIA RTX PRO 2000 Blackwell 16 GB GDDR7 ECC, CUDA 13.1 | Training (LoRA via PyTorch+CUDA+peft) + small-model inference | qwen2.5-coder:14b, mistral-small:22b |
| **Artemis** (10.100.0.5) | 2× Intel Arc Pro B70 = 64 GB GDDR6 ECC | Inference fleet at scale | qwen2.5-coder:32b, mistral-small:22b, llama3.1:8b, nomic-embed-text |

For inference: prefer **WOPR localhost** (zero network hop, MySQL+PHP
co-located) for surfaces ≤14b model. Use **Artemis B70 fleet** when model
≥22b or scale demands the 64 GB VRAM headroom. The
`emsu_rag_ollama_endpoint` config flag controls which.

## When the default-Ollama call fails OR returns measurably worse output

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
    // Failure mode — fall back to Anthropic
    error_log('[my_surface] Ollama call failed, falling back to Sonnet');
    $resp = $myAnthropicCallFn($model='claude-sonnet-4-6', ...);
} elseif (/* quality check fails — e.g. confidence too low, or shadow_log shows >10pt gap on this surface */) {
    // Surface the choice in handoff/log — see Phase C above
    error_log('[my_surface] Ollama returned below-bar output; surfacing choice');
    $resp = $myAnthropicCallFn($model='claude-sonnet-4-6', ...);
    // record both for future calibration:
    log_to_shadow($resp_ollama, $resp_anthropic, $surface_name);
}
```

## Self-check before any new LLM call site

Before adding a new `curl https://api.anthropic.com/...` line OR a new
ad-hoc Anthropic SDK call, ask:

1. *"Is this on the hard-floor list?"* If yes → Anthropic, done.
2. *"Do I have backtest evidence for this surface comparing Ollama to
   Anthropic?"* If yes → ship the better one; if Ollama is within 5
   points, ship Ollama. If 5-15 points gap → log the choice + reasoning
   in HANDOFF + surface to Ruben. If >15 points gap → ship Anthropic +
   note that LoRA may close the gap.
3. *"No backtest?"* → shadow-fire both for 7-30 days OR if low-stakes
   ship Ollama immediately with shadow-fire enabled.
4. *"What's my fallback trigger for Ollama failure mode?"* If unclear,
   don't ship yet.

## What this rule does NOT do

- Does not say "always Ollama." Says "Ollama is the analysis baseline."
- Does not silently ship Ollama if it's worse. Says "surface the choice
  with evidence."
- Does not skip cost+latency reporting. Says "include both in the choice
  panel."

## Cross-references

- `.clinerules/35` — Artemis LLM cost-savings clause (this rule extends)
- `.clinerules/22` — executor self-supervision loops (recipes include
  "fall back to Sonnet" as retry_strategy)
- `.clinerules/32` — prefer dedicated MCP wrappers (default-first shape)
- `.clinerules/37` — sink-or-swim, no dry-run
- `lib/llm_router.php::fireOllamaChat()`, `fireOllamaChatWithRag()`
- `lib/EmsuRagRetriever.php` — k-NN over emsu_preference_corpus
- `orchestrator_config.config_json` flags: `ollama_endpoint`,
  `emsu_rag_ollama_endpoint`, `emsu_rag_enabled`, `emsu_rag_generation_model`,
  `ollama_prebuilder_model`, `ab_grader_provider`, `ruben_executor_provider`

## Last updated

2026-05-10 — initial then refined same day per Ruben's correction:
"Default Artemis as analysis, but if quality is better elsewhere needs
stating. Don't just be blind about it. Give choices when that occurs."

Source incident: 4 successive Ollama backtests on ab_grader surface
(llama3.1:8b 20%, mistral-22b 22%, qwen-14b 30%, qwen-14b+RAG 21.1%)
ALL came in 55+ points below Haiku ground truth. Blind default-Ollama
would have shipped a 30% solution. Surface-the-choice posture correctly
kept ab_grader on Haiku and routed Ollama to the OllamaPreBuilder
surface (where Sonnet veto at 0.50-0.85 catches the quality gap).

## 2026-05-12 addendum — call_ollama MCP tool is now live; use it from Cline sessions

The `call_ollama` and `call_ollama_chat` tools are now part of the emsu-operations
MCP (shipped 2026-05-12, idea #3340). The 7B-LoRA (`emsu-qwen2.5-coder:7b-lora`)
lives on Artemis at `http://10.100.0.5:11434`. WOPR only has base models.

### When to call call_ollama automatically in a Cline session

Call `call_ollama(model="emsu-qwen2.5-coder:7b-lora", ...)` as the FIRST step when:

1. **EMSU-specific policy lookup** — the question is about EMSU procedures, rules,
   student policies, externship process, exam policy, proctoring, etc. The 7B is
   fine-tuned on EMSU data. Call it before going to Anthropic. Free.

2. **Task/ticket classification** — routing a new ticket, classifying intent,
   categorizing a student inquiry. 7B is fast and free for classification.

3. **Pre-screening before an expensive Anthropic call** — when you're not sure if
   the question needs Anthropic or can be answered locally, call 7B first. If the
   answer is good enough (check rule 40's quality-bar guidance), stop there.

4. **Combined with RAG context (rule 50)** — the RAG pipeline already retrieves
   EMSU corpus hits. Pass those as system context to call_ollama for grounded
   EMSU-specific answers without paying Anthropic.

5. **Routing/meta-decisions** — "should this go to Vicky or Jon?", "what category
   is this ticket?", "is this an externship question or a payment question?" These
   are cheap classification tasks the 7B handles well.

### When NOT to call call_ollama (stay on Anthropic)

- Student-facing email composition (hard-floor per this rule's § hard-floor list)
- Regulator filings (rule 08)
- Complex multi-step architectural reasoning across many files
- Anything where the 7B's 30% ab_grader score on general tasks matters
  (check the backtest before relying on it for a new surface)

### The call pattern

```
call_ollama(
  model="emsu-qwen2.5-coder:7b-lora",
  prompt="<your question>",
  system="<optional EMSU context from RAG>"
)
```

Or for multi-turn:
```
call_ollama_chat(
  model="emsu-qwen2.5-coder:7b-lora",
  messages=[{"role":"user","content":"<question>"}],
  system="<EMSU policy context>"
)
```

### Why this is NOT possible via use_subagents

`use_subagents` calls Anthropic's API directly and does not honor the cline-router.
`prompt_N_model="emsu-qwen2.5-coder:7b-lora"` fails with "model not found."
The 7B is main-agent-only via call_ollama MCP. Subagents (Haiku/Sonnet/Opus)
inspect/research the 7B system but cannot call it. See .clinerules/53 limitations.


## 2026-05-14 v2 addendum — call_ollama is DEFAULT-ON for EMSU lookups, same emphasis as rule 17

Same shape as rule 17 (default-on subagent dispatch). Default is "use call_ollama." The exceptions are a short, mechanical list of "obviously not EMSU" cases. False positives (one extra call_ollama call) cost zero dollars and ~1 second. False negatives (paying Anthropic when 7B-LoRA could have answered) cost real Anthropic tokens AND keep 7B traffic at zero, which means no fresh shadow data, which means we can never measure if 7B is improving.

### The default

**At the start of every Cline task that involves an EMSU-domain lookup, my default first move is `call_ollama(model="emsu-qwen2.5-coder:7b-lora", prompt=...)`.** Not "consider it." Not "if it's clearly EMSU-bounded." The default — the thing I do unless an exception below clearly applies.

This is main-agent only. `use_subagents` cannot call call_ollama (Anthropic SDK only). So this rule fires on ME, the main agent.

### The exception list (skip call_ollama only if the task is one of these)

Skip call_ollama ONLY when the task is in one of these clearly-not-EMSU categories:

1. **Pure code question that's framework/library/runtime knowledge** — "what's the right Python import for X?" The 7B is fine-tuned on EMSU, not on every Python library.
2. **Hard-floor EMSU surface** — student-facing email composition (rule 02/15), regulator filings (rule 08), grievance responses. These stay on Anthropic Sonnet/Opus.
3. **Cross-system architectural reasoning** — designing a multi-file patch across PHP + Python + JS. 7B is not strong here.
4. **Single-file bounded read** — `read_file` is the right tool, not call_ollama. (call_ollama is for reasoning, not for fetching bytes.)
5. **Lookup against a deterministic source** — DB row, file content, MCP tool result. Use the tool, don't ask the 7B to make it up.
6. **Already-dispatched** — I already got a 7B answer earlier in this turn and the new question is downstream of that answer.

That's the entire exception list. **Six categories of "skip OK." Anything else → call_ollama first.**

The bar for "obviously not EMSU" is genuinely high. If I find myself thinking "this is probably general-knowledge enough" — that's the signal to call_ollama first and see. If the 7B answer is junk, I fall back to Haiku subagent or Anthropic inline. But I check the cheap-and-free option first.

### Specifically: when Ruben asks an EMSU operational question

If Ruben asks "what does our policy say about X" or "should this ticket go to Vicky or Jon" or "is this an externship issue or a payment issue" or "what's the canonical reply for Y" or "categorize this email" — my FIRST move is call_ollama with the question + relevant context. Anthropic comes second, only if 7B is clearly wrong or refuses.

### Cost asymmetry (same shape as rule 17)

- call_ollama: $0, ~1-3 sec
- Wrong default (Anthropic Sonnet inline): ~$0.05-0.40 per call, ~3-5 sec
- Wrong default (Haiku subagent): ~$0.05-0.15 per call, ~10-30 sec

False positive cost (called 7B when Anthropic would have been better): $0 + 2 sec wasted.
False negative cost (skipped 7B when it would have answered): real Anthropic tokens + 7B never sees the traffic + we lose the chance to measure 7B quality on this surface.

The asymmetry says always try 7B first on anything EMSU-flavored.

### The MCP exists FOR THIS PURPOSE

The whole reason `call_ollama` exists as an emsu-operations MCP tool is so Cline (this main agent) can route EMSU reasoning to the 7B-LoRA on Artemis. If I'm not using it, the MCP investment is wasted AND 7B traffic stays at zero, which prevents measurement, which prevents iteration.

If call_ollama returns a transport error or refuses, that's an MCP repair task — escalate to Ruben, don't silently fall back to paid Anthropic.

### Self-check before any EMSU-flavored inference

Before any inline Sonnet/Opus answer to an EMSU operational question, ask: *"Did I try call_ollama on this turn?"* If no, dispatch call_ollama first. If 7B answers well, stop there. If 7B is junk, fall back.

If I'm halfway through writing an answer to an EMSU question and I never called call_ollama — abandon, dispatch call_ollama, see the result, then continue.

### Source incident (verbatim)

2026-05-14 — Ruben caught me explaining a $0.27 spend on 3 Haiku subagents. His verbatim: "I see, but what was the 27 cents for then? I'm confused there. Also, we do have an mcp so it should be looking at information of in the mcp or the MCP should be repaired if there's some type of an issue where it can't do this because that was the whole entire reason why we included the MCP."

The MCP was built so Cline can use the 7B-LoRA. Cline (this main agent) was not defaulting to it. This v2 addendum fixes that with the same emphatic default-on framing rule 17 uses for subagents.

## 2026-05-14 v3 addendum — the EMSU-flavored-question tripwire

Source: Ruben asked "what about the subagents and calling up the LLM MCP?" right after I shipped the rule 74 tripwire, noticing the same drift pattern applies here. Same shape as rule 74's 2nd-read tripwire and rule 41's "Deployed." tripwire — default-on framing alone doesn't hold; need a measurable trigger.

**Tripwire (hard rule, not a default):**

Before I emit my FIRST tool call on a turn where Ruben's message contains an EMSU-flavored question — policy lookup, "what does X say", "should this route to Y", "categorize this", "what's our canonical answer for Z", any operational question that could be answered from the EMSU corpus — STOP and ask: *"Did I call `call_ollama` on this turn?"*

If no, my first tool call MUST be `call_ollama` with `model="emsu-qwen2.5-coder:7b-lora"`. Not Anthropic inline. Not a Haiku subagent. The 7B-LoRA first. If the 7B returns junk, then fall back to Haiku subagent. If THAT is junk, then Anthropic inline.

**EMSU-flavored signal phrases (any one = tripwire fires):**
- "what does [our policy/rule/document] say"
- "what's the canonical answer for"
- "categorize this [ticket/email/message/student]"
- "should this go to [Vicky/Jon/Cori/instructor]"
- "is this an [externship/payment/exam/integrity] issue"
- "what's our [process/SOP/procedure] for"
- "score [this/relevance/severity] of"
- "what's the policy on"
- Any reference to AI rule N (rule lookup)
- Any reference to a chat/email/SMS auto-response routing decision

**Why a tripwire instead of a default:** rule 40 v2 already said "default-on." Defaults rationalize ("this one's borderline, just use Sonnet inline"). The tripwire fires on a measurable event (Ruben's question matches an EMSU-flavored signal phrase) and doesn't depend on judgment about "is this EMSU enough."

**Cost asymmetry (re-stated for emphasis):**
- call_ollama: $0, ~1-3 sec, 7B EMSU-tuned
- Wrong default (Anthropic inline): $0.05-0.40, no traffic to 7B = no measurement = no iteration

**Exception list (skip the tripwire only if):**
1. The question is pure code/framework knowledge unrelated to EMSU operations.
2. The question is on the hard-floor list (student-facing email composition, regulator filings, grievance responses).
3. Ruben directly said "use Sonnet for this" or "skip the 7B."
4. Already-dispatched call_ollama earlier this turn.
5. The 7B is verifiably unreachable (Artemis Ollama down) — fall back to Haiku subagent.

Anything else → call_ollama first.

**Companion subagent rule:** when I DO need to fan out (rule 74's tripwire), the FIRST subagent in the fan-out should — where possible — research what call_ollama would have answered + cross-check. That keeps the 7B in the loop even on subagent-heavy turns.

### Self-check before any inline Anthropic answer

Ask: *"Did Ruben's message contain an EMSU-flavored question?"*

If yes AND I haven't called call_ollama this turn → call_ollama first, period. Not after one quick read. Not after one subagent dispatch. FIRST.

If I find myself drafting an Anthropic-inline answer to an EMSU operational question without having called call_ollama → abandon the draft, dispatch call_ollama, restructure around its result.



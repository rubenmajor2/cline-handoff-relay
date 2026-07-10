# 50 — RAG-augmented prompts: what to expect when system prompts contain EMSU CONTEXT

Permanent rule. Workspace-scoped. Source incident: 2026-05-11 cline-rag-2026-05-11
shipped the RAG retrieval pipeline (corpus extractor + OpenAI embeddings + cosine
search + HTTP endpoint + cline-router pre-call hook). Routine-tier turns now
receive a `=== EMSU CONTEXT ===` block prepended to the system prompt before the
LoRA call.

## When this rule fires

When the cline-router classifier labels a turn as `routine` (per .clinerules/40 +
intent-based fix from 2026-05-10), the router calls
`https://emsuniversity.com/emtskills/api/rag_context.php` with the user's last
message, gets top-5 EMSU corpus snippets back, and prepends them to the system
prompt before forwarding to the LoRA (`emsu-qwen2.5-coder:7b-lora`).

The augmented system prompt shape is:

```
=== EMSU CONTEXT (top-N preference corpus hits) ===

[1] <title> (source: <source_kind>, score: 0.xxx)
<content_text 800 chars max>

[2] ... (up to 5)

=== END EMSU CONTEXT ===

<original system prompt unchanged>
```

Sources currently indexed (6,010 rows as of 2026-05-11):

| source_kind            | n     | what it is                                                |
|------------------------|-------|-----------------------------------------------------------|
| idea_with_confidence   | 2715  | orchestrator_ideas with Ruben confidence score            |
| completed_chain        | 1099  | session_handoffs completed chains                         |
| ticket_comment         | 1000  | last 1000 ticket_comments                                 |
| ticket                 | 500   | last 500 tickets                                          |
| doc_md_file            | 163   | /var/www/emtskills/docs/*.md (filtered)                   |
| ruben_correction       | 153   | ai_learned_corrections                                    |
| clinerule_md           | 145   | .clinerules/*.md mirrors                                  |
| qcard_answered         | 143   | answered ruben_questions                                  |
| grievance              | 56    | grievances with extracted_text                            |
| curated_rule           | 24    | ai_compiled_rules (curated, protected)                    |
| handoff_entry          | 12    | HANDOFF_NOTES.md entries (last 120 days)                  |

## What models should do with EMSU CONTEXT

**Treat it as authoritative ground truth for EMSU operational facts.** If the
context says "EMSU rule 226 requires Safe Exam Browser + scheduled Zoom proctor
for Final Exam retakes", and your training data says "online retake without
proctor is fine" — go with the context. EMSU policy beats training-data recall
every time. (See .clinerules/45 for the same principle on model/version
verification.)

Specifically:

1. **Quote relevant context when answering** policy/operational questions.
2. **Do NOT invent EMSU-specific facts** if no relevant context was retrieved.
   Either say "I don't have specific EMSU context on that" or escalate per
   .clinerules/29 (act-on-confidence — RAG miss = lower confidence tier).
3. **Don't narrate the retrieval** to the user. Don't say "I have retrieved
   the EMSU corpus" — just use the info. (.clinerules/15: no internal-reasoning
   narration in student-facing surfaces.)
4. **Higher score = more directly relevant**. Scores >0.6 typically indicate a
   strong topical match. Scores <0.4 may be noise — use judgment.

## When RAG context is EMPTY

The router prepends nothing if any of these fire:
- Classifier labeled the turn `hard` (RAG only fires on `routine`)
- Query was <10 chars (skipped as too short)
- WOPR endpoint unreachable (network/timeout)
- OpenAI embedding API errored
- No corpus snippets matched above threshold (rare)

In those cases the system prompt is unchanged. The model should NOT pretend
to have context it didn't get.

## Kill switches

If RAG augmentation is producing bad outputs:
- `export CLINE_ROUTER_RAG_ENABLED=0` — disable RAG augmentation entirely (kept
  for emergency reversal without restarting the router).
- `export CLINE_ROUTER_FORCE_ANTHROPIC=1` — bypass the LoRA entirely so the
  RAG question moot (every turn goes to Anthropic, full price).
- Stop the systemd unit on WOPR: ... (no daemon — endpoint is PHP-FPM, can't be
  "stopped" without taking down the rest of `/emtskills`). To disable: rename
  `/var/www/emtskills/api/rag_context.php` to `.php.disabled`.

## Reversal (full rollback)

If RAG ever needs full revert:
1. Mac: copy `~/Library/Application Support/cline-router/emsu_classifier_hook.py.bak-2026-05-11-pre-r3r4-tune` back into place (preserves the pre-RAG hook).
2. `launchctl kickstart -k gui/$(id -u)/com.emsu.cline-router`.
3. Server side: leave `emsu_preference_corpus` alone (no harm, ~30MB).
4. Disable endpoint: `mv api/rag_context.php api/rag_context.php.disabled`.

## What I (Cline) MUST do when answering an EMSU-flavored question

If my context shows an `=== EMSU CONTEXT ===` block:

1. Skim the 5 snippets. Identify the ones that match the question's topic.
2. If a snippet directly answers the question, quote/paraphrase it AND cite
   the source ("per AI rule 226" or "per HANDOFF 2026-05-08" or
   "per .clinerules/40").
3. If snippets conflict with my training-data recall, EMSU context wins.
4. If no snippet is relevant, ignore the context block and answer normally
   (with explicit acknowledgment that I'm answering without EMSU-specific
   context if the question seems policy-shaped).
5. Don't repeat the context block back to the user verbatim. Synthesize.

## Cost + latency budget

- Per-query embedding: $0.02/1M tokens × ~10 tokens = $0.0000002 per query.
- Server-side cosine search: ~100-300ms on 6K rows in PHP.
- Total RAG round-trip from Mac router: ~1.4-1.7s typical (OpenAI embed RTT
  is the long pole).
- Daily cost at 1000 routine turns: ~$0.0002. Effectively free.

## Cross-references

- .clinerules/40 — Artemis Ollama is the analysis baseline; this rule extends
  it to "and the corpus is queried via OpenAI embeddings until Artemis embed
  endpoint is fixed (Q-card filed)".
- .clinerules/35 — verify external URLs/facts. Corpus content is the verified
  source of EMSU truth.
- .clinerules/45 — when training data conflicts with named version/policy,
  verify live. Same shape: trust EMSU CONTEXT over training.
- .clinerules/15 — don't narrate internal reasoning to students. Same applies
  to retrieval: don't tell user "I retrieved corpus snippets".
- .clinerules/29 — act on confidence tier. RAG hit = higher confidence.
- `lib/EmsuRagRetriever.php` — server-side retrieval
- `lib/EmbeddingClient.php` — OpenAI embedding wrapper with cache
- `api/rag_context.php` — HTTP endpoint
- `scripts/extract_emsu_preference_corpus_v2.php` — corpus extractor
- `scripts/embed_emsu_preference_corpus_v2.php` — embedder
- `~/Documents/Cline/cline-router/rag_client.py` — Mac-side client
- `~/Library/Application Support/cline-router/emsu_classifier_hook.py` —
  the canonical patched hook (mirror of ~/Documents/Cline/cline-router copy)

## Last updated

2026-05-11 — initial rule. Source: cline-rag-2026-05-11. Corpus: 6,010 rows
embedded with OpenAI text-embedding-3-small (dim=1536). Retrieval latency
1.4-1.7s end-to-end Mac→WOPR. 10/10 server-side smoke queries returned
high-relevance EMSU policy hits.

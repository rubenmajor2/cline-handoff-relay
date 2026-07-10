# RAG Retrieval Best Practices (EMSU reference)

Knowledge library entry. Workspace scope: the EMSU preference corpus (`admin_portal.emsu_preference_corpus`) + `lib/EmsuRagRetriever.php` retrieval stack that feeds the ticket / email / SMS / Vapi-voice agents.
Author audience: Cline main, Fleet Agent, future subagents working on corpus retrieval quality.
Last researched: 2026-06-03 (live web + 5-subagent research). Sources linked inline.

This is the "don't re-do the research, read this then act" doc for improving EMSU RAG retrieval. It captures where we are, what the literature/practitioners say, and the recommended upgrade path.

---

## Current state (as of 2026-06-03)

- Corpus: `emsu_preference_corpus`, ~34,700 rows after dedup (was 49,919), 1536-dim OpenAI `text-embedding-3-small` vectors stored as JSON in a TEXT column (`embedding_blob`).
- Retrieval: `EmsuRagRetriever::cosineSimilaritySearch()` — **brute-force PHP cosine** over a candidate pool. Fixed 2026-06-03 from `LIMIT 500` (no ORDER BY = arbitrary ~1% slice) to **pool=6000 ORDERED by source-kind value tier then recency** (tunable `orchestrator_config.emsu_rag_candidate_pool`).
- Scoring: cosine × per-source-kind weight (canonical_policy 2.5x … idea_with_confidence 0.3x).
- Timing measured on WOPR: 500 rows=0.12s, 5,000=1.09s, full 50K=10.86s.
- Hygiene: `cron_fleet_corpus_embed_watchdog.php` (every min, keeps embeddings fresh) + `cron_fleet_corpus_prune_watchdog.php` (hourly dedup + age-prune). Both KAIZEN targets.
- Eval: NONE yet. We cannot currently quote a defensible "% better" number.

---

## 1. Vector index — the biggest structural upgrade

**Brute-force in app code stops being acceptable around ~10K-50K vectors** for interactive latency; we're at the edge. The pool-ordering fix bought headroom but the real fix is an ANN index.

| Option | Effort | Free/self-host | Latency 35K → 500K | Notes |
|---|---|---|---|---|
| **MariaDB native VECTOR + HNSW** ⭐ | Med* | Yes (already on MariaDB) | ms → low-ms | GA in **11.8 LTS** (preview 11.7, MDEV-34939). `ALTER TABLE … ADD COLUMN embedding VECTOR(1536); CREATE VECTOR INDEX …; … ORDER BY VEC_DISTANCE_COSINE(embedding, VEC_FromText('[...]')) LIMIT n`. Optimizer auto-uses the index. **⚠️ VERIFIED 2026-06-03: WOPR runs MariaDB 10.11.14 — VECTOR type NOT available (`ERROR 4161 Unknown data type: 'VECTOR'`). This path requires a MariaDB major upgrade 10.11→11.8 on the production DB = a significant, risky op (backup, replication-aware, downtime window). *Effort is Med→High because of the upgrade, not the SQL.* Until then, the pgvector/FAISS sidecar or the ordered-pool brute-force is the realistic path.** |
| pgvector (Postgres) | Med | Yes | ms → low-ms | HNSW + IVFFlat, `vector_cosine_ops`. Means standing up Postgres alongside MariaDB. |
| sqlite-vec / FAISS (flat→IVF) | Med | Yes | fast → needs IVF at scale | Bolt-on; FAISS is the gold standard but adds a Python sidecar service. |
| Qdrant / Chroma | Med-High | Yes (Docker) | fast | Full vector DB; more infra than EMSU needs at 35K. |
| MySQL HeatWave | n/a | No (Oracle cloud) | fast | Not applicable to self-host. |

**Recommended migration path:** (1) confirm WOPR MariaDB ≥ 11.7; (2) add a real `VECTOR(1536)` column alongside `embedding_blob`, backfill from the JSON; (3) `CREATE VECTOR INDEX`; (4) rewrite `cosineSimilaritySearch()` to `ORDER BY VEC_DISTANCE_COSINE(...) LIMIT k` and drop the PHP scan; (5) keep the source-kind weighting as a *post-retrieval re-score* on the top-k (not a pre-filter). Reversible: keep `embedding_blob` until the VECTOR path is proven.

Sources: https://mariadb.org/projects/mariadb-vector/ · https://mariadb.com/kb/en/mariadb-11-7-0-release-notes/ · https://mariadb.com/resources/blog/how-fast-is-mariadb-vector/ · pgvector https://github.com/pgvector/pgvector

---

## 2. Retrieval quality beyond raw cosine

- **Reranking (cross-encoder)** — highest ROI when recall is OK but precision@5 is poor (right doc in top-50, not top-5). Two-stage: vector/hybrid gets top-50, a cross-encoder rescores. Free/local CPU options: `cross-encoder/ms-marco-MiniLM-L-6-v2`, `BAAI/bge-reranker-base/large`. Adds tens-hundreds ms on CPU — fine for support. **This is likely the single biggest quality lever after a vector index.**
- **Hybrid search (BM25 + dense, fused via Reciprocal Rank Fusion)** — consistently beats pure vector on keyword-heavy / acronym queries (EMS has lots: SEB, NREMT, Moodle). MariaDB has FULLTEXT for the BM25 side; combine with vector via RRF. Solid impact-per-effort.
- **Source/metadata weighting (what we do now: cosine × weight)** — it's a pragmatic heuristic, not an anti-pattern, but the literature prefers: (a) **metadata *filtering*** (hard pre-filter by source_kind/recency) over score-multiplication, and (b) using the weight only as a **post-retrieval tiebreak on the top-k**, not to reshape the whole candidate pool. Learned weights (from click/resolution feedback) are the mature version. Our 2026-06-03 ordered-pool approach is a reasonable middle ground until a vector index lands.

Sources: sentence-transformers cross-encoders https://www.sbert.net/examples/applications/retrieve_rerank/ · bge-reranker https://github.com/FlagOpen/FlagEmbedding · RRF (Cormack et al.) · Anthropic "Contextual Retrieval" blog.

---

## 3. Eval harness — so we can quote a real % instead of guessing

**Metrics that matter for support RAG:** Recall@k (most important — is the right doc retrieved at all?), MRR, nDCG, hit-rate. LLM-judge metrics (context precision/recall) are secondary.

**Build a minimal free harness:**
1. Golden set: mine historical resolved tickets → `(query, relevant_doc_ids)` pairs (the resolved answer points at the canonical_policy / qcard row that solved it). ~100-200 pairs is enough to start.
2. Harness: a CLI PHP script that calls `EmsuRagRetriever::retrieve($query, k)` for each golden query and computes Recall@k / MRR against the expected doc ids. Reuse the existing `chat_corpus_selftest` CLI pattern (require the retriever in a REGRESSION_TEST_MODE, assert per-query).
3. A/B: run the same golden set against config A (`emsu_rag_candidate_pool=500`) vs B (`=6000`) vs future (VECTOR index) — report Recall@5 delta. **This is the only defensible way to answer "how much better".**

Frameworks (all free): RAGAS, DeepEval, promptfoo, TruLens, LlamaIndex eval. For a PHP/MySQL retriever the lightest path is a hand-rolled query→expected-doc harness (no Python service needed); use RAGAS later if LLM-judged answer quality is wanted.

Sources: RAGAS https://docs.ragas.io · DeepEval https://github.com/confident-ai/deepeval · promptfoo https://www.promptfoo.dev · nDCG/MRR standard IR refs.

---

## 4. Corpus hygiene — what to add next to the prune watchdog

We ship exact-content dedup + age-prune. Add, in order:
1. **Near-duplicate (semantic) dedup** — drop rows with cosine > ~0.97 to an existing row (practitioner threshold; >0.95 for aggressive). Catches "same answer, trivially reworded" that exact-match misses.
2. **MinHash/LSH near-dup** for textual Jaccard ≥ 0.8 (5-grams) — the scaled, embedding-free option (ref: "Deduplicating Training Data Makes LMs Better", Lee et al., https://arxiv.org/abs/2107.06499 ; OSS https://github.com/ChenghaoMou/text-dedup ).
3. **Never-retrieved pruning** — log retrieval hits per row; prune low-value rows never returned in N days (usage signal beats age alone).
4. **Safeguards (critical):** never delete the *last* copy of a unique fact; never prune canonical_policy/clinerule/curated/qcard/ruben_correction/handoff/grievance; keep a soft-delete/quarantine window before hard delete. Our current watchdog already honors the first two.

Sources: https://arxiv.org/abs/2107.06499 · https://github.com/ChenghaoMou/text-dedup · https://milvus.io/docs/minhash-lsh.md

---

## Recommended priority order (impact per effort)

1. **Eval harness first** (P1) — without it every other change is unmeasurable. ~1 day.
2. **MariaDB native VECTOR + HNSW index** (P1) — IF WOPR MariaDB ≥ 11.7; else schedule the upgrade. Removes the brute-force ceiling permanently.
3. **Cross-encoder reranker on top-50** (P2) — biggest precision win after the index.
4. **Hybrid BM25+vector (RRF)** (P2) — wins on EMS acronym/keyword queries.
5. **Semantic near-dup dedup** (P3) — incremental corpus cleanliness.

## Last updated
2026-06-03 — initial, from 5-subagent live research (Ruben directive: "investigate the best way to do this and make a proposal, search the forums, add what you find to the Fleet library"). Verify WOPR MariaDB version before acting on #2.

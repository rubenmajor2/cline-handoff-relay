"""rag_client.py — Mac-side RAG retrieval client for cline-router.

Calls WOPR's https://emsuniversity.com/emtskills/api/rag_context.php with the
user's prompt and returns a context block to prepend to the system prompt
before the LoRA call.

Failure modes are NON-FATAL — RAG augmentation is optional. If WOPR is
unreachable, the secret is wrong, or the corpus is empty, we return "" and
the router continues without RAG. This is per .clinerules/29 (act on
confidence tier — RAG miss = ship without it, don't block the user turn).

Cost: $0.02/1M tokens for the query embedding (text-embedding-3-small) on
the WOPR side. ~6 tokens per query × 1000 queries/day = $0.0001/day.

Latency: typical 200-400ms (embed + cosine + HTTP round trip).
Timeout: hard 1500ms — if RAG doesn't return fast, ship without it.

Source incident: 2026-05-11 cline-rag-2026-05-11.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from typing import Optional


RAG_ENDPOINT = os.environ.get(
    "CLINE_ROUTER_RAG_ENDPOINT",
    "https://emsuniversity.com/emtskills/api/rag_context.php",
)
RAG_SHARED_SECRET = os.environ.get(
    "CLINE_ROUTER_RAG_SECRET",
    "5a92cbaafab8b7e768b817e54f522b377888320081b6b27880901bc57434d1fc",
)
# 2.5s timeout. OpenAI embed RTT alone is ~200-400ms + WOPR cosine ~50ms +
# HTTPS handshake ~100ms + cross-coast network ~50-150ms = ~500-700ms typical,
# up to 1.6s observed under load. 2.5s gives headroom without dragging total
# turn latency beyond ~3s.
RAG_TIMEOUT_SEC = float(os.environ.get("CLINE_ROUTER_RAG_TIMEOUT", "2.5"))
RAG_TOP_K = int(os.environ.get("CLINE_ROUTER_RAG_TOP_K", "5"))

# Kill switch — set to skip RAG entirely without removing the hook.
RAG_ENABLED = os.environ.get("CLINE_ROUTER_RAG_ENABLED", "1") not in ("0", "false", "no")

# Min query length to bother retrieving. Skip "hi", "yes", etc.
MIN_QUERY_LEN = 10


def fetch_context(query: str, top_k: int = RAG_TOP_K) -> tuple[str, dict]:
    """Fetch RAG context block for a query.

    Returns:
        (context_block, meta) where context_block is "" on any failure or
        empty corpus, and meta is a dict with retrieval diagnostics.
    """
    if not RAG_ENABLED:
        return "", {"skipped": "disabled"}

    q = (query or "").strip()
    if len(q) < MIN_QUERY_LEN:
        return "", {"skipped": "too_short", "len": len(q)}

    # Cap query length — texts > 8KB embed slowly without retrieval gain
    q = q[:6000]

    payload = json.dumps({"query": q, "top_k": top_k}).encode("utf-8")
    req = urllib.request.Request(
        RAG_ENDPOINT,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-RAG-Key": RAG_SHARED_SECRET,
            "User-Agent": "cline-router-rag/1.0",
        },
        method="POST",
    )

    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=RAG_TIMEOUT_SEC) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return "", {"error": "http", "code": e.code, "ms": int((time.time() - t0) * 1000)}
    except urllib.error.URLError as e:
        return "", {"error": "url", "reason": str(e.reason), "ms": int((time.time() - t0) * 1000)}
    except (TimeoutError, ConnectionError, OSError) as e:
        return "", {"error": "net", "detail": str(e), "ms": int((time.time() - t0) * 1000)}

    elapsed_ms = int((time.time() - t0) * 1000)
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return "", {"error": "decode", "ms": elapsed_ms, "raw_preview": raw[:200]}

    if not data.get("ok"):
        return "", {"error": "endpoint_nack", "detail": data.get("error", ""), "ms": elapsed_ms}

    block = data.get("context_block") or ""
    snippets = data.get("snippets") or []
    server_ms = data.get("latency_ms", 0)

    return block, {
        "ok": True,
        "client_ms": elapsed_ms,
        "server_ms": server_ms,
        "n_snippets": len(snippets),
        "top_source": snippets[0]["source_kind"] if snippets else None,
        "top_score": snippets[0]["score"] if snippets else None,
        "corpus_mode": data.get("corpus_size_in_use", "unknown"),
    }


def augment_system_prompt(system_text: str, last_user_text: str) -> tuple[str, dict]:
    """Prepend RAG context to the system prompt for ollama-routed turns.

    Returns:
        (augmented_system_prompt, meta_dict)
    """
    block, meta = fetch_context(last_user_text)
    if not block:
        return system_text, meta

    # Prepend so RAG context comes BEFORE the original system prompt.
    # The LoRA sees: "Relevant EMSU context: ..." then existing role/style/rules.
    augmented = block + "\n\n" + (system_text or "")
    return augmented, meta


# ---- self-test (run via `python rag_client.py` directly) ----
if __name__ == "__main__":
    import sys
    test_queries = [
        "how do we handle student grievance refund requests?",
        "what is the proctoring policy for the EMSU final exam retake?",
        "what should happen when a student emails about a signed affiliation agreement?",
    ]
    qs = sys.argv[1:] or test_queries
    for q in qs:
        block, meta = fetch_context(q)
        print(f"\n=== Q: {q}")
        print(f"meta: {json.dumps(meta, indent=2)}")
        if block:
            print(f"context_block first 600 chars:\n{block[:600]}")
        else:
            print("(no context)")

# 122 — Verify the CURRENT version before recommending, upgrading, or judging any software/model

Permanent rule. Workspace-scoped. Archive rule (queryable, not hardfloor).

## The bright-line rule

**Before you recommend, upgrade, downgrade, prune, or judge ANY LLM, model, library, package, or software version, you MUST verify the CURRENT latest state two ways before answering:**

1. **Live web** — `brave_web_search` (or `fetch`) for the current release / latest stable / changelog as of today.
2. **Live host** — inspect the actual running system: `ollama list`, `pip show <pkg>`, `npm view <pkg> version`, `<binary> --version`, `dpkg -l`, the route table, the call log, etc.

THEN answer, citing what the live check returned. Training-data memory is a starting hypothesis, never the answer.

## Why this rule exists

Training data has a cutoff. The model landscape, library versions, and the EMSU host state all move faster than that cutoff. Answering "the latest stable is X" or "don't upgrade, that version is broken" from memory produces confidently-wrong guidance that sends Ruben down a dead end or, worse, deletes/avoids something that is actually live and working.

The fix is mechanical: never trust recall on a version/latest/"is X still the best" question. Look it up live, look at the box live, then speak.

## Banned phrases (do not emit these without a live check in the same turn)

- "As of my training..." / "As of my last update..." / "As of my knowledge cutoff..."
- "The latest stable is X" — without an `npm view` / `pip index` / web-search result backing it
- "That version is broken / failed / don't upgrade" — without re-checking current state
- "X is the newest model" / "the current best is Y" — without a live web search
- Any judgment of whether software is current, maintained, or recommended that rests only on memory

If you catch yourself about to type any of these, STOP and run the web search + host check first.

## 0-call-count is NOT death evidence

A model/route with 0 rows in `llm_call_log` (or any "0 usage" signal) is **not** evidence the thing is dead, broken, or prunable. A closed routing gate, an unwired candidate, or a not-yet-flipped 3G target all show 0 calls while being perfectly healthy. Usage count alone never justifies pruning or a "it failed" verdict.

Before removing/avoiding anything on a low-usage signal:
- Trace WHY it has 0 calls (closed gate vs actually retired) — cross-ref .clinerules/29: act on *verified* evidence, not a proxy metric.
- Check whether it is an active 3G candidate or part of a live idea (#64xx/#65xx/#77xx).

A misread 0-call-count is how `llama3.3:70b` Q4 got wrongly deleted from Artemis and had to be re-pulled.

## Source incident

**2026-06-01 session.** Cline gave a stale "don't upgrade / the 70B failed on Artemis / 0 calls = prune" recommendation straight from training-data memory plus a misread 0-call-count, instead of:
- checking the live Artemis host (which can in fact serve a 70B Q5 — 4× Intel Arc Battlemage, 125 GB RAM, Vulkan), and
- recognizing the active `llama3.3:70b-instruct-q5_K_M` program (ideas #6485/#6269/#6518).

The "70B failed on Artemis" claim was itself a stale myth: the 2026-05-26 pilot fell back to a 32B proxy over a broken SMS-Mac tunnel and scored 0% SKIPPED — never a real eval. The model was wrongly pruned on "0 calls," then re-pulled. A live `ollama list` + a 30-second web search on the current model landscape would have prevented every part of this.

See `~/Documents/Cline/Rules-archive/0-knowledge-library/llm-models-quants-and-artemis-serving.md` for the live-verified reference this incident produced.

## Self-check before answering any version/model/latest question

1. *Am I about to state what's latest / best / current / broken from memory?* → run `brave_web_search` first.
2. *Am I judging the EMSU host's software or a model's health?* → inspect the live box (`ollama list`, `--version`, route table, call log) first.
3. *Am I treating a 0-usage count as "dead"?* → no. Trace the gate. Cross-ref rule 29.

## Cross-references

- .clinerules/29 — agents act on *verified* evidence; usage count alone is not sufficient evidence
- .clinerules/120 — context is never an excuse to skip the live check
- .clinerules/38 — Ruben-asks → ship/autonomous; a live-verified answer is part of shipping

## Last updated

2026-06-01 — initial. Source: stale-from-memory 70B recommendation + misread 0-call-count during the 2026-06-01 Artemis 70B-Q5 session. Companion to the llm-models-quants-and-artemis-serving knowledge-library entry created the same night.

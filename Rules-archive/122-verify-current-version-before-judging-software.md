# 122 — Verify the CURRENT version live before recommending, upgrading, or judging any model/software

Permanent rule. Workspace-scoped. Source incident: 2026-06-01.

## The bright-line rule

**Before recommending, upgrading, downgrading, or judging ANY LLM, model, software package, or library version, you MUST verify the CURRENT latest version via (a) a live web search AND (b) a live host inspection. Never answer from training-data memory.**

Training data has a cutoff. The model you remember as "newest" shipped months ago; the package you remember as "broken at 0.x" is now at 2.x; the host you remember as "couldn't run the 70B" may be actively serving it right now. Memory is a stale cache. The only valid source for a version/capability claim is live state.

## What "verify live" means concretely

Two independent checks, both required:

1. **Live web search** for the current release. `brave_web_search` ("latest <thing> release 2026") or `fetch` the vendor's releases page / changelog / model card. Get the actual current version string and date.
2. **Live host inspection** of what is ACTUALLY installed/serving right now:
   - Models: `ollama list`, `/api/tags`, the LiteLLM model registry, `orchestrator_llm_routes`
   - Python: `pip show <pkg>` / `pip index versions <pkg>`
   - Node: `npm view <pkg> version` / `npm ls <pkg>`
   - Binaries: `<tool> --version`
   - Fleet/serving state: `fleet_inventory`, `fleet_now`, the lora_fleet dashboard

Only after BOTH return do you form a recommendation.

## Banned patterns

- ❌ "As of my training data, the latest stable is X." — training data is not a version source.
- ❌ "The newest model is X" / "X is the current best" stated without a live web check this session.
- ❌ "Don't upgrade, version X had problems" — recalled from memory, not re-verified against the current release.
- ❌ Judging a model "failed" / "too slow" / "dead" from a recalled benchmark instead of a live smoke test.

## 0-call-count is NOT evidence a model failed

A model showing 0 calls in `llm_call_log` does NOT mean it failed, is broken, or should be removed. The overwhelmingly common cause is a **closed routing gate** — the route weight is 0, a kill-switch is set, or the surface was never wired. Investigate the gate before concluding the model is dead. Cross-ref rule 29: act on verified evidence, and "0 calls" without tracing the routing path is not verified evidence of failure.

## Self-check before any version/capability claim

Ask: *"Am I about to state which version is newest / best / broken, or whether a host can run something, based on what I REMEMBER rather than what I just CHECKED live this session?"* If yes — stop, run the web search + host inspection, then answer.

## Source incident

2026-06-01 — During the Artemis 70B-Q5 backtest task, Cline gave a stale "don't upgrade / the 70B failed" recommendation drawn from training-data memory plus a misread 0-call-count in `llm_call_log`, instead of (a) checking the live host where `llama3.3:70b-instruct-q5_K_M` was in fact installed and serving, and (b) recognizing the active 70B-Q5 pilot program. Ruben flagged the stale-memory answer. The correct move was a live `ollama list` + a live smoke test + a web check of the current llama release — never the cached recollection.

## Cross-references

- .clinerules/29 — agents act on VERIFIED evidence (0-call ≠ dead model; trace the gate)
- .clinerules/120 — context size is never an excuse to skip the live verification
- .clinerules/38 — Ruben-asks → ship the verified answer, don't defer

## Last updated

2026-06-01 — initial. Source: stale-memory 70B recommendation incident during the Artemis Q5 backtest task.

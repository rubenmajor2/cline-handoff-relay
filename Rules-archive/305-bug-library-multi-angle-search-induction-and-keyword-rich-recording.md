# 305 — Bug library: sweep by decomposed keyword angles + induce, and record keyword-rich

Permanent rule. Workspace-scoped. Source: 2026-08-08 — Big Mac (Intel Arc B70, gpt-oss-120b, vLLM XPU PP=3) bring-up. `bug_library_check_before_fix` was called with ONE long exact-symptom sentence and returned NOVEL_SYMPTOM, even though directly relevant incidents existed (#2139 PP=6 lazy-communicator desync, #2123 collective-timeout fix, #2150/#2151 Ray shm_broadcast timeout). The exact-match query shape guaranteed a miss and nearly caused a re-derivation of an already-known failure class. Ruben: "I don't think you're looking at similar issues and then deducing or inducting what you might be able to find... this may be a rule adjustment." + "posting to it probably should be posting with relevant keywords and information. I would like all agents to do this when encountering bugs in the future. The bug library has an incredibly wealthy amount of information."

## The bright-line rule

**A single exact-symptom bug-library query is NEVER sufficient.** `bug_library_check_before_fix` / `bug_library_search` do keyword matching; a long narrative symptom string matches nothing because no recorded incident shares the whole sentence. You MUST decompose into angles, sweep, then induce. One NOVEL_SYMPTOM return from one exact-match string proves nothing.

### SEARCH side — decompose, sweep, induce

Before declaring NOVEL_SYMPTOM (and before re-deriving any fix):

1. **Decompose the symptom into independent keyword angles.** Pull it apart into its component dimensions. Standard angles:
   - **Error type** — the exception/error class (`EngineCore`, `500`, `TimeoutError`, `OOM`, `shm_broadcast`, `EngineDeadError`)
   - **Platform / hardware** — (`XPU`, `Battlemage`, `Arc B70`, `CX7`, `GB10`, `RoCE`)
   - **Model family** — (`gpt-oss-120b`, `GLM-5.2`, `llama3.3`, `Qwen3`)
   - **Parallelism / topology** — (`pipeline parallel`, `PP=3`, `TP=2`, `tensor parallel`, `Ray`, `EP=4`)
   - **Quantization / dtype** — (`MXFP4`, `AWQ`, `FP4`, `bfloat16`)
   - **Component / parser** — (`harmony`, `tool_calls`, `doorman`, `frankenstein-tools`)
   - **Network / collective layer** — (`NCCL`, `XCCL`, `CCL`, `ALLGATHER`, `P2P`)

2. **Sweep: run >=4 `bug_library_search` calls, one per angle** — short 1-3 word queries, NOT the full sentence. These are independent read-only calls; batch them in parallel in one message.

3. **Induce: for each relevant hit, write 2-3 sentences mapping its root cause + resolution onto YOUR case.** Ask: "same failure *shape*? same layer? does its fix apply even though the exact symptom differs?" A PP=6 "decode returns zero tokens" incident IS relevant to your PP=3 "generation 500" — same pipeline-parallel P2P communicator layer. State the mapping explicitly before acting. Cite the incident ID.

4. **Only if EVERY angle returns empty may you declare the symptom novel.** One angle empty means nothing. All angles empty means novel.

### RECORD side — post with keyword-rich, decomposed metadata

When calling `bug_library_record`, the entry is only useful if a future agent's angle sweep can MATCH it. So:

1. **problem_key** = a slug carrying the searchable tokens: `<component>_<platform>_<topology>_<errorclass>_<yyyymmdd>` (e.g. `vllm_xpu_pp3_gptoss120b_enginecore_gen500_20260808`).
2. **symptom** = lead with the decomposed angle terms as discrete tokens (error type, platform, model, parallelism, quantization), THEN the narrative. A future `bug_library_search("pipeline parallel vLLM")` or `("MXFP4 XPU")` should hit your row.
3. **diagnosis / resolution** = name the layer + the exact lever (config flag, env var, cleanup step), not just "fixed it."
4. **evidence** = the log lines / curl output / audit rows that prove it.

A record that only says "generation was slow, restarted and it worked" is unfindable and useless. Record so the NEXT agent's angle sweep lands on it.

## Scope: ALL agents, ALL bugs

This is not LLM-routing-only. Any agent hitting any bug (routing, Moodle, payments, voice, tooling) that consults or records to a bug/knowledge library uses this method. The bug library is institutional memory; its value is the breadth of keyword coverage, which only exists if every agent both sweeps by angle and records by angle.

## Self-check

Before declaring NOVEL_SYMPTOM:
1. Did I run >=4 angle searches (not one exact-symptom string)? If no, do them now.
2. Did I write an induction mapping each relevant hit onto my case, citing incident IDs? If no, do it.
3. Did ALL angles come back empty? Only then is it novel.

Before `bug_library_record`:
1. Does problem_key carry component+platform+topology+errorclass tokens?
2. Does the symptom lead with the decomposed angle terms?
3. Would a future `bug_library_search` on each angle hit this row? If no, enrich keywords.

## Cross-references

- Rule 156 — call bug_library_check_before_fix FIRST (this rule is the HOW for that call)
- Rule 262 — consult bug library + community before recycling (this rule sharpens the library half)
- Rule 297 — classify before you diagnose (the induction IS the classification step)
- Rule 263 — verify-before-claim (the induction must cite real incident IDs)
- Idea #25075 — tooling half (bug_library_search_multi server-side sweep + fuzzy matching)

## Source incident

2026-08-08 — Big Mac bring-up. Exact-symptom `check_before_fix` returned NOVEL_SYMPTOM; the 5-angle sweep returned 6 relevant incidents including the resolved #2123 fix that was directly applied. Ruben directive: make the multi-angle + induction method a rule, and require keyword-rich recording, for all agents.

## Last updated

2026-08-08 — initial.
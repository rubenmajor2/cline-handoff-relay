# 146 — Frankenstein-LLM routes EVERY LLM we own (incl 405B + Mac mini). Cline is PRIORITY. Never re-derive this wrong.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-12 — Ruben, repeatedly ("I've told you about 20 times now"), after a window kept narrowing frankenstein-llm to "5 models / 2 boxes" and treating tunnel-probe failures as "boxes dead." This rule is the durable Cline-side memory so it is NEVER re-derived wrong again.

## The bright-line facts (do NOT re-derive, do NOT assume from old info)

1. **`frankenstein-llm` is the ONE router for EVERY LLM in the system.** Not the 5-member 120B `pool_members` sub-list. Not "the 120B." EVERY model: the 7B/14B/32B local Ollama, the 70B fleet (sms-70b, Joshua, Artemis-70B q4/q5), the 3× 120B (Cesar :11506, Cato :11507, Artemis-120B), the 405B (frankenstein-405b, Augustus+Tiberius TP=2 :11512), the RunPod pods, the qwen coders, DeepSeek, AND the paid heads (Sonnet, Opus, Fable-5). **Plus the Mac mini** (the box Cline's :11505 tunnel rides; it hosts models too). If we own an LLM, it is under Project Frankenstein. That is the entire point of having an efficient router — one door in front of the whole fleet.

2. **Cline traffic is PRIORITY.** When Cline is working, Executor and Orchestrator traffic may be QUEUED behind it. Cline must stay fast. The adapter lane logic: Cline (interactive, NO buffer) spills to the ladder the instant a 120B is busy (FRANK_TOOLS_SAT_INTERACTIVE=1); Executor/Orchestrator (HAVE a buffer) queue on the free local boxes (FRANK_TOOLS_SAT_BATCH=6). Lower SAT = spill sooner. Cline never waits behind batch.

3. **Memory is NOT the constraint; compute is.** A 120B's KV cache holds ~486K tokens (num_gpu_blocks×block_size), only ~20% used in normal operation. The 131K in Cline's settings is PER-CONVERSATION context, NOT a fleet limit. Do NOT lower Cline's context to "save memory" — there's nothing to save. The lever under load is spilling compute across the fleet sooner, never shrinking context.

4. **The free 120Bs were trained to route ABOVE Sonnet/Opus in some cases (W/T ≥ 45%, rule 121 / KIND_TIER_PIN).** A free local model that wins ≥45% of head-to-heads vs the paid model is promoted above it. Never assume paid > free by default — check the W/T scoreboard (llm_router_live.php). Free-local-first is the whole cost-catabolism thesis.

5. **A failed localhost tunnel probe is NOT "the box is dead" (rule 141).** Augustus/Tiberius/405B probe via 127.0.0.1:11508/11509/11512 = reverse tunnels from the Spark boxes to WOPR. HTTP 0 there means the TUNNEL is down, not the box. Ruben has seen the 405B serve. If a probe shows down, the fix is "re-establish the tunnel," NOT "the box is unprovisioned/dead." Never tell Ruben a box is dead from one localhost probe — verify the box directly or say "the tunnel endpoint is down."

## Why this keeps getting forgotten (and the fix)

A fresh Cline window reads the registry `pool_members: [5]` (the 120B SUB-pool) and the narrow config ladder, and concludes "frankenstein-llm = 5 models." That is the trap. The WHOLE-fleet truth lives in `docs/PROJECT_FRANKENSTEIN.md` ("the frankenstein-llm entrypoint rides the spill ladder across ALL models by health: 7B→14B→32B→70B→120B→pod→DeepSeek→Sonnet→Opus. NOT just the 120B") and now in THIS rule. Read both BEFORE reasoning about Frankenstein routing. The project-frankenstein MCP `now`/`failover`/`routing_map` actions are the live truth (rule 141) — call them first.

## Self-check before ANY statement about Frankenstein routing

1. Am I about to say frankenstein-llm "only has N models / is just the 120B"? → WRONG. It routes the whole fleet. Re-read this rule + PROJECT_FRANKENSTEIN.md.
2. Am I about to tell Ruben a box is "dead/unprovisioned" from a localhost probe? → STOP. That's a tunnel-probe failure (rule 141). Say "tunnel endpoint down," not "box dead."
3. Am I treating paid > free as default? → Check W/T (rule 121). Free local may be promoted above paid.
4. Am I about to lower Cline's context to save memory? → There is no memory pressure (KV ~20% used). Don't.
5. Is Cline staying priority over Executor/Orchestrator? → Yes, always. Queue batch, never Cline.

## Cross-references

- `docs/PROJECT_FRANKENSTEIN.md` — the canonical architecture (read FIRST, rule 141)
- Rule 141 — call the project-frankenstein MCP before answering; never declare a box dead from one tunnel probe
- Rule 140 — verify routing from live headers, not files
- Rule 142 — no dead-end ladder rungs (every rung a real config model)
- Rule 121 — W/T ≥45% ship floor: free local promoted above paid
- Rule 92 — fix at the core (the router/ladder, not band-aids)
- Ideas #11943 (full-fleet ladder), #11942 (Cline-priority spill), #11944 (adaptive decode-health saturation), #11941 (registry/terminology)

## Last updated

2026-06-12 — initial. Source: Ruben, ~20th time correcting "frankenstein-llm routes everything, Cline is priority, the boxes aren't dead, stop re-deriving." Hardened into a read-at-runtime rule so it is never forgotten again.

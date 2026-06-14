# 146 — Frankenstein-LLM routes EVERY LLM we own (incl 405B + Mac mini). Cline is PRIORITY. Never re-derive this wrong.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-12 — Ruben, repeatedly ("I've told you about 20 times now"), after a window kept narrowing frankenstein-llm to "5 models / 2 boxes" and treating tunnel-probe failures as "boxes dead." This rule is the durable Cline-side memory so it is NEVER re-derived wrong again.

## The bright-line facts (do NOT re-derive, do NOT assume from old info)

1. **`frankenstein-llm` is the ONE router for EVERY LLM in the system.** Not the 5-member 120B `pool_members` sub-list. Not "the 120B." EVERY model: the 7B/14B/32B local Ollama, the 70B fleet (sms-70b, Joshua, Artemis-70B q4/q5), the 3× 120B (Cesar :11506, Cato :11507, Artemis-120B), the 405B (frankenstein-405b, Augustus+Tiberius TP=2 :11512), the RunPod pods, the qwen coders, DeepSeek, AND the paid heads (Sonnet, Opus, Fable-5). **Plus the Mac mini** (the box Cline's :11505 tunnel rides; it hosts models too). If we own an LLM, it is under Project Frankenstein. That is the entire point of having an efficient router — one door in front of the whole fleet.

2. **Cline traffic is PRIORITY.** When Cline is working, Executor and Orchestrator traffic may be QUEUED behind it. Cline must stay fast. The adapter lane logic: Cline (interactive, NO buffer) spills to the ladder the instant a 120B is busy (FRANK_TOOLS_SAT_INTERACTIVE=1); Executor/Orchestrator (HAVE a buffer) queue on the free local boxes (FRANK_TOOLS_SAT_BATCH=6). Lower SAT = spill sooner. Cline never waits behind batch.

3. **Memory is NOT the constraint; compute is.** A 120B's KV cache holds ~486K tokens (num_gpu_blocks×block_size), only ~20% used in normal operation. The 131K in Cline's settings is PER-CONVERSATION context, NOT a fleet limit. Do NOT lower Cline's context to "save memory" — there's nothing to save. The lever under load is spilling compute across the fleet sooner, never shrinking context.

4. **The free 120Bs were trained to route ABOVE Sonnet/Opus in some cases (W/T ≥ 45%, rule 121 / KIND_TIER_PIN).** A free local model that wins ≥45% of head-to-heads vs the paid model is promoted above it. Never assume paid > free by default — check the W/T scoreboard (llm_router_live.php). Free-local-first is the whole cost-catabolism thesis.

5. **A failed health probe is NOT "the box is dead" — SERVED-TRUTH beats a /v1/models GET (rule 141 + 140).** Augustus/Tiberius/405B probe via 127.0.0.1:11508/11509/11512. A raw host-shell `curl /v1/models` there returns HTTP 0 AND registry_health shows DOWN — YET the 405B serves live (verified 2026-06-12: router audit log `picked=frankenstein-405b` 5× in one minute; llm_router_live.php shows frankenstein-405b served a real case, FREE, L4). Why: LiteLLM runs in Docker and reaches :11512 via its own network path; the host-localhost GET and the health-probe cron do NOT. So the probe is a FALSE-NEGATIVE. **The ground truth that a model is alive is the router audit log (`picked=X`) + the served-cost header (rule 140), NOT a /v1/models GET.** NEVER tell Ruben a box is "dead/down/unprovisioned" from a probe — first check `/tmp/emsu_router_audit.log` for recent `picked=<that model>` and the llm_router_live.php "what served" panel. If it served in the last few minutes, it is ALIVE regardless of what the probe says. (Source incident: I called the 405B "tunnel down / unprovisioned" TWICE from the false probe; Ruben showed the router page proving it was serving. Filed #11952 to fix the probe.)

6. **A STORED FLEET/REGISTRY NOTE IS A HYPOTHESIS, NOT TRUTH — and Ruben's direct correction OVERRIDES it on the FIRST turn.** Source incident 2026-06-14: Ruben asked "are the M4 2024 Mac's LLMs in the frankenstein-llm rotation?" A window read the `fleet_inventory.mac_ruben` free-text note ("M4 Mac... 16GB RAM, excluded from LLM serve fleet by design") and repeated it as fact THREE times, even after Ruben said "that's not correct, it has 64GB" and "it has a qwen 32B as well as a 7 or 14B." The note was WRONG (a sibling window had conflated the MacBook Pro with the M4 and stamped it as durable "by design" metadata). Rules: (a) hardware specs (RAM, models_served) and "excluded by design" claims are only true if they came from a LIVE PROBE or from Ruben, never from a sibling window's guess written into a note; (b) the instant Ruben states a fact that contradicts a stored note, RUBEN WINS, stop re-citing the note, correct the data at the source, and act; (c) if you cannot live-probe a box (SSH/tunnel down), the fallback is "deferring to Ruben's stated specs," NOT "repeating the old note." Re-asserting a contradicted note is both a rule-140 violation (note = hypothesis) and a rule-29 violation (arguing instead of acting). M4 ground truth: 64GB, serves qwen2.5-coder:32b/14b/7b, LLM-serve-ELIGIBLE, un-enrolled only because WOPR:2224 SSH + the ollama tunnel are down (#12425); once restored, frank_registry_autosync auto-enrolls it (rule 152). Fixed the bad fleet_inventory rows this date.

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

# Rule 322 Case Law — Mechanical Amendment Trail (trim-then-archive, 2026-08-19)

Moved from Rules/322-what-was-serving-single-table.md (2 amendments).

## Amendment (from reversal, 2026-08-19 06:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787098931968
- RCA bucket: stale assumption
- Trigger pattern: Quoting a registry rung name (cato-120b) as the serving backend without resolving router-audit picked + live process truth; stale fleet labels treated as serving models
- Reversal note: Completion claimed 'frankenstein-llm -> cato-120b clean tool call' but there is no Cato 120B: router audit shows req frankenstein-llm picked frankenstein-tools (federation, GLM-first on all lanes), and the underlying physical model is the GLM-5.2 hex ring PP=6 (Pompeii-50c0/Marcus-63ce/Tiberius-e9e0/Cesar-3b41/Cato-2aa8/Augustus-e3b2, Cato=rank 0, 671 tok/s aggregate off cato :8210/metrics). 'cato-120b' is a stale registry rung annotation (frankenstein_registry.yaml lines 117/244). Amendment: a registry rung name or probe-header backend label is a ROUTING NAME, never a physical model; before quoting what served, resolve via router audit picked field + federation upstream truth + live ps; Cato/Cesar claims must name the GLM ring, not 120B.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 10:31 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787126689836
- RCA bucket: insufficient probe
- Trigger pattern: Answering "which model is serving this window" with per-box capability benchmarks instead of joining router-audit picked + adapter upstream log + /v1/models per turn for the caller's own surface; and 
- Reversal note: Asked "which model are we actually hitting in Cline", I had spent the prior hour benchmarking BOXES (per-upstream tok/s, ring concurrency, host health) and could not answer the question, because a box benchmark says what a box CAN do, not what THIS caller's turns WERE routed to. The answer took one join I had not made: router audit (req -> picked, surface="Cline Main") to get the routing name, then the adapter upstream log for the SAME minutes to get the physical upstream per turn, then /v1/models on each upstream to name the served model. That join showed the window split between gpt-oss-120B at 5-24s and the GLM-5.2 ring at 191-194s, and the ring's own canary was logging DECODE_STALL median 0.00 tok/s while EMSU_GLM_FIRST_ALL_LANES=1 forced interactive turns onto it. Amendment: to answer "what is serving THIS caller", the required probe is the per-turn join of router-audit picked + adapter upstream log for the same timestamps + /v1/models on the resolved upstream, filtered to the cal

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

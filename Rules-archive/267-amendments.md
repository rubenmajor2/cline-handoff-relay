Rule 267 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 267 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/267-orchestrator-executor-offload-and-reconcile.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 3 amendment(s))

## Amendment (from reversal, 2026-08-20 03:12 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 26422FT-18-r317b
- RCA bucket: stale assumption
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: 2026-08-19 within-window reversal: completion tagged idea 27658 [proposed] from filing-time memory while the live orchestrator_ideas record had flipped to rejected (pipeline auto-reject, no reason recorded). Amended behavior: disposition tags must come from a live read of orchestrator_ideas (status, dev_stage) in the same window; when reconcile_ideas times out, a direct read of those columns is an acceptable reconcile substitute and must be cited as (verified: direct read). A rejected idea is tagged [rejected] and, if the work is still open, a replacement idea is filed and cited instead.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 06:52 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-improvements-browser-report
- RCA bucket: stale assumption
- Trigger pattern: approved buildable idea carried across windows as an executor deferral instead of being built in-window
- Reversal note: Within-window reversal: Argus improvements window verified #27672 (approved 2026-08-19, both parts buildable in-window) had been deferred to the executor queue TWICE instead of built. Part (a) was already shipped by another window under #27646 B-6; part (b) was built and deployed in-window in ~10 tool calls once actually attempted. Amended behavior: when a GATE B reconcile or a new-window pickup surfaces an approved idea whose spec names concrete files/queries, the window MUST build it in-window per GATE A0 before doing anything else; 'it is already filed' is never a reason to defer buildable work.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 07:00 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-improvements-browser-report
- RCA bucket: stale assumption
- Trigger pattern: reconcile_ideas tag trusted over a direct DB read after a promote call returned ok without writing
- Reversal note: Within-window reversal: reconcile_ideas reported #27697 [executing] (status=in_progress) at 23:46 PT, but a direct mysql SELECT at 23:57 PT showed status=rejected with updated_at 23:00:01 and every reason column NULL. idea_promote_and_run(27697) had returned ok:true at 23:46 but never wrote the row (updated_at unchanged). Amended behavior: after idea_promote_and_run or create_idea returns ok, verify the write with a direct SELECT of status/dev_stage/updated_at before tagging; when a reconcile tag contradicts a direct DB read, the direct read wins. A rejected idea is tagged [rejected] and a replacement idea is filed and cited (done: #27712).

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

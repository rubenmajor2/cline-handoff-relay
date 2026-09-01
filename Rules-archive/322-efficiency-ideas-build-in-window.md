# 322 — Approved efficiency/capacity ideas BUILD IN-WINDOW, never parked in the executor

Permanent rule. Source: 2026-08-15 Ruben directive (verbatim intent): "if we are increasing capacity and that has already been approved, those ideas actually need to be built and shipped within that window. Things that structurally increase efficiency on a massive scale should be built and shipped immediately... those are top priorities that should not be handed off to the executor, but rather built within that exact window. It's fine to use rule 267 to help drive it and then take over at the end the iteration, but it is not acceptable to just leave it in the executor especially when it has to do with efficiency."

## The gate

When a task touches an idea that is BOTH (a) approved (by Ruben or by prior directive) AND (b) a **structural efficiency/capacity increase** — routing/adapter improvements, throughput levers, worker-pool math, fleet-wide behavior layers (e.g. Virtual LoRA), context/cost reducers, automation that removes a human bottleneck — then:

1. **The window that holds the idea BUILDS it, this window, end to end.** Not "re-queued to the executor," not "watch the executor pick it up," not `[executing]` in a pickup prompt.
2. **Using rule 267 to drive it is fine as a speed lever** (fire the executor, let it generate spec/patches in parallel) — but the WINDOW takes over at the end of the iteration and ships it. The window owns the deploy, the verify, and the `[deployed]` tag.
3. **If the executor's release guard holds it** (autonomous_idea_needs_verify, regression_risk_review, no_code_patches misread), that is NOT a park signal — it is the GATE C hand-ship trigger. Apply the patches (or your own better version) by hand, verify live, tag `[deployed]`.
4. **A pickup prompt that says "watch the executor" for an approved efficiency idea is a violation of this rule.** The canonical failure (source incident): Virtual LoRA v2 #26461 sat with green patches + passing tests through THREE guard holds while windows kept re-queueing it and writing "watch the executor pick it up" — Ruben had to steer to get it built. It was then hand-shipped in ~6 minutes.

## Why efficiency ideas get this special treatment

Efficiency/capacity ideas are the multiplier class: they raise the throughput of ALL future work. Every hour one sits in the executor queue is an hour of compounded lost throughput across every agent and surface. A student-ops fix affects one student; an adapter-layer fix affects every request. That asymmetry is why they jump the queue and get built inline.

## The test (run when reconciling any approved idea)

*"Does this idea, once live, make the SYSTEM faster/cheaper/higher-capacity (vs fixing one case)?"* If yes AND it is approved AND this window has the tools → build it now. GATE A0 of rule 267 (build-here-first) already covers the general case; this rule removes ANY discretion for the efficiency class specifically.

## Cross-refs

- Rule 267 GATE A0 (build-here-first) + GATE C (blocked-executor hand-ship) — this rule is the efficiency-class specialization with zero discretion
- Rule 161 — approved means executing, never parked
- Rule 300 — end-to-end delivery, a filed idea is not a deliverable
- Rule 29 — agents default to action

## Source incident

2026-08-15 — Virtual LoRA v2 (#26461): approved, patches generated, tests green at 01:27 PT; held by release guard 3x; re-queued at 11:48 with a "watch the executor" pickup thread; Ruben steered at 12:23 ("This needs to actually be executed here and now"); hand-shipped and verified live (VIRTUAL_LORA applied log line) at 12:29 PT — 6 minutes of actual work after ~11 hours of queue-sitting.

## Last updated

2026-08-15 — initial. Ruben directive, same-session codification.

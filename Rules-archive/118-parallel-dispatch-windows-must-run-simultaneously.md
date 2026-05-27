# 118 — When Ruben asks for multiple copy windows, they MUST run simultaneously

Permanent rule. Workspace-scoped.

## Source incident

2026-05-26 task `cline_fleet_llm_coordinator` — Ruben dispatched 6 parallel Cline windows for fleet/LLM stabilization (Windows A-F), expected them to run in parallel. Cline then issued follow-up windows (M, C-rerun, L) with implicit dependencies ("dispatch L AFTER M+C land"). Ruben pushback verbatim:

> *"I need copy windows to run all at once. I don't have time to babysit windows. Cline rules. When I ask for multiple copy prompts or windows I need them to all be able to be ran simultaneously"*

## The bright-line rule

**When Ruben asks for N copy windows / dispatch prompts in a single turn, EVERY one of those windows MUST be safe to run in parallel right now, regardless of order.** No "wait for X to complete before dispatching Y." No "Window L is queued for after M+C land." Every prompt is fire-and-forget the moment Ruben pastes it.

## What this means in practice

1. **No serialized dependencies in the dispatch turn.** If Window B genuinely needs data from Window A, restructure so A produces a persistent artifact (DB row, scorecard file, status flag) and B reads-or-degrades-gracefully if A hasn't landed yet. The artifact handoff happens through the DB / filesystem, not through Cline-window timing.

2. **Idempotency is mandatory.** Each window must be safe to run multiple times. Re-running shouldn't double-ship code, double-file ideas, or corrupt state. Use INSERT ... ON DUPLICATE KEY UPDATE, status checks before writes, file-exists guards.

3. **Collision avoidance is explicit, not implicit.** Each dispatch prompt must declare in plain text:
   - "This window writes to: <files / DB tables / config>"
   - "This window does NOT touch: <files / DB tables that other parallel windows own>"
   - "If <collision-prone resource> is mid-write by another window, this window skips/defers gracefully."

4. **Hard guards on shared resources.** If two windows might both want to write `/etc/litellm/config.yaml`, ONE owns it and the others read-only. If two might both update `lora_fleet_routing_state` for the same row, use SELECT ... FOR UPDATE or skip if already touched in last N minutes.

5. **No "ETA after Window X" timing.** Every window's success criteria must be measurable independently (its own DB row, its own scorecard, its own log file).

## The 3-question self-check before dispatching N parallel windows

Before sending N prompts in one turn, ask:

1. *"If Ruben pastes all N right now, will any two of them write to the same file or DB row in conflicting ways?"* If yes → restructure.
2. *"Does any window's first tool call require data that another window produces?"* If yes → restructure so the reader degrades (skip-or-wait, not fail).
3. *"Is each window idempotent — safe to re-paste if Ruben accidentally double-fires it?"* If no → add guards.

If all three answers are clean, the N windows are parallel-safe. Send them.

## Anti-patterns that violate this rule

- ❌ "Dispatch Window A first. Once it lands, dispatch B."
- ❌ "Window L: run AFTER Window M and C-rerun complete."
- ❌ "Estimated total elapsed: M+C in parallel ~1h, then L for 2h."
- ❌ "Window B's first tool call: read the scorecard Window A wrote." (B should: read scorecard if exists; otherwise log + skip; rerun-safe)
- ❌ Two windows both safe_deploy_file the same target path.
- ❌ Two windows both UPDATE the same `orchestrator_ideas.id` row without optimistic-lock check.

## Good shape

- ✅ Window A writes to /var/www/emtskills/lib/EmailAIResponder.php; Window B writes to /var/www/emtskills/lib/SMSAIResponder.php. Different files, parallel-safe.
- ✅ Window A files orchestrator_ideas row; Window B reads any new ideas filed since 1h ago via SELECT. B doesn't block on A.
- ✅ Window A and B both update fleet_decision_log via INSERT (append-only). No row collision.
- ✅ Both windows use SELECT FOR UPDATE NOWAIT on the shared row, and skip cleanly if the lock can't be acquired. No deadlocks.

## Why this rule matters

Ruben's bandwidth IS the constraint. If he has to gate-keep dispatch order, that's the bottleneck — defeats the purpose of multi-window parallel execution. Every "dispatch L after M" sentence in the playbook costs him 30-60 minutes of waiting for the cue. The fix is structural: write the windows so the order doesn't matter.

## Cross-references

- `.clinerules/29` — agents-act-on-confidence-tier (each parallel window IS an agent with its own action gates)
- `.clinerules/38` — Ruben-asks = autonomous-or-shipped (dispatching N windows IS the autonomous-tier authorization)
- `.clinerules/41` — post-deploy-call-the-tool (each window's first tool call must be concrete)
- `.clinerules/91` — every-completion-needs-pickup-prompt (each window ends with a pickup prompt; they don't share state through the coordinator thread)

## Last updated

2026-05-26 17:12 PT — initial rule. Source: cline_fleet_llm_coordinator session where Cline kept inserting "do A first, then B" serialization into multi-window dispatches. Ruben's correction quoted verbatim above.
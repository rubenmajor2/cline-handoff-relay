# Cluster Surfacing — Close the Improvement Loop

**Severity: HARDFLOOR**
**Applies: ALWAYS**
**Created: 2026-08-29** (original intent per prior Cline Learner check-in) — **Actual file shipped + verified 2026-08-29 22:20 PT** by a later window that found the prior "shipped" claim was false: the file existed nowhere (local Rules dir, archive, server corpus, FTS index). This file is the real artifact closing that gap. See Rule 317 amendment log for the reversal.

## Core Principle

Ruben's improvement loop is "agents act, RUBEN learns, the loop closes." The cluster-session is where groupable ideas live. When a window starts any task, it must surface the clusters that relate to that task and act on them — otherwise approved, clustered work sits invisible in the ideas pipeline forever.

## Mandatory behavior (every new task)

1. **At task start, call `list_clusters`** (ruben-orchestrator MCP). Surface the cluster list once, as context.
2. **If a cluster matches the task's domain** (topic keyword overlap in the cluster title/description), DO NOT just recite it:
   - Call `get_cluster_recommendation(cluster_id=...)` to read the WHY narrative.
   - If the cluster contains member ideas relevant to the current task, reference the member idea IDs in the completion (with rule-91 disposition tags).
   - If the cluster is approved-ready and actionable in-window, act on it (rule 29: agents act on confidence tier; rule 161: approved means executing).
3. **If no cluster matches**, that is a legitimate outcome — state "no matching cluster this task" once. Do not invent a match.
4. **Never hand-derive idea dispositions** — always reconcile (reconcile_ideas) so tags reflect live server state.

## Why this exists (observed failure)

The 2026-08-29 check-in: clusters were never surfaced to Cline. Ideas sat inside cluster#29 (silent-ghost/blocker watchdog meta-fixes) and cluster#21 (DEADMAN promises) with no window acting on them, because no rule forced the cluster view into every new task's start. A hardfloor rule is the durable fix: cheap to comply with (one MCP call per task), impossible to skip without a visible gap.

## Verification requirement (rule 317 pairing)

Any claim that a rule was shipped must be backed by `clinerules_lookup` or `read_file` of the actual rule file — a corpus stats count (e.g., "353 rules") alone is NOT evidence a specific rule exists. This file exists because a prior window violated exactly that.

## Cross-references

- Rule 29 — agents act on confidence tier (the action half of "close the loop")
- Rule 161 — ideas never queued; approved means executing
- Rule 267 — reconcile ideas before completion (GATE B)
- Rule 91 — pickup prompt must carry real idea #s with server-derived dispositions
- Rule 317 — verify-before-claim; a "shipped" claim needs a probe showing the artifact
- Rule 300 — end-to-end delivery: no deferring buildable work

## Last updated

2026-08-29 — created (as the real artifact; prior claimed-shipped copy was fabricated).
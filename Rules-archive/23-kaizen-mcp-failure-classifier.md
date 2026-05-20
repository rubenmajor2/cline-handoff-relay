# 23 — KAIZEN MCP: when to reach for it (failure-classifier nurturer)

Permanent rule. Workspace-scoped. Source incident: 2026-05-05 #1777968053585
follow-up — kaizen MCP was wired into both Mac and Artemis Cline but no
`.clinerules` file documented when to use it, so it stayed dormant while the
exact problems it exists to solve (rule-22 self-supervision loops, rule-99
YOLO retry traps) were happening live in adjacent windows.

## What KAIZEN is

KAIZEN is a workspace-scoped MCP server that **classifies recurring failures
in autonomous-agent logs and proposes/seeds repair recipes**. It's the runtime
companion to `.clinerules/22-executor-self-supervision-loops.md` — that rule
is the policy ("every executor needs a classifier + recipe table + retry
consumer + kill switch"), KAIZEN is the live tool that nurtures the
classifier and the recipe table for each agent.

Lives at `http://localhost:7861/mcp` on Mac (forwarded via tunnel to WOPR's
mcp-kaizen.service on port 7851). Same alias `kaizen` exposed on Artemis at
`http://localhost:7851/mcp`.

## When to reach for KAIZEN — the 5 trigger cases

1. **An autonomous executor has a chronic high-rate failure mode and you
   don't know why.** Run `kaizen_session_summary` first. It returns coverage
   %, classifier distribution, and recently-seeded recipes for the named
   target (default: ruben_executor). If coverage is below ~80%, the
   classifier has gaps.

2. **You're triaging "why does this executor keep silent-ghosting / 
   replanning forever / racking up cost?"** Run `kaizen_scan_failures` with a
   short lookback (e.g., minutes=60) to see the last failures with
   classification labels. Unclassified rows mean rule 22 layer 1
   (classification) is broken for that target. Classified rows but no recipe
   match mean rule 22 layer 2 (recipe table) is incomplete.

3. **You're about to write a new failure_category by hand.** Run
   `kaizen_propose_classifier_rule` first — it groups the unclassified
   error_text patterns and proposes category names + detection regexes that
   match the dominant ones. This avoids the "I made up a category that
   matches 1 row out of 200" mistake.

4. **You just shipped a classifier patch + a recipe row, and want to label
   historic data.** Run `kaizen_backfill_pattern` with a SQL LIKE pattern to
   write the new category onto NULL/empty/unclassified historic rows. Use
   `dry_run=true` first to verify the count of matches.

5. **You're pointing KAIZEN at a NEW agent target for the first time.** Run
   `kaizen_describe_target` with the agent name — it returns the table/column
   mapping the classifier needs and tells you what's missing. Always do this
   before any other KAIZEN call against an unfamiliar target.

## When NOT to reach for KAIZEN

- One-shot bugs. KAIZEN exists for **recurring** failure patterns. A single
  ticket about a single student doesn't need a classifier rule.
- Front-of-house bugs (UI, route, email rendering). KAIZEN classifies
  agent-execution failures, not user-facing rendering.
- Anything that's not actually persisted in a "failure log" table. KAIZEN
  needs a target with rows that have an error_text/category/timestamp shape.
  Check via `kaizen_describe_target` first.
- When you're already neck-deep in a triage loop and the right move is to
  look at the live execution log directly — KAIZEN is for the
  pattern-recognition layer, not raw forensics.

## Workflow shape (the canonical sequence)

When a user says "this executor keeps doing X and we don't know why":

```
1. kaizen_session_summary         → coverage %, distribution, recent recipes
2. kaizen_scan_failures hours=24  → see what's actually failing
3. (read a representative error_text + check classifier source code)
4. kaizen_propose_classifier_rule → get a proposed regex + category name
5. (Cline edits the classifier source PHP/Node/Py to add the rule)
6. kaizen_seed_recipe             → wire the new category to a retry strategy
                                     (replan_compact / escalate_blocked / ...)
7. kaizen_backfill_pattern dry=t  → check how many historic rows now match
8. kaizen_backfill_pattern dry=f  → label historic rows
9. (Cline ships the classifier patch via safe-deploy)
10. kaizen_session_summary        → confirm coverage % moved up
```

If at step 1 the coverage is already ≥90%, the classifier doesn't have a
visible gap and the failure mode is somewhere else (config, rate-limit, bad
plan input). Don't add a rule just because you can — the false-positive
classification cost is high.

## Ground-truth invariants

- KAIZEN tool calls are **read-mostly** except for `kaizen_seed_recipe` (writes
  one DB row) and `kaizen_backfill_pattern` (writes many rows). The rest are
  reports/proposals.
- `kaizen_propose_classifier_rule` does NOT modify code or DB. Output is a
  JSON proposal you review and ship via the normal classifier patch +
  `kaizen_seed_recipe` flow.
- Targets registered in the KAIZEN registry: `ruben_executor` is the canonical
  one (orchestrator_execution_log on admin_portal). New targets need
  `kaizen_describe_target` first.

## Cross-references

- `.clinerules/22-executor-self-supervision-loops.md` — the policy KAIZEN
  enforces.
- `.clinerules/99-yolo-prevention-learned.md` — the per-rule playbook the
  yolo_learner cron generates by analyzing similar logs (Cline-task-side, not
  agent-execution-side).
- HANDOFF_NOTES.md on WOPR for the most recent KAIZEN target list +
  classifier coverage by target.

## Self-check before any non-trivial autonomous-agent triage

Ask: **"Is this a one-shot bug, or has this failure mode shown up 3+ times in
the last week?"** If 3+ times, KAIZEN is the right first move. If one-shot,
fix the one bug and move on; don't over-engineer a classifier for a
non-recurring case.

## Last updated

2026-05-05 04:03 PT — initial rule. Source: KAIZEN MCP wired to both Mac and
Artemis but never documented as a tool to reach for, so it stayed unused
while rule-22-class problems happened in adjacent Cline windows. Filed as
part of #1777968053585 Mac-Artemis parity work.

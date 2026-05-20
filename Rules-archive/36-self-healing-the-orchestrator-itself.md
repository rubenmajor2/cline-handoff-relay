# 36 — When the failure IS the orchestrator's design gap, repair wins over escalation

Permanent rule. Workspace-scoped. Source: 2026-05-10 alert triage —
Ruben got 7 emails on 3 trivially-fixable bugs (cline-fleet snapshot newline-
in-JSON, StudentJourneyNotes.php case mismatch, lib/*.php mode 600 blocking
www-data). RUBEN saw all 7 and escalated each because no `learned_pattern`
row matched. Per .clinerules/22 layer 1 ("classification first, retry
second"), RUBEN was working as designed — but the design was producing
exactly the email noise it exists to prevent.

Ruben's correction: *"The design, the ultimate design method wins. When
it comes to bugs like this it's better for the repair to take place. That
should be a general rule with one caveat: there should be some analysis on
the repair to ensure that when the repair is done that it does not violate
the business logic with a similar confidence as RUBEN would normally have."*

This rule encodes that.

## The bright-line rule

**When a failure is itself the orchestrator's design gap (RUBEN/KAIZEN exists
to act on this class but has no pattern row to match against), Cline acts at
RUBEN-equivalent confidence WITHIN the same business-logic envelope RUBEN
would apply, then records the audit trail RUBEN would have written.**

The orchestrator's purpose wins over its current pattern-table state. A bug
that escalates because RUBEN has never seen its fingerprint before is not a
"this needs human judgment" case — it's a "RUBEN needs a pattern row, but
the repair is independent of that" case. Don't conflate the two.

## When this rule applies (all four must be true)

1. **The failure is the orchestrator's own job class.** RUBEN/KAIZEN/Bug
   Hunter/exec watchdog/cron self-heal would have been the right system to
   handle this if a pattern row existed. Examples that qualify:
   - Snapshot/telemetry parser failures
   - Missing-file errors with an obvious sibling on disk (case mismatch,
     stale require path)
   - Permission-denied on lib files where the FPM user is in the owning
     group already (mode upgrade only)
   - Stuck lock files past TTL where the holding process is already gone
   - Cron false-positive watchdog alerts where the underlying cron is
     verifiably healthy
   - Self-heal cron's own bugs that prevent it from self-healing

2. **The repair has clear business-logic isolation.** None of these touch:
   - Money (Authnet, QB invoices, refunds, Affirm, payment_suspensions)
   - Student-facing email/SMS/voice (per rule 15, 31)
   - Moodle gradebook, suspensions, or course access for a real student
   - Regulator/grievance/legal-grade comms (per rule 08)
   - External API credentials, OAuth tokens, vault entries
   - User accounts, roles, permissions on the admin portal

3. **The repair is reversible in <30 seconds via a single command.**
   File-mode flip, symlink delete, lock-file unlink, hosts-file revert,
   safe-deploy with backup file, single-row DB UPDATE with prior value
   captured.

4. **Confidence ≥ 0.85 against business-logic match.** Not just
   "the technical fix works" — also "the technical fix doesn't accidentally
   touch a different business-logic surface." See the analysis template
   below.

If any of those four are not met → escalate or Q-card per rule 29. The bar
is intentionally narrow.

## The required confidence analysis (do this BEFORE acting)

Before applying the repair, document the four-axis check (in
`attempt_completion` body, in HANDOFF_NOTES, or as an internal ticket
comment — wherever the next agent will see it):

```
REPAIR ANALYSIS (rule 36)
1. Failure class:    [snapshot parser / missing file / permission / lock / cron false-positive / self-heal-of-self-heal]
2. Business surface: [telemetry only / lib infra only / cron infra only / ...] -- must NOT include money/students/Moodle/regulator
3. Repair action:    [exact command(s) being run]
4. Reversal command: [exact command to undo, runnable in <30s]
5. Confidence:       [0.85-1.00] -- if below 0.85 on ANY axis, do NOT act
6. Why orchestrator missed it: [no learned_pattern row / no recipe / classifier didn't match / sub-threshold confidence]
```

If the repair changes a code file, the safe-deploy backup IS the reversal.
If it's a chmod, the prior mode IS the reversal. If it's a symlink, `rm` IS
the reversal. Always state it explicitly so a future agent (or Ruben) can
unwind without thinking.

## After acting: feed RUBEN so it doesn't ask again

This is the part that closes the loop. Cline acted because RUBEN had no
pattern row. To prevent the same pattern landing in Ruben's inbox next
week, also do:

1. **Insert one `orchestrator_learned_patterns` row** with:
   - `pattern_hash` — descriptive slug, e.g. `snapshot_unparseable_cline_fleet`
   - `event_type` + `event_source` — match what watchdog produces
   - `keyword_pattern` — short regex / substring that will catch siblings
   - `dominant_action` — what RUBEN should do next time
   - `confidence` — what Cline computed in step 5 above
   - `auto_enabled=1` if confidence ≥0.90 AND repair is genuinely idempotent
   - `auto_promote_class=safe_no_op` for telemetry/infra only;
     `standard` for anything that touches services
2. **Insert one `failure_repair_recipes` row** if a fixed remediation
   sequence exists, with `detection_pattern`, `planner_input_modifier`,
   `retry_strategy`, `max_attempts`. Per rule 23 (KAIZEN).
3. **Append one row** to `cline_task_ledger.md` per rule 07 with
   `task_id` = the umbrella slug (e.g. `#orchestrator-self-heal-gap-2026-05-10`).
4. **`attempt_completion` body** lists which patterns were seeded so Ruben
   knows the loop is closed.

This converts a one-off Cline repair into a permanent RUBEN capability. The
SECOND time the fingerprint hits, RUBEN handles it without anyone seeing an
email.

## What this rule does NOT change

- Per rule 29, money / students / Moodle / regulator / legal stays
  Q-card-only. No exceptions even if the repair seems trivial.
- Per rule 15, no student-facing AI surface change is ever covered by this
  rule. AI prompt rules go through the curated `ai_compiled_rules` path
  with `clinerules:` source guard.
- Per rule 31, anything that commits the human-owned SLA queue (Vicky,
  Jon, Cori) on the user's behalf stays a handoff, not autonomous.
- Per rule 08, regulator/NOI work is never covered. Always counsel-grade
  posture.

This rule is specifically for the **infra/telemetry/permission/case-mismatch
class of bug where the orchestrator was supposed to be the actor but
couldn't because of its own design gap**. Stay in that lane.

## Voice in the wrap-up

When acting under this rule, the `attempt_completion` body should:

1. State up front "applying rule 36" so Ruben knows this is the
   self-heal-the-orchestrator path, not blanket autonomy creep.
2. Show the 6-line REPAIR ANALYSIS verbatim. Don't paraphrase.
3. Show what was seeded into `orchestrator_learned_patterns` /
   `failure_repair_recipes` / `cline_task_ledger.md` so the gap is closed.
4. State the reversal command for each repair, plain English.

## Cross-references

- Rule 17 — default-on subagent dispatch (use a subagent to verify the
  business-logic isolation if the surface is unfamiliar)
- Rule 22 — executor self-supervision loops (the policy this rule
  operates inside)
- Rule 23 — KAIZEN MCP (the tool to use after seeding the pattern)
- Rule 29 — agents act on confidence tier (rule 36 is the
  same-confidence variant for orchestrator-internal bugs)
- Rule 32 — prefer dedicated MCP wrappers (the MCP path to seed
  patterns + recipes safely)

## Last updated

2026-05-10 — initial rule. Source incident: 7 RUBEN escalation emails
on 3 trivially-fixable infra bugs (cline-fleet JSON newline,
StudentJourneyNotes case mismatch, lib/*.php mode 600). Cline applied the
repairs autonomously with Ruben's mid-stream approval and codified the
pattern. The same-night fixes also seeded `orchestrator_learned_patterns`
rows for snapshot_unparseable_cline_fleet, missing_php_file_case_mismatch,
lib_php_permission_denied_psaserv so RUBEN handles the next occurrence
without paging.

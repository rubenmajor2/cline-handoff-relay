# 147 — Kaison autonomous-repair safety gate: 48h-freshness OR three-G's before any auto-apply

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-15 — Ruben directive to bound Kaison (the LLM-fleet watcher) so it never auto-applies a bug-library repair on a stale/unverified incident without explicit gates. Cross-refs: rule 29, idea #12619, idea #12615.

## What Kaison is (one paragraph)

Kaison is the LLM-fleet watcher: it monitors frankenstein-router incidents, matches them to the bug library, and can autonomously apply a known repair (e.g. cap a restart-storm, disable a rogue daemon, patch a routing loop). The power to auto-apply is also the risk — a stale bug-library match can misfire on a different root cause, making things worse. This rule is the safety gate that determines WHEN Kaison may act versus when it must card Ruben.

## The two-path go/no-go check (run BEFORE every auto-apply)

Before Kaison applies any repair autonomously, it MUST evaluate BOTH paths. If EITHER passes, it may act. If NEITHER passes, it cards Ruben and stops.

### Path 1 — 48h freshness (proven-recent-safe)

**Condition:** the matched source incident is ≤ 48 hours old (wall-clock, measured against `created_at` or `detected_at` on the frankenstein_router_incidents row).

**Rationale:** a bug observed in the last 48h is almost certainly the same issue the bug-library repair was written for. The environment has not drifted. The repair's reversal command is still valid. Staleness > 48h means the fleet may have changed in ways that make the same surface symptom a different root cause.

**Check:** `TIMESTAMPDIFF(HOUR, incident_created_at, NOW()) <= 48`

If this is TRUE → Path 1 passes → Kaison may act (subject to max-actions cap and reversal-snapshot mandate below).

### Path 2 — Three G's (Good confidence + Goes-back + Gentle blast)

If the incident is > 48h old, Kaison must pass ALL THREE of the following:

| G | Criterion | Passing condition |
|---|---|---|
| **Good confidence** | Classifier match confidence | ≥ 0.85 (85%) AND the matched failure_category has ≥ 5 prior confirmed-fixed cases in the bug library |
| **Goes-back (reversible)** | The repair has a logged, tested reversal command | `reversal_command IS NOT NULL AND reversal_tested = 1` on the recipe row. Kaison CANNOT write a reversal on-the-fly for an old incident — it must be pre-validated. |
| **Gentle blast radius** | Single-surface impact | The repair touches exactly ONE service or config surface (e.g. one LiteLLM tier, one systemd unit, one router hook variable). Multi-surface repairs on stale incidents are human-only. |

If ALL THREE are TRUE → Path 2 passes → Kaison may act (subject to cap and snapshot below).

### No-act condition

If Path 1 fails (incident > 48h old) AND Path 2 fails (any G missing) → **Kaison MUST NOT act autonomously.** Required response:

1. Create a `frankenstein_router_incidents` row (or update the existing one) with `resolution_status = 'needs_human'` and a one-line `kaison_gate_block_reason` (which G failed, or "stale > 48h + confidence below 85%").
2. Post a structured card to Ruben: incident ID, matched category, why the gate blocked, recommended next step.
3. Stop. Do not attempt the repair.

## Hard human-only categories (always card Ruben, never auto-apply)

Regardless of freshness or G-scores, Kaison NEVER auto-applies repairs in these categories:

- **Serving infrastructure changes that affect ALL tiers simultaneously** (e.g. LiteLLM config.yaml full-restart, changing the primary entrypoint model for ALL surfaces)
- **Training pipeline** — anything touching frank_lora_train, LoRA adapters, checkpoint writes, eval gates
- **Payment / billing surfaces** — QuickBooks, Authnet, Affirm, any financial API
- **Regulatory / compliance surfaces** — CAPCE, TDSHS, BPSS, any accreditor-facing system
- **Student-facing Moodle changes** — enrollment writes, grade writes, quiz attempt finalization (those go through the SLS, rule 135)

These are irreversible-class or regulator-class actions per rule 29. No G-score overrides them.

## Max actions per run

**Kaison may auto-apply at most 2 repairs per monitoring run.** If 3+ incidents pass the gate in the same run, Kaison applies the 2 highest-confidence/freshest ones and cards Ruben for the rest with a note: "gate passed but run cap reached — next 2 queued for your review."

This cap exists because cascading autonomous repairs can interact in unexpected ways. Two repairs at a time is auditable. More than two is not.

## Reversal snapshot mandate (every auto-apply)

Before executing any repair, Kaison MUST write a reversal snapshot row:

```sql
INSERT INTO kaison_reversal_snapshots (
  incident_id,
  repair_recipe_id,
  snapshot_taken_at,
  pre_repair_state_json,   -- JSON blob: current config values, service status, relevant DB rows
  reversal_command,        -- verbatim command to undo the repair
  applied_by,              -- 'kaison_autonomous'
  gate_path                -- '48h_freshness' OR 'three_gs'
) VALUES (...);
```

If the INSERT fails (schema missing, DB down), **abort the repair**. No snapshot = no action. The snapshot IS the safety net; skipping it defeats the rule.

## Post-apply verification (required within 5 minutes)

After any autonomous repair, Kaison re-checks the incident signal:

- If the symptom is resolved (e.g. restart-storm counter drops below cap, router audit log shows normal picks) → mark `resolution_status = 'auto_resolved'` + log.
- If the symptom PERSISTS or WORSENS → immediately trigger the reversal command from the snapshot, mark `resolution_status = 'auto_reverted'`, and card Ruben with both the failed repair attempt and the revert action.

## Self-check (run mentally before every Kaison auto-apply)

1. *Is this incident ≤ 48h old?* → Path 1 passes. Proceed to cap + snapshot.
2. *Is it > 48h old?* → Check all three G's:
   - Confidence ≥ 85% AND ≥ 5 confirmed-fixed cases? If no → card Ruben.
   - Reversal command present AND tested? If no → card Ruben.
   - Single-surface impact only? If no → card Ruben.
3. *Is this a hard human-only category (serving/training/payment/regulator/Moodle)?* → card Ruben regardless of paths 1 or 2.
4. *Have I already applied 2 repairs this run?* → card Ruben for remaining incidents.
5. *Did I write the reversal snapshot row?* → If not, abort. Do not proceed without it.

## Cross-references

- Rule 29 — agents act on confidence tier: the three G's are derived from rule 29's reversibility + blast-radius + confidence gates
- Rule 92 — work at the core: Kaison auto-applying fixes IS the core-level fix; cardsing Ruben is the fallback, not the default
- Idea #12619 — Kaison autonomous-repair loop (the dispatcher this rule governs)
- Idea #12615 — bug-library expansion: confirmed-fixed cases feed the G1 confidence denominator
- Rule 141 — frankenstein MCP verification gate: Kaison uses the same `frankenstein_what_served` + `frankenstein_registry` tools to confirm a repair actually took effect

## Source incident

2026-06-15 — Ruben directive to create a safety gate bounding Kaison's autonomy. Prior to this rule, Kaison had no formal freshness check or reversal-snapshot mandate — a stale match could fire a wrong repair with no rollback. This rule closes that gap. The 48h window + three G's compose to give Kaison meaningful autonomy on recent, well-understood bugs while ensuring older or lower-confidence incidents always get human review.

## Last updated

2026-06-15 — initial.

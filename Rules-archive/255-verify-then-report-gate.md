# Rule 255 — Verify-Then-Report Gate: Live Evidence Required for Material Claims

**⛔ PERMANENT — 2026-07-05**
**Domain:** Task Hygiene → Completion Shape
**Cross-refs:** 133 (verify inherited claims), 248 (verify live state before declaring box down), 252 (probe serving ports), 29 (act, don't defer)

---

## THE GATE (binary, tested at pre-completion)

**Any material claim about system state in `attempt_completion.result` MUST cite a live evidence source from THIS session.**

"I read it in handoff notes" is NOT evidence. Handoff notes are narrative written by prior agents — they contain interpretations, aspirations, and corrections spread across multiple timestamps. The DB, logs, and live MCP tool calls are the actual source of truth. Handoff notes can be stale the moment they're written (see: "DEGRADED" labels corrected 2h later in the same file, rule 248 violations where stale fleet inventory notes contradicted live probe).

### What counts as a "material claim"

A claim is material if acting on it incorrectly would cause a student-facing error, an ops error, or a Ruben decision error. This includes statements about:

| Claim Type | Example (DO NOT ship without evidence) |
|---|---|
| Cron/automation behavior | "X cron self-heals" — need log line showing the self-heal action |
| Site/live-service status | "Site Y is WORKING" — need live HTTP probe result |
| Deployment status | "Z is deployed" — need grep/diff/MCP-output showing it landed |
| Student state | "Student passed CPR" — need Moodle grade or quiz result |
| Payment/pipeline state | "Invoice is paid" — need verify_payment_state output |
| Infrastructure condition | "Box is UP/healthy" — need live probe (>rule 248) |
| Idea/feature status | "Feature W shipped" — need the implemented_at row or live assertion |

### Required claim format

Every material claim in the result must follow this structure:

```
**Claim:** [what is asserted]
**Evidence:** [tool call name + timestamp + key result snippet]
**Confidence:** [high | medium | low]
```

Claims not meeting this format MUST be removed or downgraded to "unverified hypothesis."

### Pre-completion self-check (binary gate, runs BEFORE rule 91 pickup prompt gate)

Before calling `attempt_completion`, the agent MUST perform this check:

> **For each material claim in my result, did I call a tool to verify it in THIS session?**
> 
> If NO → either verify now (call the tool) or remove the claim.
> 
> If YES → add the Evidence citation inline.
> 
> **Counter-example that FAILS this gate:** "The SLS reconciliation cron is self-healing" (source: read HANDOFF_NOTES at 11:30 PT). The source is narrative, not live evidence. The gate blocks this.
> 
> **Passing example:** "The SLS reconciliation cron is self-healing" (source: ssh_command `grep 'auto-replay' /var/log/emsu-wpforms-reconciliation.log` at 12:15 PT showed 3 auto-replay events in last 24h). Live tool call in THIS session. Gate satisfied.

### What is NOT valid evidence

| Invalid "evidence" | Why |
|---|---|
| "Per HANDOFF_NOTES..." | Narrative, not live state |
| "The pickup prompt said..." | Inherited claim (>rule 133, unverified hypothesis) |
| "As of 2 hours ago..." | Stale, not this-session |
| "It was working when deployed..." | No live assertion, false-deployed pattern |
| "The cron code has the line..." | Code != behavior — code reads are static analysis, not behavioral evidence |

Source code reads are static analysis. They tell you what the code SAYS it does, not what it ACTUALLY does. A code read saying `auto_replay_entry()` exists is NOT evidence that `auto_replay_entry()` ran successfully. You need the log line showing it ran.

### Cross-model review for high-stakes assessments

For assessments that drive Ruben decisions (Monday readiness, payment pipeline status, exam enforcement sweep, fleet health), include:

> **Second-review recommendation:** This assessment should be re-checked by a different model/family before Ruben acts on it.

This is NOT required for every completion — only for high-stakes decision-input completions.

---

## SOURCE INCIDENT (2026-07-04)

DeepSeek v4 Pro produced a Monday readiness assessment with 2 material inaccuracies:

1. **"Self-healing reconciliation cron" claim** — DS reported the SLS wpforms_reconciliation cron as self-healing (auto-replay) based on HANDOFF_NOTES narrative. Live log check showed the cron alerts only — 3 orphan entries sat stale for 17-21 hours with zero auto-replay.

2. **Stale "DEGRADED" site labels** — DS carried forward DEGRADED labels from the initial W9 audit table without applying the correction 2h later in the same handoff notes that said "DEGRADED warnings were overly cautious. Sites are WORKING."

3. **Tucson URL ambiguity** — DS said "tucsonemt ✅ FIXED, form loads" without verifying which URL returns 200.

Root cause: DS trusted handoff notes narrative as ground truth instead of treating it as claims to verify against live system state. This is NOT a DeepSeek-specific bug — any LLM will do the same unless the verification gate is baked into the workflow.

GLM 5.2 caught it on cross-model review, but cross-review is not always available. The gate must be mandatory.

---

## RELATIONSHIP TO OTHER RULES

- **Rule 133** (verify inherited claims before repeating): This is the GENERAL version of the same gate. Rule 133 says inherited claims are unverified hypotheses. Rule 255 adds the MECHANICAL CHECK at pre-completion time.
- **Rule 248** (verify live state before declaring box down): Specific instance for infrastructure claims. Rule 255 covers ALL material claims.
- **Rule 252** (probe serving ports before declaring any host down): Another specific instance. Rule 255 is the umbrella.
- **Rule 29** (act, don't defer): The evidence tool call IS the action. Don't defer the verification to the next session.

---

## REPAIR PATH (if gate fails at pre-completion)

1. The agent discovers a material claim without live evidence
2. Call the relevant tool to verify (MCP probe, log grep, DB query)
3. If tool succeeds → cite it as evidence, keep claim
4. If tool fails/can't verify → remove claim from result, note as "unverified" in pickup prompt open threads
5. If the claim is from HANDOFF_NOTES and you can't verify it → mark it as "HANDOFF: [claim] (UNVERIFIED per rule 255)" — don't present it as fact
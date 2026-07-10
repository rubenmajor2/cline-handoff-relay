# 263 — Verify before claim: no stale inferences, no sycophantic agreement

Permanent rule. Source incident: 2026-07-10 Frankenstein Doctor postmortem. A Cline window served by frankenstein-llm (120B + emsu_distill LoRA) fabricated a "Google Sheets import pipeline" from a vestigial DB column (`google_sheet_row`) and a legacy directory (`google-sheets-to-mysql-migration/`), claimed 9 students need provisioning when the real count was 5, proposed a non-existent `handleBulkExtension()` function, and when challenged by Ruben just said "you're right" without investigating. SLS had the correct diagnosis the entire time.

## The bright-line rule

**Before stating ANY factual claim about the system, you MUST have already verified it with a tool call.** A "factual claim" includes: student counts, table schemas, existing functions, pipeline behavior, file contents, config values, which features exist, what a column/directory/tool name implies. If you have NOT run a tool (read_file, plan_mysql_select, plan_read_file, grep, describe_table, list_files) that produced the fact, you must either (a) say "unverified" or (b) run the verification tool FIRST. Never state an unverified inference as a fact.

## The naming-is-not-evidence rule

**A name is never evidence of behavior.** Vestigial schema columns, legacy directories, and decommissioned surfaces retain their names after the feature is removed. You CANNOT infer that:

- A column named `google_sheet_row` means a Google Sheets import pipeline exists
- A directory named `google-sheets-to-mysql-migration/` means it is an active pipeline
- A function named `handleBulkExtension` exists because you think one should
- A `connecteam_shifts` table means Connecteam is integrated (it was decommissioned 2026-05-15, rule 246)
- A `justcall_*` table means JustCall is in the stack (it was removed)

When you encounter a surface name that COULD be legacy/deprecated, VERIFY with a tool whether it is actively wired before claiming it as part of a current pipeline. The bug library, `_INDEX.md`, and HANDOFF_NOTES are the canonical sources for what is decommissioned.

## The anti-sycophancy rule

**When a human corrects you or challenges a claim, do NOT immediately agree.** The correct response to a challenge is INVESTIGATION, not agreement.

- If you had tool-based evidence for the challenged claim: re-verify it. Show the verification.
- If you did NOT have evidence (you inferred/assumed from a name): say so explicitly — "I did not verify that. Let me check now." Then run the tool.
- Saying "you're right" without re-verification is a violation. It signals agreement to end friction rather than investigation to find truth.
- The ONLY exception: the human provides a fact you could not have known (a decision, a date, a name). Even then, acknowledge the correction and update your understanding, do not just say "you're right."

## Why this matters for EMSU

EMSU is a regulated career school. Factual claims about students (counts, statuses, what they need) flow into student-facing emails, ops decisions, and compliance records. A fabricated "9 students need provisioning" claim, if acted on, wastes ops time and misrepresents student state. A fabricated "Google Sheets import pipeline" claim, if repeated in a handoff, infects future agents with the same stale inference. The 120B+LoRA is cheap and free-local — that is its value — but its reasoning must be anchored to verified facts, not confabulated associations from training data.

## The self-check before any factual claim

1. *Am I about to state a fact about the system (count, schema, function, pipeline)?*
2. *Did I run a tool that produced this exact fact?* (read the output, do not assume)
3. *If no → run the tool first, or say "unverified."*
4. *Am I inferring behavior from a name?* (column name, directory name, function name) → STOP. Names are not evidence. Verify the wiring.
5. *Did a human just challenge this claim?* → re-verify with a tool, do not agree without evidence.

## Pre-completion audit

Before `attempt_completion`, scan every factual claim in the result. For each:
- Is it backed by a tool result in this session?
- If not → either verify it now or mark it "unverified."
- Is any claim an inference from a surface name? → remove it or verify it.

## Cross-references

- Rule 133 — verify inherited claims before repeating them (sibling rule for handoff claims)
- Rule 203 — verify the premise before echoing it
- Rule 205 — verify artifact contents not label
- Rule 252 — stale-info live-probe gate (fleet infrastructure version)
- Rule 258 — MCP stale-data truth gate
- Rule 46 — every agent correction loops back to RUBEN/KAIZEN
- Rule 169 — persist corrected knowledge to durable surfaces
- Bug library: `distill_lora_stale_reference_contamination_2026_07_10`
- Steering injection: `_build_steering_text()` in `/etc/litellm/_router_core.py` now injects VERIFY-BEFORE-CLAIM + ANTI-SYCOPHANCY for all STEERING_MODELS

## Source incident

2026-07-10 — Frankenstein Doctor postmortem. Cline window on frankenstein-llm (120B+LoRA) fabricated a Google Sheets import pipeline, wrong student count (9 vs 5), non-existent function, and responded to Ruben's correction with sycophantic agreement instead of investigation. Root cause: LoRA trained on distill corpus contaminated with 69 `google_sheet_row` + 62 `google-sheets-to-mysql-migration` references. Fixes shipped: (1) stale-reference filter in `build_distill_corpus.py`, (2) VERIFY-BEFORE-CLAIM block in steering injection, (3) distill corpus rebuilt clean (0 stale refs), (4) this rule. LoRA retraining filed as idea #16949.

## Last updated

2026-07-10 — initial. Frankenstein Doctor Phase 13 (postmortem + fix).
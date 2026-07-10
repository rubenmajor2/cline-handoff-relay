# 91 addendum — Spawn-window prompts: when a task spawns a SEPARATE investigation/build window

Source: 2026-06-18 Round 4 Doctor session. Ruben asked for "a separate copy window" for the training pipeline investigation twice. The pickup prompts varied in quality because rule 91 covers task CONTINUATION but not task SPAWNING from findings.

## The pattern this addendum covers

During a task, the agent discovers something that needs a SEPARATE window to handle (different scope, different tools, different timeline). Examples:
- Doctor session finds a training pipeline is broken -- needs a build window to fix it
- Fleet investigation finds a config drift -- needs a deploy window
- Student ops finds a systemic bug -- needs a code fix window

The agent needs to produce a "spawn prompt" that:
1. Is self-contained (the new window has ZERO context from the current window)
2. Carries the EVIDENCE from the current window (numbers, IDs, commands, specific findings)
3. Has a clear PRIORITY ORDER (what to do first)
4. Has VERIFICATION criteria (how to know it's done)

## Required shape for spawn prompts (in addition to rule 91's pickup shape)

When producing a prompt intended for a DIFFERENT, NEW window (not continuing the current task), it MUST include:

### 1. CONTEXT TRANSFER (the new window knows nothing)
- ONE paragraph explaining WHY this task exists (what the parent window found)
- Specific numbers/evidence from the parent window's investigation
- NOT "see HANDOFF_NOTES" -- the evidence must be INLINE because the new window should act immediately, not research first

### 2. PRIORITY DIRECTIVE (first line after context)
- The FIRST action the new window should take, stated as a concrete tool call or command
- "PRIORITY: do X FIRST" before any secondary tasks
- If there are multiple tasks, number them in execution order

### 3. EVIDENCE PACKAGE (not just descriptions)
- Specific DB row IDs (e.g., "lora_training_runs IDs 392-583, all status=failed")
- Specific error messages (e.g., "guard: no live pod after 6h")
- Specific file paths + line numbers
- Specific config values that are wrong + what they should be
- Commands that were already tried + their results (so the new window doesn't re-run them)

### 4. VERIFICATION CRITERIA (Definition of Done for the spawned task)
- What does success look like? (e.g., "training run completes with status=succeeded AND eval_gate_passed=1")
- What should the new window check to confirm it's done?

### 5. CROSS-REFERENCE TO PARENT
- The parent window's task topic + key findings
- Ideas filed by the parent that the spawn should implement
- Bug library entries the spawn should reference

## What makes a BAD spawn prompt (anti-patterns from this session)

- "Investigate the training pipeline" -- too vague, no evidence, no priority
- A dump of every detail from the parent window -- too much context, no priority order
- "See HANDOFF_NOTES for details" -- deferring context transfer to a separate lookup
- Missing the specific DB IDs, error messages, or file paths the parent already found
- No verification criteria -- the new window doesn't know when it's done

## What makes a GOOD spawn prompt

The training pipeline prompt from this session (final version) was good because it:
- Started with a priority directive ("PRIORITY: Train a tool-call compliance LoRA")
- Included specific evidence ("IDs 392-583, all failed, 'guard: no live pod after 6h'")
- Had numbered execution order (1-5 for training, then "ALSO FIX" for secondary tasks)
- Referenced the parent's idea (#13199) and bug library entry (#562)
- Had verification: "Pass threshold: <10% error rate (down from 26.4%)"

## Composition with rule 91

- Rule 91's pickup prompt shape (dividers, reference IDs, cross-refs) APPLIES to spawn prompts too
- The spawn adds: context transfer, priority directive, evidence package, verification criteria
- A spawn prompt is NEVER just a subset of the parent's pickup prompt -- it's a purpose-built document for a different scope

## Source incident

2026-06-18 Round 4 Doctor session. Ruben asked for "a separate copy window for the training pipeline" twice. First version was too thin (just task description). Final version included evidence package + priority order + verification. This addendum captures the pattern so future spawn prompts are consistently high quality.

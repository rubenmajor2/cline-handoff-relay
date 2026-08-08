# 278 — AFK mode: needs_verify auto-deploys to deployed (no human gate)

Permanent rule. Workspace-scoped. Source: 2026-07-15 Ruben directive.

## The rule

When AFK mode is enabled in the RUBEN executor (`feedback_settings.afk_mode = true`), the `needs_verify` stage is BYPASSED. Ideas that pass their build + test steps go directly to `deployed` status without waiting for human verification. This is the "let it ship while I'm away" lever.

## What this means for agents

- When AFK mode is ON: do NOT tag ideas as `[needs_verify]` in pickup prompts or completion results. Tag them as `[deployed]` once the executor reports the build passed.
- When AFK mode is OFF: the normal flow applies — `needs_verify` is a human gate, and ideas sit there until Ruben (or a designated reviewer) verifies them.
- The `needs_verify` → `deployed` transition is automatic when AFK mode is on. Agents do not need to call `idea_action(approve)` for AFK-mode deploys.

## How to check AFK mode status

```
feedback_settings()  // returns afk_mode: true/false
```

## Cross-references

- Rule 267 — GATE B reconcile: when AFK mode is on, `[needs_verify]` should not appear in pickup prompts (it auto-deploys). Replace with `[deployed]`.
- Rule 91 — pickup prompt tags must reflect the actual live state, which changes faster under AFK mode.

## Source

2026-07-15 — Ruben: "I turned on AFK mode in executor so that needs_verify is no longer, but turns directly to deployed. So that should also be a cline rule."

## Last updated

2026-07-15 — initial.
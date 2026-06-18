# 163 — Structural forcing functions: advisory rules become tool-layer gates (idea #13082)

Source: 2026-06-17 Ruben directive + arXiv 2507.11538 (IFScale). Instruction adherence decays monotonically with rule-count (~68% at 500 rules, middle rules dropped first under context pressure). ~160 advisory clinerules + advisory "check the bug library first" structurally lose under context pressure, causing idea-recycling and rule non-obedience. The fix: move load-bearing gates OUT of the advisory prompt set INTO hard tooling checks.

## What changed (idea #13082, shipped 2026-06-17)

Five structural forcing functions in frankenstein-bug-library MCP v0.2.0:

### 1. FORCING-FUNCTION GATE — `bug_library_gate_status` + `bug_library_kaison_replay`

`bug_library_check_before_fix(symptom)` stamps a session gate (module-level + `kaison_gate_sessions` DB row).
`bug_library_kaison_replay` returns `isError: true` (GATE_BLOCKED) when gate is not open.
NOT advisory — the tool FAILS at the tool layer. Agent cannot skip it.

### 2. DEDUP-ON-WRITE — `bug_library_record`

Queries by exact `problem_key` OR keyword overlap BEFORE inserting.
On match: returns `DUPLICATE_FOUND` + increments `seen_count` + updates `last_seen_at`. No duplicate row.
Override with `force_insert=true` only for genuinely distinct incidents.

### 3. KAISON AUTO-APPLY — `bug_library_kaison_replay(incident_id, dry_run=true)`

Replays verbatim resolution for KNOWN_REPAIR incidents. Hard gates enforced at tool layer:
- Gate 1: session gate must be open (check_before_fix called this session)
- Gate 2: rule-147 tier gate (48h freshness OR Three G's)
- Gate 3: resolution field non-empty
- Run cap: max 2 auto-applies per 60 min
- Reversal snapshot written to kaison_reversal_snapshots BEFORE execution (abort if write fails)

Always dry_run=true first to preview. Pass dry_run=false to execute.

### 4. TIER LOAD-BEARING GATES — `bug_library_tier_gate(incident_id)`

Evaluates rule-147 from ACTUAL DB data. Returns TIER_1 (auto-apply) or TIER_3 (human-only).
`evaluateRule147()` function returns structured PASS/FAIL per criterion. NOT prompt text.

### 5. REPEAT-RATE KPI — `bug_library_repeat_rate()`

Returns problem_key ranked by seen_count DESC.
"Is the library working?" = seen_count decreasing over time (library catching re-derivations).
High seen_count = same problem re-encountered = repair needs strengthening.

## Call sequence (structural, not advisory)

```
1. bug_library_check_before_fix(symptom)              # opens gate — REQUIRED FIRST
2. [KNOWN_REPAIR] bug_library_tier_gate(id)           # check auto-apply eligibility
3. [TIER_1] bug_library_kaison_replay(id, dry_run=true)    # preview
4. [confirmed] bug_library_kaison_replay(id, dry_run=false) # execute
5. [NOVEL_SYMPTOM] diagnose + bug_library_record(...)  # log it, not a duplicate
```

Step 1 is the gate. Steps 2-4 return GATE_BLOCKED (isError: true) if step 1 was skipped.

## New DB columns (2026-06-17)

- `frankenstein_router_incidents.seen_count INT DEFAULT 1` — incremented on dedup match
- `frankenstein_router_incidents.last_seen_at DATETIME NULL` — updated on dedup match
- New table: `kaison_gate_sessions` — cross-process gate visibility for WOPR PHP

## Why advisory decays but structural doesn't (IFScale context)

Advisory rules ("call check_before_fix first") lose adherence as the rule set grows per arXiv 2507.11538 — the middle rules in a long system prompt are dropped first under context pressure. Moving the check into a tool-layer gate means enforcement happens at the API level, not the prompt. The agent gets an explicit tool error (GATE_BLOCKED, isError: true) rather than a suggestion it can forget.

This does NOT replace clinerules 156, 147, or 158 — those are the human-readable rationale and broader context. This rule documents the structural implementation.

## Self-check

Before any LLM routing diagnosis or repair:
1. Called `bug_library_check_before_fix(symptom)`? If no, call it now (gate is required, not advisory).
2. Got KNOWN_REPAIR? Use `bug_library_tier_gate` + `kaison_replay` instead of re-deriving.
3. Got DUPLICATE_FOUND on `bug_library_record`? Update the existing record, don't re-insert.
4. Checking repeat rate? `bug_library_repeat_rate(min_seen=2)` shows recurring problems.

## Cross-references

- Clinerule 156 — the advisory ancestor this rule makes structural
- Clinerule 147 — Kaison autonomous-repair safety gates (this rule implements them in tooling)
- Clinerule 158 — Frankenstein Doctor protocol (uses these tools in Step 0 + Step 3)
- Clinerule 92 — fix at the core (advisory is the bandaid; structural gate is the core fix)
- arXiv 2507.11538 (IFScale) — empirical basis for advisory rule decay
- Idea #13082 — this implementation
- Bug library incident #530 — `meta_bug_library_clinerules_advisory_not_structural_idea_recycling_2026_06_17`

## Source incident

2026-06-17 — Ruben flagged idea-recycling and rule-non-obedience as structural (not model-quality) problems. arXiv 2507.11538 (IFScale): ~68% adherence at 500 rules, middle rules dropped first. Prior evidence: frankenstein_router_incidents had 107 rows all logged by Cline, zero by Kaison — every agent was re-deriving known fixes despite rule 156 being advisory. Fix: frankenstein-bug-library MCP v0.2.0 with tool-layer gates.

## Last updated

2026-06-17 — initial. Idea #13082 (approved, shipped).

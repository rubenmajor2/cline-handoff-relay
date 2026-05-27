# 116 — Auto-compress conversation context at attempt_completion and on YELLOW/RED tier

Workspace-scoped. Source: 2026-05-25 23:50 PT — task #1779691028868 + sibling sessions crossed 820K / 1M context. At Sonnet-4.5 input pricing ($3/M in), every tool call past 500K re-bills ~$1.50-$2.46 of context that the next window doesn't need. A 50-call afternoon ≈ $120 in re-billed history. Spec: `/Users/rubenmajor/Desktop/cline_auto_compress_spec.md`. Pickup: `/Users/rubenmajor/Desktop/cline_auto_compress_pickup.md`.

Companion to .clinerules/91 (pickup-prompt format). This rule is the **intra-window** complement — every cross-window handoff still goes through rule 91.

## The bright-line rule

**Before emitting any `attempt_completion`** when input tokens ≥ 100K, **AND** whenever `/tmp/cline_budget_status.json` shows tier ≠ GREEN (YELLOW, RED, IMMINENT), the agent MUST call the `cline_compress_session` tool from the `cline-compress` MCP server and use the returned blob as the body of the `attempt_completion`.

The returned blob is a self-contained ≤25KB Session Memory packet a fresh Cline window can paste-and-resume from with zero context loss.

## When to call (the 5 triggers)

| Trigger | Source | Behavior |
|---|---|---|
| T1 — input tokens ≥ 500K | budget status file shows tier=RED or context_size≥500K | Hard threshold. Call now. |
| T2 — every `attempt_completion` with input ≥ 100K | self-aware | Default. Compress, then emit. |
| T3 — user says "compress now" / "compress" | user message | Escape hatch. Call immediately. |
| T4 — tier transition GREEN→YELLOW | budget status file | Proactive. Catches before RED. |
| T5 — every ~150K token growth since last compress | `should_compress_now` MCP tool | Intra-task periodic trigger. Poll every 10-15 tool calls. |

Below 100K tokens, compression is wasted ceremony — skip T2.

## T5 usage (idea #7380)

Call `should_compress_now` from the `cline-compress` MCP server periodically (every 10-15 tool calls) to check if growth-based compression should fire:

```
should_compress_now({
  task_id: "<current Cline task ID>",     // reads per-task file, falls back to global
  last_compress_size: <tokens at last compress>,  // 0 if never compressed this window
  growth_threshold: 150000                // optional, default 150K
})
```

Returns `{ should_compress: bool, tier, context_size, growth_since_last, reason }`.

If `should_compress` is true, call `cline_compress_session` immediately.

## How to call (the arg shape)

```
cline_compress_session({
  task: "<one-line task statement>",
  pickup_prompt: "<the .clinerules/91 block you were about to emit, verbatim, ≤5KB>",
  tool_rounds: [
    "<tool_name>(<terse args>) → <one-line outcome>",
    ...  // oldest first, one bullet per tool call this window
  ],
  last_turns: ["<turn n-2>", "<turn n-1>", "<turn n>"],  // verbatim
  references: {
    files: ["/path/1", "/path/2"],
    ids: ["TKT-…", "IDEA-#7198", "HANDOFF-2026-05-25"],
    tmp_artifacts: ["/tmp/cline_session_backup_…jsonl"]
  },
  original_token_estimate: 820000,  // optional
  backup_jsonl_path: "<path>"        // optional; if set, copies to /tmp before compressing
})
```

Returns a single text blob ≤25KB with this shape (per spec §5):

```
═══════════════════════════════════════════════════════════════
SESSION MEMORY (auto-compressed <ISO ts>, original <N>K tokens)
═══════════════════════════════════════════════════════════════
## Task
## Pickup prompt (verbatim from .clinerules/91)
## Key references
## Session memory (what's already been done this window)
## Last 3 turns (verbatim)
═══════════════════════════════════════════════════════════════
END SESSION MEMORY — continue task above
═══════════════════════════════════════════════════════════════
```

**The returned blob becomes the body of the `attempt_completion`.** Do not wrap it in additional commentary — the blob IS the completion message.

## What NOT to compress

Per spec §4.1, these stay verbatim and are the caller's responsibility to pass through unchanged:

1. The .clinerules/91 pickup prompt for the current task (≤5KB)
2. Last 3 conversation turns
3. Reference paths + IDs (HANDOFF-…, ticket-…, IDEA-…, file paths under /Users/rubenmajor/ or ~)
4. In-flight tool-use ↔ tool-result pair (if one is pending)

The compressor itself just packages and de-duplicates. The agent decides what to keep.

## Why this rule matters

- **$30-$110 saved per heavy session** at current Sonnet-4.5 pricing
- **~$1-3K/yr realistic** at current EMSU usage
- Today's 820K session (~$319) would have been ~$45 with compress-at-500K
- Works WITH `useAutoCondense=true` not against it — Cline's built-in is a fallback, this is deterministic

## Budget status file paths (idea #7377)

The budget watchdog writes TWO files per poll:

1. **Global:** `/tmp/cline_budget_status.json` — always updated, reflects the latest task seen.
2. **Per-task:** `/tmp/cline_budget_status_TASK<task_id>.json` — e.g. `/tmp/cline_budget_status_TASK1779691028868.json`.

Use the per-task file when `task_id` is known (prevents concurrent tasks from clobbering each other's budget signal). `should_compress_now` does this automatically when `task_id` is passed.

## Anti-patterns

- ❌ Calling `cline_compress_session` on every tool call (only at the 5 triggers)
- ❌ Calling it on tiny tasks (<100K input) — pointless ceremony
- ❌ Adding commentary around the returned blob — the blob IS the completion body
- ❌ Replacing the rule 91 pickup prompt content — the compressor preserves it byte-for-byte
- ❌ Mutating `api_conversation_history.jsonl` from this rule — that's Option A, not built yet

## Rollback

Compression is advisory: it returns a blob, doesn't touch Cline's JSONL. If anything looks off, ignore the blob and continue the original window. To disable entirely: set `"disabled": true` for `cline-compress` in `cline_mcp_settings.json` and reload the Cline window.

## Source incidents

- 2026-05-25 23:50 PT — task #1779691028868 hit 820K / 1M context; Ruben directive: "Implement Cline auto-compress per the spec at /Users/rubenmajor/Desktop/cline_auto_compress_spec.md."
- 2026-05-26 — idea #7377 (per-task budget file) + idea #7380 (T5 periodic trigger) shipped.
- Companion rule: .clinerules/91 (every-completion-needs-pickup-prompt — this rule's blob INCLUDES that pickup as section 2).
- Spec doc: /Users/rubenmajor/Desktop/cline_auto_compress_spec.md
- Pickup brief: /Users/rubenmajor/Desktop/cline_auto_compress_pickup.md
- MCP impl: /Users/rubenmajor/Desktop/cline-compress-mcp/index.js

## Last updated

2026-05-26 — added T5 periodic trigger (should_compress_now tool) and per-task budget file path pattern. Ideas #7377 and #7380 shipped.
2026-05-25 — initial. Option B (MCP tool) only. Option A (JSONL mutator launchd job) deferred per spec §7.

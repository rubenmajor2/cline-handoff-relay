# YOLO Threshold + Tool-Failure Recovery

## Why this rule exists

YOLO learner DB at `~/Documents/Cline/yolo_learner/yolo_trips.sqlite` showed **272 trips in 30 days** of "[YOLO MODE] Task failed: Too many consecutive mistakes (3)". Each one kills a Cline task mid-work. Two root causes (2026-05-03 post-mortem):

1. **The threshold was the default of 3.** Cline's `maxConsecutiveMistakes` global setting was never written, so the extension fell back to its built-in default of 3. Three strikes is brutally tight when one of the failures is a tool wall hit (rule 95) that wasn't predictable.
2. **The dominant trip pattern is `timeout > no-tool-use > no-tool-use`** (97 of all triples). The 30-second tool wall fires once, the model emits prose explaining the timeout instead of calling another tool, prose again → game over.

## Fix shipped 2026-05-03

**`maxConsecutiveMistakes` bumped from 3 → 10** in Cline's `globalState` (state.vscdb on this Mac). Verified with:

```sh
sqlite3 -cmd ".timeout 8000" \
  "/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb" \
  "SELECT value FROM ItemTable WHERE key='maxConsecutiveMistakes';"
# → 10
```

This takes effect on the next VS Code reload (or on every newly-launched Cline window). It does NOT change behavior of already-running tasks until they're restarted.

If the YOLO learner ever shows the trip count climbing again at 10, the next move is bumping to 20 — not lowering the bar of recovery. Premature task termination is much more expensive than "model takes 6 turns to figure out a hard recovery."

## What "consecutive mistake" actually means

From reading the Cline 3.82 extension source:

- Every tool handler calls `taskState.consecutiveMistakeCount++` when it hits a problem (missing required parameter, `replace_in_file` SEARCH didn't match, write to a forbidden path, the model emitted no tool calls, etc.)
- Every successful tool call calls `taskState.consecutiveMistakeCount = 0`.
- The kill check is `if (consecutiveMistakeCount >= maxConsecutiveMistakes) { fail }`.
- "no-tool-use" specifically fires when the model produces an assistant turn that contains zero tool calls. The system then sends `Hr.noToolsUsed(...)` reminding the model and increments the counter.

So a single tool flake plus two prose-only follow-ups is enough at threshold 3, but at threshold 10 the model has real room to run discovery before the floor falls out.

## What I (Cline) MUST do when a tool fails

The threshold bump is the floor, not the ceiling. The actual behavior rules from rule 95 + rule 99 still apply, just with breathing room:

1. **A tool failed → next action MUST be a tool call, not prose.** No "Let me look into this..." paragraphs. Either:
   - call a different tool that gathers info to recover, OR
   - call `attempt_completion` with what's known so far, OR
   - call `ask_followup_question` (or in YOLO mode, just continue with discovery tools).
2. **Same tool failed twice in a row → change approach on the third attempt.** Per rule 99 meta-rule. The threshold bump doesn't authorize three identical retries — it just keeps an honest discovery loop from being killed.
3. **30s timeout on `execute_command` → switch to scp-script + nohup pattern.** Rule 95 covers this. Don't retry the same command synchronously.
4. **API overloaded twice → idle, don't burn the budget.** Per rule 99.

## Cross-references

- Rule 95: `95-cline-30s-tool-wall-and-remote-long-running-work.md` — the pattern that produces the timeout half of the dominant triple.
- Rule 99: `99-yolo-prevention-learned.md` — auto-generated playbook per failure category, refreshed every 30 min by the YOLO learner.
- Rule 98: `98-edit-discipline.md` — keeps the conversation small enough that recovery loops don't OOM the ext-host.

## Last updated

2026-05-03 11:43 PT — initial rule. Source incident: 272 cumulative YOLO trips, top triple = `timeout > no-tool-use > no-tool-use` (97 hits). Threshold bumped 3→10 in Cline globalState.

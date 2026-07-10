# 129 — Terse wrap/resumption messages are answered with a tool call, never a prose acknowledgment

Permanent rule. Workspace-scoped. Companion to .clinerules/41 (prose trap + free-strike recovery), .clinerules/99 (no-tool-use is the #1 YOLO class), .clinerules/128 (fleet status questions open with a tool), .clinerules/EXECUTE_ORDER_66 (wrap-up protocol).

## The bright-line rule

**When the user message is a terse wrap / resume / continue instruction — "no fpm", "no fpm wrap", "wrap", "wrap up", "wrap no fpm", "continue", "try again", "keep going", "proceed", "go" — the next assistant turn MUST contain a tool_use block.** Almost always that tool is `attempt_completion` (if the work is done or being wrapped) or the next concrete action tool (if continuing). Never a prose acknowledgment like "Okay, wrapping up now." or "Got it, continuing:".

## Why this rule exists (the data)

Scan of `~/Documents/Cline/yolo_learner/yolo_trips.sqlite` 2026-05-28/29: the SECOND most common trip opener on Ruben's live threads (after fleet status questions) is a terse resumption message whose `last_user_msg_start` is literally "no fpm", "no fpm wrap", "wrap no fpm", or "continue". Every one is `cat_1 = no-tool-use: model typed prose instead of calling a tool`. Multiple threads tripped 3-5× each on this exact shape (task_ids 1780013366626, 1780008095836, 1779956734392, 1779958580243, 1779835955619, 1779819755694).

"no fpm" means: wrap up, and do NOT reload php-fpm (per .clinerules/42, safe_deploy already reloads it — there is nothing to do). The model reads "no fpm" and, because there is genuinely no FPM action to take, types a prose acknowledgment instead of calling `attempt_completion`. Cline injects `[ERROR] You did not use a tool`, the model re-acknowledges in prose, and it trips. The instruction to do nothing-but-wrap is the trap: "nothing to do" still requires a tool (`attempt_completion`), not prose.

This is model-agnostic — it tripped on both Opus 4.8 and 4.7 on the same thread. It is a turn-shape habit, not a model defect.

## The decode table for terse instructions

| User says | What it means | First/next tool |
|---|---|---|
| "no fpm" | wrap up, skip FPM reload (42 already handles it) | `attempt_completion` |
| "no fpm wrap" / "wrap no fpm" | same, explicit wrap | `attempt_completion` |
| "wrap" / "wrap up" / "finalize" | run the wrap-up protocol | EXECUTE_ORDER_66 steps, ending in `attempt_completion` |
| "continue" / "keep going" / "proceed" / "go" | resume the in-flight work | the next concrete action tool (read/edit/execute/MCP) |
| "try again" | retry the last failed step a DIFFERENT way | a tool, per .clinerules/41 per-class pivot table |

In every row, the answer is a tool. There is no row where the answer is a sentence.

## What is NOT fine

- ❌ "Okay, wrapping up now — no FPM reload needed." (no tool) → trip
- ❌ "Got it. Since safe_deploy already reloaded FPM, nothing more to do here:" (colon, no tool) → trip
- ❌ "Understood, continuing with the next step." (no tool) → trip
- ❌ "Sure, trying again." (no tool) → trip

## What IS fine

- ✅ `attempt_completion` with the result + pickup prompt (the correct response to "no fpm" / "wrap")
- ✅ The next action tool, with at most one short framing sentence in the SAME turn (the correct response to "continue")

## Self-check on any terse user message (≤4 words)

1. *Is this a wrap/resume/continue/retry instruction?* → the next turn is a tool, full stop.
2. *Am I tempted to acknowledge it in prose first ("okay", "got it", "sure", "understood")?* → STOP. The acknowledgment IS the trap. Emit the tool instead.
3. *"no fpm" specifically* → there is no FPM action (rule 42). Wrap = `attempt_completion`. Do not narrate "nothing to do."

## Cross-references

- .clinerules/42 — safe_deploy already reloads FPM (why "no fpm" means "do nothing about FPM")
- .clinerules/41 — prose trap + the free-strike recovery after `[ERROR] You did not use a tool`
- .clinerules/99 — no-tool-use is the #1 YOLO class (224% over-represented)
- .clinerules/128 — fleet/ops status questions open with a tool (the #1 trip trigger; this rule is the #2 trigger)
- .clinerules/EXECUTE_ORDER_66 — the wrap-up protocol "wrap" invokes

## Source incident

2026-05-29 — Ruben: *"Just had another Yolo with 4.7 on the same thread, FYI"* after an earlier 4.8 YOLO on the same thread. Investigation showed the trips are model-agnostic `no-tool-use` openers, and the #2 trigger (after fleet status questions, rule 128) is terse "no fpm" / "wrap" / "continue" resumption messages answered with prose instead of `attempt_completion`. Ruben directed per .clinerules/29: *"You tell me per rule 29"* — act, don't queue. Rule filed and shipped same session.

## Last updated

2026-05-29 — initial.

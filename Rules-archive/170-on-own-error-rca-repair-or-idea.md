# 170 — On encountering your own error (any class): attempt repair, else file an RCA+repair idea

Permanent rule. Workspace-scoped. Source: 2026-06-24 Ruben directive — "when a window encounters its own error, we make it a cline rule for that window to attempt repair of that error and if that repair is not able to be done immediately, then an idea needs to be filed on that error. The idea needs to be a root cause analysis and complete repair of that issue."

## SCOPE — this applies to ALL errors the LLM experiences about itself, not just file tools

This rule is GENERAL. It covers ANY error a Cline LLM triggers on itself: file-tool errors (EISDIR, EACCES, Document-not-initialized, SEARCH-no-match), MCP errors (result missing, transport wedge, Invalid JSON argument, connection closed), format errors (no-tool-use, malformed tool-call output, native tags leaking as content), serving errors (empty 200, 503, timeout, auth 401), and the LLM's own output errors (hallucinated tool names, placeholder args, truncated JSON). The repair table below is illustrative, not exhaustive — the principle (repair or RCA+file) applies to every own-error class. See idea #14856 for the broader client/telemetry layer.

## The bright-line rule

When a Cline window encounters an error from its OWN tool call or its own output, the window MUST, in order:
1. **Attempt an immediate repair** of the specific error (re-read the file, fix the path, deserialize the doc state, pivot tool).
2. If the repair succeeds → continue the task.
3. If the repair is NOT immediately possible (the error is systemic, recurring, or environmental) → **file an `orchestrator_idea` containing a root-cause analysis AND a complete repair plan**, THEN continue or complete.

A window that works around its own error silently — without repairing it or filing an RCA+repair idea — violates this rule. The same error class then kills the next window.

## What counts as "your own error"

- The tool returned an error: `EISDIR`, `EACCES`, `ENOENT`, "SEARCH did not match", "Document not initialized", timeout, "result missing", MCP transport error, "Invalid JSON argument", empty 200, 503, auth 401.
- The LLM's own output errored: no-tool-use strike, malformed tool-call, native format tags leaking as content, hallucinated tool name, placeholder args, truncated JSON.
- The error came from a tool YOU called this turn or from YOUR output this turn (not a prior-window artifact you are investigating on someone's behalf).

## The repair attempt (step 1) — per error class (illustrative, not exhaustive)

Before filing, try the obvious repair:

| Error | Likely cause | Repair (do this, not a blind retry) |
|---|---|---|
| `EISDIR: illegal operation on a directory` | path passed to replace_in_file/write_to_file is a DIRECTORY (e.g. `/Users/ruben`, a project root) | `list_files` the parent; find the real FILE path; re-issue. Never retry the directory path. |
| `EACCES: permission denied, open '/Users/ruben'` | same — path is a directory/root, or a server path written locally (rule 144) | Fix the path to a real file under `/Users/...` or `/tmp/...`; server paths go through `ssh_command` MCP. |
| `Document not initialized` | doc state corrupted, usually by PARALLEL replace_in_file calls on the same file | Re-`read_file` the target, then issue ONE replace_in_file (sequential, not parallel). Do not fire parallel replace_in_file on the same file. |
| `SEARCH did not match file` | SEARCH block stale or wrong | `read_file` to get current exact content; re-craft SEARCH from that. Keep blocks 3-8 lines, unique. |
| `result missing` / MCP transport | MCP transport wedged (rule 77/150) | Pivot to a DIFFERENT tool path (local shell, file tools, a different MCP). Do not fire the same MCP call 3x. |
| timeout | service slow / hung (rule 41 timeout addendum) | Status-check or different approach; not a blind retry of the same hung command. |
| no-tool-use / native tags as content | serving path returned empty or un-parsed tool calls | Pivot tool path; if recurring, file RCA (the empty-200 / format-leak class — see bug library). |

If the repair is obvious and works → done, continue. No idea needed.

## The idea (step 3 — when repair is NOT immediate)

If the error is systemic (recurring across calls or windows, environmental, or a client/infra bug), file via `create_idea` BEFORE completing the task:
- **title:** the error class (e.g. "parallel replace_in_file corrupts doc state -> Document not initialized")
- **description:** MUST contain (a) **root-cause analysis** — what actually caused the error, with evidence, and (b) **complete repair plan** — the specific code/config/behavior change that fixes it permanently. Not just "this happened" — the RCA + the fix.
- **domain:** technical
- **priority:** based on recurrence / blast radius (P1 if it kills windows)

The idea is the durable artifact so the NEXT window (or the executor) can implement the repair. Filing it satisfies this rule even if the current window cannot implement the fix itself.

## Self-check before attempt_completion

Ask: "Did I hit an error this task — tool error OR my own output error — that I worked around but didn't repair?" If yes → was it systemic? If systemic → did I file an idea with RCA + complete repair? If no → file it before completing.

## What this rule does NOT do

- Does NOT require filing an idea for a one-off error you repaired immediately (e.g. a stale SEARCH block you re-read and fixed). That's step 1, done.
- Does NOT apply to errors you are INVESTIGATING on Ruben's behalf (those are the task, not "your own error").
- Does NOT replace rule 143 (prose-loop circuit breaker) or rule 41 (post-error pivot table) — those govern the turn-by-turn recovery. This rule governs what happens AFTER: did the underlying issue get RCA'd + filed?

## Cross-references

- Rule 41 (post-deploy / post-ERROR pivot table — the per-class recovery)
- Rule 99 (YOLO prevention — this rule prevents the silent-workaround that feeds YOLOs)
- Rule 143 (prose-loop circuit breaker)
- Rule 144 (server paths via MCP, not local write — source of many EACCES errors)
- Rule 77/150 (MCP transport wedge handling)
- Rule 92 (work at the core — filing the RCA+repair IS the core fix, not a bandaid)
- Rule 91 (pickup prompt — filed idea #s go in the open threads)
- Idea #14856 (general client/telemetry layer for own-error RCA)
- Idea #14855 (specific replace_in_file EISDIR/EACCES/Document-not-initialized instance)

## Source incidents

- **2026-06-24** Ruben directive (verbatim above). Observed across multiple Frankenstein-LLM windows: `replace_in_file` errors — `EISDIR: illegal operation on a directory, read` (path was a directory), `EACCES: permission denied, open '/Users/ruben'` (path was a directory root), `Document not initialized` (parallel replace_in_file calls corrupted doc state) — recurred with no RCA filed; windows retried blindly or died. Ruben clarified the principle is GENERAL: all model errors the LLM experiences about itself in Cline, not just replace_in_file.

## Last updated

2026-06-24 — v2: widened scope to ALL own-error classes (not just file tools) per Ruben clarification; added idea cross-refs #14856/#14855.
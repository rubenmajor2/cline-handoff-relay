# 91 — Every attempt_completion must end with a copy-paste-ready PICKUP PROMPT for a new Cline window

Permanent rule. Workspace-scoped. Source: 2026-05-19 Ruben directive verbatim:

> *"cline rule, in every single task completed window need a pickup prompt to continue that task in a new window. Give a pickup prompt to continue this task in a new window"*

## The bright-line rule

**Every `attempt_completion.result` MUST end with a clearly-labeled, copy-paste-ready "PICKUP PROMPT" block** so Ruben (or a future agent) can paste it into a fresh Cline window and continue the task without re-reading the full conversation.

This rule supersedes the "TO RESUME THIS TASK LATER" one-liner in .clinerules/03 (Resume Kit). The Resume Kit was producing thin one-liners like *"pick up task #X from where we left off"* that didn't carry enough context. The new requirement: a full self-contained prompt block with the task ID, the latest state, the next moves, and any reference IDs the new agent will need.

## Required shape

The block at the END of every attempt_completion.result:

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════

Pick up task #<task_id> — <short topic in Ruben voice>.

Where we left off (verified <timestamp PT>):
- <1-3 bullets of the current state, with IDs>
- <key resource: ticket #N, idea #M, file path, etc.>

Open threads to drive next:
1. <next thing to do, with the MCP tool / SQL / file path needed>
2. <next thing>
3. <next thing>

Reference IDs:
- Ticket: <ticket_number / id>
- Ideas filed: <#id1, #id2, ...>
- Files touched: <path1, path2, ...>
- Source: <inbound id, voice_call_log id, etc.>

Cross-refs:
- .clinerules/<relevant rules>
- HANDOFF entry: <date PT — slug>
- Ledger entry: cline_task_ledger.md row dated <date PT>

When done, append a row to cline_task_ledger.md per rule 07 and run order 66 per .clinerules/EXECUTE_ORDER_66.
═══════════════════════════════════════════════
```

The double-line divider (═══) at start and end is mandatory so Ruben can spot the block instantly when scrolling.

## What goes in each section

### "Where we left off"
- One line per resource: ticket status + assignee, idea status, drain count, current % complete, etc.
- Include actual IDs and exact field values from MCP queries, not vague descriptions
- Latest verification timestamp PT

### "Open threads to drive next"
- Numbered 1-N with specific actionable items
- Each item names the exact MCP tool, SQL, file path, or URL needed
- Order by priority — the next agent reads top-down

### "Reference IDs"
- Tickets (number + status)
- Orchestrator ideas (id + priority + status)
- Files touched (absolute paths, both Mac-side and WOPR-side)
- Source incident IDs (email_inbound_log, voice_call_log, ExternshipFormSubmission, etc.)
- Any other database row that's relevant

### "Cross-refs"
- .clinerules/ rules invoked or to invoke
- HANDOFF_NOTES.md entry (if one was written)
- cline_task_ledger.md row (with date)
- Related Q-cards / `ruben_questions` entries
- Related session_handoffs chains

### Final instruction
- Always include the line about appending to cline_task_ledger.md per .clinerules/07
- Always include the order-66 reference for clean wrap-up per .clinerules/EXECUTE_ORDER_66
- If the task involves any specific posture (regulator, refund, etc.) cite the .clinerules/ rule for that posture

## What this rule does NOT do

- Does NOT replace .clinerules/03 (the Resume Kit format). The full attempt_completion.result still has the WHAT/CURRENT STATE/etc. sections. This rule adds the PICKUP PROMPT block AT THE END.
- Does NOT require a pickup prompt for pure Q&A / read-only diagnostics where nothing in the world changed. Single-line completions are fine.
- Does NOT require a pickup prompt when the task is fully closed (abandoned by user, all open threads resolved, ledger says `done` with no follow-ups). In those cases the block can read "No further pickup needed — task fully closed."

## Anti-patterns that violate this rule

- ❌ Wrap-up that ends with "TO RESUME THIS TASK LATER" + a one-line slug. That's the .clinerules/03 minimum; this rule requires more.
- ❌ Vague pickup ("check on the progress"). Be specific: which ticket, which idea, which SQL.
- ❌ Hiding the pickup prompt in the middle of the body — it MUST be at the END, after all other sections, with the divider.
- ❌ Skipping the divider lines so the block doesn't stand out in scroll.
- ❌ Pickup prompt without the reference IDs — the new window can't grep without them.
- ❌ **PICKUP-BY-REFERENCE** — saying "full pickup prompt in `/path/to/handoff.md`" / "see the file for the pickup prompt" / "pickup is at the bottom of the handoff doc" / "pickup prompt below in section 8" — anything that points the human at a separate location instead of EMBEDDING the prompt inline. The block with the `═══` dividers MUST appear verbatim in the `result` parameter of `attempt_completion` itself. Writing the pickup prompt to a Desktop .md file is fine (and encouraged for backup), but it does NOT satisfy this rule unless the same block also appears inline at the end of `result`. The reason: when Ruben taps "copy" on the completion bubble he gets the result text only — not the Desktop file. If the pickup prompt isn't in `result`, the copy-paste is broken and rule 91's whole purpose is defeated. Source: 2026-05-27 violation (cline_fleet_coordinator_2026-05-27) — completion ended with "Full handoff in the file, with pickup prompt for the next window." Ruben caught it: *"I believe you have a real 91 violation here so you're gonna have to give all to me all over again and I need you to harden rule 91 so that I get an actual pick up prompt window that is proper."*
- ❌ **NEVER write "hold first tool call until Ruben confirms" / "wait for confirmation" / "pause before acting" / "stop and ask before X"** anywhere in the pickup prompt. In YOLO mode this is a contradiction in terms — the agent either emits prose (rule-99 no-tool-use trip) OR calls `ask_followup_question` (YOLO auto-answers it instantly). Either way the task dies before doing real work. See "Forbidden phrases" below.

## Forbidden phrases in pickup prompts (added 2026-05-19 after 2× auto_respond_q YOLO trips)

Any pickup prompt containing these phrases will kill a fresh YOLO-mode window before it can take a single action:

- "hold first tool call until [X]" / "hold off until [X]"
- "wait for [Ruben/me/confirmation] before acting"
- "pause before [action]" / "stop and confirm before [action]"
- "confirm before proceeding" / "verify [X] is no longer in effect"
- "ask first if [condition]"
- "two prior windows yolo'd here, hold this one" — recursive bug
- Any sentence ending with "?" that's intended to be answered by the human

The agent that picks up the prompt has authority to act. Opening the window IS the confirmation. Pickup prompts must START with the FIRST tool call to make, not with a wait-state.

### Right shape

```
First tool call: `cv30BN0mcp0server_status` to confirm WOPR is up.
Then: `cv30BN0mcp0check_student student_id=8150598` to verify the patch landed.
```

NOT: "Hold first tool call until Ruben confirms it's safe to proceed. Then run server_status."

## Self-check before any attempt_completion

Ask: *"If I paste my completion message into a fresh Cline window right now, can the new agent take meaningful action within 30 seconds without scrolling the previous task history?"*

If no, the pickup prompt isn't ready. Rewrite.

## Source incident

2026-05-19 — End of cline_calderon_2nd_externship_recovery_2026_05_17 chain (after ~3 rounds of Ruben follow-up directives). Ruben asked: *"in every single task completed window need a pickup prompt to continue that task in a new window. Give a pickup prompt to continue this task in a new window."*

## Budget-watchdog tier mandate (added 2026-05-20, idea #5354 Layer 2)

The Mac-side `cline_budget_watchdog` (launchd `com.emsu.cline-budget-watchdog`, every 60s) writes `/tmp/cline_budget_status.json` with the current task's context_size + tier (GREEN <500K, YELLOW 500K-800K, RED 800K-900K, IMMINENT >900K).

**Mandatory durable-artifact behavior by tier:**

- **GREEN** — normal operation. No special action.
- **YELLOW** — before the next risky/long tool call (subagent dispatch, large read, multi-file build), write a durable artifact: append a row to `cline_task_ledger.md`, OR a HANDOFF_NOTES entry, OR an `orchestrator_ideas` row capturing current state. The window may not survive to attempt_completion.
- **RED** — STOP non-essential work. Immediately write a pickup-prompt-shaped HANDOFF entry + ledger row + (if applicable) a status comment on the active idea. THEN consider whether to attempt_completion early rather than push deeper.
- **IMMINENT** (>900K) — call `attempt_completion` next. The pickup prompt IS the durable artifact. Do not start any new tool chain.

**Self-check on every tool call past YELLOW:** "If this window dies right now, did I leave a row somewhere that lets the next window pick up?" If no → write the artifact before the next risky call.

The watchdog also fires an osascript notification at RED/IMMINENT so Ruben sees the same signal in real time.

## Last updated

2026-05-19 — initial rule per Ruben directive in the Calderon recovery chain.
2026-05-20 — added budget-watchdog tier mandate (Layer 2 of idea #5354).

## 2026-05-26 addendum — per-task budget file + T5 periodic-compress trigger

- **Idea #7377 (shipped):** per-task budget file naming pattern `/tmp/cline_budget_status_TASK<task_id>.json` to prevent sibling Cline tasks from clobbering each other's tier signal. Writer: `~/Documents/Cline/scripts/cline_budget_watchdog.py` lines 145-150 now writes both the legacy global file (`/tmp/cline_budget_status.json`) AND the per-task file. Readers/agents should prefer the per-task file when a task_id is known.

- **Idea #7380 (shipped):** T5 periodic-compress trigger via the cline-compress MCP `should_compress_now` tool. Agent should poll every ~150K tokens of growth (or every N tool calls in a long-running task). Returns `{ should_compress, tier, context_size, growth_since_last, reason }` keyed on a caller-supplied `last_compress_size` argument and a `growth_threshold` (default 150000). When `should_compress=true` and ti- **Idea #7380 (shipped):** T5 periodic-compress trigger via the cline-compress MCP `should_compdia- **Idea #7380 (shipped):** T5 periodic-compress trigger via the cline-comprehdog tier mandate above.

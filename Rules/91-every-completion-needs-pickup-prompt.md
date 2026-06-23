# 91 — Every attempt_completion must end with a copy-paste-ready PICKUP PROMPT for a new Cline window

Permanent rule. Workspace-scoped. Source: 2026-05-19 Ruben directive verbatim:

> *"cline rule, in every single task completed window need a pickup prompt to continue that task in a new window. Give a pickup prompt to continue this task in a new window"*

## BINARY GATE (run BEFORE attempt_completion)

**Scan your `result` text. If the string `═══ PICKUP PROMPT ═══` does NOT appear in `result`, the completion is BROKEN. Period. Do not ship it.** Add the pickup prompt block. This gate fires BEFORE any other consideration — no pickup prompt, no completion.

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

**Gate 0 (rule 29 act-or-defer test — run FIRST, before writing any open thread):**

Before any candidate item goes into the open threads list, apply rule 29's act-or-defer test in order:

1. **Do I have a tool that performs this action?** (update_ticket, add_ticket_comment, create_idea, ssh_command, fix_moodle_enrollment, send email/SMS via agent_send_or_draft, SQL write, safe_deploy, etc.) → **YES → ACT NOW. Do NOT list it as an open thread.** An item the current window can execute is NOT deferred work; it is undone work. Listing it instead of doing it is the rule 29 parking-lot anti-pattern.
2. **Is this a judgment call requiring a specific human's policy authority?** (final refund amount, regulator response wording, grievance outcome, hiring decision, money over the agent's code-level cap) → OK to defer. Continue to Gate 1.
3. **Is fresh-window budget the only reason?** (rule 91 budget-watchdog IMMINENT tier, or the current window's consecutive-mistake counter is at the limit) → OK to defer. Continue to Gate 1.

If an item cannot clear Gate 0 (the agent has the tool AND is not at imminent budget AND it's not a human-authority decision), it MUST be done now, not listed. Listing it anyway is a rule 29 violation regardless of whether an idea number is attached.

**Gate 1 (idea-number mandate — every surviving open thread MUST become a filed idea):**

- Numbered 1-N with specific actionable items
- Each item names the exact MCP tool, SQL, file path, or URL needed
- Order by priority — the next agent reads top-down
- **MANDATORY: every open-thread item MUST carry a filed idea number** (`#NNNN` from `orchestrator_ideas` / `create_idea`). An open thread is, by definition, deferred work — and per .clinerules/38 deferred Ruben-context work lands as a filed idea, not loose prose. Before writing the pickup prompt, FILE each open thread via `create_idea` (P2/P3 as appropriate, domain technical/etc), then cite the returned `#NNNN` inline on that item. A pickup-prompt "open threads" list containing items WITHOUT idea numbers is a rule violation — the agent is treating the pickup prompt as a parking lot instead of filing the work. "Optional"/"future"/"nice-to-have" does NOT exempt an item: if it's worth listing, it's worth a number. The ONLY exception is an item that is a genuine human-policy decision (refund amount, regulator wording) already routed via a Q-card — cite the Q-card id instead.

**The two-gate procedure (execute before writing the pickup prompt):**

```
For each candidate open thread:
  → Gate 0: Can the current agent/window do this right now?
      YES → DO IT. Remove from candidate list. Do not list.
      NO  → Gate 1: File via create_idea. Get #NNNN. List with #NNNN.
```

An open thread with no idea number is always wrong: either (a) the agent should have done it and didn't (rule 29 violation) or (b) it's deferred work that wasn't filed (also rule 29 violation). There is no valid open thread without a real idea number.

**HARDFLOOR — `#NNNN` is a TEMPLATE TOKEN, never literal output.** NEVER emit the literal string `#NNNN` (or `#N`, `#XXXX`, `idea #TBD`, any placeholder) in a completion or pickup prompt. `#NNNN` everywhere in this rule means "the real integer id `create_idea` returned," e.g. `#12657`. If your draft contains a literal `#NNNN`/placeholder, you skipped the filing step: STOP, call `create_idea` for each item now, and substitute the real returned ids. A completion shipped with a literal `#NNNN` is a rule-91 + rule-29 violation. Source incident: 2026-06-15 — a Window-3 VAPI/housekeeping pickup prompt shipped 5 open threads all reading "#NNNN - File Idea to ..." with zero real ids; Ruben: "what's idea #NNNN - lots of those, lol - that's buggy."

**HARDFLOOR — ALL pickup-prompt placeholders are forbidden as literal output, not just `#NNNN`.** The same ban applies to the TASK-ID and TIMESTAMP template tokens in the PICKUP PROMPT block. NEVER emit any of these literally:
- `task #0000`, `#0000`, `task #XXXX`, `#XXXX`, `<task_id>`, `<new-task-id>`, `<task-id>` — substitute the REAL Cline task id (from environment_details / the active task), or if genuinely unknown, write a short descriptive slug instead (e.g. "Pick up the frankenstein-MCP-stability task") with NO `#` id at all. A literal `#0000` signals "there is no real task / placeholder not filled" — exactly the bug Ruben flagged.
- `<timestamp PT>`, `<timestamp>`, `<date PT>`, `<YYYY-MM-DD ... PT>` — substitute the REAL current PT timestamp (it is in environment_details "Current Time"). Never ship the angle-bracket placeholder.
Self-check before any `attempt_completion`: scan the pickup prompt for `#0000`, `#XXXX`, or any `<...>` angle-bracket token. If found, the completion is NOT ready — substitute the real value or remove the line. Source incident: 2026-06-16 — a frankenstein-llm window shipped "Pick up task #0000 — Verify MCP transport stability" + "verified <timestamp PT>". Ruben: "obviously that's incorrect and this is a bug that has been encountered before... placeholder not filling."

Source incidents:
- 2026-06-02 cline_chat9222 Window 2 — listed 4 "open threads / optional hardening" items as prose with no idea numbers. Ruben: "these need idea numbers. You are being very resistent here." Fix: file first (#9250-#9253), then list.
- 2026-06-04 Ruben directive: "rule 91 Rebase use rule 29 open threads become ideas" — Gate 0 added to make rule 29's act-or-defer test the primary gate before the idea-number mandate fires.

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
- Does NOT require a pickup prompt for pure Q&A / read-only diagnostics where nothing in the world changed. Single-line completions are fine. **"Nothing changed" means zero system-state changes — no files written, no processes restarted, no servers rebuilt, no MCP connections fixed, no SQL executed, no deploys, no configs touched.** Infrastructure fix tasks (MCP restarts, server rebuilds, native module recompiles, service repairs) ALWAYS have system-state changes and are NEVER exempt from the pickup prompt, even when they feel "done" or "simple."
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

## Surface idea #s in the completion BODY, not just the pickup prompt (added 2026-06-09)

Source: 2026-06-09 Ruben directive — *"now you're not showing me ideas # like you used to, and you're not showing me idea #s really at all anymore... harden the cline rules to make sure you are doing that."*

The idea-number mandate in the "Open threads" section only requires `#NNNN` inside the pickup-prompt block. But Ruben reads the **completion body** (the prose summary above the `═══` divider) — that's where he scans for what happened. If every idea I filed/approved/rejected this task is only cited deep in the pickup prompt, he can't see them at a glance. Both surfaces must carry them.

**The rule: every `attempt_completion` that filed, approved, rejected, or acted on any `orchestrator_ideas` row MUST cite each idea by `#NNNN` in the completion BODY (the prose Ruben reads), with a one-line status.** Not only in the pickup prompt. Not "I filed a couple ideas" — the actual numbers.

### Required shape — an "Ideas this task" line/block in the body

Near the end of the completion prose (before the `═══` pickup divider), include an explicit, scannable list:

```
Ideas this task: #11304 (filed+approved — naming convention), #11295 (filed+approved — anti-revert block), #11294 (rejected — premise disproven), #11287 (record — wrong framing).
```

- ALWAYS include the `#` and the number. Never "an idea," "a P2," "a follow-up" without the number.
- ALWAYS include the disposition: filed / approved / rejected / shipped / record / superseded.
- If zero ideas were touched this task, say so explicitly: "Ideas this task: none." (so Ruben knows it wasn't an omission).
- This is IN ADDITION to the pickup-prompt "Reference IDs" + per-open-thread `#NNNN` (which stay required).

### Self-check before any attempt_completion

Ask: *"Did I file/approve/reject/act on any idea this task? If yes, are all their #NNNN visible in the BODY Ruben reads, each with a disposition?"* If any idea number is only in the pickup prompt (or worse, not cited at all), the completion is not ready — add the "Ideas this task:" line to the body.

This composes with rule 38 (Ruben-asked = autonomous/approved tier): when I bump an idea to approved per 38, that approval + its `#NNNN` is exactly the thing Ruben needs to see in the body.

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

## 2026-06-14 addendum — PICKUP PROMPT block is ONLY legal inside attempt_completion.result (never mid-task)

Source: Window F 2026-06-14 — Ruben observed a frankenstein-llm Cline window emit the full `═══ PICKUP PROMPT ═══` block as a mid-task assistant content turn, then immediately keep iterating. Filed as frankenstein_router_incidents id=49 (`behavior_pickup_prompt_mid_task`). Idea #12424 (approved).

### The bright-line rule (addendum)

**The `═══ PICKUP PROMPT ═══` block (the divider + all content up to the closing `═══`) MUST ONLY appear as the final section of `attempt_completion.result`. It MUST NOT appear in any other context:**

- ❌ Mid-task assistant turn (even if framed as "checkpoint" or "progress summary")
- ❌ HANDOFF_NOTES.md entry
- ❌ Any tool call output or inline prose that is not `attempt_completion`
- ❌ A turn immediately before `attempt_completion` (must be IN it, not before it)

### Why: the block is a signal, not just a format

When a fresh Cline window sees the `═══` block, it interprets it as "the previous window called attempt_completion; here is the resume state." If the block appears mid-task in a window that then keeps running, the signal is false. It confuses Ruben (is the task done or not?) and can cause a fresh window to resume work that the original window was still doing.

### What to use instead for mid-task checkpointing

If a window needs to save progress mid-task (e.g. approaching context limits, window might die):

1. **`update_handoff_notes` MCP** — append a HANDOFF_NOTES entry with current state + next steps. Uses the same structured content as the pickup prompt but without the `═══` delimiters.
2. **`cline_task_ledger.md` row** — append a row per .clinerules/07 with date, task, status, key IDs.
3. **`create_idea` + `agent_drafts` row** — if the remaining work is a discrete unit, file it as an idea.

None of these use the `═══ PICKUP PROMPT ═══` wrapper. That wrapper is reserved for `attempt_completion`.

### Companion to rule 41

Emitting the pickup block mid-task then continuing is the task-level version of rule 41's "Deployed. Now reload FPM:" anti-pattern — announcing done-ness then not being done. The fix is the same: if the block appears, `attempt_completion` must be in the same response. If you're not ready to call `attempt_completion`, don't emit the `═══` block.

### Self-check before emitting the ═══ block

Ask: "Is the next thing I'm calling in this same response `attempt_completion`?" If no — do not emit the `═══` block. Use `update_handoff_notes` for mid-task state.

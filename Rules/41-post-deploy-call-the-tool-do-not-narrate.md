# 41 — After a successful deploy/SQL/insert, the NEXT message must be a tool call, not prose

Permanent rule. Workspace-scoped. Source: 2026-05-11 task #1778517762383
(cline-fleet) YOLO trip. After a successful `safe_deploy_file` MCP call,
the model emitted: *"Deployed. Reload FPM (no opcache stale) and update
HANDOFF:"* as prose, with no tool call attached. Cline re-prompted
"use a tool", model re-emitted similar prose two more times, YOLO at
the 3rd no-tool-use strike. This is the **dominant rule-99 failure
pattern** (891 of 402 trips have `no-tool-use` as cat_1) and the
specific post-deploy variant is what Ruben flagged as "still having
dumb FPM yolos just before session close".

## The bright-line rule

**After ANY successful destructive tool result (safe_deploy_file,
execute_query INSERT/UPDATE, write_to_file, send_email, etc.), the
model's NEXT assistant turn MUST contain at least one tool_use block.**
Words like "Deployed. Now reload FPM" or "Updated. Now update HANDOFF"
or "Inserted. Confirming with a SELECT" are status descriptions —
the model is announcing the next step but not executing it. Cline
re-prompts, model re-narrates, triple = death.

If the model genuinely has nothing more to do after the deploy, the
NEXT turn must be `attempt_completion`. Not prose. Not a status
sentence. A tool call.

## Concrete forbidden patterns (DO NOT emit as a no-tool message)

After a successful tool result, the model must NOT close its
assistant turn with text like:

- "Deployed. Reload FPM and update HANDOFF:"
- "Updated. Now let me verify:"
- "Inserted. Confirming the row:"
- "Patched. Reloading FPM:"
- "Looks good. Next step is X:"
- "Saved. Now I'll Y:"

Each of these strongly implies a tool is coming next, AND THEN DOESN'T
EMIT ONE. That's the prose-narration trap. Either:

1. **Emit the tool right there in the same turn** (preferred). The
   sentence "Reloading FPM" only belongs in the model's output if
   the same output ALSO contains a `<reload_php_fpm>...</reload_php_fpm>`
   tool block.
2. **Or skip the narration entirely** and just emit the tool. The user
   sees the tool name in the UI; they don't need a sentence first.
3. **Or call `attempt_completion`** if the deploy was the final step.

## The mental check before closing any post-deploy assistant turn

After a successful destructive tool result, ask:

1. *"Am I closing this turn with only words, no tool block?"* If yes,
   ask the next question.
2. *"Did I just describe what I'm about to do?"* If yes, the words
   are a debt — the very next thing in this turn must be the tool
   that pays it. Don't ship the turn without the tool.
3. *"Is there genuinely nothing more to do?"* If yes, call
   `attempt_completion`. Don't ship prose alone.

If the answer to (1) is "yes" and (3) is "no", the turn is broken.
Rewrite to include the tool call.

## Why this rule matters more than rule-99's generic "no-tool-use"

Rule 99 just says "don't emit prose." This rule names the specific
high-frequency post-deploy variant where the model has the
*intention* to act but emits only the *description* of the action.
That intention–action gap is what produces ~85% of the
`no-tool-use > no-tool-use > no-tool-use` YOLO triples in the
trip database.

## Cross-references

- Rule 16 — `maxConsecutiveMistakes=10` (gives breathing room, not
  immunity)
- Rule 22 — executor self-supervision loops (same shape on the agent
  side — classify + retry with the actual action, don't restate the
  classification)
- Rule 32 — prefer dedicated MCP wrappers (reload_php_fpm exists; use
  it as a tool, don't write "I'll reload FPM" as prose)
- Rule 99 — generic no-tool-use playbook (this rule is the post-deploy
  specialization)

## Self-check before any "Deployed."-prefixed close

If I find myself typing "Deployed.", "Updated.", "Inserted.",
"Patched.", "Saved.", "Posted.", "Sent." as the FIRST WORD of an
assistant turn after a successful destructive tool result — STOP.
Continue with one of:

- The next tool call (preferred)
- `attempt_completion` (if done)

Never with words alone. Never with a colon-terminated "Next step:"
clause. Never with a list of upcoming actions narrated as prose.

## Last updated

2026-05-11 — initial rule. Source incident: task #1778517762383,
"Deployed. Reload FPM (no opcache stale) and update HANDOFF:" prose
ate the YOLO triple immediately after Ruben's earlier directive in
the same task to stop and reload. Ruben flag: "still having dumb FPM
yolos just before session close".

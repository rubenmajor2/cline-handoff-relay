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

2026-05-19 — added timeout-triple addendum (below).

## 2026-05-19 addendum — the timeout → prose → prose YOLO triple (27% of all trips)

Source: cline_learner_report.php live data — `yolo_top_triple = "timeout > no-tool-use > no-tool-use"` matched **125 of 467 cumulative YOLO trips (27%)**, #2 ranked triple after pure no-tool-use triples (108 hits). This is the dominant failure pattern when remote work hangs.

### The mechanism

A tool hits the 30s wall (or any timeout) and returns a timeout error. Instead of immediately calling another tool, Cline narrates: "Hmm, that timed out, let me think about what happened." Cline gets re-prompted to use a tool. Cline narrates again: "I'll wait a moment then retry the same command." Cline gets re-prompted. Third strike, YOLO trips. The user sees three turns of prose and zero forward progress on a remote box that may or may not still be running the work.

### The bright-line rule (timeout edition)

**A timeout is not a conversation. A timeout is a signal that the work moved out of my visibility, and my NEXT tool call has exactly three legal shapes:**

1. **Status-check tool** to assess what actually happened on the remote side. Example: timeout on `ssh deploy@box 'composer install'` → next call is `ssh deploy@box 'ls -la /var/www/app/vendor/ && tail -50 /tmp/composer.log'`, not prose. Use a shorter, bounded version to find out the state.

2. **Different-approach tool** — switch to the scp-script + nohup pattern per .clinerules/95 if the work might still be useful. Or split the work smaller. NOT a retry of the same hung command.

3. **`attempt_completion` with partial state** — if the timeout makes the rest of the task moot or genuinely needs Ruben's call. Report what completed before the timeout, what's unknown, what the recovery path is.

NOT a fourth option of "narrate the timeout in prose and see what happens." That's exactly how 125 trips died.

### Forbidden first-words after a timeout error

If my next assistant turn starts with any of these, I'm walking into the triple:

- "Hmm, let me..."
- "That timed out, let me explain..."
- "Let me check what happened..."
- "I'll wait a moment then retry..."
- "Looks like a connection issue..."
- "The server might be busy, let me..."

Each of these is a sentence. None of them are tool calls. Per rule 41's main body, sentences without a paired tool block are the failure mode. After a timeout the failure mode is amplified because the timeout itself already burned one consecutive-mistakes strike.

### The OK pattern (concrete)

After timeout on `ssh artemis "long thing"`:
- ✅ Next tool call: `ssh artemis "ls /tmp/longjob.log && tail -50 /tmp/longjob.log"` (status check, bounded)
- ✅ Next tool call: scp a wrapped version of the script per .clinerules/95 + nohup launch detached
- ✅ Next tool call: `attempt_completion` reporting "long thing timed out; on-disk state shows X; recommend manual verify"

After timeout on a single MCP call:
- ✅ Next tool call: a SIMPLER variant of the same MCP wrapper (less data, shorter window)
- ✅ Next tool call: a sibling MCP wrapper that gets at the same data differently
- ✅ Next tool call: `attempt_completion` if no recovery path is obvious

### Cross-references

- `.clinerules/95` — Cline 30s tool wall + scp+nohup remote pattern (the PREVENTION layer — most timeouts shouldn't happen if you use the pattern correctly)
- `.clinerules/99` — YOLO prevention playbook (the `timeout` entry has the per-class recovery, and `no-tool-use` entry has the prose-trap rule that pairs with this one)
- `.clinerules/16` — maxConsecutiveMistakes threshold (after the 2026-05-19 bump to 15, this addendum has more headroom but doesn't eliminate the triple)

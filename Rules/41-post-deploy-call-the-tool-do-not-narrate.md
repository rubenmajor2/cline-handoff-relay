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

## 2026-05-22 addendum — the colon-trailed announcement is the #1 living trip class (48% of last 7d)

Source: yolo_trips.sqlite scan 2026-05-22 20:04 PT. Last 7 days = 73 trips, **35 (48%) are pure prose→prose→YOLO with NO preceding tool error**. Top triple this week: `no-tool-use > no-tool-use > (none)` (19) + `no-tool-use > no-tool-use > no-tool-use` (16) = 35 of 73. These are NOT timeouts or API overloads — they are the model successfully completing a tool call, then writing the NEXT step as prose and never emitting it.

### Three fresh source incidents (all 2026-05-22, all the same shape)

1. **task #1779466924466, 19:23 PT** — after a successful `ssh_command` confirming PHP lint passed, model wrote: *"Panel wired. Now reload FPM and verify, then tackle #5792."* No tool block. Re-prompt × 2. YOLO.
2. **task #1779466420483, 19:23 PT** — after a successful MCP tool call returned `MCP error -32000: Connection closed`, model wrote: *"MCP tunnel hiccup. Retry:"* No tool block (just the colon). Re-prompt × 2. YOLO.
3. **task #1779494742877, 19:23 PT** — after a successful `replace_in_file` to `_INDEX.md`, model wrote: *"Reindexing the MCP and stamping a ledger row."* No tool block. Re-prompt × 2. YOLO.
4. **THE META-INCIDENT — task #1779500505183, 20:06 PT (this very task)** — Cline was *literally writing this rule* about the prose-trap. After successfully running `python3 scan.py && python3 write_rule.py` to regenerate rule 99, the model wrote: *"Rule 99 regenerated with fresh data. Now reindex the clinerules MCP so the addendum is queryable."* No tool block. Hit `[ERROR] You did not use a tool` immediately. The model documenting the trap was caught in the trap, ~30 seconds after writing the binary colon test below. **This is the strongest possible evidence that the failure mode is not about knowing the rule — it is about a reflexive "narrate the next step" habit that fires faster than the self-check.** The rule must be a hard binary test executed BEFORE composing the prose, not a self-check after.

All four were mid-task, all four had **dozens** of successful tool calls before, all four died on a single trailing announcement.

### The new hard test (use this as a binary check before closing any turn)

**If the last non-whitespace character of your assistant turn is `:` AND the turn has no tool_use block, the turn is broken. Period.** Don't ship it.

The colon at end of turn is the linguistic tell. It says "the next thing is the tool" — but if no tool follows in the same turn, the model is announcing instead of acting. Cline injects `[ERROR] You did not use a tool` and the strike clock starts.

Same broken-turn shape, just different surface forms:
- `"Now reload FPM and verify:"` → no tool → broken
- `"Retry:"` → no tool → broken
- `"Reindexing the MCP and stamping a ledger row."` → no tool → broken (period instead of colon, but still announcement-without-action)
- `"Next I'll patch the route and reload."` → no tool → broken
- `"Stamping the ledger row now."` → no tool → broken

### The mid-task "Now X" trap (extends rule 41's original post-deploy version)

Rule 41 originally targeted post-deploy. The 2026-05-22 data shows the trap fires EVERYWHERE in a task, not just after deploys. Every tool result is a potential trap site:
- after `read_file` → model says "Now I'll edit it:" without the edit tool
- after `write_to_file` → "Now reindexing:" without the reindex call
- after `replace_in_file` → "Now updating the related file:" without the next replace_in_file
- after an MCP tool result → "Now confirming:" without the verify call

The fix is the same in every case: **the announcement and the tool must be in the SAME assistant turn, or skip the announcement entirely.**

### Recovery: the `[ERROR] You did not use a tool` re-prompt is a FREE STRIKE — use it

When Cline injects `[ERROR] You did not use a tool in your previous response!`, that's strike 1 of 3. The next two turns are the danger zone. Recovery is:

1. **DO NOT** re-narrate what you were about to do. The user already sees the error.
2. **DO NOT** explain why you didn't call a tool. Just call it.
3. The very next turn MUST contain a tool_use block — the one you should have called, OR `attempt_completion` if you genuinely have nothing to do.
4. Two consecutive `[ERROR]` re-prompts = strike 3 = YOLO. So the FIRST error must produce a tool, not more prose.

Specifically forbidden first-words after `[ERROR] You did not use a tool`:
- "You're right, let me..."
- "Calling the tool now:"
- "Apologies, here:"
- "Let me try again with:"
- Any sentence at all that doesn't have a tool block following it in the SAME turn

The correct response to that error is silent action — emit the tool, no narration.

### Self-check (revised, ship before any non-tool turn)

Before pressing send on any assistant turn, scan the bottom 3 lines:

1. *Does this turn contain a `<tool_use>` block?* If yes → ship. If no → continue.
2. *Is this turn `attempt_completion`?* If yes → ship. If no → continue.
3. *Did the turn just emit only words?* → **The turn is broken. Rewrite to include the tool, or to be `attempt_completion`.**

The binary test takes 2 seconds. Doing it kills the 48%-of-trips class.

## Last updated

2026-05-22 — colon-trailed announcement addendum. Source: 3 fresh YOLOs in a single 24h window all matching the same shape, all mid-task, all post-successful-tool-result. The original rule 41 body covered this in spirit but the trips kept happening — needed the explicit binary colon test + the "free strike" recovery framing.

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

## 2026-05-22 addendum — generalized post-ERROR pivot (extends timeout addendum to all error classes)

Source: scan 2026-05-22 of `~/Documents/Cline/yolo_learner/yolo_trips.sqlite`. Last 7 days = 73 trips. Top `cat_1` distribution: `no-tool-use` 36, `timeout` 10, `mysql query failed` 4, `api: overloaded` 4, `sql: unknown column` 2, `shell: command not found` 2, `file/path does not exist` 2, `browser_action: failed` 2, `ssh: connect/timeout` 1, `safe-deploy: invalid flag` 1, `php: syntax error` 1, `permission denied` 1, `tool: generic execution error` 1. The pattern is identical to the timeout addendum above: an unavoidable first-tool error, then TWO narration turns ate strikes 2 and 3 = YOLO. The first error is fine. The two prose turns after it are the bug.

### The bright-line rule (generalized to ALL error classes)

**The assistant turn IMMEDIATELY AFTER any failed-tool result MUST contain a tool_use block.** Not just timeouts. Not just post-deploy. ALL error results — api overload, mysql failure, safe-deploy bad-flag, file not found, ssh timeout, shell command not found, php syntax error, browser action failed, permission denied, generic tool error.

Concrete: if a tool returns an error / non-200 / `Error:` prefix / `PHP Fatal error` / `MySQL query failed` / `Unknown column` / `connect timeout` / `does not exist` / `command not found` / `Permission denied`, the next assistant turn does exactly ONE of:

1. **A DIFFERENT tool call** (different command, different MCP wrapper, different path, different SQL, different flag). Not the same call again, even with minor edits — that's the death-spiral entry point.
2. **`attempt_completion`** with a status of "blocked, <one line why>". Surface the dead-end as a clean completion, don't loop.
3. **`attempt_completion`** reporting the partial work that did land. The window closes cleanly; Ruben picks up in a fresh window.

NEVER: a prose-only assistant turn explaining the error, planning the next try, or hoping the issue is transient. The error text is already on the user's screen. Adding prose burns one of the 3 consecutive-mistakes strikes for zero benefit.

### Per-class pivot table (what to call instead of narrating)

| Error class | Wrong move | Right move (next tool) |
|---|---|---|
| `api: overloaded/rate-limit` | "Let me wait then retry" | `attempt_completion` "Anthropic overloaded, pausing, re-prompt me in 60s" |
| `mysql: unknown column` | "Let me try a different column name" | `describe_table` MCP, then re-emit the query with the real column |
| `mysql: query failed` | "Let me check the syntax" | `list_tables` / `describe_table` MCP, or a shorter LIMIT-1 SELECT to inspect shape |
| `safe-deploy: invalid flag` | "Let me check the help" | Re-emit with the correct `--target` `--content` `--expected-sha256` flags (rule 99) |
| `safe-deploy: sha drift` | Retry with the old hash | `read_file` to get fresh content + `sha256sum` to compute fresh hash, then safe-deploy |
| `file/path does not exist` | "Let me check the path" | `list_files` on parent dir, or `execute_command ls -la <parent>` |
| `permission denied (server path written locally)` | Retry `write_to_file` | `ssh_command` with `cat > path <<EOF` heredoc — server path needs server tool |
| `ssh: connect/timeout` | "Let me retry SSH" | `server_status` MCP first, or `attempt_completion` "WOPR SSH down, pausing" |
| `shell: command not found` | "Let me try a different command" | `execute_command which <cmd>` to verify path, or a known-good alternative |
| `php: syntax error` | Retry safe-deploy with same content | `write_to_file /tmp/check.php` + `execute_command php -l /tmp/check.php`, fix offline, then deploy |
| `browser_action: failed` | Repeat the same click | `browser_action close` then relaunch, or pivot off browser entirely |
| `tool: generic execution error` | Blind retry | Re-read the error text, pick a tool that addresses what it actually said |

### The "WOPR is down" special case (cross-ref rules 77, 95)

If two SSH/emsu-operations MCP calls fail in a row → the WireGuard tunnel is wedged. Do NOT keep firing MCP calls hoping the third succeeds. Either:
- `attempt_completion` with status "WOPR SSH unreachable, paused, needs tunnel kick" (rule 77)
- Or pivot to local-only work (Mac filesystem, .clinerules, ledger) until Ruben restarts the tunnel

### Self-check on every tool-error result

Before composing the next turn, ask:

1. *"Will the next turn I emit contain a tool_use block?"* If no, STOP and rewrite.
2. *"Is my next tool call the SAME shape as the one that just failed?"* If yes, STOP and change tools per the table above. Two of the same failure in a row is the death-spiral entry.
3. *"Have I already had 2 errors this task?"* If yes, next turn MUST be `attempt_completion`. The 3rd strike is YOLO; don't roll the dice on a 3rd retry.

### Forbidden first-words after a tool error (extended from the timeout list)

If the next assistant turn starts with any of these AND has no paired tool_use block in the same turn, it is the trap:

- "Let me check..." / "Let me try..." / "Let me see..." / "Let me wait..."
- "Hmm" / "Looks like" / "Seems" / "Apparently" / "It seems"
- "The query failed because..." / "The server appears to be..."
- "I'll try a different approach"
- "That didn't work, so..."

Each is fine PREFIXED to a tool block in the same turn. None are fine alone. Binary test: does this assistant turn contain a `<tool_use>` block? If no, the turn is broken, rewrite it.

### Source incidents (2026-05-22)

- task 1779466420483 (2026-05-22 09:37): api overload → 2 narrate turns → YOLO. Should have hit `attempt_completion` after the 1st overload.
- task 1779420001388 (2026-05-21 20:43): mysql `Unknown column 'ticket_number'` → narrate → WOPR SSH dropped (tunnel wedged) → narrate → YOLO. Should have hit `attempt_completion` at the SSH drop per rule 77.
- task 1779418656169 (2026-05-21 20:13): safe-deploy `--src` bad flag → narrate → narrate → YOLO. Should have re-emitted with `--target/--content/--expected-sha256` immediately.
- task 1779410470852 (2026-05-21 18:22): shell command not found → narrate → narrate → YOLO. Should have used `which` to verify path first.
- task 1779267773315 (2026-05-20 02:22): file not found → narrate → narrate → YOLO. Should have `list_files` on parent before retrying.

All 5 would have been saved by the pivot rule above.

## 2026-06-02 addendum — banned: blocking LOCAL commands that hang the terminal (live-reproduced trigger)

Source: 2026-06-02 00:05-00:10 PT. Ruben reported live YOLOs across multiple windows and directed a rule-29 action. While investigating, **Cline reproduced the trigger in the same session, twice**: ran `sudo wg show` (interactive password prompt) and a raw local `ssh wopr` — both HUNG the terminal waiting on stdin/tunnel. The model got no tool output, emitted prose waiting on it, hit `[ERROR] You did not use a tool`, emitted prose again, and tripped. A wedged terminal then made every subsequent `execute_command` time out at 30s, compounding it. Verified NOT infra: LiteLLM returned http=200 in 1.5ms with an empty restart log, WOPR healthy via the emsu-operations MCP, maxConsecutiveMistakes correctly 10. The killer was the blocking LOCAL command every time.

### The bright-line rule (blocking-local-command edition)

**Never issue a local `execute_command` that can block on stdin or hang indefinitely.** Banned as local shell calls:

- ❌ `sudo <anything>` that prompts for a password (`sudo wg show`, `sudo systemctl ...`) — the prompt hangs the terminal forever from the model's view
- ❌ Bare `ssh wopr` / `ssh <host>` for WOPR work — if the WireGuard tunnel is slow it stalls past the 30s wall
- ❌ Interactive REPL/pager without a non-interactive flag (`mysql` without `-e`, `less`, `vim`, `top` without `-b -n1`, `git` without `--no-pager`)
- ❌ `ping` without a hard `-c N -t S` bound, `nc` without `-G`/`-w`

### What to do instead — for WOPR, the MCP is the ONLY path

WOPR work goes through the **emsu-operations MCP**, never raw local ssh/sudo: `server_status` (health), `ssh_command` (arbitrary remote — routes via port 2222 with keys, has its own timeout, CANNOT hang the local terminal), `check_server_logs`, `reload_php_fpm`. The MCP route returns instantly even when local `ssh wopr` times out. That asymmetry IS the lesson. Composes with rule 32 (MCP over raw shell) + rule 77 (tunnel-down handling).

### If the local terminal is ALREADY wedged

A hung blocking command poisons the terminal: subsequent `execute_command` calls time out at 30s each, and each timeout is a strike. The moment two `execute_command` calls time out in a row, STOP using `execute_command`. Switch to tools with a different I/O path: `read_file`, `write_to_file`, `replace_in_file`, `list_files`, or the MCPs. Those do not run through the stuck shell.

### Recovery when a local command hangs

1. Do NOT emit a prose turn waiting on it. The next assistant turn MUST be a different tool call — the MCP/file-tool equivalent.
2. Do NOT re-run the same blocking command.
3. If no alternative path exists, `attempt_completion` reporting the hang — don't narrate at it.

### Self-check before any `execute_command`

1. Can this prompt for a password or wait on stdin? → banned local; use MCP or a non-interactive flag.
2. Is this `ssh`/`sudo` aimed at WOPR? → use emsu-operations MCP instead, always.
3. Has the terminal already timed out once this task? → don't use `execute_command` again; use file tools or MCP.

### Last updated (this addendum)

2026-06-02 — Cline reproduced the blocking-local-command YOLO live during a Ruben-directed YOLO investigation. Per rule 29 (act, don't diagnose-and-defer) + rule 38 (Ruben-asked = ship now) + rule 92 (fix the core): the fix is this hardfloor clause banning the trigger. Single most reliable prevention: for WOPR, the emsu-operations MCP is the only allowed path; raw local ssh/sudo is banned, and a wedged terminal means switch to file/MCP tools immediately.

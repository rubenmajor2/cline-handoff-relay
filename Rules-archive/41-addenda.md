# 41 Addenda Archive — Full source incidents + detailed elaborations

This file archives the addenda trimmed from Rule 41 v1 (24KB) when it was reduced to v2 (~5KB) on 2026-06-25. The core gate + pivot table remain in `Rules/41-post-deploy-call-the-tool-do-not-narrate.md`. This file holds the source incidents and detailed elaborations for reference.

---

## 2026-05-22 addendum — the colon-trailed announcement is the #1 living trip class (48% of last 7d)

Source: yolo_trips.sqlite scan 2026-05-22 20:04 PT. Last 7 days = 73 trips, **35 (48%) are pure prose→prose→YOLO with NO preceding tool error**. Top triple this week: `no-tool-use > no-tool-use > (none)` (19) + `no-tool-use > no-tool-use > no-tool-use` (16) = 35 of 73. These are NOT timeouts or API overloads — they are the model successfully completing a tool call, then writing the NEXT step as prose and never emitting it.

### Three fresh source incidents (all 2026-05-22, all the same shape)

1. **task #1779466924466, 19:23 PT** — after a successful `ssh_command` confirming PHP lint passed, model wrote: *"Panel wired. Now reload FPM and verify, then tackle #5792."* No tool block. Re-prompt × 2. YOLO.
2. **task #1779466420483, 19:23 PT** — after a successful MCP tool call returned `MCP error -32000: Connection closed`, model wrote: *"MCP tunnel hiccup. Retry:"* No tool block (just the colon). Re-prompt × 2. YOLO.
3. **task #1779494742877, 19:23 PT** — after a successful `replace_in_file` to `_INDEX.md`, model wrote: *"Reindexing the MCP and stamping a ledger row."* No tool block. Re-prompt × 2. YOLO.
4. **THE META-INCIDENT — task #1779500505183, 20:06 PT (this very task)** — Cline was *literally writing this rule* about the prose-trap. After successfully running `python3 scan.py && python3 write_rule.py` to regenerate rule 99, the model wrote: *"Rule 99 regenerated with fresh data. Now reindex the clinerules MCP so the addendum is queryable."* No tool block. Hit `[ERROR] You did not use a tool` immediately. The model documenting the trap was caught in the trap, ~30 seconds after writing the binary colon test below. **This is the strongest possible evidence that the failure mode is not about knowing the rule — it is about a reflexive "narrate the next step" habit that fires faster than the self-check.**

All four were mid-task, all four had **dozens** of successful tool calls before, all four died on a single trailing announcement.

### The mid-task "Now X" trap (extends rule 41's original post-deploy version)

Rule 41 originally targeted post-deploy. The 2026-05-22 data shows the trap fires EVERYWHERE in a task, not just after deploys. Every tool result is a potential trap site:
- after `read_file` → model says "Now I'll edit it:" without the edit tool
- after `write_to_file` → "Now reindexing:" without the reindex call
- after `replace_in_file` → "Now updating the related file:" without the next replace_in_file
- after an MCP tool result → "Now confirming:" without the verify call

The fix is the same in every case: **the announcement and the tool must be in the SAME assistant turn, or skip the announcement entirely.**

---

## 2026-05-19 addendum — the timeout → prose → prose YOLO triple (27% of all trips)

Source: cline_learner_report.php live data — `yolo_top_triple = "timeout > no-tool-use > no-tool-use"` matched **125 of 467 cumulative YOLO trips (27%)**, #2 ranked triple after pure no-tool-use triples (108 hits). This is the dominant failure pattern when remote work hangs.

### The mechanism

A tool hits the 30s wall (or any timeout) and returns a timeout error. Instead of immediately calling another tool, Cline narrates: "Hmm, that timed out, let me think about what happened." Cline gets re-prompted to use a tool. Cline narrates again: "I'll wait a moment then retry the same command." Cline gets re-prompted. Third strike, YOLO trips.

### The bright-line rule (timeout edition)

**A timeout is not a conversation. A timeout is a signal that the work moved out of my visibility, and my NEXT tool call has exactly three legal shapes:**

1. **Status-check tool** to assess what actually happened on the remote side. Example: timeout on `ssh deploy@box 'composer install'` → next call is `ssh deploy@box 'ls -la /var/www/app/vendor/ && tail -50 /tmp/composer.log'`, not prose.
2. **Different-approach tool** — switch to the scp-script + nohup pattern per .clinerules/95 if the work might still be useful. NOT a retry of the same hung command.
3. **`attempt_completion` with partial state** — if the timeout makes the rest of the task moot or genuinely needs Ruben's call.

### Forbidden first-words after a timeout error

- "Hmm, let me..."
- "That timed out, let me explain..."
- "Let me check what happened..."
- "I'll wait a moment then retry..."
- "Looks like a connection issue..."
- "The server might be busy, let me..."

### The OK pattern (concrete)

After timeout on `ssh artemis "long thing"`:
- ✅ Next tool call: `ssh artemis "ls /tmp/longjob.log && tail -50 /tmp/longjob.log"` (status check, bounded)
- ✅ Next tool call: scp a wrapped version of the script per .clinerules/95 + nohup launch detached
- ✅ Next tool call: `attempt_completion` reporting "long thing timed out; on-disk state shows X; recommend manual verify"

### Cross-references

- `.clinerules/95` — Cline 30s tool wall + scp+nohup remote pattern (the PREVENTION layer)
- `.clinerules/99` — YOLO prevention playbook
- `.clinerules/16` — maxConsecutiveMistakes threshold

---

## 2026-05-22 addendum — generalized post-ERROR pivot (extends timeout addendum to all error classes)

Source: scan 2026-05-22 of `~/Documents/Cline/yolo_learner/yolo_trips.sqlite`. Last 7 days = 73 trips. Top `cat_1` distribution: `no-tool-use` 36, `timeout` 10, `mysql query failed` 4, `api: overloaded` 4, `sql: unknown column` 2, `shell: command not found` 2, `file/path does not exist` 2, `browser_action: failed` 2, `ssh: connect/timeout` 1, `safe-deploy: invalid flag` 1, `php: syntax error` 1, `permission denied` 1, `tool: generic execution error` 1. The pattern is identical to the timeout addendum: an unavoidable first-tool error, then TWO narration turns ate strikes 2 and 3 = YOLO.

### The bright-line rule (generalized to ALL error classes)

**The assistant turn IMMEDIATELY AFTER any failed-tool result MUST contain a tool_use block.** Not just timeouts. Not just post-deploy. ALL error results.

Concrete: if a tool returns an error, the next assistant turn does exactly ONE of:

1. **A DIFFERENT tool call** (different command, different MCP wrapper, different path, different SQL, different flag). Not the same call again.
2. **`attempt_completion`** with a status of "blocked, <one line why>".
3. **`attempt_completion`** reporting the partial work that did land.

NEVER: a prose-only assistant turn explaining the error, planning the next try, or hoping the issue is transient.

### The "WOPR is down" special case (cross-ref rules 77, 95)

If two SSH/emsu-operations MCP calls fail in a row → the WireGuard tunnel is wedged. Do NOT keep firing MCP calls hoping the third succeeds. Either:
- `attempt_completion` with status "WOPR SSH unreachable, paused, needs tunnel kick" (rule 77)
- Or pivot to local-only work until Ruben restarts the tunnel

### Self-check on every tool-error result

1. *"Will the next turn I emit contain a tool_use block?"* If no, STOP and rewrite.
2. *"Is my next tool call the SAME shape as the one that just failed?"* If yes, STOP and change tools. Two of the same failure in a row is the death-spiral entry.
3. *"What is my CONSECUTIVE error streak right now?"* At 2+, my next call must be a DIFFERENT, simpler tool. At 4 consecutive, next turn MUST be `attempt_completion` per rule 143 v2.

### Forbidden first-words after a tool error

- "Let me check..." / "Let me try..." / "Let me see..." / "Let me wait..."
- "Hmm" / "Looks like" / "Seems" / "Apparently" / "It seems"
- "The query failed because..." / "The server appears to be..."
- "I'll try a different approach"
- "That didn't work, so..."

Each is fine PREFIXED to a tool block in the same turn. None are fine alone.

### Source incidents (2026-05-22)

- task 1779466420483 (2026-05-22 09:37): api overload → 2 narrate turns → YOLO. Should have hit `attempt_completion` after the 1st overload.
- task 1779420001388 (2026-05-21 20:43): mysql `Unknown column 'ticket_number'` → narrate → WOPR SSH dropped (tunnel wedged) → narrate → YOLO. Should have hit `attempt_completion` at the SSH drop per rule 77.
- task 1779418656169 (2026-05-21 20:13): safe-deploy `--src` bad flag → narrate → narrate → YOLO. Should have re-emitted with `--target/--content/--expected-sha256` immediately.
- task 1779410470852 (2026-05-21 18:22): shell command not found → narrate → narrate → YOLO. Should have used `which` to verify path first.
- task 1779267773315 (2026-05-20 02:22): file not found → narrate → narrate → YOLO. Should have `list_files` on parent before retrying.

All 5 would have been saved by the pivot rule above.

---

## 2026-06-02 addendum — banned: blocking LOCAL commands that hang the terminal (live-reproduced trigger)

Source: 2026-06-02 00:05-00:10 PT. Ruben reported live YOLOs across multiple windows and directed a rule-29 action. While investigating, **Cline reproduced the trigger in the same session, twice**: ran `sudo wg show` (interactive password prompt) and a raw local `ssh wopr` — both HUNG the terminal waiting on stdin/tunnel. The model got no tool output, emitted prose waiting on it, hit `[ERROR] You did not use a tool`, emitted prose again, and tripped. A wedged terminal then made every subsequent `execute_command` time out at 30s, compounding it.

### What to do instead — for WOPR, the MCP is the ONLY path

WOPR work goes through the **emsu-operations MCP**, never raw local ssh/sudo: `server_status` (health), `ssh_command` (arbitrary remote — routes via port 2222 with keys, has its own timeout, CANNOT hang the local terminal), `check_server_logs`, `reload_php_fpm`. The MCP route returns instantly even when local `ssh wopr` times out. Composes with rule 32 (MCP over raw shell) + rule 77 (tunnel-down handling).

### If the local terminal is ALREADY wedged

A hung blocking command poisons the terminal: subsequent `execute_command` calls time out at 30s each, and each timeout is a strike. The moment two `execute_command` calls time out in a row, STOP using `execute_command`. Switch to tools with a different I/O path: `read_file`, `write_to_file`, `replace_in_file`, `list_files`, or the MCPs.

### Recovery when a local command hangs

1. Do NOT emit a prose turn waiting on it. The next assistant turn MUST be a different tool call.
2. Do NOT re-run the same blocking command.
3. If no alternative path exists, `attempt_completion` reporting the hang.

### Self-check before any `execute_command`

1. Can this prompt for a password or wait on stdin? → banned local; use MCP or a non-interactive flag.
2. Is this `ssh`/`sudo` aimed at WOPR? → use emsu-operations MCP instead, always.
3. Has the terminal already timed out once this task? → don't use `execute_command` again; use file tools or MCP.

---

## Why this rule matters more than rule-99's generic "no-tool-use"

Rule 99 just says "don't emit prose." This rule names the specific high-frequency post-deploy variant where the model has the *intention* to act but emits only the *description* of the action. That intention–action gap is what produces ~85% of the `no-tool-use > no-tool-use > no-tool-use` YOLO triples in the trip database.

## Concrete forbidden patterns (DO NOT emit as a no-tool message)

After a successful tool result, the model must NOT close its assistant turn with text like:

- "Deployed. Reload FPM and update HANDOFF:"
- "Updated. Now let me verify:"
- "Inserted. Confirming the row:"
- "Patched. Reloading FPM:"
- "Looks good. Next step is X:"
- "Saved. Now I'll Y:"

Each of these strongly implies a tool is coming next, AND THEN DOESN'T EMIT ONE. That's the prose-narration trap. Either:

1. **Emit the tool right there in the same turn** (preferred).
2. **Or skip the narration entirely** and just emit the tool.
3. **Or call `attempt_completion`** if the deploy was the final step.
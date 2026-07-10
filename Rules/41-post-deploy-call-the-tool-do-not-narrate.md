# 41 — After a successful deploy/SQL/insert, the NEXT message must be a tool call, not prose

Permanent hardfloor rule. v2 (2026-06-25) trims v1's 24KB of addenda to the core gate + pivot table. Full addenda archived in `Rules-archive/41-addenda.md`.

## The bright-line rule

**After ANY successful destructive tool result (safe_deploy_file, execute_query INSERT/UPDATE, write_to_file, send_email, etc.), the model's NEXT assistant turn MUST contain at least one tool_use block.** Words like "Deployed. Now reload FPM" or "Updated. Now update HANDOFF" are status descriptions — announcing the next step but not executing it. Cline re-prompts, model re-narrates, triple = death.

If the model genuinely has nothing more to do after the deploy, the NEXT turn must be `attempt_completion`. Not prose.

## The binary colon test (run BEFORE closing any turn)

**If the last non-whitespace character of your assistant turn is `:` AND the turn has no tool_use block, the turn is broken. Period.** Don't ship it.

The colon at end of turn says "the next thing is the tool" — but if no tool follows in the same turn, the model is announcing instead of acting.

Same broken shape, different surface forms:
- `"Now reload FPM and verify:"` → no tool → broken
- `"Retry:"` → no tool → broken
- `"Next I'll patch the route and reload."` → no tool → broken
- `"Stamping the ledger row now."` → no tool → broken

**The mid-task "Now X" trap:** this fires EVERYWHERE, not just post-deploy. Every tool result is a trap site: after `read_file` → "Now I'll edit it:" without the edit tool; after `replace_in_file` → "Now updating the related file:" without the next replace. **The announcement and the tool must be in the SAME turn, or skip the announcement entirely.**

## The three legal shapes after ANY tool result (success OR error)

1. **A tool_use block** in the same turn (preferred)
2. **`attempt_completion`** if the work is genuinely done
3. **`attempt_completion`** if blocked (error, dead-end, timeout)

NEVER: a prose-only assistant turn. The error/result text is already on the user's screen. Adding prose burns a consecutive-mistakes strike for zero benefit.

## Per-class pivot table (what to call instead of narrating after an ERROR)

| Error class | Wrong move | Right move (next tool) |
|---|---|---|
| `api: overloaded/rate-limit` | "Let me wait then retry" | `attempt_completion` "Anthropic overloaded, pausing, re-prompt me in 60s" |
| `mysql: unknown column` | "Let me try a different column" | `describe_table` MCP, then re-emit with the real column |
| `mysql: query failed` | "Let me check the syntax" | `list_tables` / `describe_table` MCP, or LIMIT-1 SELECT |
| `safe-deploy: invalid flag` | "Let me check the help" | Re-emit with correct `--target` `--content` `--expected-sha256` |
| `safe-deploy: sha drift` | Retry with old hash | `read_file` + `sha256sum` for fresh hash, then safe-deploy |
| `file/path does not exist` | "Let me check the path" | `list_files` on parent dir |
| `permission denied (server path)` | Retry `write_to_file` | `ssh_command` with heredoc — server path needs server tool (rule 144) |
| `ssh: connect/timeout` | "Let me retry SSH" | `server_status` MCP first, or `attempt_completion` "WOPR SSH down" |
| `shell: command not found` | "Let me try a different command" | `execute_command which <cmd>` to verify path |
| `php: syntax error` | Retry safe-deploy same content | `write_to_file /tmp/check.php` + `php -l`, fix offline, then deploy |
| `timeout` | "Let me retry the same command" | Status-check tool (bounded), or scp+nohup per rule 95, or `attempt_completion` |
| `tool: generic execution error` | Blind retry | Re-read error, pick a tool that addresses what it said |

**Two of the same failure in a row = death-spiral entry.** Change tools per the table. With ceiling=3, strike 2 (2 consecutive errors) = bail to `attempt_completion` per rule 143 v3. Strike 3 = death.

## Banned: blocking LOCAL commands that hang the terminal

Never issue a local `execute_command` that can block on stdin or hang:
- ❌ `sudo <anything>` that prompts for a password
- ❌ Bare `ssh wopr` / `ssh <host>` for WOPR work — use emsu-operations MCP `ssh_command` instead
- ❌ Interactive REPL/pager without non-interactive flag (`mysql` without `-e`, `less`, `vim`, `top` without `-b -n1`)
- ❌ `ping` without `-c N -t S` bound

If two `execute_command` calls time out in a row, STOP using `execute_command`. Switch to `read_file`, `write_to_file`, `replace_in_file`, `list_files`, or MCP tools — they don't run through the stuck shell.

## Recovery after `[ERROR] You did not use a tool`

1. **DO NOT** re-narrate what you were about to do. The user sees the error.
2. **DO NOT** explain why. Just call the tool.
3. The very next turn MUST contain a tool_use block OR `attempt_completion`.
4. **CEILING=3 (live):** the FIRST error must produce a tool (strike 1 recovery). A SECOND consecutive error = strike 2 = BAIL to `attempt_completion` with a pickup prompt (rule 143 v3). Strike 3 = YOLO death with no pickup prompt. There is no strike-3 recovery — the task dies at strike 3.

Forbidden first-words after the error: "You're right, let me...", "Calling the tool now:", "Apologies, here:", "Let me try again with:". The correct response is silent action — emit the tool.

## Self-check before closing any assistant turn

1. *Does this turn contain a `<tool_use>` block?* If yes → ship. If no → continue.
2. *Is this turn `attempt_completion`?* If yes → ship. If no → continue.
3. *Did the turn just emit only words?* → **The turn is broken. Rewrite to include the tool, or be `attempt_completion`.**

## Cross-refs

- Rule 143 — prose-loop circuit breaker (v3, ceiling=3): strike 1 recover with a (simpler) tool; strike 2 bail to `attempt_completion`. Strike 3 = death.
- Rule 99 — generic no-tool-use playbook (this rule is the post-deploy specialization)
- Rule 144 — server paths via emsu-operations MCP, never local write_to_file
- Rule 95 — scp+nohup for long-running remote commands (timeout prevention)
- Full addenda + source incidents: `Rules-archive/41-addenda.md`

## Source

2026-05-11 — task #1778517762383 YOLO trip. "Deployed. Reload FPM (no opcache stale) and update HANDOFF:" prose ate the YOLO triple. Ruben: "still having dumb FPM yolos just before session close." 2026-06-25 v2 trim.
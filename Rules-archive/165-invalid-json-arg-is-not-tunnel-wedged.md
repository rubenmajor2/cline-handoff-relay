# 165 — "Invalid JSON argument" is a CLIENT-SIDE arg-parse rejection, NOT a wedged tunnel. Reformat the command; never conclude the WOPR tunnel is down from it.

Permanent rule. Workspace-scoped. Source: 2026-06-20 — a window ran a long #13487 LoRA-training session, hit a run of `Invalid JSON argument used with emsu-operations for ssh_command` errors on commands with complex nested quotes / heredocs / `$(...)` / embedded JSON, and WRONGLY concluded "WOPR tunnel may need a kick / tools wedged" in its completion. Ruben: "Correct why this page thinks WOPR tunnel is wedged. Something is off, investigate and resolve whatever stale documentation causes agents to think this." Live-verified the tunnel was 100% fine the entire time (`server_status` + `echo TUNNEL_FINE && uptime` both succeeded between the failures).

## The bright-line distinction (this is the whole rule)

MCP tool failures fall into TWO completely different classes. Do not conflate them:

| Error text | Class | Meaning | Correct response |
|---|---|---|---|
| `Invalid JSON argument used with <server> for <tool>` | **CLIENT-SIDE ARG-PARSE REJECTION** | The MCP client could not parse YOUR arguments into JSON. The command never left the Mac. The tunnel/transport is irrelevant and almost certainly fine. | **REFORMAT the command** (simplify quoting). Do NOT retry the same shape. Do NOT conclude the tunnel is down. |
| `MCP error -32000: Connection closed` / empty body / `result missing` / 45s timeout / `ECONNREFUSED` | **TRANSPORT FAILURE** | The request reached (or tried to reach) the server and the channel failed. | Rule 77 / rule 143: ≥1 reconnect attempt, then pivot or `attempt_completion` if genuinely wedged. |

**`Invalid JSON argument` is NOT in the transport-failure bucket.** It is the MCP arg-parser saying "your `arguments` value is not valid JSON I can hand to the tool." The server, the SSH tunnel, the WireGuard link — none of them were even contacted. Concluding "tunnel wedged" from it is a category error.

## Why it happens (so you fix the real thing)

The `emsu-operations ssh_command` / `mysql` tools take a JSON object like `{"command":"..."}`. When the `command` string contains: nested single+double quotes, `<<'EOF'` heredocs, `$(...)` command substitution, embedded JSON payloads (curl `-d '{...}'`), or backslash-escapes, the MCP client's JSON serializer can choke and reject the whole call with `Invalid JSON argument` BEFORE any SSH happens. Same command, simpler quoting = succeeds. This is purely a serialization problem on the Mac side.

## The correct response — REFORMAT, don't retry-or-bail

When you see `Invalid JSON argument`:
1. **Simplify the command shape.** Drop heredocs, drop `$(...)`, drop embedded JSON. Run it as the plainest possible single-line command, or split it into steps.
2. **For complex/multiline content** (writing a file, a Python script, a config): write it to a local file with `write_to_file` on the Mac, then `scp`/transfer it — or base64-encode the payload and `base64 -d` it on WOPR — or write it via a here-string the parser tolerates. Do NOT keep jamming a giant nested-quote command into `ssh_command`.
3. **Confirm the tunnel is fine** (if you genuinely doubt it) with ONE trivial call: `ssh_command {"command":"echo OK && uptime"}` or `server_status`. If that returns, the tunnel is up and the prior failure was 100% arg-format.
4. **Never** write "tunnel wedged / WOPR needs a kick / tools wedged" in a completion when the only failures were `Invalid JSON argument`. That is a false diagnosis that wastes Ruben's time and trains the next agent wrong.

## The banned conclusion

Do NOT emit, in any completion or handoff, any of these when the failures were `Invalid JSON argument`:
- "WOPR tunnel may need a kick"
- "the MCP tools are wedged"
- "transport returning empty results" (it returned a PARSE error, not an empty result)
- "tunnel-down, paused"

These phrases are reserved for genuine TRANSPORT failures (the right-hand column above), per rule 77.

## Self-check before blaming the tunnel

1. *What was the LITERAL error text?* If it contains `Invalid JSON argument`, it is an arg-parse rejection — reformat, do not blame the tunnel.
2. *Did `server_status` or a trivial `echo` command work recently?* If yes, the tunnel is up; the failure was your command shape.
3. *Am I about to write "tunnel wedged" in a completion?* Re-read the error text first. Only a transport error (Connection closed / timeout / empty body / ECONNREFUSED) justifies it.

## Cross-references

- Rule 77 — WOPR tunnel-down handling (the REAL transport-failure playbook; this rule keeps false positives out of it)
- Rule 95 — make ≥1 reconnect attempt before reporting an MCP broken (applies to transport failures, not arg-parse rejections)
- Rule 143 — prose-loop circuit breaker: "3 empty/result-missing in a row from the same server = wedged transport" — note `Invalid JSON argument` is NOT an empty result, it is a parse rejection, so it does not count toward that wedge trigger
- Rule 144 — server-path writes go through ssh_command (use file-write + transfer for complex payloads to avoid the arg-parse trap entirely)
- Rule 41 addendum — the MCP "result missing" trigger is for empty bodies, not for arg-parse rejections

## Source incident

2026-06-20 — #13487 clinerules/tool_compliance LoRA window. A long sequence of `ssh_command` calls carrying RunPod-mint curls (embedded `-d '{...}'` JSON), pod-staging heredocs, and `$(date +%s)` substitutions repeatedly returned `Invalid JSON argument`. The window concluded the WOPR tunnel was wedged and parked the task. In reality `server_status` worked throughout and `echo TUNNEL_FINE && uptime` succeeded on the first plain-shaped call — the tunnel was never down. The fix was always to simplify the command shape (single-line, no embedded JSON/heredoc), not to kick a tunnel. This rule makes that distinction permanent so no future window mis-diagnoses an arg-parse rejection as a transport outage.

## Last updated

2026-06-20 — initial.
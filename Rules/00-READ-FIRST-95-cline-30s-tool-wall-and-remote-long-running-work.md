# Cline's 30-Second Tool Wall, and How to Drive Long-Running Remote Work Anyway

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> ## ⚠️ LIVE VIOLATION COUNTER — auto-updated every 30 min
> 
> **This rule is being violated.** Detector ran at 2026-05-19 19:20:36 PDT.
> 
> - last 7 days: **0** violation(s)
> - last 30 days: **0** violation(s)
> - all-time: **0** violation(s)
>
>   - remote commands without nohup/disown/scp-script (30d): **0**
>
> If you (Cline) are reading this rule, you are part of the count. The detector
> at `~/Documents/Cline/rule_violations/scan.py` looks at every Cline task on
> this Mac and flags should-have-but-didn't cases. Ruben gets a text when the
> burst rate jumps. **Don't add to the count.**
>
> Counters are stamped in by `~/Documents/Cline/rule_violations/write_rule.py`.
> Edit anywhere outside the BEGIN/END markers; this block is regenerated.
<!-- RULE_VIOLATION_COUNTERS:END -->
## The wall

Every `execute_command` tool call has a hard 30-second wall. If a command hasn't returned by then, the Cline tool reports "Command execution timed out after 30 seconds" and Cline gets no output, no exit code, no tail. The actual remote process may still be running — Cline just can't see it. From there:

- The terminal stays stuck in "Actively Running Terminals" forever (until the underlying process really exits or someone kills it from outside).
- Subsequent `ssh artemis ...` calls either get serialized behind the still-running session, or get a stale read.
- Cline's "no output to read" instinct is to retry. Two retries of the same hung command will trip the YOLO 3-strike consecutive-mistakes wall and end the task. (See rule 99 — this exact pattern is the #1 historical failure mode, and `timeout > no-tool-use > no-tool-use` is the most-common triple.)

This rule is about how to do **multi-second to multi-minute work on a remote box** (Artemis, WOPR, Quest, etc.) without ever hitting that wall.

## The durable pattern: scp-script + nohup launch + poll-the-log

Use this whenever a remote operation **might** take more than ~10 seconds. Don't wait for it to actually take >30s before adopting the pattern — the cost of using it on a 5-second job is one extra round-trip; the cost of getting bitten on a 35-second job is the whole task ending.

The shape is three steps. Each step is its own short tool call that returns in well under 30 seconds.

### Step 1: stage the work as a self-contained script on the Mac side

Use `write_to_file` to put a complete bash script at `/tmp/<task>_remote.sh`. The script must:

- Set `set -e` for fail-fast, OR explicitly handle each error case if you need partial-success behavior.
- Pipe ALL output into a known log file: `LOG=/tmp/cline-<task>.log; exec >> "$LOG" 2>&1`.
- Print clear `===` section banners and timestamps so the poller can tell where it got to.
- Print a clear `=== ALL DONE <iso-timestamp> ===` line at the very end, so the poller knows it really finished (vs. died mid-step).
- Take secrets via env vars (e.g. `GH_TOKEN`), NOT positional args — args show up in `ps aux` and get captured in shell history. Env vars are visible to root but at least don't leak in process lists.
- Be idempotent where possible. The poller may need to re-run if the first run died.

### Step 2: scp it up + nohup-launch it detached

Two commands, both short:

```bash
# 2a. Push the script up
scp -o ConnectTimeout=15 /tmp/<task>_remote.sh artemis:/tmp/<task>_remote.sh
# (returns in <5s, will fit in 30s wall)

# 2b. Launch it detached. nohup + & + disown means the ssh session can return
#     without waiting for the script. Note the < /dev/null and the redirect of
#     both stdout and stderr — without these, ssh's own session may stay open
#     waiting on the script's stdout pipe.
ssh -o ConnectTimeout=10 artemis "rm -f /tmp/cline-<task>.log; \
  nohup env GH_TOKEN='$PAT' bash /tmp/<task>_remote.sh < /dev/null > /dev/null 2>&1 & \
  disown; sleep 1; echo LAUNCHED && ps -ef | grep -E '<task>_remote' | grep -v grep"
# (returns in ~2-3s — only the launch time, not the whole job)
```

Two things that matter and are easy to get wrong:

1. **`disown` after the `&`** is what lets ssh come back without waiting. Without it, ssh hangs until the child process exits.
2. **Redirect script stdout/stderr to `/dev/null`** in the launch command. The script itself already redirected to its log file via `exec >>`. If the launch command leaves stdout connected to the ssh pipe, ssh stays open until the script's stdout closes — which on a long job means hitting the 30s wall again.

### Step 3: poll the log with `sleep N && ssh tail`

```bash
# Wait an estimated chunk, then check progress
sleep 25 && ssh -o ConnectTimeout=10 artemis \
  "tail -120 /tmp/cline-<task>.log; \
   echo '---'; \
   (ps -ef | grep -E '<task>_remote' | grep -v grep || echo NOT_RUNNING)"
```

- Pick `sleep N` based on how long you estimate the job will take. For a ~25s job, `sleep 25` is fine. For a multi-minute job, `sleep 60` and re-check; sleep is cheap.
- The `tail` shows you actual progress. The `ps` line tells you whether it's still running or done.
- If the log shows `=== ALL DONE ===`, you're done.
- If the log shows an error and the process is `NOT_RUNNING`, the script died mid-flight; read the tail, fix, re-run from Step 1 (the script's idempotence comes into play here).
- If the process IS still running, just `sleep` again and re-poll.

This polling pattern naturally fits inside the 30s wall and gives Cline real-time visibility into long-running jobs without ever hanging a single tool call.

## When to skip the pattern

Don't reach for this for trivial reads. It adds overhead. Skip it if:

- The remote command genuinely returns in under 10 seconds (most one-shot reads, single mysql queries, single file writes).
- The remote command is a single SSH read-only fetch with bounded output (e.g. `ssh artemis "git log --oneline -5"`).
- You're running on the local Mac with no remote hop.

Use it when:

- Remote work involves git fetch/push over the public internet (variable latency).
- Remote work runs a multi-step shell script (compile, deploy, build).
- Remote work touches services that block on external IO (Anthropic API call, email send, Authnet refund).
- Remote work might prompt interactively (credentials, SSL cert verify) — combine with `GIT_TERMINAL_PROMPT=0` so the prompt fails fast instead of stalling forever.
- You've already been bitten once on this same remote command (don't try harder, switch patterns).

## What goes wrong if you DON'T use this pattern

Real failure mode from 2026-05-02 #cline-handoff-relay-bootstrap (this is the source incident):

1. First attempt: `ssh artemis "GH_TOKEN=... bash -s" <<'REMOTE_EOF' ... REMOTE_EOF` — synchronous heredoc. The script wanted to do `git fetch + git push` but the credentials weren't seeded yet, so git tried to prompt for username on stdin. The 30s wall hit while git was still waiting on a TTY that would never arrive.
2. Tool reported timeout. Cline (me) couldn't tell whether the script had partially run.
3. The ssh process kept running on the Mac side, stuck on git's interactive prompt, even after Cline's tool gave up. Subsequent `ssh artemis` calls got serialized behind it, returning fragments of stale terminal output.
4. Recovery required `pkill -9 -f "ssh artemis"` from a separate terminal, then cleaning a leftover `.git/index.lock` on Artemis from the partially-completed git transaction, then restarting the work with the scp-script + nohup pattern that completed cleanly in ~25 seconds.

Net cost of the wrong pattern: ~5 minutes of recovery + a polluted "Actively Running Terminals" entry that lingered through the rest of the session.

Net cost of the right pattern: 3 short tool calls, each well under 30s, no recovery needed.

## Hardening checklist for any remote work

Before running anything that touches a remote shell:

- [ ] Estimate worst-case duration. If anywhere near 30s, use the scp-script pattern.
- [ ] If git over HTTPS is involved: confirm the credential helper is configured AND `~/.git-credentials` (or equivalent) actually has bytes. Empty file ≠ working creds.
- [ ] Export `GIT_TERMINAL_PROMPT=0` so any auth gap fails fast instead of stalling.
- [ ] Wrap the remote command in `timeout 60s` if it absolutely must stay synchronous. Better to fail loud than stall silent.
- [ ] If using `ssh artemis "cmd"` synchronously, mentally check: does anything in `cmd` read from stdin? If yes, redirect `< /dev/null`.
- [ ] Always have a way to check progress out-of-band (a log file, a status file, a sentinel marker) so a hung tool call doesn't blind you.

## Cross-references

- Rule 96 (`96-cline-window-discipline.md`) — covers the broader "long-running Cline windows + ext-host RAM" surface; this rule is the narrower "individual tool call" surface.
- Rule 99 (`99-yolo-prevention-learned.md`) — `timeout > no-tool-use > no-tool-use` triple is the most-common YOLO triple; this rule's whole point is preventing the first `timeout` from happening.
- Rule 14 (`14-unity-headless-driving-without-user.md`) — same shape applied to Unity batchmode work that takes minutes. The "every Unity step has a flat-file output" guidance is the Unity-specific version of "every remote step writes to a known log file."
- HANDOFF_NOTES.md / cline_task_ledger.md — the natural home for "if the polling step shows still-running, leave a breadcrumb here so the next agent can pick up the polling without re-launching."

## Last updated

2026-05-02 — initial rule. Source incident: cline-handoff-relay-bootstrap on Artemis. The first synchronous SSH heredoc hung at the 30s wall on a git credential prompt; switching to scp-script + nohup launch + sleep+tail polling completed the same work cleanly in ~25 seconds.

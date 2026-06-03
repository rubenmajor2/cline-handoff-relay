# 136 — Artemis (Intel Arc box) access path: emsu-operations MCP ssh_command, NEVER raw `ssh artemis`

Source: 2026-06-03 Artemis Arc 70B serving session. Raw `ssh artemis` from the Mac repeatedly returned `Permission denied (publickey)` and (per rule 41 addendum) the prose-without-tool recovery spiral that follows a hung/failed SSH caused multiple YOLO trips across Cline windows. Ruben directive: "these instructions need to persist because in numerous Cline windows they cause Yolos."

## The bright-line rule

**To run anything on Artemis (the 4× Intel Arc Battlemage box, `10.100.0.5`), use the `emsu-operations` MCP `ssh_command` tool with the command prefixed `ssh artemis "<cmd>"`. NEVER run raw `ssh artemis` from the Mac via `execute_command`.**

```
✅ emsu-operations ssh_command:  ssh -o BatchMode=yes -o StrictHostKeyChecking=no artemis "<remote cmd>"
❌ execute_command:              ssh artemis "<remote cmd>"     # hangs / publickey-denied → YOLO
```

## Why raw `ssh artemis` from the Mac fails

- Artemis is only reachable through WOPR via ProxyJump. The Mac `~/.ssh/config` has:
  ```
  Host artemis
      HostName 10.100.0.5
      User emsuserver
      Port 22
      IdentityFile ~/.ssh/id_ed25519
      ProxyJump wopr
  ```
- From the Mac directly, the key flow resolves in the wrong context and Artemis returns `Permission denied (publickey)`. The `execute_command` terminal then sits there (or the next prose turn has no tool) and the consecutive-mistakes clock starts → YOLO (see rule 41's blocking-local-command addendum + rule 99 no-tool-use class).
- The **emsu-operations MCP** originates its SSH on WOPR (`ssh -p 2222 emsuserver@127.0.0.1` tunnel), where the ProxyJump + `id_ed25519` key ARE trusted. From there, `ssh artemis "<cmd>"` works every time. The MCP also has its own timeout so it can't wedge the local terminal.

## The canonical access path (one line)

**Mac → emsu-operations MCP `ssh_command` → (runs on WOPR) → `ssh artemis` → Artemis (10.100.0.5, user `emsuserver`, ProxyJump wopr).**

Same door as rule 42/118-style WOPR ops: the MCP is the only allowed path; raw local ssh/sudo to the fleet is banned (composes with rule 41's 2026-06-02 blocking-local-command clause).

## Practical notes (learned 2026-06-03)

- **Long jobs:** the MCP `ssh_command` has a ~30-90s ceiling. For installs/builds/model-loads, launch detached on Artemis with `setsid bash /path/script.sh > /path/log 2>&1 </dev/null &` and poll the log in separate short calls (rule 95 pattern). Do NOT inline a `sleep 70` that exceeds the wall.
- **Leading `pkill` aborts chains:** `pkill -f X; <rest>` makes the whole MCP call report "Command failed" when pkill's exit is nonzero (no match). Put `pkill ... 2>/dev/null || true` OR run the kill inside a script file, not inline before the work you care about.
- **Nested single-quotes break the double hop.** Prefer writing a script to a file on Artemis first (`printf '%s\n' ... > /home/emsuserver/foo.sh`), then `bash /home/emsuserver/foo.sh` in a second call. Avoids quoting hell across Mac→WOPR→Artemis.
- **GPU runtime gotcha (for Arc work):** do NOT `source /opt/intel/oneapi/setvars.sh`; use torch's bundled libsycl on `LD_LIBRARY_PATH`. See `/Users/rubenmajor/Desktop/ARTEMIS_ARC_70B_SERVING.md` for the full serving config.

## Self-check before any Artemis command

1. *Am I about to `execute_command` a raw `ssh artemis ...`?* → STOP. Use the emsu-operations MCP `ssh_command` instead.
2. *Is this a long-running job?* → setsid-detach + poll the log, don't block past the tool wall.
3. *Does my command start with `pkill`/`grep`/a pipeline that can exit nonzero?* → wrap with `|| true` or move it into a script file so the MCP doesn't false-flag "Command failed."

## Cross-references

- `.clinerules/41` — post-deploy / blocking-local-command addendum (raw ssh/sudo to fleet banned; wedged terminal → switch to MCP/file tools)
- `.clinerules/95` — Cline 30s tool wall + scp/setsid+nohup remote pattern for long jobs
- `.clinerules/99` — YOLO prevention (no-tool-use + timeout classes that this trigger feeds)
- `.clinerules/77` — tunnel-down handling (if the WOPR hop itself is wedged)

## Last updated

2026-06-03 — initial. Source: Artemis Arc 70B serving session; raw `ssh artemis` publickey denials + the no-tool recovery spiral caused YOLOs in multiple windows. Canonical path = emsu-operations MCP `ssh_command` running `ssh artemis "<cmd>"` (WOPR-originated, ProxyJump trusted).

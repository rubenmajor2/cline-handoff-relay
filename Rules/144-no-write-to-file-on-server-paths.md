# 144 — NEVER write_to_file / replace_in_file on a server path (/etc, /var, /usr, /opt, /root). Use emsu-operations ssh_command.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-09 — a Cline window running in `/Users/rubenmajor/Desktop` tried to `write_to_file` to `/etc/litellm/router_hook.py` and looped on `EACCES: permission denied, mkdir '/etc/litellm'`. The window kept retrying the same local-write that can NEVER succeed, because `/etc/litellm` lives on WOPR, not the Mac. This is the rule-99 "permission denied (wrote to server path locally?)" class, hardened into a bright-line pre-write gate so the loop is impossible.

## The bright-line rule

**`write_to_file` and `replace_in_file` operate on the LOCAL Mac filesystem ONLY.** If the target path starts with any of these prefixes, it is a SERVER path and these tools will ALWAYS fail with EACCES (or worse, write to a phantom local path):

- `/etc/` `/var/` `/usr/` `/opt/` `/root/` `/srv/` `/run/`
- `/var/www/emtskills/` (the EMSU web root — WOPR)
- `/etc/litellm/` (LiteLLM config + router_hook.py — WOPR)
- any absolute path that is NOT under `/Users/`, `/tmp/`, or `/private/`

**For ANY server-path write, use the emsu-operations MCP, never the file tools:**

| Want to do | Wrong (loops on EACCES) | Right |
|---|---|---|
| Edit `/etc/litellm/router_hook.py` | `write_to_file /etc/litellm/router_hook.py` | `ssh_command` with `sudo python3` patch script, OR `sudo tee` heredoc |
| Edit `/var/www/emtskills/routes/x.php` | `replace_in_file /var/www/.../x.php` | `ssh_command` with `sudo tee` heredoc, OR `safe_deploy_file` MCP |
| Read a server file | `read_file /etc/...` (works but slow) | `read_server_file` MCP |
| Create a server file | `write_to_file /etc/...` | `ssh_command` `sudo tee /path <<'EOF' ... EOF` |

## The pre-write self-check (run BEFORE every write_to_file / replace_in_file)

1. *Does the target path start with `/Users/`, `/tmp/`, or `/private/`?* → OK, it's local, proceed.
2. *Does it start with `/etc/`, `/var/`, `/usr/`, `/opt/`, `/root/`, `/srv/`, `/run/`?* → STOP. This is a WOPR path. Switch to `ssh_command` (sudo tee heredoc or sudo python3 patch).
3. *Am I in the Desktop working directory but trying to edit a server file?* → The working dir does NOT change where the file lives. `/etc/litellm/...` is always WOPR regardless of cwd.

## The loop-breaker (rule 143 composition)

If `write_to_file` or `replace_in_file` returns `EACCES: permission denied, mkdir '<server path>'` — do NOT retry the same write. The path is on WOPR; a local write can never succeed. The NEXT tool call must be either:
- `ssh_command` with the equivalent `sudo tee` / `sudo python3` server-side write, OR
- `attempt_completion` reporting the work is already done elsewhere (if a sibling window did it).

Two EACCES-on-server-path errors in a row = you are in the rule-143 loop. Switch tools immediately or call `attempt_completion`.

## Why this is hardfloor and not just rule 99

Rule 99's `permission denied` entry describes the symptom. This rule is the PRE-WRITE GATE: it names the exact path prefixes and the exact correct tool, so the agent never even attempts the doomed local write. The 2026-06-09 incident showed an agent in YOLO mode loop on this for many turns because rule 99 said "use ssh_command" but didn't give a binary path-prefix test to run BEFORE the write. This rule supplies that test.

## Cross-references

- Rule 99 — `permission denied (wrote to server path locally?)` failure class (this rule is the pre-write gate version)
- Rule 143 — prose-loop circuit breaker (two EACCES-on-server-path = switch tools or attempt_completion)
- Rule 42 — safe_deploy_file already reloads FPM (the right tool for /var/www PHP deploys)
- Rule 32 — prefer dedicated MCP tools over raw shell
- Rule 41-addendum (2026-06-02) — blocking LOCAL commands that hang the terminal (sibling failure: raw ssh/sudo locally)

## Source incident

2026-06-09 23:04 PT — a Cline window (running in /Users/rubenmajor/Desktop, doing idea #11415) tried `write_to_file /etc/litellm/router_hook.py` and got `EACCES: permission denied, mkdir '/etc/litellm'`. It retried the same local write multiple times instead of switching to `ssh_command`. The patch was already correctly applied in a sibling window via `emsu-operations ssh_command`. Ruben: "that is not a root cause fix. I don't want something like this to happen again."

## Last updated

2026-06-09 — initial. Source: write_to_file EACCES loop on /etc/litellm/router_hook.py.

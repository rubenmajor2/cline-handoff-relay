# 42 — safe_deploy_file already reloads FPM. Do not reload again.

Permanent hardfloor rule. Workspace-scoped. Source: 2026-05-24 scan — `fpm-reload: sudoers blocks systemctl, use kill -USR2 wrapper` is the #4 YOLO trip class with **35 cumulative trips, all identical shape**: `fpm-reload-fail > no-tool-use > no-tool-use > YOLO`.

## The bright-line rule

**After a successful `safe_deploy_file` MCP call, FPM has ALREADY been reloaded via `kill -USR2` inside ssh.ts. You do NOT need to reload it again. Do not call any reload command. Move on to the next step (verification, attempt_completion, next file, etc).**

If you genuinely need to force a reload independent of a deploy (rare — e.g. you wrote via raw `ssh_command cat > file`, or an upstream cron deployed and you want to invalidate OPcache early), use the **`reload_php_fpm` MCP tool** (one click, no args). NEVER raw shell.

## Banned commands — these ALL fail and are the canonical YOLO entry

The WOPR sudoers file (`/etc/sudoers.d/emsuserver`) explicitly NEGATES these. They will always return rc=1 with `Sorry, user emsuserver is not allowed to execute ...`:

- ❌ `sudo systemctl reload php8.3-fpm`
- ❌ `sudo systemctl reload php8.3-fpm.service`
- ❌ `sudo systemctl restart php8.3-fpm`
- ❌ `sudo systemctl restart php8.3-fpm.service`
- ❌ `sudo service php8.3-fpm reload`
- ❌ `sudo service php8.3-fpm restart`

If your next planned tool call after a safe_deploy contains any of those strings, STOP. Delete the call. The deploy already reloaded.

## The legal alternatives (only when you really need to reload)

In order of preference:

1. **`reload_php_fpm` MCP tool (emsu-operations).** Zero args. Uses SIGUSR2. Use this.
2. `/usr/local/bin/emsu-safe-phpfpm-restart.sh <reason>` — rate-limited wrapper (45s cooldown), best for crons.
3. `/usr/local/bin/emsu-fpm-guard reload <reason>` — guard wrapper with cooldown + audit log.
4. Raw `sudo kill -USR2 $(cat /var/run/php/php8.3-fpm.pid)` — last resort, bypass.

## The post-deploy reflex trap (canonical YOLO source)

All 35 logged trips look like this:

```
[turn N]   safe_deploy_file <path> → SUCCESS (FPM auto-reloaded inside ssh.ts)
[turn N+1] "Deployed. Now reload FPM:"     ← rule 41 violation (prose only) +
           sudo systemctl reload php8.3-fpm ← rule 42 violation (banned cmd)
           → sudoers denies → error
[turn N+2] "Hmm, let me try the wrapper:"  ← no-tool-use strike 1
[turn N+3] "Let me check the path..."       ← no-tool-use strike 2
[turn N+4] YOLO
```

The fix is at turn N+1: **the next tool call after a successful safe_deploy_file is NOT a reload — it's whatever comes next in the task** (verify, deploy next file, run a smoke test, or attempt_completion).

## Self-check before any FPM reload tool call

Ask:

1. *Did I just successfully run `safe_deploy_file`?* If yes → FPM is already reloaded. SKIP this call entirely.
2. *Am I about to type `systemctl` or `service` with `php8.3-fpm`?* If yes → STOP. Use `reload_php_fpm` MCP tool instead, or skip the reload.
3. *Is the reload necessary at all?* If the file I touched isn't a PHP source file under /var/www/, no reload is needed regardless.

## Cross-references

- Rule 41 — post-deploy call the tool do not narrate (this rule is the FPM-specific specialization)
- Rule 99 — yolo prevention learned, `fpm-reload` section (35 trips logged)
- Rule 32 — prefer dedicated MCP tools over raw shell

## Last updated

2026-05-24 — initial. Source: 35 logged FPM-reload YOLO trips in yolo_trips.sqlite, all the same shape. The wrapper exists, the MCP tool exists, the safe_deploy already does it — agents just keep typing `systemctl` reflexively. Hardfloor needed.

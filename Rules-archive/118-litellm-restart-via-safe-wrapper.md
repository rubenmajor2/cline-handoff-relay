# 118 — Never restart litellm with raw systemctl. Use the safe wrapper.

Permanent rule. Workspace-scoped. Source: 2026-05-26 20:24-20:32 PT incident.

## The bright-line rule

**Never run `sudo systemctl restart litellm`, `sudo systemctl stop litellm`, or `sudo docker stop litellm` directly.** Always go through `/usr/local/bin/emsu-safe-litellm-restart.sh`, with a `--reason=` flag.

```
sudo /usr/local/bin/emsu-safe-litellm-restart.sh --reason="config.yaml add deepseek-v4"
```

The wrapper enforces:
1. **300-second (5-minute) cooldown** between restarts. Returns exit 75 (EX_TEMPFAIL) if another restart happened recently. Prevents agent-A from restarting while agent-B is mid-deploy. (Bumped from 120s on 2026-05-26 22:39 PT after a busy deploy session pushed 4 restarts in 30 min, each >120s apart, none blocked. 300s forces iterative deploys to batch.)
2. **Pre-flight smoketests** — runs both `emsu-litellm-router-hook-smoketest.py` and `emsu-litellm-config-smoketest.sh` BEFORE taking docker down. If either fails, no restart happens, the previous container keeps running.
3. **Audit log** at `/var/log/emsu-litellm-restart.log` — every restart attempt (allowed or blocked) is recorded with reason + caller age. Greppable forever.

## Why this rule exists

LiteLLM runs as `docker run --rm` in `litellm.service`. Every restart drops the container, runs ExecStartPre gates (~3-5s), starts a fresh container (~5-10s). Port 4000 is unreachable the entire window. Cline windows hitting `/anthropic/v1/messages` during that gap get `Connection error. ECONNREFUSED` / `UND_ERR_SOCKET` / 10-second tool-call timeouts. **Two tool-call timeouts in a row = YOLO trip.**

Source incident: 2026-05-26 20:24, 20:26, 20:31, 20:32 PT — a parallel Cline window doing a deepseek-v4 deploy fired 4 raw `sudo systemctl restart litellm` calls in 8 minutes. Ruben had multiple Cline windows open. Every other window got ~50 seconds of cumulative connection errors and one window YOLO'd.

Per .clinerules/92 (work-at-the-core): the fix is NOT "please be careful, only restart once." Agents will always race. The fix is the cooldown at the wrapper.

## When to use --force

Almost never. The only legitimate cases:
- Hot patch to router_hook.py to fix a live UnboundLocalError (every second of downtime hurts more than the cooldown helps).
- Recovery from a known-broken state where you confirmed the previous restart left litellm wedged.

If using `--force`, always pair with `--reason='<specific why force needed>'` so the audit log captures it.

## What this rule does NOT cover

- Routine `docker logs litellm` or `journalctl -u litellm` reads — those don't take the service down, fine to run direct.
- `systemctl status litellm` — read-only, fine.
- Editing `/etc/litellm/config.yaml` or `/etc/litellm/router_hook.py` without a restart — fine (the file is bind-mounted into docker, but the running container only re-reads on restart). Edit freely, then call the wrapper when you need the change live.

## Self-check before any litellm restart

Ask:
1. *"Am I about to call `sudo systemctl restart|stop|reload litellm` directly?"* → STOP. Use `/usr/local/bin/emsu-safe-litellm-restart.sh --reason='<why>'` instead.
2. *"Is there a chance another Cline window is mid-work?"* → That's exactly when the cooldown matters. Trust the wrapper.
3. *"Did the wrapper return exit 75 (blocked)?"* → Wait the printed `wait=Ns` seconds and re-run. Don't `--force`.

## Cross-references

- `.clinerules/29` — act-on-confidence (the wrapper IS the safe-default action)
- `.clinerules/41` — post-deploy call the tool, don't narrate (after `emsu-safe-litellm-restart.sh`, your next tool call must be a verification curl, not prose)
- `.clinerules/42` — safe-deploy already reloads FPM. Same pattern: prefer wrappers over raw systemctl.
- `.clinerules/92` — work at the core, not bandaids

## Last updated

2026-05-26 — initial. Source: parallel deepseek-v4 deploy carpet-bombed litellm with 4 restarts in 8 min, causing Ruben's other Cline windows to see connection errors + at least one YOLO. Wrapper: `/usr/local/bin/emsu-safe-litellm-restart.sh`. Audit log: `/var/log/emsu-litellm-restart.log`.

# Opus 4.8 YOLO fix — router fallback + raise live mistake limit

Date: 2026-05-29
Cause: claude-opus-4-8 returns 529 overloaded in bursts -> each overload = a consecutive mistake in Cline -> with the live host limit cached at 3, three overloads = instant YOLO.

## Step 1 (immediate, no server needed) — reload the window
Cmd+Shift+P -> "Developer: Reload Window".
This makes the live mistake limit = 10 (the value already stored in state/state.vscdb).
Survives short overload bursts instead of dying at 3.

## Step 2 (core fix) — add litellm router fallback so 529 fails over instead of becoming a Cline strike
Append to /etc/litellm/config.yaml under litellm_settings (or merge if it exists).
This routes claude-opus-4-8 -> sonnet on overload/error so Cline never sees the 529.

```yaml
litellm_settings:
  num_retries: 2
  request_timeout: 600
  allowed_fails: 3
  cooldown_time: 30
  fallbacks:
    - claude-opus-4-8: ["claude-sonnet-4-5", "claude-haiku-4-5"]
    - "claude-opus-4-8:1m": ["claude-sonnet-4-5", "claude-haiku-4-5"]
    - claude-opus-real: ["claude-sonnet-4-5", "claude-haiku-4-5"]
  context_window_fallbacks:
    - claude-opus-4-8: ["claude-opus-4-8:1m"]
```

NOTE: verify the exact sonnet/haiku model_name strings in config.yaml first
(grep -n "model_name" /etc/litellm/config.yaml) and match them exactly.

## Step 3 — apply safely (rule 118: never raw systemctl on litellm)
```
sudo /usr/local/bin/emsu-safe-litellm-restart.sh --reason="add opus-4-8 -> sonnet fallback on 529"
```

## Step 4 — verify
```
curl -s http://localhost:4000/v1/models | python3 -c "import sys,json;print([m['id'] for m in json.load(sys.stdin)['data'] if 'opus' in m['id']])"
# then force an opus call and confirm no 529 reaches the client
```

## Interim (until fallback is live)
Switch Cline's model to claude-haiku-4-5 (stored default) or sonnet for routine work.
Per rule 99: two overloaded responses in a row = stop and idle, do not fire a 3rd call.

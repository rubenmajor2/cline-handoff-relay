# cline-handoff-relay

Tiny relay so Ruben's Mac and Artemis (code-server box) can share Cline rule
files without depending on SSH between the two (Artemis port 22 is firewalled
at the router, so direct scp Mac→Artemis can't work).

The repo holds:
- `~/Documents/Cline/Rules/*.md` from both machines (source of truth on either
  side; whichever side commits last wins for that file).
- `write_rule.py` — the yolo_learner rule generator from the Mac.

## One-time setup on each machine

Both machines clone or init `~/Documents/Cline/Rules/` against this repo. After
that, an hourly `git pull && git push` keeps them in sync.

### On the Mac

```bash
cd ~/Documents/Cline/Rules
# if the dir is not already a git repo:
git init -b main
git remote add origin https://github.com/rubenmajor2/cline-handoff-relay.git
git fetch origin
git checkout -b main --track origin/main 2>/dev/null || git pull --allow-unrelated-histories origin main
git add -A
git commit -m "bootstrap from Mac" || true
git push -u origin main
```

If git asks for credentials, use a GitHub Personal Access Token with `repo`
scope. Cache it: `git config --global credential.helper osxkeychain`.

### On Artemis

```bash
cd /home/emsuserver/Documents/Cline/Rules
git remote add origin https://github.com/rubenmajor2/cline-handoff-relay.git 2>/dev/null || true
git fetch origin
git pull --allow-unrelated-histories origin main || true
git add -A
git commit -m "bootstrap from Artemis" || true
git push -u origin main
```

Token caching on Linux: `git config --global credential.helper store` puts
it in plaintext at `~/.git-credentials`. Acceptable on a single-user box.

## Hourly auto-sync

### Mac (launchd)

Drop `~/Library/LaunchAgents/com.ruben.cline-rules-sync.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ruben.cline-rules-sync</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>cd ~/Documents/Cline/Rules &amp;&amp; git pull --rebase --autostash origin main &amp;&amp; git add -A &amp;&amp; (git diff --cached --quiet || (git commit -m "Mac auto-sync $(date +%FT%T)" &amp;&amp; git push origin main))</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/tmp/cline-rules-sync.log</string>
  <key>StandardErrorPath</key><string>/tmp/cline-rules-sync.log</string>
</dict></plist>
```

Then: `launchctl load ~/Library/LaunchAgents/com.ruben.cline-rules-sync.plist`

### Artemis (cron)

`crontab -e` for the `emsuserver` user, add:

```
0 * * * * cd /home/emsuserver/Documents/Cline/Rules && git pull --rebase --autostash origin main && git add -A && (git diff --cached --quiet || (git commit -m "Artemis auto-sync $(date +\%FT\%T)" && git push origin main)) >> /tmp/cline-rules-sync.log 2>&1
```

## Manual sync (either machine)

```
cd ~/Documents/Cline/Rules && git pull --rebase origin main && git add -A && git commit -m "manual sync" && git push origin main
```

## Why this exists

- Artemis SSH is firewalled at the router (port 22 unreachable from outside the
  LAN), so `scp emsuserver@artemis:...` from the Mac never connects.
- WOPR SSH is on port 2222 (different machine, not the right target for rules).
- iCloud / Syncthing / rclone aren't installed on Artemis.
- GitHub HTTPS port 443 is reachable from both Mac and Artemis, full-duplex,
  no firewall complications.

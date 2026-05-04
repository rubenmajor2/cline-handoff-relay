# Artemis bootstrap — copy/paste runbook

Last updated 2026-05-02 by Mac side. Mac is fully bootstrapped: 16 rules
files pushed, hourly launchd auto-sync running.

This file is the resume kit for the Artemis-side bootstrap that the original
README outlined but never got executed. Everything below is copy-pasteable
inside the Cline window on Artemis.

## TL;DR — why the Cline window on Artemis stalled

When this task was kicked off, the Artemis Cline agent almost certainly hit
one of these three things:

1. **`~/Documents/Cline/Rules/` was not a git repo yet.** Running
   `cd ~/Documents/Cline/Rules && git status` makes git walk **up** the tree
   looking for a `.git/` parent. On Linux that walk hits `/home/emsuserver/`
   and possibly `/home/`. If any parent is a git repo or has a slow filesystem
   that's where it gets stuck. (Same exact failure mode happened on the Mac —
   `~/.git/` exists for tracking RUBEN agent code under `~/.ruben-ai/`, and
   `git status` from a non-repo subdirectory walks up to it and lists
   thousands of untracked entries before timing out.)

2. **No GitHub PAT cached.** The Artemis bootstrap script needs to push, and
   the first push will prompt for credentials. Cline cannot answer an
   interactive `Username:` / `Password:` prompt — the agent stalls forever
   waiting on stdin that never comes. Solution below: configure
   `credential.helper store` and pre-seed `~/.git-credentials` BEFORE the
   first push.

3. **Cline's tool sandbox doesn't pass through `git push` interactive
   auth.** Even if creds *were* configured globally, the agent shell may not
   have inherited the env. We force `GIT_TERMINAL_PROMPT=0` to make any auth
   gap fail loudly with a non-zero exit instead of stalling on stdin.

## Pre-flight: collect what you need

You need a **GitHub Personal Access Token (classic)** with `repo` scope.
Already provisioned on the Mac (40-char PAT in macOS keychain). Either:

- Reuse the same PAT (read it on the Mac with:
  `security find-internet-password -s github.com -a rubenmajor2 -w`)
- Or create a new PAT scoped to just this repo at
  https://github.com/settings/tokens?type=beta → Fine-grained, repo
  `rubenmajor2/cline-handoff-relay`, permissions `Contents: Read/Write`.

Save the PAT as `$GH_TOKEN` in the shell where you'll run the bootstrap.

## Step 1 — Pre-seed credentials (avoids the stall)

```bash
# On Artemis, as emsuserver
mkdir -p ~/Documents/Cline
cd ~/Documents/Cline

# Cache git credentials so push doesn't prompt
git config --global credential.helper store
GH_TOKEN='<paste-PAT-here>'   # don't commit this
printf 'https://rubenmajor2:%s@github.com\n' "$GH_TOKEN" > ~/.git-credentials
chmod 600 ~/.git-credentials

# Identity for commits
git config --global user.email "rmajor@emsuniversity.com"
git config --global user.name  "Ruben Major"

# Block any future interactive prompts (so a misconfig fails fast,
# not stalls Cline forever)
echo 'export GIT_TERMINAL_PROMPT=0' >> ~/.bashrc
export GIT_TERMINAL_PROMPT=0
```

## Step 2 — Bootstrap the Rules dir

If `~/Documents/Cline/Rules/` already has files in it from prior agents,
those files will be merged with what's on GitHub (Mac just pushed 16 rules
files at commit `a93a110`).

```bash
mkdir -p ~/Documents/Cline/Rules
cd ~/Documents/Cline/Rules

# Init the repo if it isn't one already
[ -d .git ] || git init -b main

# Wire the remote
git remote get-url origin >/dev/null 2>&1 \
  || git remote add origin https://github.com/rubenmajor2/cline-handoff-relay.git

# Pull the Mac's commit
git fetch origin
git checkout -B main --track origin/main 2>/dev/null \
  || git pull --rebase --autostash origin main

# Show what's local but not yet pushed
git status --short
```

If you see `?? somefile.md` for files that exist on Artemis but not in the
remote, those are Artemis-original rules. Commit them:

```bash
git add -A
git diff --cached --quiet || git commit -m "Artemis bootstrap $(date +%FT%T)"
git push -u origin main
```

If the push prompts for a username, your `~/.git-credentials` from Step 1
isn't being read. Verify with `cat ~/.git-credentials` (should have one
line starting `https://rubenmajor2:`).

## Step 3 — Verify

```bash
# Should show the Mac's commit on top
git log --oneline -5
# Should show clean tree
git status
# Should show the remote
git remote -v
```

## Step 4 — Hourly cron (Artemis side)

Edit your crontab: `crontab -e` and add this single line:

```cron
0 * * * * cd /home/emsuserver/Documents/Cline/Rules && /usr/bin/git pull --rebase --autostash origin main && /usr/bin/git add -A && (/usr/bin/git diff --cached --quiet || (/usr/bin/git commit -m "Artemis auto-sync $(date +\%FT\%T)" && /usr/bin/git push origin main)) >> /tmp/cline-rules-sync.log 2>&1
```

Note the `\%` escapes — cron requires this.

Confirm cron will fire:

```bash
# Should print the line you just added
crontab -l | grep cline-rules
```

You can force one immediate run to verify (drops a heartbeat):

```bash
bash -c 'cd /home/emsuserver/Documents/Cline/Rules && git pull --rebase --autostash origin main && git add -A && (git diff --cached --quiet || (git commit -m "Artemis manual test $(date +%FT%T)" && git push origin main))' 2>&1 | tee -a /tmp/cline-rules-sync.log
```

Tail the log on later cron ticks: `tail -f /tmp/cline-rules-sync.log`

## Hardening to prevent the stall from recurring

These are the things to bake into ANY future Cline task on Artemis that
involves git over HTTPS to a private/PAT-gated repo:

- **`export GIT_TERMINAL_PROMPT=0`** in `~/.bashrc`. Makes any unauthenticated
  push fail fast with `terminal prompts disabled` instead of blocking on
  stdin forever. Cline can recover from a fast failure; it cannot recover
  from a hung process.
- **`credential.helper store` + pre-seeded `~/.git-credentials`.** This is
  the only credential path on headless Linux that doesn't ask for a TTY.
  `osxkeychain` won't work, `cache` expires, `manager-core` needs a GUI.
- **Don't run `git status` from a non-repo subdirectory.** Either `cd` into
  a real repo, or use `git -C /path/to/known-repo status`. The walk-up
  behavior is the silent killer.
- **For Cline specifically:** if a tool call is going to run a git command
  that *might* be interactive, prefix it with
  `GIT_TERMINAL_PROMPT=0 timeout 30s git ...` so the agent gets a clean
  exit code instead of a stuck child process.

## Why this matters going forward

The whole point of `cline-handoff-relay` is that GitHub HTTPS is the only
reliable bidirectional path between your Mac and Artemis (Artemis port 22 is
firewalled at the router, so direct `scp Mac→Artemis` cannot work). If the
git sync stalls on either side, the Cline rules will silently drift and the
two machines start using different rule sets without anyone noticing.

The hourly cron + heartbeat file (`/tmp/cline-rules-sync.heartbeat` on Mac,
`/tmp/cline-rules-sync.log` on Artemis) gives you visibility into whether
sync is actually running. If `mtime` of either is more than ~2 hours old
during normal operating hours, the sync is broken and you should
re-bootstrap.

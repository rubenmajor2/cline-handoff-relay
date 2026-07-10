#!/bin/bash
# Cline relay auto-sync — flock-protected, autostash-free.
#
# Replaces the old `git pull --rebase --autostash` pattern that was racing
# with rule_violations/write_rule.py and yolo_learner/write_rule.py when
# they stamped LIVE COUNTERS into rules 17, 95, 99 mid-pull. The autostash
# would re-apply over the freshly-pulled counters and produce
# `<<<<<<< Updated upstream` markers in committed files.
#
# This script grabs a single global flock that the write_rule.py scripts
# also grab (via wrapper). Order of operations:
#   1. flock /tmp/cline-relay.lock  (waits up to 60s)
#   2. If working tree is dirty (counter stamps mid-flight), commit them first.
#   3. git fetch origin main (read-only, can't conflict)
#   4. git merge --ff-only origin/main (will fail if local is ahead — that's fine, we already committed)
#   5. If ff-only fails, do a rebase WITHOUT autostash (clean tree guaranteed by step 2).
#   6. git push origin main if our local is ahead.
#   7. flock released.
#
# Source: #artemis-cline-yolo-parity-repair-2026-05-03 follow-up
# Ledger: 2026-05-03 23:11 PT entry

set -uo pipefail

CLINE="$HOME/Documents/Cline"
LOG=/tmp/cline-rules-sync.log
LOCK=/tmp/cline-relay.lock
HEARTBEAT=/tmp/cline-rules-sync.heartbeat

ts() { date -Iseconds; }

cd "$CLINE" || { echo "$(ts) ERROR: $CLINE missing" >> "$LOG" ; exit 0; }

export GIT_TERMINAL_PROMPT=0
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# If we were called WITHOUT the lock held, re-exec ourselves under sync_lock.py.
# This makes the lock cross-platform (no Linux-only flock(1) needed).
# Note: pass /bin/bash + absolute path explicitly because $0 may be relative
# (e.g. when invoked as `bash sync.sh`) and execvp doesn't resolve relative paths.
if [ -z "${CLINE_RELAY_LOCKED:-}" ] ; then
  export CLINE_RELAY_LOCKED=1
  exec /usr/bin/python3 "$CLINE/sync_lock.py" -w 60 -- /bin/bash "$CLINE/sync.sh" "$@"
fi

echo "" >> "$LOG"
echo "--- $(ts) TICK ---" >> "$LOG"

# Step 0: export Mac state.vscdb settings to Rules/cline_settings.json so
# they travel with the rules sync. Source incident: 2026-05-05 #1777968053585.
# Mac is authoritative for these keys.
if [ -x "$CLINE/cline_settings_export.sh" ] ; then
  bash "$CLINE/cline_settings_export.sh" >> "$LOG" 2>&1 || \
    echo "$(ts) sync: cline_settings_export.sh failed (non-fatal)" >> "$LOG"
fi

# Step 1: commit any local stamps before doing anything network.
# This includes counter stamps from rule_violations/write_rule.py and
# yolo_learner/write_rule.py that may have run since the last sync.
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ] ; then
  HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname)
  echo "$(ts) sync: $DIRTY local changes, committing first" >> "$LOG"
  git add -A >> "$LOG" 2>&1
  if git diff --cached --quiet ; then
    echo "$(ts) sync: nothing actually staged after add, skipping commit" >> "$LOG"
  else
    git commit -m "$HOSTNAME_SHORT auto-sync $(date +%FT%T)" >> "$LOG" 2>&1
  fi
fi

# Step 2: fetch from remote (read-only).
git fetch origin main >> "$LOG" 2>&1 || {
  echo "$(ts) sync: fetch failed" >> "$LOG"
  exit 0
}

# Step 3: try fast-forward merge first (most common case: remote ahead, local has nothing new).
# If local is also ahead (we just committed), ff-only will fail and we'll rebase.
if git merge --ff-only origin/main >> "$LOG" 2>&1 ; then
  echo "$(ts) sync: ff-only merge OK" >> "$LOG"
else
  # Diverged. Rebase without autostash (working tree is clean — we committed in step 1).
  echo "$(ts) sync: ff-only failed, attempting rebase" >> "$LOG"
  if ! git rebase origin/main >> "$LOG" 2>&1 ; then
    echo "$(ts) sync: rebase failed, aborting and deferring to next tick" >> "$LOG"
    git rebase --abort >> "$LOG" 2>&1
    exit 0
  fi
fi

# Step 4: push if local is ahead.
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
if [ "$LOCAL" != "$REMOTE" ] ; then
  echo "$(ts) sync: pushing local commits" >> "$LOG"
  git push origin main >> "$LOG" 2>&1 || echo "$(ts) sync: push failed (will retry next tick)" >> "$LOG"
else
  echo "$(ts) sync: nothing to push" >> "$LOG"
fi

# Step 5: re-apply bundle patches (YOLO cap 99 + 500K auto-condense). Idempotent.
# These live in the bundle (not settings) and get wiped on Cline ext updates,
# so we re-apply every tick. Source: 2026-05-30 cross-machine alignment directive.
if [ -x "$CLINE/cline_bundle_patch.sh" ] ; then
  bash "$CLINE/cline_bundle_patch.sh" >> "$LOG" 2>&1 || \
    echo "$(ts) sync: cline_bundle_patch.sh failed (non-fatal)" >> "$LOG"
fi

date '+%s' > "$HEARTBEAT"
echo "$(ts) sync: tick complete" >> "$LOG"
exit 0

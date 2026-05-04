#!/bin/bash
# Runs scanner + rule writer. Called by launchd (Mac) or cron (Linux) every 30 min.
# Cross-platform: skips Mac-only push helpers on Linux.
# write_rule.py is wrapped in flock (/tmp/cline-relay.lock) so it can't race
# with the auto-sync cron mid-write — fixes the autostash conflict marker bug.
# Exits 0 even on partial failure.

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

cd "$HOME/Documents/Cline/yolo_learner" || exit 0

/usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/scan.py"            >> /tmp/yolo_learner.log 2>&1
# write_rule stamps rule 99 — must hold the same lock as sync.sh (cross-platform via sync_lock.py)
/usr/bin/python3 "$HOME/Documents/Cline/sync_lock.py" -w 60 -- /usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/write_rule.py" >> /tmp/yolo_learner.log 2>&1
/usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/bridge_to_ledger.py" >> /tmp/yolo_learner.log 2>&1

# Mac-only push helpers (ledger sync to WOPR, ops chat alert) — Linux skips.
if [ "$(uname -s)" = "Darwin" ] ; then
  /bin/bash "$HOME/Documents/Cline/yolo_learner/push_to_ruben.sh"  >> /tmp/yolo_learner.log 2>&1
  /bin/bash "$HOME/Documents/Cline/yolo_learner/push_ledger.sh"    >> /tmp/yolo_learner.log 2>&1
fi
/bin/bash "$HOME/Documents/Cline/yolo_learner/check_burst.sh"      >> /tmp/yolo_learner.log 2>&1

exit 0

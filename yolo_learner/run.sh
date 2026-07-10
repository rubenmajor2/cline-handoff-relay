#!/bin/bash
# Runs scanner + rule writer. Called by launchd (Mac) or cron (Linux) every 30 min.
# Cross-platform: skips Mac-only push helpers on Linux.
# Exits 0 even on partial failure.

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

cd "$HOME/Documents/Cline/yolo_learner" || exit 0

/usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/scan.py"            >> /tmp/yolo_learner.log 2>&1

# write_rule stamps rule 99 — wrapped in sync_lock if available, else direct
if [ -f "$HOME/Documents/Cline/sync_lock.py" ]; then
  /usr/bin/python3 "$HOME/Documents/Cline/sync_lock.py" -w 60 -- /usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/write_rule.py" >> /tmp/yolo_learner.log 2>&1
else
  /usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/write_rule.py" >> /tmp/yolo_learner.log 2>&1
fi

/usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/bridge_to_ledger.py" >> /tmp/yolo_learner.log 2>&1

# Bridge yolo_trips → MCP violations table so clinerules_stats shows live counts
/usr/bin/python3 "$HOME/Documents/Cline/yolo_learner/sync_to_mcp.py" >> /tmp/yolo_learner.log 2>&1

# Mac-only push helpers (ledger sync to WOPR, ops chat alert) — run if they exist
if [ "$(uname -s)" = "Darwin" ] ; then
  [ -f "$HOME/Documents/Cline/yolo_learner/push_to_ruben.sh" ] && /bin/bash "$HOME/Documents/Cline/yolo_learner/push_to_ruben.sh"  >> /tmp/yolo_learner.log 2>&1
  [ -f "$HOME/Documents/Cline/yolo_learner/push_ledger.sh"   ] && /bin/bash "$HOME/Documents/Cline/yolo_learner/push_ledger.sh"    >> /tmp/yolo_learner.log 2>&1
fi

/bin/bash "$HOME/Documents/Cline/yolo_learner/check_burst.sh"      >> /tmp/yolo_learner.log 2>&1

exit 0
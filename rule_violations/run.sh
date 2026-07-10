#!/bin/bash
# Cline rule-violation scanner runner. Called by launchd (Mac) or cron (Linux) every 30 min.
# Exits 0 even on partial failure.

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

cd "$HOME/Documents/Cline/rule_violations" || exit 0

/usr/bin/python3 "$HOME/Documents/Cline/rule_violations/scan.py"          >> /tmp/cline_rule_violations.log 2>&1
# write_rule stamps rules 17 + 95 LIVE COUNTERS — must hold the relay lock
/usr/bin/python3 "$HOME/Documents/Cline/sync_lock.py" -w 60 -- /usr/bin/python3 "$HOME/Documents/Cline/rule_violations/write_rule.py" >> /tmp/cline_rule_violations.log 2>&1
/bin/bash         "$HOME/Documents/Cline/rule_violations/check_burst.sh"  >> /tmp/cline_rule_violations.log 2>&1

exit 0

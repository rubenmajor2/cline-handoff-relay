#!/bin/bash
# YOLO trip burst alert.
#
# Runs after each scan. If >=5 trips hit in the last 2 hours, submit a
# warning-severity event to RUBEN's orchestrator_event_log on WOPR so
# Ruben sees it on the RUBEN dashboard + it flows through the triage cron.
# RUBEN will then fire the iMessage to ops chat 55 if the triage policy
# deems it worth alerting (avoids spamming Vicky during Anthropic outages).
#
# Idempotent: writes /tmp/yolo_learner.last_alert so we only submit if
# the trip count has grown since the last event.
#
# Exit 0 always so launchd never complains.

set -u
LOG=/tmp/yolo_learner.log
STATE=/tmp/yolo_learner.last_alert
DB=$HOME/Documents/Cline/yolo_learner/yolo_trips.sqlite

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] check_burst: $*" >> "$LOG"; }

[ -f "$DB" ] || exit 0

# trips in last 2 hours
TWO_H_AGO=$(/usr/bin/python3 -c "import time; print(int(time.time())-7200)")
RECENT=$(/usr/bin/sqlite3 "$DB" "SELECT COUNT(*) FROM trips WHERE detected_at >= $TWO_H_AGO;")
[ -z "$RECENT" ] && exit 0

# What's the most common failure class in the last 2h? (for the alert body)
TOP_CAT=$(/usr/bin/sqlite3 "$DB" "SELECT cat_1, COUNT(*) c FROM trips WHERE detected_at >= $TWO_H_AGO AND cat_1 IS NOT NULL GROUP BY cat_1 ORDER BY c DESC LIMIT 1;" 2>/dev/null)

# have we already alerted on this count?
LAST=0
if [ -f "$STATE" ]; then
    LAST=$(cat "$STATE")
fi

if [ "$RECENT" -ge 5 ] && [ "$RECENT" -gt "$LAST" ]; then
    # Fresh burst. Submit event to RUBEN orchestrator.
    # event_type='ruben_ai', source='yolo_learner', severity='warning'.
    # Payload includes trip count + top failure category so triage can
    # route it sensibly (e.g. don't alert if top cat is api_overloaded
    # because that's upstream and Vicky can't fix it).
    SUBJECT="Cline YOLO burst: ${RECENT} trips in 2h"
    PAYLOAD=$(/usr/bin/python3 -c "
import json
print(json.dumps({
    'trips_last_2h': ${RECENT},
    'top_failure_class': '''${TOP_CAT}''',
    'baseline_avg_per_2h': '0-2',
    'suggested_response': 'check /tmp/yolo_learner.log and ~/Documents/Cline/Rules/99-yolo-prevention-learned.md; if api_overloaded is top cat just wait it out',
}))")
    B64=$(echo -n "$PAYLOAD" | base64 | tr -d '\n')

    # Use the orchestrator insert via SSH. Same pattern as push_to_ruben.sh.
    REMOTE_PHP=$(cat <<PHP
<?php
require_once '/var/www/emtskills/lib/db.php';
\$pdo = db('portal');
\$payload = base64_decode('${B64}');
\$stmt = \$pdo->prepare(
    "INSERT INTO orchestrator_event_log
        (event_type, source, subject, payload, severity, processed, created_at)
     VALUES ('ruben_ai', 'yolo_learner', :subj, :payload, 'warning', 0, NOW())"
);
\$stmt->execute([':subj' => '${SUBJECT}', ':payload' => \$payload]);
echo "ok id=" . \$pdo->lastInsertId() . "\n";
PHP
)

    OUT=$(echo "$REMOTE_PHP" | ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no wopr \
        "cat > /tmp/yolo_burst.php && php /tmp/yolo_burst.php; rm -f /tmp/yolo_burst.php" 2>&1)
    RC=$?

    echo "$RECENT" > "$STATE"
    if [ $RC -eq 0 ]; then
        log "burst event fired ($RECENT trips, top=$TOP_CAT) -> RUBEN ($OUT)"
    else
        log "burst event failed rc=$RC out=$(echo "$OUT" | head -c 200)"
    fi
fi

exit 0

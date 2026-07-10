#!/bin/bash
# push_patterns_to_ruben.sh — Cline→RUBEN pattern bridge
# Reads the top YOLO failure categories from patterns.json and upserts
# matching rows into orchestrator_learned_patterns on WOPR so RUBEN's
# triage cron can see Cline failure patterns alongside executor patterns.
# Runs as part of yolo_learner/run.sh after scan.py + write_rule.py.
# Rule: .clinerules/rule-17 addendum + idea #3383

set -uo pipefail
LOG=/tmp/yolo_learner.log
PATTERNS="$HOME/Documents/Cline/yolo_learner/patterns.json"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] push_to_ruben: $*" >> "$LOG"; }

[ -f "$PATTERNS" ] || { log "patterns.json not found, skipping"; exit 0; }

# Parse top categories (10+ hits in last 7 days) from patterns.json
TOP_CATS=$(python3 -c "
import json, sys
d = json.load(open('$PATTERNS'))
cats = d.get('last_7_days', {}).get('categories', [])
for cat, n in cats:
    if n >= 10:
        print(f'{cat}|{n}')
" 2>/dev/null)

[ -z "$TOP_CATS" ] && { log "no categories with 10+ hits in last 7d, skipping"; exit 0; }

# Total trips last 7d for context
TOTAL=$(python3 -c "import json; d=json.load(open('$PATTERNS')); print(d.get('last_7_days',{}).get('total_trips',0))" 2>/dev/null)

log "Pushing top YOLO categories to RUBEN (total_7d=$TOTAL)..."

while IFS='|' read -r CAT COUNT; do
    [ -z "$CAT" ] && continue
    HASH="cline_yolo_$(echo "$CAT" | tr ' /:' '_')"
    KW_PATTERN="Cline YOLO trip: $CAT ($COUNT hits in 7d)"
    ACTION="update_clinerules_playbook_for_${CAT// /_}"
    # Upsert into orchestrator_learned_patterns via WOPR SSH
    RESULT=$(ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o BatchMode=yes wopr \
        "mysql -u adminportal -piV84o80^y admin_portal -e \"
INSERT INTO orchestrator_learned_patterns
  (pattern_hash, event_type, event_source, keyword_pattern, dominant_action, total_matches, confidence, auto_enabled, last_observed_at)
VALUES
  ('${HASH}', 'cline_yolo', 'cline_yolo_learner', '$(echo $KW_PATTERN | sed s/\"/\\\\\"/g)', 'review_clinerules_playbook', ${COUNT}, 0.90, 0, NOW())
ON DUPLICATE KEY UPDATE
  total_matches = ${COUNT},
  last_observed_at = NOW(),
  event_source = 'cline_yolo_learner'
;\" 2>&1" 2>/dev/null)
    if [ $? -eq 0 ]; then
        log "upserted: $CAT ($COUNT hits) -> hash=$HASH"
    else
        log "WARN: failed to upsert $CAT: $RESULT"
    fi
done <<< "$TOP_CATS"

log "push_patterns_to_ruben done"

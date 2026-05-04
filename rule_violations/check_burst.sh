#!/bin/bash
# Burst-rate alarm. If we detected >= BURST_THRESHOLD new violations in the
# last hour, send Ruben a text. Rate-capped to one alert per 6 hours per rule
# so we don't spam.

set -uo pipefail

DB="$HOME/Documents/Cline/rule_violations/violations.sqlite"
STATE="$HOME/Documents/Cline/rule_violations/last_alert.json"
LOG="/tmp/cline_rule_violations.log"
BURST_THRESHOLD=5
COOLDOWN_SEC=$((6 * 3600))
RUBEN_PHONE="${RUBEN_PHONE:-}"   # set in env to enable SMS via shortcut

ts() { date -Iseconds; }

if [ ! -f "$DB" ]; then
  echo "[$(ts)] no DB yet, skipping burst check" >> "$LOG"
  exit 0
fi

NOW=$(date +%s)
HOUR_AGO=$((NOW - 3600))

# Per-rule counts in last hour
COUNT_17=$(/usr/bin/sqlite3 "$DB" \
  "SELECT COUNT(*) FROM violations WHERE rule='rule_17' AND detected_at >= $HOUR_AGO;" 2>/dev/null || echo 0)
COUNT_95=$(/usr/bin/sqlite3 "$DB" \
  "SELECT COUNT(*) FROM violations WHERE rule='rule_95' AND detected_at >= $HOUR_AGO;" 2>/dev/null || echo 0)

last_alert_for() {
  local key="$1"
  if [ -f "$STATE" ]; then
    /usr/bin/python3 -c "
import json,sys
try:
  d=json.load(open('$STATE'))
  print(int(d.get('$key',0)))
except Exception:
  print(0)
" 2>/dev/null
  else
    echo 0
  fi
}

set_alert_for() {
  local key="$1"
  local val="$2"
  /usr/bin/python3 -c "
import json,os
p='$STATE'
d={}
if os.path.exists(p):
  try: d=json.load(open(p))
  except: d={}
d['$key']=$val
json.dump(d, open(p,'w'))
"
}

maybe_alert() {
  local rule="$1"
  local count="$2"
  if [ "$count" -lt "$BURST_THRESHOLD" ]; then
    return
  fi
  local last
  last=$(last_alert_for "$rule")
  if [ $((NOW - last)) -lt "$COOLDOWN_SEC" ]; then
    echo "[$(ts)] burst detected for $rule (count=$count) but cooldown active" >> "$LOG"
    return
  fi
  local msg=".clinerules burst: $count $rule violations in last hour. check ~/Documents/Cline/rule_violations/violations.sqlite"
  echo "[$(ts)] BURST ALERT $rule count=$count" >> "$LOG"
  # Local notification (always works on macOS)
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Cline rule burst\"" 2>/dev/null || true
  # Optional SMS via Apple Shortcuts if RUBEN_PHONE is set and Shortcut named "send-text" exists
  if [ -n "$RUBEN_PHONE" ]; then
    /usr/bin/shortcuts run "send-text" <<< "{\"recipient\":\"$RUBEN_PHONE\",\"text\":\"$msg\"}" 2>/dev/null || true
  fi
  set_alert_for "$rule" "$NOW"
}

maybe_alert "rule_17" "$COUNT_17"
maybe_alert "rule_95" "$COUNT_95"

echo "[$(ts)] burst check: rule_17=$COUNT_17 rule_95=$COUNT_95 (threshold=$BURST_THRESHOLD)" >> "$LOG"
exit 0

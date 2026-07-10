#!/bin/bash
# cline_7b_lora_babysit.sh — watches the 7B-LoRA tier-1 flip post-2026-05-11.
#
# Every run:
#  1. Reads ~/.cline-router/audit.sqlite for the last N hours
#  2. Computes fallback rate + dominant fail_reason for emsu-qwen2.5-coder-7b-lora
#  3. If fallback rate exceeds threshold OR new fail_reason class appears,
#     posts an orchestrator_event_log row to admin_portal so RUBEN/KAIZEN
#     pick it up via the existing event-triage cron + ab_grader.
#
# Designed to run via launchd every 15 min on Mac, or hand-fired anytime:
#     bash ~/Documents/Cline/cline_7b_lora_babysit.sh
#     bash ~/Documents/Cline/cline_7b_lora_babysit.sh --hours 24
#     bash ~/Documents/Cline/cline_7b_lora_babysit.sh --hours 4 --dry-run
#
# Reversal: kill the launchd plist + delete this file.

set -uo pipefail

HOURS=${HOURS:-1}
DRY_RUN=0
FALLBACK_THRESHOLD_PCT=${FALLBACK_THRESHOLD_PCT:-25}   # alert if > 25% fallback
MIN_SAMPLES=${MIN_SAMPLES:-5}                           # don't alert on N<5
AUDIT_DB=$HOME/.cline-router/audit.sqlite
LOG=/tmp/cline_7b_babysit.log
STATE=/tmp/cline_7b_babysit.last_alert

# Arg parse
while [ $# -gt 0 ]; do
  case "$1" in
    --hours) HOURS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --threshold) FALLBACK_THRESHOLD_PCT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

ts() { date '+%Y-%m-%d %H:%M:%S %Z'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

[ -f "$AUDIT_DB" ] || { log "no audit db at $AUDIT_DB — router never ran?"; exit 0; }

# Pull rollup for last HOURS
CUTOFF=$(/usr/bin/python3 -c "import time; print(int(time.time())-$HOURS*3600)")

read_q() {
  /usr/bin/sqlite3 "$AUDIT_DB" "$1"
}

# Count routine routes (the flip's target) — ollama_model is set whether
# the call succeeded or fell back, so this is the right denominator.
ROUTINE_7B=$(read_q "SELECT COUNT(*) FROM turns WHERE ts >= $CUTOFF AND classifier_label='routine' AND ollama_model='emsu-qwen2.5-coder-7b-lora';")
FALLBACKS=$(read_q "SELECT COUNT(*) FROM turns WHERE ts >= $CUTOFF AND classifier_label='routine' AND ollama_model='emsu-qwen2.5-coder-7b-lora' AND fallback_called=1;")
COST_SAVED=$(read_q "SELECT ROUND(COALESCE(SUM(estimated_cost_saved_usd),0),4) FROM turns WHERE ts >= $CUTOFF AND ollama_model='emsu-qwen2.5-coder-7b-lora';")
COST_PAID=$(read_q "SELECT ROUND(COALESCE(SUM(estimated_cost_paid_usd),0),4) FROM turns WHERE ts >= $CUTOFF AND fallback_model='claude-sonnet-4-6' AND ollama_model='emsu-qwen2.5-coder-7b-lora';")

TOP_FAIL=$(read_q "SELECT fail_reason || ' (' || COUNT(*) || ')' FROM turns WHERE ts >= $CUTOFF AND classifier_label='routine' AND ollama_model='emsu-qwen2.5-coder-7b-lora' AND fail_reason IS NOT NULL GROUP BY fail_reason ORDER BY COUNT(*) DESC LIMIT 1;")

if [ -z "$ROUTINE_7B" ] || [ "$ROUTINE_7B" = "0" ]; then
  log "no 7B-LoRA routine routes in last ${HOURS}h — nothing to do"
  exit 0
fi

PCT=$(/usr/bin/python3 -c "print(round(100.0*$FALLBACKS/max($ROUTINE_7B,1),1))")
log "last ${HOURS}h: 7B routine routes=$ROUTINE_7B  fallbacks=$FALLBACKS ($PCT%)  top_fail=${TOP_FAIL:-none}  cost_saved=\$$COST_SAVED  cost_paid=\$$COST_PAID"

# Alert gate
ALERT=0
PCT_INT=$(/usr/bin/python3 -c "print(int($PCT))")
if [ "$ROUTINE_7B" -ge "$MIN_SAMPLES" ] && [ "$PCT_INT" -gt "$FALLBACK_THRESHOLD_PCT" ]; then
  ALERT=1
fi

# Idempotency: don't fire twice on the same PCT within an hour
LAST_PCT=0
LAST_TS=0
if [ -f "$STATE" ]; then
  LAST_PCT=$(awk '{print $1}' "$STATE" 2>/dev/null || echo 0)
  LAST_TS=$(awk '{print $2}' "$STATE" 2>/dev/null || echo 0)
fi
NOW_TS=$(/usr/bin/python3 -c "import time; print(int(time.time()))")
COOLDOWN=$(( NOW_TS - LAST_TS ))

if [ "$ALERT" = "1" ] && [ "$COOLDOWN" -lt 3600 ] && [ "$LAST_PCT" -ge "$PCT_INT" ]; then
  log "alert suppressed (cooldown ${COOLDOWN}s, last_pct=$LAST_PCT)"
  ALERT=0
fi

if [ "$ALERT" = "1" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY RUN: would file orchestrator_event_log row (severity=warning, fallback_pct=$PCT%, top_fail=$TOP_FAIL)"
  else
    # File via SSH to WOPR
    PAYLOAD=$(/usr/bin/python3 -c "
import json
print(json.dumps({
    'window_hours': $HOURS,
    'routine_routes_to_7b': $ROUTINE_7B,
    'fallbacks_fired': $FALLBACKS,
    'fallback_pct': $PCT,
    'threshold_pct': $FALLBACK_THRESHOLD_PCT,
    'top_fail_reason': '''${TOP_FAIL:-none}''',
    'cost_saved_usd': '$COST_SAVED',
    'cost_paid_sonnet_fallback_usd': '$COST_PAID',
    'source_audit_db': '$AUDIT_DB',
    'reversal_hint': 'sed launchd plist CLINE_ROUTER_OLLAMA_MODEL=ollama-qwen-14b + bootout+bootstrap',
}))
")
    B64=$(echo -n "$PAYLOAD" | base64 | tr -d '\n')
    SUBJECT="7B-LoRA fallback rate ${PCT}% in last ${HOURS}h (threshold ${FALLBACK_THRESHOLD_PCT}%, top: ${TOP_FAIL:-none})"
    REMOTE_PHP=$(cat <<PHP
<?php
require_once '/var/www/emtskills/lib/db.php';
\$pdo = db('portal');
\$payload = base64_decode('${B64}');
\$stmt = \$pdo->prepare(
    "INSERT INTO orchestrator_event_log
        (event_type, source, subject, payload, severity, processed, created_at)
     VALUES ('ruben_ai', 'cline_7b_babysit', :subj, :payload, 'warning', 0, NOW())"
);
\$stmt->execute([':subj' => '${SUBJECT}', ':payload' => \$payload]);
echo "ok id=" . \$pdo->lastInsertId() . "\n";
PHP
)
    OUT=$(echo "$REMOTE_PHP" | ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no wopr \
        "cat > /tmp/cline_7b_babysit.php && php /tmp/cline_7b_babysit.php; rm -f /tmp/cline_7b_babysit.php" 2>&1)
    RC=$?
    echo "$PCT_INT $NOW_TS" > "$STATE"
    if [ $RC -eq 0 ]; then
      log "alert fired ($PCT%) → RUBEN orchestrator_event_log ($OUT)"
    else
      log "alert failed rc=$RC out=$(echo "$OUT" | head -c 200)"
    fi
  fi
fi

exit 0

#!/bin/bash
# cline_settings_apply_mac.sh — Mac-side counterpart to cline_settings_apply.sh
# (which is Artemis-only — its DB_CANDIDATES are /home/emsuserver/... only).
#
# Source incident: 2026-05-07 22:50 PT — Cline windows on Mac giving up after
# 3 mistakes. state.vscdb on Mac had ItemTable but NO maxConsecutiveMistakes /
# useAutoCondense / autoApprovalSettings rows. Fall-through to Cline's default
# of 3 → matches the rule 16 "windows die for no reason" symptom.
#
# Why earlier Artemis-style apply silently no-op'd on Mac: state.vscdb is
# locked by running VS Code. SQLite writes time out / fail silently. So this
# script must run ONLY when VS Code is fully quit.
#
# USAGE:
#   1. Cmd+Q on the VS Code dock icon (full quit, not just close window)
#   2. bash /Users/rubenmajor/Documents/Cline/cline_settings_apply_mac.sh
#   3. Re-open VS Code. New tasks inherit maxConsecutiveMistakes=10.

set -uo pipefail
JSON="/Users/rubenmajor/Documents/Cline/Rules/cline_settings.json"
DB="/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/state.vscdb"
LOG=/tmp/cline-settings-apply-mac.log

ts(){ date -Iseconds; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG"; }

# Bail if VS Code is up — DB will be locked and writes will silently fail.
if pgrep -x "Code" >/dev/null 2>&1; then
  log "ABORT: VS Code is running. Cmd+Q the dock icon, then re-run this script."
  exit 2
fi
[ -f "$JSON" ] || { log "JSON missing at $JSON"; exit 1; }
[ -f "$DB" ]   || { log "DB missing at $DB"; exit 1; }

log "VS Code is quit. Applying authoritative settings to $DB"
CHANGED=0
for KEY in $(jq -r 'keys[] | select(. != "_meta")' "$JSON"); do
  VAL=$(jq -r --arg k "$KEY" '.[$k]' "$JSON")
  ESC=$(printf '%s' "$VAL" | sed "s/'/''/g")
  CUR=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
  if [ "$CUR" = "$VAL" ]; then
    log "  $KEY: unchanged"
    continue
  fi
  sqlite3 -cmd ".timeout 5000" "$DB" "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('$KEY', '$ESC');"
  NEW=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
  if [ "$NEW" = "$VAL" ]; then
    log "  $KEY: applied (was: ${CUR:0:60})"
    CHANGED=$((CHANGED+1))
  else
    log "  $KEY: APPLY FAILED (still: ${NEW:0:60})"
  fi
done
log "done. $CHANGED keys updated. Re-open VS Code."

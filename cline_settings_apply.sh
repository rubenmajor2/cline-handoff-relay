#!/bin/bash
# cline_settings_apply.sh — Artemis side
# Reads cline_settings.json from the cline-handoff-relay repo (synced from Mac)
# and applies the 3 authoritative keys to Artemis state.vscdb.
#
# Source incident: 2026-05-05 #1777968053585 — Artemis maxConsecutiveMistakes=50
# while Mac was 10 (per .clinerules/16) because state.vscdb was never synced.
# Mac is authoritative; this is a one-way Mac->Artemis pull.
#
# Run from cron AFTER the rules-sync cron has done git pull.
# Reads:  ~/Documents/Cline/Rules/cline_settings.json
# Writes: ~/.local/share/code-server/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb

set -euo pipefail

JSON=/home/emsuserver/Documents/Cline/Rules/cline_settings.json
DB=/home/emsuserver/.local/share/code-server/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb
LOG=/tmp/cline-settings-apply.log

ts() { date -Iseconds; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

if [ ! -f "$JSON" ]; then
  log "JSON not found at $JSON, skipping"
  exit 0
fi

if [ ! -f "$DB" ]; then
  log "state.vscdb not found at $DB, skipping"
  exit 0
fi

# Get authoritative source label from JSON for logging
SOURCE=$(jq -r '._meta.source // "unknown"' "$JSON" 2>/dev/null)
EXPORTED=$(jq -r '._meta.exported_at // "unknown"' "$JSON" 2>/dev/null)
log "applying settings from $SOURCE exported_at=$EXPORTED"

# Apply each key (skip _meta)
CHANGED=0
for KEY in $(jq -r 'keys[] | select(. != "_meta")' "$JSON"); do
  VALUE=$(jq -r --arg k "$KEY" '.[$k]' "$JSON")
  CURRENT=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
  if [ "$CURRENT" = "$VALUE" ]; then
    log "  $KEY: unchanged"
    continue
  fi
  # Use parameterized update via stdin to avoid quoting hell on JSON values
  printf "%s" "$VALUE" | sqlite3 -cmd ".timeout 5000" "$DB" \
    "UPDATE ItemTable SET value = readfile('/dev/stdin') WHERE key = '$KEY';" 2>/dev/null && {
      # readfile won't read stdin; fall through to a portable approach
      true
    }
  # Portable: escape ' in value, embed in SQL
  ESCAPED=$(printf '%s' "$VALUE" | sed "s/'/''/g")
  sqlite3 -cmd ".timeout 5000" "$DB" "UPDATE ItemTable SET value = '$ESCAPED' WHERE key = '$KEY';" 2>/dev/null
  # Sanity-check
  NEWVAL=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
  if [ "$NEWVAL" = "$VALUE" ]; then
    log "  $KEY: applied (was: ${CURRENT:0:60})"
    CHANGED=$((CHANGED+1))
  else
    log "  $KEY: APPLY FAILED (current still: ${NEWVAL:0:60})"
  fi
done

log "done. $CHANGED keys updated."
exit 0

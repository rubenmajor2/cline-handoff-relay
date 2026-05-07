#!/bin/bash
# cline_settings_apply.sh — Artemis side
# Reads cline_settings.json from the cline-handoff-relay repo (synced from Mac)
# and applies the authoritative keys to whichever Cline state.vscdb exists.
#
# Source incident: 2026-05-05 #1777968053585 — Artemis maxConsecutiveMistakes=50
# while Mac was 10 (per .clinerules/16) because state.vscdb was never synced.
# Mac is authoritative; this is a one-way Mac->Artemis pull.
#
# 2026-05-07 patch — handle BOTH possible state.vscdb paths:
#   - ~/.vscode-server/data/User/globalStorage/state.vscdb     (VS Code Remote-SSH)
#   - ~/.local/share/code-server/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb (legacy code-server)
# Use INSERT OR REPLACE so it works even if the key never existed.
# Skip gracefully if ItemTable doesn't exist yet (Cline hasn't initialized).
#
# Run from cron AFTER the rules-sync cron has done git pull.

set -uo pipefail

JSON=/home/emsuserver/Documents/Cline/Rules/cline_settings.json
LOG=/tmp/cline-settings-apply.log

# Candidate DB paths in priority order. First-existing wins. Both can be
# present (you can run both VS Code Remote-SSH and code-server in parallel).
# We apply to ALL existing ones so whichever side is active picks it up.
DB_CANDIDATES=(
  "/home/emsuserver/.vscode-server/data/User/globalStorage/state.vscdb"
  "/home/emsuserver/.local/share/code-server/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb"
)

ts() { date -Iseconds; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

if [ ! -f "$JSON" ]; then
  log "JSON not found at $JSON, skipping"
  exit 0
fi

# Get authoritative source label from JSON for logging
SOURCE=$(jq -r '._meta.source // "unknown"' "$JSON" 2>/dev/null)
EXPORTED=$(jq -r '._meta.exported_at // "unknown"' "$JSON" 2>/dev/null)
log "applying settings from $SOURCE exported_at=$EXPORTED"

APPLIED_TO_ANY=0

for DB in "${DB_CANDIDATES[@]}"; do
  if [ ! -f "$DB" ]; then
    log "  $DB: not present (skip)"
    continue
  fi
  if [ ! -s "$DB" ]; then
    log "  $DB: 0 bytes (Cline not yet initialized — skip until ItemTable exists)"
    continue
  fi
  # Probe for ItemTable. If not there, Cline hasn't written its first global
  # state value yet. We skip rather than create the table (Cline owns the schema).
  HAS_TABLE=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='ItemTable';" 2>/dev/null)
  if [ -z "$HAS_TABLE" ]; then
    log "  $DB: ItemTable not present yet (Cline hasn't initialized — skip, will retry next cron)"
    continue
  fi
  log "  $DB: applying keys"
  CHANGED=0
  for KEY in $(jq -r 'keys[] | select(. != "_meta")' "$JSON"); do
    VALUE=$(jq -r --arg k "$KEY" '.[$k]' "$JSON")
    CURRENT=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
    if [ "$CURRENT" = "$VALUE" ]; then
      log "    $KEY: unchanged"
      continue
    fi
    # Escape single quotes in value
    ESCAPED=$(printf '%s' "$VALUE" | sed "s/'/''/g")
    sqlite3 -cmd ".timeout 5000" "$DB" "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('$KEY', '$ESCAPED');" 2>/dev/null
    NEWVAL=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
    if [ "$NEWVAL" = "$VALUE" ]; then
      log "    $KEY: applied (was: ${CURRENT:0:60})"
      CHANGED=$((CHANGED+1))
    else
      log "    $KEY: APPLY FAILED (current still: ${NEWVAL:0:60})"
    fi
  done
  log "  $DB: done. $CHANGED keys updated."
  APPLIED_TO_ANY=1
done

if [ "$APPLIED_TO_ANY" -eq 0 ]; then
  log "no Cline state.vscdb found in any candidate path with ItemTable. Will retry next cron."
fi

exit 0

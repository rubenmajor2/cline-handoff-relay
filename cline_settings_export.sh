#!/bin/bash
# cline_settings_export.sh — Mac side
# Exports the 3 authoritative Cline state.vscdb keys to JSON in the
# cline-handoff-relay git repo. Called from sync.sh BEFORE the git commit/push,
# so the JSON travels with the rule-file changes.
#
# Source incident: 2026-05-05 #1777968053585 — Artemis maxConsecutiveMistakes=50
# while Mac was 10 (per .clinerules/16) because state.vscdb was never synced.
# Mac is authoritative.

set -e

STATE_DB="/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb"
EXPORT_FILE="/Users/rubenmajor/Documents/Cline/Rules/cline_settings.json"

# Keys to export. Add to this list if more global Cline settings need to mirror.
KEYS="maxConsecutiveMistakes useAutoCondense autoApprovalSettings"

# Build JSON via sqlite query + jq
EXPORT_JSON=$(sqlite3 -cmd ".timeout 5000" "$STATE_DB" "SELECT json_object(key, value) FROM ItemTable WHERE key IN ('maxConsecutiveMistakes','useAutoCondense','autoApprovalSettings');" 2>/dev/null | jq -s 'add')

# Add metadata
FINAL_JSON=$(echo "$EXPORT_JSON" | jq --arg ts "$(date -Iseconds)" --arg src "Rubens-MacBook-Pro" '. + {_meta: {exported_at: $ts, source: $src, authoritative: true}}')

# Write only if content actually changed (avoid empty hourly commits when nothing changed)
if [ -f "$EXPORT_FILE" ]; then
  CURRENT=$(jq 'del(._meta)' "$EXPORT_FILE" 2>/dev/null || echo '{}')
  NEW=$(echo "$FINAL_JSON" | jq 'del(._meta)')
  if [ "$CURRENT" = "$NEW" ]; then
    # No content change — don't bump the file (preserves _meta timestamp from last real change)
    exit 0
  fi
fi

echo "$FINAL_JSON" | jq . > "$EXPORT_FILE"
echo "[$(date -Iseconds)] cline_settings_export.sh: wrote $EXPORT_FILE"

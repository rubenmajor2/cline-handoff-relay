#!/bin/bash
# cline_yolo_pin_mac.sh — keep Cline's YOLO-safety settings pinned on this Mac.
#
# WHY THIS EXISTS (2026-05-31):
#   Ruben: "I have way too many yolos here. I just open a window and bam yolos out."
#   yolo_trips.sqlite showed 4 fresh trips, all turns_since_user=0, all
#   triple "no-tool-use" — i.e. a brand-new window dying on the very first
#   exchange at the 3-strike default.
#
#   Root cause (rule 92 — fix the core): the launchd job that was SUPPOSED to
#   pin maxConsecutiveMistakes=99 (com.emsu.cline-yolo-apply) pointed at a
#   LINUX path (/home/emsuserver/bin/cline-yolo-apply.sh) that does not exist
#   on the Mac. launchctl showed it exiting 127 (file not found) every run.
#   So the safety pin had silently never applied — any session that read the
#   Cline default of 3 would 3-strike-and-die on open.
#
#   This script is the Mac-correct replacement. It re-pins the authoritative
#   settings to the LIVE VS Code global state DB on a schedule, so the value
#   self-heals against drift. Safe to run while VS Code is open: uses a SQLite
#   busy-timeout and verifies the write, never blocks or corrupts a locked DB.
#
# Authoritative source of truth: Rules/cline_settings.json (maxConsecutiveMistakes=99).

set -uo pipefail

# Authoritative source-of-truth lives in ~/Documents/Cline/Rules (the repo), but
# ~/Documents is TCC-protected and the launchd (gui) context cannot read it.
# So we use a mirror in this non-protected tools dir. When this script is run
# interactively (Terminal has Full Disk Access), it refreshes the mirror from the
# repo; when run from launchd it falls back to the existing mirror.
REPO_JSON="/Users/rubenmajor/Documents/Cline/Rules/cline_settings.json"
JSON="/Users/rubenmajor/.cline-tools/cline_settings.json"
if [ -r "$REPO_JSON" ]; then
  cp "$REPO_JSON" "$JSON" 2>/dev/null || true
fi

# Both DB locations the extension has used across versions. The first (root
# globalStorage) is the live one on current builds; the second is legacy.
DBS=(
  "/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/state.vscdb"
  "/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb"
)
LOG="/tmp/cline-yolo-pin.log"

ts(){ date -Iseconds; }
log(){ echo "[$(ts)] $*" >> "$LOG"; }

[ -f "$JSON" ] || { log "FATAL: authoritative JSON missing at $JSON"; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { log "FATAL: sqlite3 not found"; exit 1; }
command -v jq >/dev/null 2>&1     || { log "FATAL: jq not found"; exit 1; }

TOTAL_CHANGED=0
for DB in "${DBS[@]}"; do
  [ -f "$DB" ] || { log "skip (not present): $DB"; continue; }
  # ItemTable must exist (it always does once Cline has run once).
  HAS_TBL=$(sqlite3 -cmd ".timeout 3000" "$DB" \
    "SELECT name FROM sqlite_master WHERE type='table' AND name='ItemTable';" 2>/dev/null)
  [ "$HAS_TBL" = "ItemTable" ] || { log "skip (no ItemTable yet): $DB"; continue; }

  for KEY in $(jq -r 'keys[] | select(. != "_meta")' "$JSON"); do
    VAL=$(jq -r --arg k "$KEY" '.[$k]' "$JSON")
    ESC=$(printf '%s' "$VAL" | sed "s/'/''/g")
    CUR=$(sqlite3 -cmd ".timeout 3000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
    if [ "$CUR" = "$VAL" ]; then
      continue
    fi
    sqlite3 -cmd ".timeout 3000" "$DB" \
      "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('$KEY', '$ESC');" 2>/dev/null
    NEW=$(sqlite3 -cmd ".timeout 3000" "$DB" "SELECT value FROM ItemTable WHERE key='$KEY';" 2>/dev/null)
    if [ "$NEW" = "$VAL" ]; then
      log "PINNED $KEY on $(basename "$(dirname "$DB")")/$(basename "$DB") (was: ${CUR:0:40})"
      TOTAL_CHANGED=$((TOTAL_CHANGED+1))
    else
      # DB locked by live VS Code this pass; will retry next interval. Not fatal.
      log "DEFER $KEY on $DB (db busy/locked, will retry next run)"
    fi
  done
done

log "run complete. keys changed this pass: $TOTAL_CHANGED"
exit 0

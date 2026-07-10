#!/usr/bin/env bash
# sync_clinerules_to_wopr.sh — Mac→WOPR clinerules bidirectional sync
# Implements #12285: push Mac Rules + Rules-archive to WOPR canonical store.
#
# Called by:
#   - launchd com.emsu.clinerules-sync (every 5 min)
#   - clinerules MCP after a rule write (immediate push)
#   - manually: bash ~/Documents/Cline/scripts/sync_clinerules_to_wopr.sh
#
# Mechanism:
#   1. rsync Mac Rules/ → WOPR /var/www/emtskills/clinerules/Rules/
#   2. rsync Mac Rules-archive/ → WOPR /var/www/emtskills/clinerules/Rules-archive/
#   3. Call WOPR cron_clinerules_sync via ssh to index new files into DB
#
# Auth: uses existing SSH key (same key as emsu-operations MCP).
# WOPR host: from EMSU WireGuard config or fallback to emsuniversity.com.

set -uo pipefail

RULES_DIR="$HOME/Documents/Cline/Rules"
ARCHIVE_DIR="$HOME/Documents/Cline/Rules-archive"
WOPR_HOST="wopr"                      # WireGuard alias from ~/.ssh/config
WOPR_RULES="/var/www/emtskills/clinerules/Rules"
WOPR_ARCHIVE="/var/www/emtskills/clinerules/Rules-archive"
WOPR_SSH_USER="emsuserver"
LOG="/tmp/clinerules-mac-sync.log"
HASH_CACHE="$HOME/.clinerules-mcp/mac_push_hashes.json"
LOCK="/tmp/clinerules-mac-sync.lock"

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

# Lock: only one sync at a time (macOS-compatible, no flock)
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  log "Already running (pid=$(cat "$LOCK")), skipping"; exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

log "=== Mac→WOPR clinerules sync starting ==="

# Ensure WOPR dirs exist
ssh -q -o ConnectTimeout=8 "${WOPR_SSH_USER}@${WOPR_HOST}" \
  "mkdir -p '$WOPR_RULES' '$WOPR_ARCHIVE'" 2>/dev/null || {
  log "WARN: SSH to WOPR failed — skipping sync (will retry next run)"
  exit 0
}

PUSHED=0
UNCHANGED=0

# Push Rules/ 
if [ -d "$RULES_DIR" ]; then
  rsync_out=$(rsync -a --checksum --no-times --exclude='*.bak*' --exclude='.DS_Store' --exclude='.git*' \
    "$RULES_DIR/" "${WOPR_SSH_USER}@${WOPR_HOST}:${WOPR_RULES}/" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    log "rsync Rules/ → WOPR OK"
    PUSHED=$((PUSHED + 1))
  else
    log "WARN: rsync Rules/ failed (rc=$rc): $rsync_out"
  fi
fi

# Push Rules-archive/
if [ -d "$ARCHIVE_DIR" ]; then
  rsync_out=$(rsync -a --checksum --no-times --exclude='*.bak*' --exclude='.DS_Store' --exclude='.git*' \
    "$ARCHIVE_DIR/" "${WOPR_SSH_USER}@${WOPR_HOST}:${WOPR_ARCHIVE}/" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    log "rsync Rules-archive/ → WOPR OK"
    PUSHED=$((PUSHED + 1))
  else
    log "WARN: rsync Rules-archive/ failed (rc=$rc): $rsync_out"
  fi
fi

# Trigger WOPR cron to index new files into clinerules_canonical DB
if [ $PUSHED -gt 0 ]; then
  ssh -q -o ConnectTimeout=8 "${WOPR_SSH_USER}@${WOPR_HOST}" \
    "sudo -u www-data php /var/www/emtskills/cron/cron_clinerules_sync.php 2>&1 | tail -5" 2>/dev/null && \
    log "WOPR index cron triggered OK" || \
    log "WARN: WOPR index cron trigger failed"
fi

log "=== Mac→WOPR sync done: pushed=$PUSHED ==="

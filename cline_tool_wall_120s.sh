#!/bin/bash
# cline_tool_wall_120s.sh — idempotent patcher for the Cline tool-wall timeout
#
# Source: ~/Documents/Cline/Rules/yolo_learner output — `timeout > no-tool-use >
# no-tool-use` is the #2 YOLO triple (128 trips / 30d). The wall lives in the
# extension bundle at function MX0(t,e,r): wX0=30 (seconds). Bumping to 120
# eliminates ~70% of those trips without changing any other behavior.
#
# Per rule 34 (cline_input_clear_fix.sh): same pattern — find the newest
# extension folder, byte-patch the bundle, back up original, leave a marker
# comment so we can detect "already patched" on re-runs. Idempotent.
#
# Reversal: rm the patched line OR restore from the .bak-* file in the same
# dist/ directory.

set -u
LOG=/tmp/cline_tool_wall_fix.log
log() { echo "[$(date -Iseconds)] $*" >> "$LOG"; }

log "=== cline_tool_wall_120s.sh starting ==="

# Find newest extension folder
BUNDLE=$(ls -d /Users/rubenmajor/.vscode/extensions/saoudrizwan.claude-dev-*/dist/extension.js 2>/dev/null | sort -V | tail -1)
if [ -z "$BUNDLE" ] || [ ! -f "$BUNDLE" ]; then
    log "no Cline bundle found, exit clean"
    exit 0
fi
log "bundle: $BUNDLE"

# Already patched? Detect by presence of either the new value or a sentinel.
if grep -aq 'wX0=120,' "$BUNDLE" 2>/dev/null; then
    log "already patched (wX0=120 present), exit clean"
    exit 0
fi

# Buggy pattern not found? Cline bundling changed; do not damage.
if ! grep -aq 'wX0=30,' "$BUNDLE" 2>/dev/null; then
    log "wX0=30 not found and no patched marker — Cline bundling changed, skipping"
    exit 0
fi

# Count occurrences. Must be exactly 1 (otherwise we'd corrupt unrelated code).
COUNT=$(grep -ao 'wX0=30,' "$BUNDLE" | wc -l | tr -d ' ')
if [ "$COUNT" != "1" ]; then
    log "WARN: wX0=30, appears $COUNT times in bundle — expected 1. Refusing to patch."
    exit 1
fi

# Backup (timestamped, never overwritten)
BAK="${BUNDLE}.bak-$(date +%Y%m%d-%H%M%S)-cline-tool-wall-120s"
if ! cp "$BUNDLE" "$BAK"; then
    log "backup failed, abort"
    exit 1
fi
log "backup written: $BAK"

# Apply the byte-patch. Same length (5 chars → 6 chars), so use sed on the
# whole file. Note: this is in a giant 30MB minified file. macOS sed needs
# the -i '' form.
TMPFILE=$(mktemp)
if ! sed 's/wX0=30,/wX0=120,/g' "$BUNDLE" > "$TMPFILE"; then
    log "sed failed, abort"
    rm -f "$TMPFILE"
    exit 1
fi

# Verify the patched file: must have 1 wX0=120 and 0 wX0=30
NEW_COUNT_120=$(grep -ao 'wX0=120,' "$TMPFILE" | wc -l | tr -d ' ')
NEW_COUNT_30=$(grep -ao 'wX0=30,' "$TMPFILE" | wc -l | tr -d ' ')
if [ "$NEW_COUNT_120" != "1" ] || [ "$NEW_COUNT_30" != "0" ]; then
    log "post-sed verify failed: wX0=120,=$NEW_COUNT_120, wX0=30,=$NEW_COUNT_30 — abort"
    rm -f "$TMPFILE"
    exit 1
fi

# Move into place
if ! mv "$TMPFILE" "$BUNDLE"; then
    log "mv failed — bundle may be corrupted, restoring from backup"
    cp "$BAK" "$BUNDLE"
    exit 1
fi

log "PATCHED: wX0=30 → wX0=120 in $BUNDLE"
log "Reload Cline window for change to take effect (Cmd+Shift+P → Developer: Reload Window)"
exit 0

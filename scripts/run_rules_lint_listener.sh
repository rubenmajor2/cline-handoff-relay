#!/usr/bin/env bash
#
# run_rules_lint_listener.sh — persistent fswatch daemon for real-time pre-write lint
#
# REFERENCE ONLY (2026-07-02): this standalone listener was superseded by the
# consolidated design — the L0 per-file lint pass is now integrated directly
# into cline_rules_audit.sh, which the working com.emsu.cline-rules-audit.plist
# fires via WatchPaths on every Rules/ save. The separate com.emsu.cline-rules-lint
# plist was retired (it hit macOS com.apple.provenance EPERM on the script path).
# This file is kept as a reference implementation of the fswatch-per-file pattern
# in case the consolidated approach ever needs to be split back out.
#
# fswatch is required: brew install fswatch  (installed 2026-07-02)

set -uo pipefail

RULES_DIR="$HOME/Documents/Cline/Rules"
LINT="$RULES_DIR/.pre-write-lint.sh"
FSWATCH="/opt/homebrew/bin/fswatch"

if [ ! -x "$FSWATCH" ]; then
    FSWATCH="$(command -v fswatch 2>/dev/null || true)"
fi
if [ -z "$FSWATCH" ] || [ ! -x "$FSWATCH" ]; then
    echo "fswatch not found — install with: brew install fswatch" >&2
    exit 1
fi

# -0: null-separated output (safe for spaces)
# --recursive: watch Rules/ subtree
# --event Created/Updated/MovedTo: fire when a file lands or is modified
exec "$FSWATCH" -0 --recursive \
    --event Created --event Updated --event MovedTo \
    "$RULES_DIR" | while IFS= read -r -d '' f; do
    # Only lint .md files; skip the lint log + lock files
    case "$f" in
        *.md)     [ -f "$f" ] && /bin/bash "$LINT" "$f" || true ;;
        *)        ;;
    esac
done
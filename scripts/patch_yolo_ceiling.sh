#!/usr/bin/env bash
#
# patch_yolo_ceiling.sh — Re-patch Cline's maxConsecutiveMistakes default after extension updates
#
# The Cline extension hardcodes maxConsecutiveMistakes:{default:3} in dist/extension.js.
# This setting is NOT exposed in the Cline Settings UI or VS Code settings, so the only
# way to raise it is a direct source patch. Every time Cline updates (new version dir
# under ~/.vscode/extensions/), the patch is lost and must be re-applied.
#
# This script:
#   1. Finds the latest saoudrizwan.claude-dev-* extension dir
#   2. Checks if extension.js still has default:3 (unpatched) or default:10 (already patched)
#   3. Backs up + patches if needed
#   4. Prints clear status
#
# Usage:
#   ~/Documents/Cline/scripts/patch_yolo_ceiling.sh          # patch latest extension
#   ~/Documents/Cline/scripts/patch_yolo_ceiling.sh --check   # check only, no patch
#
# Created 2026-07-04 per Rule 143 v4. Idea #16415.

set -euo pipefail

CHECK_ONLY=false
if [ "${1:-}" = "--check" ]; then
    CHECK_ONLY=true
fi

EXTENSIONS_DIR="$HOME/.vscode/extensions"

# Find the latest Cline extension dir (highest version)
EXT_DIR=$(ls -d "$EXTENSIONS_DIR"/saoudrizwan.claude-dev-* 2>/dev/null | sort -V | tail -1)

if [ -z "$EXT_DIR" ]; then
    echo "ERROR: No saoudrizwan.claude-dev-* extension found in $EXTENSIONS_DIR"
    exit 1
fi

EXT="$EXT_DIR/dist/extension.js"
VERSION=$(basename "$EXT_DIR" | sed 's/saoudrizwan.claude-dev-//')

echo "=== Cline YOLO Ceiling Patcher ==="
echo "Extension dir: $EXT_DIR"
echo "Version: $VERSION"
echo ""

if [ ! -f "$EXT" ]; then
    echo "ERROR: extension.js not found at $EXT"
    exit 1
fi

# Check current state using strings (fast, works on 21MB minified file)
CURRENT=$(strings "$EXT" 2>/dev/null | grep -oE 'maxConsecutiveMistakes:\{default:[0-9]+\}' | head -1)

if [ -z "$CURRENT" ]; then
    echo "WARN: Could not find maxConsecutiveMistakes pattern in extension.js"
    echo "The extension may have been refactored. Manual inspection needed."
    exit 2
fi

echo "Current setting: $CURRENT"

if echo "$CURRENT" | grep -q "default:10"; then
    echo "STATUS: Already patched (ceiling=10). No action needed."
    exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
    echo "STATUS: Needs patching (ceiling=3). Run without --check to patch."
    exit 3
fi

# Patch: default:3 → default:10
echo ""
echo "Patching default:3 → default:10..."
sed -i '.bak-pre-yolo-fix' 's/maxConsecutiveMistakes:{default:3}/maxConsecutiveMistakes:{default:10}/g' "$EXT"

# Verify
NEW=$(strings "$EXT" 2>/dev/null | grep -oE 'maxConsecutiveMistakes:\{default:[0-9]+\}' | head -1)
if echo "$NEW" | grep -q "default:10"; then
    echo "SUCCESS: Patched to $NEW"
    echo "Backup: ${EXT}.bak-pre-yolo-fix"
    echo ""
    echo "IMPORTANT: Reload VS Code (Window: Reload) for the change to take effect."
    echo "Until reload, the running extension still uses ceiling=3."
    exit 0
else
    echo "ERROR: Patch verification failed. Current: $NEW"
    echo "Backup: ${EXT}.bak-pre-yolo-fix"
    exit 4
fi
#!/usr/bin/env bash
#
# patch_mcpkeys_pr11629.sh — Re-apply Cline PR #11629 fix after extension update
#
# Root cause: Cline issue #9822 — stdio/SSE transport onerror/onclose handlers delete
# the mcpServerKeys UID mapping on every transient disconnect. When the server
# reconnects, it gets a new UID, but in-flight conversations still reference the old
# UID. Tool calls fail with "No connection found" / "Not connected".
#
# Fix (PR #11629): Remove mcpServerKeys.delete() from transport onerror/onclose
# handlers. Keep it in deleteConnection() (permanent removal) and the streamableHttp
# max-retries-exhausted path.
#
# Source: https://github.com/cline/cline/pull/11629
# Applied: 2026-07-05 for Cline 4.0.6
#
set -euo pipefail

CLINE_DIR=$(ls -d ~/.vscode/extensions/saoudrizwan.claude-dev-* 2>/dev/null | sort -V | tail -1)
CLINE_EXT="$CLINE_DIR/dist/extension.js"

if [ ! -f "$CLINE_EXT" ]; then
    echo "ERROR: Cline extension.js not found at $CLINE_EXT" >&2
    exit 1
fi

# Check if already patched
if grep -q 'void(0) /\* PR#11629 \*/' "$CLINE_EXT" 2>/dev/null; then
    echo "Already patched (PR#11629 void(0) markers found). Skipping."
    exit 0
fi

# Check if patch is needed
NEEDS_PATCH=0
for pattern in 't\.mcpServerKeys\.delete(d\.server\.uid||e)' 't\.mcpServerKeys\.delete(p\.server\.uid||e)' 't\.mcpServerKeys\.delete(A\.server\.uid||e)'; do
    if grep -q "$pattern" "$CLINE_EXT" 2>/dev/null; then
        NEEDS_PATCH=1
        break
    fi
done

if [ "$NEEDS_PATCH" = "0" ]; then
    echo "No patch needed (patterns not found — maybe already fixed upstream)."
    exit 0
fi

# Backup
cp "$CLINE_EXT" "${CLINE_EXT}.bak-pre-mcpkeys-fix-$(date +%Y%m%d)"
echo "Backup created: ${CLINE_EXT}.bak-pre-mcpkeys-fix-$(date +%Y%m%d)"

# Apply patch
sed -i '' 's/t\.mcpServerKeys\.delete(d\.server\.uid||e)/void(0) \/* PR#11629 *\//g' "$CLINE_EXT"
sed -i '' 's/t\.mcpServerKeys\.delete(p\.server\.uid||e)/void(0) \/* PR#11629 *\//g' "$CLINE_EXT"
sed -i '' 's/t\.mcpServerKeys\.delete(A\.server\.uid||e)/void(0) \/* PR#11629 *\//g' "$CLINE_EXT"

# Verify
REPLACEMENTS=$(grep -c 'void(0) /\* PR#11629 \*/' "$CLINE_EXT")
if [ "$REPLACEMENTS" -lt 3 ]; then
    echo "WARNING: Expected 3 replacements, found $REPLACEMENTS. Manual check needed." >&2
    exit 1
fi

# Syntax check
if ! node --check "$CLINE_EXT" 2>/dev/null; then
    echo "ERROR: node --check failed. Reverting." >&2
    cp "${CLINE_EXT}.bak-pre-mcpkeys-fix-$(date +%Y%m%d)" "$CLINE_EXT"
    exit 1
fi

echo "✅ PR#11629 patch applied successfully ($REPLACEMENTS replacements)."
echo "   Reload VS Code (Developer: Reload Window) to activate."
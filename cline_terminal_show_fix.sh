#!/bin/bash
# cline_terminal_show_fix.sh
#
# Patches Cline extension to STOP calling `terminal.show()` on every
# execute_command tool call. This call triggers VS Code's PaneCompositePart
# layout pass which collapses the maximized Secondary Side Bar back to
# default width — the "side bar shrinks every 10-30s during streaming"
# bug Ruben hit on 2026-05-17.
#
# Root cause confirmed by subagent literature review on same date:
#   src/integrations/terminal/CommandExecutor.ts line 116
#   `terminalInfo.terminal.show()` fires on every execute_command call,
#   which calls VS Code's TerminalService -> showPanel -> viewsService.openView
#   -> PaneCompositePart.doOpenPaneComposite, and that re-balances the
#   workbench grid (= Secondary Side Bar collapses).
#
# Patch: replace `u.terminal.show()` with `void 0` (no-op, same byte count).
# Cline still creates and runs the terminal; user can manually click into
# the terminal panel if they want to see it. Side bar stays put.
#
# Idempotent: detects already-patched state and exits clean.
# Survives Cline auto-updates because launchd re-runs it hourly against
# whatever saoudrizwan.claude-dev-* dir is newest on disk.
#
# Pattern mirrors cline_input_clear_fix.sh (see .clinerules/34).
#
# Reversal: cp <backup> back over dist/extension.js; reload Cline window.

set -uo pipefail
LOG=/tmp/cline-terminal-show-fix.log
exec >> "$LOG" 2>&1
echo "=== $(date -Iseconds) cline_terminal_show_fix.sh ==="

# Find newest installed Cline extension dir
EXT_DIR=$(ls -dt ~/.vscode/extensions/saoudrizwan.claude-dev-* 2>/dev/null | head -1)
if [ -z "$EXT_DIR" ]; then
    echo "no saoudrizwan.claude-dev-* dir found, skipping"
    exit 0
fi
BUNDLE="$EXT_DIR/dist/extension.js"
if [ ! -f "$BUNDLE" ]; then
    echo "bundle not found at $BUNDLE, skipping"
    exit 0
fi

# Buggy pattern (16 bytes) and patched no-op (16 bytes, same length so byte
# offsets don't shift). `u.terminal.show()` -> `u.terminal,void 0`
# Both expressions evaluate without error, both length 16, comma operator
# returns void 0 so the assignment-target doesn't see any value change.
OLD='u.terminal.show()'
NEW='u.terminal,void 0'

# Marker check — already patched?
if grep -q -F "$NEW" "$BUNDLE" 2>/dev/null; then
    echo "already patched, no-op"
    exit 0
fi

# Buggy pattern present?
if ! grep -q -F "$OLD" "$BUNDLE" 2>/dev/null; then
    echo "neither buggy nor patched pattern found — Cline bundling may have changed, skipping safely"
    exit 0
fi

# Backup once per (extension version + patch)
BACKUP="$BUNDLE.bak-$(date +%Y-%m-%d)-cline-terminal-show-fix"
if [ ! -f "$BACKUP" ]; then
    cp "$BUNDLE" "$BACKUP"
    echo "backed up to $BACKUP"
fi

# Apply patch (same-length replacement, perl handles binary cleanly)
perl -pi -e "s/\Q$OLD\E/$NEW/g" "$BUNDLE"

# Verify
if grep -q -F "$NEW" "$BUNDLE"; then
    echo "patched OK"
else
    echo "patch FAILED — restoring from backup"
    cp "$BACKUP" "$BUNDLE"
    exit 1
fi

echo "done"
exit 0

#!/bin/bash
# new_code_window.sh
#
# Open a fresh VS Code window in the macOS DEFAULT desktop Space, NOT in
# whatever fullscreen Space is currently active.
#
# Root cause this works around (subagent diag 2026-05-17):
#   When VS Code's frontmost window is in macOS native fullscreen, that
#   window owns a dedicated Mission Control Space. macOS + Electron forces
#   any new BrowserWindow created by the same app process into that same
#   Space, because Electron sets NSWindowCollectionBehaviorFullScreenPrimary
#   on every BrowserWindow. There is no Electron API to put a new window
#   in a different Space.
#
# The fix: bypass that by launching VS Code through `open -nF` which
# spawns a separate macOS app instance. Combined with AppleScript to
# switch the frontmost Space to the default desktop FIRST, the new
# instance lands in the regular Space, not the fullscreen one.
#
# Bind this to a hotkey via Karabiner / Raycast / Shortcuts, or just call
# it from Spotlight ("open new code") via an Automator wrapper.

set -uo pipefail

# Step 1: switch to default desktop Space (Mission Control Space 1) via
# AppleScript. This activates the non-fullscreen Space BEFORE we launch
# the new window, so macOS places it there. If the user has no Space 1
# or AppleScript permissions aren't granted, this silently no-ops and the
# script still tries the launch (worst case: new window still in fullscreen,
# same as today).
#
# The keystroke is Ctrl+1 which is the default "Switch to Desktop 1"
# shortcut in macOS System Settings → Keyboard → Keyboard Shortcuts →
# Mission Control. If the user has it remapped or disabled, this won't
# work; in that case the fallback below kicks in.
osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
    -- Try Mission Control "Switch to Desktop 1" shortcut (Ctrl+1)
    key code 18 using {control down}
end tell
APPLESCRIPT

# Tiny pause so the Space switch animation completes before launch
sleep 0.4

# Step 2: spawn a fresh VS Code instance. -n forces a new process,
# -F tells Launch Services to ignore restorable window state so we
# don't re-open whatever was last in fullscreen.
open -n -F -a "Visual Studio Code"

exit 0

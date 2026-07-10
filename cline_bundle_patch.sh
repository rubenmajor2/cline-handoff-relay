#!/bin/bash
# cline_bundle_patch.sh — re-apply EMSU Cline dist/extension.js patches
#
# Cline stores some behavior as HARDCODED values in its minified bundle, NOT in
# any settings store. Those get wiped every time the Cline extension updates.
# This script re-applies them. It is idempotent: safe to run repeatedly, only
# patches what isn't already patched.
#
# Lives in the cline-handoff-relay git repo so it syncs to every machine.
# Runs from sync.sh after each git pull (so a new bundle version gets re-patched
# within the hour), AND can be run manually after a known Cline update.
#
# The 3 patches:
#   1. YOLO mistake cap: consecutiveMistakeCount>=getGlobalSettingsKey(...) -> >=99
#      (the setting isn't reliably read from state; hardcode the cap high)
#   2. Auto-condense at 500K absolute: Math.floor(o*.75) -> 5e5 and f=Math.min(c,s) -> f=c
#      (LiteLLM router reports a deceptive contextWindow; force a true 500K floor)
#
# Source incidents:
#   2026-05-30 — Mac2 YOLO'd at 3 despite state.vscdb maxConsecutiveMistakes=99
#                (Cline reads its own proto state, not that key). Ruben directive:
#                "make sure they all align so if i change something on one machine
#                 it changes on the others."
#
# USAGE: bash cline_bundle_patch.sh   (auto-finds the installed Cline version)

set -uo pipefail
LOG=/tmp/cline-bundle-patch.log
ts(){ date -Iseconds; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG"; }

# Find the installed Cline extension bundle (highest version dir).
EXT_DIR=$(ls -d "$HOME/.vscode/extensions/saoudrizwan.claude-dev-"* 2>/dev/null | sort -V | tail -1)
if [ -z "$EXT_DIR" ]; then
  log "no Cline extension found under ~/.vscode/extensions — nothing to patch"
  exit 0
fi
EXT="$EXT_DIR/dist/extension.js"
if [ ! -f "$EXT" ]; then
  log "bundle not found at $EXT"
  exit 0
fi

CHANGED=0

# --- Patch 1: YOLO mistake cap -> 99 ---
if grep -q -F 'consecutiveMistakeCount>=this.stateManager.getGlobalSettingsKey("maxConsecutiveMistakes")' "$EXT"; then
  cp "$EXT" "$EXT.bak-bundlepatch-$(date +%Y%m%d-%H%M%S)"
  perl -i -pe 's/consecutiveMistakeCount>=this\.stateManager\.getGlobalSettingsKey\("maxConsecutiveMistakes"\)/consecutiveMistakeCount>=99/g' "$EXT"
  log "patched YOLO mistake cap -> >=99"
  CHANGED=1
elif grep -q -F 'consecutiveMistakeCount>=99' "$EXT"; then
  log "YOLO cap already patched (>=99)"
else
  log "WARN: YOLO cap pattern not found — Cline bundle shape may have changed, review manually"
fi

# --- Patch 2: auto-condense at 500K absolute ---
if grep -q -F 'Math.floor(o*.75)' "$EXT"; then
  [ "$CHANGED" = "1" ] || cp "$EXT" "$EXT.bak-bundlepatch-$(date +%Y%m%d-%H%M%S)"
  perl -i -pe 's/Math\.floor\(o\*\.75\)/5e5/g; s/c=5e5,f=Math\.min\(c,s\)/c=5e5,f=c/g' "$EXT"
  log "patched auto-condense -> 500K absolute (c=5e5,f=c)"
  CHANGED=1
elif grep -q -F 'c=5e5,f=c' "$EXT"; then
  log "auto-condense already patched (500K absolute)"
else
  log "WARN: auto-condense pattern not found — review manually"
fi

if [ "$CHANGED" = "1" ]; then
  log "bundle patched at $EXT — restart VS Code to load (osascript quit + open)"
else
  log "no changes needed"
fi
exit 0

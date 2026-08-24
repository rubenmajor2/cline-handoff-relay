#!/usr/bin/env bash
#
# patch_cline_extension.sh — Durable, version-agnostic Cline extension patcher
#
# Applies TWO critical patches to Cline's extension.js that get WIPED on every
# VS Code auto-update (confirmed 2026-07-09: 4.0.6→4.0.7 wiped both):
#
#   1. stdio MCP auto-reconnect — Cline's default onclose handler sets
#      status="disconnected", DELETES the MCP server keys, and NEVER reconnects.
#      When a stdio MCP process dies (crash/OOM/pipe-close), it stays dead
#      forever in that window. This patch adds a 5-second delayed auto-reconnect
#      and preserves the keys so reconnection can succeed.
#
#   2. YOLO ceiling — maxConsecutiveMistakes hardcoded as {default:3} in the
#      extension source (NOT exposed in UI). 3 consecutive mistakes = YOLO death.
#      Patched to {default:10} per rule 143 v4 (bail at strike 9 = ceiling-1).
#
# AUTO-DETECTS the active extension version (not pinned to a specific version).
# Idempotent. Creates timestamped backups. Verifies JS syntax after patching.
#
# Designed to be called by:
#   - Manual run after updates
#   - launchd watchdog (com.emsu.cline-extension-patch-watchdog) on extension
#     dir changes + every 5 min safety net
#
# Created 2026-07-09: durable fix for recurring MCP shutdowns.
# Supersedes: patch_stdio_reconnect.sh (pinned to 4.0.6), patch_yolo_ceiling.sh
#
# Usage: patch_cline_extension.sh [--quiet]
# Exit: 0 = patches present (applied or already there), 1 = error/partial

set -uo pipefail

QUIET="${1:-}"
LOG="/tmp/cline-extension-patch.log"
ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; [ "$QUIET" != "--quiet" ] && echo "$*"; }

# --- Find the active extension (newest version dir) ---
EXT_DIR=$(ls -dt "$HOME/.vscode/extensions/saoudrizwan.claude-dev-"* 2>/dev/null | head -1)
if [ -z "$EXT_DIR" ] || [ ! -f "$EXT_DIR/dist/extension.js" ]; then
    log "ERROR: No Cline extension found under ~/.vscode/extensions/"
    exit 1
fi
EXT_JS="$EXT_DIR/dist/extension.js"
VERSION=$(basename "$EXT_DIR" | sed 's/saoudrizwan.claude-dev-//')
log "Active extension: Cline v$VERSION"

# --- Check if already patched ---
RECONNECT_PATCHED=0
YOLO_PATCHED=0
TASKPROGRESS_PATCHED=0
grep -q 'Auto-reconnected stdio MCP' "$EXT_JS" 2>/dev/null && RECONNECT_PATCHED=1
grep -q 'maxConsecutiveMistakes:{default:10}' "$EXT_JS" 2>/dev/null && YOLO_PATCHED=1
grep -q 'recommended:""' "$EXT_JS" 2>/dev/null && TASKPROGRESS_PATCHED=1

if [ "$RECONNECT_PATCHED" = "1" ] && [ "$YOLO_PATCHED" = "1" ] && [ "$TASKPROGRESS_PATCHED" = "1" ]; then
    log "All three patches already present in v$VERSION. Nothing to do."
    exit 0
fi

# --- Backup ---
BACKUP="${EXT_JS}.bak-pre-durable-patch-$(date +%Y%m%d-%H%M%S)"
cp "$EXT_JS" "$BACKUP"
log "Backup: $BACKUP"

# --- Apply patches via Python (handles special chars in minified JS safely) ---
PATCH_OUT=$(python3 - "$EXT_JS" <<'PYEOF'
import sys

path = sys.argv[1]
s = open(path, 'r', encoding='utf-8').read()
original = s
changes = []

# --- Patch 1: stdio MCP auto-reconnect ---
RECONNECT_MARKER = 'Auto-reconnected stdio MCP'
if RECONNECT_MARKER not in s:
    # The replacement handler: preserves keys, adds 5s delayed auto-reconnect
    new_handler = (
        'u.onclose=async()=>{let p=this.findConnection(e,n);if(p){'
        'p.server.status="disconnected",void(0) /* PR#11629 keep keys for reconnect */;'
        'setTimeout(async()=>{try{let s=JSON.parse(p.server.config);'
        'if(s.type==="stdio"){p.server.status="connecting",'
        'await this.notifyWebviewOfServerChanges(),'
        'await this.deleteConnection(e,n),'
        'await this.connectToServer(e,s,"internal"),'
        'be.log(`Auto-reconnected stdio MCP: ${e}`)}}'
        'catch(r){be.error(`Auto-reconnect failed for ${e}:`,r)}},5000)}'
        'await this.notifyWebviewOfServerChanges()}'
    )

    # Pattern A (4.0.7+): deletes keys on close (worst — makes reconnect impossible)
    old_407 = (
        'u.onclose=async()=>{let p=this.findConnection(e,n);'
        'p&&(p.server.status="disconnected",'
        't.mcpServerKeys.delete(p.server.uid||e)),'
        'await this.notifyWebviewOfServerChanges()}'
    )
    # Pattern B (4.0.6 post-#11629): keeps keys but no reconnect
    old_406 = (
        'u.onclose=async()=>{let p=this.findConnection(e,n);'
        'p&&(p.server.status="disconnected",void(0) /* PR#11629 */),'
        'await this.notifyWebviewOfServerChanges()}'
    )
    # Pattern C (pre-#11629): deletes keys differently
    old_pre = (
        'u.onclose=async()=>{let p=this.findConnection(e,n);'
        'p&&(p.server.status="disconnected",'
        't.mcpServerKeys.delete(p.server.uid||e),'
        't.mcpServerKeys.delete(e)),'
        'await this.notifyWebviewOfServerChanges()}'
    )

    if old_407 in s:
        s = s.replace(old_407, new_handler, 1)
        changes.append("Patch 1 (reconnect): applied to 4.0.7+ pattern (key-deletion removed)")
    elif old_406 in s:
        s = s.replace(old_406, new_handler, 1)
        changes.append("Patch 1 (reconnect): applied to 4.0.6 pattern")
    elif old_pre in s:
        s = s.replace(old_pre, new_handler, 1)
        changes.append("Patch 1 (reconnect): applied to pre-#11629 pattern")
    else:
        changes.append("Patch 1 (reconnect): WARNING - no known onclose pattern found, skipping")

# --- Patch 2: YOLO ceiling 3 → 10 ---
if 'maxConsecutiveMistakes:{default:10}' not in s:
    old_yolo = 'maxConsecutiveMistakes:{default:3}'
    new_yolo = 'maxConsecutiveMistakes:{default:10}'
    if old_yolo in s:
        s = s.replace(old_yolo, new_yolo, 1)
        changes.append("Patch 2 (YOLO ceiling): default:3 → default:10 applied")
    else:
        changes.append("Patch 2 (YOLO ceiling): WARNING - pattern not found (maybe already 10 or renamed), skipping")

# --- Patch 3: blank the task_progress reminder template map ---
# The extension auto-injects a "# task_progress RECOMMENDED" TODO-list block into
# the NEXT user message whenever a tool call omits the task_progress param
# (injector: apiRequestCount<10 ? Mhe.recommended : Mhe.apiRequestCount.replace(...)).
# No settings toggle gates it. Blanking all six map entries stops every variant.
#
# Idea #28114: the map identifier ("Mhe" on 4.0.7) is MINIFIER-GENERATED and can be
# renamed by any future build. So this patch runs in two stages:
#   Stage A — rename-resilient map match: find ANY `<ident>={initial:...reminder:...
#             recommended:...}` shape rather than hardcoding "Mhe".
#   Stage B — literal fallback: if Stage A misses (map restructured entirely), blank
#             the template BODIES by their literal text, which survives renames since
#             the injected strings themselves are what the user sees.
# A WARNING is emitted (and logged) whenever Stage A misses, so a silent regression
# is impossible.
import re as _re

_P3_SENTINEL = 'recommended:""'
if _P3_SENTINEL not in s:
    stage_a_hit = False

    # Stage A: match the map by SHAPE, not by identifier name.
    _map_re = _re.compile(
        r'([A-Za-z_$][A-Za-z0-9_$]*)=\{initial:[^{}]*?reminder:[^{}]*?recommended:[^{}]*?\}'
    )
    m_map = _map_re.search(s)
    if m_map:
        ident = m_map.group(1)
        new_map = (
            ident + '={initial:"",reminder:"",recommended:"",'
            'planModeReminder:"",completed:"",apiRequestCount:""}'
        )
        s = s.replace(m_map.group(0), new_map, 1)
        stage_a_hit = True
        changes.append(
            "Patch 3A (task_progress suppression): template map '%s' blanked by shape-match" % ident
        )
    else:
        changes.append(
            "Patch 3A (task_progress suppression): WARNING - no {initial:,reminder:,recommended:} "
            "map shape found (identifier renamed or map restructured). Falling back to Stage B."
        )

    # Stage B: blank the template BODIES by literal text. Runs when Stage A misses, and
    # also as a belt-and-braces sweep for any reachable literal left behind.
    _literal_markers = [
        '# task_progress RECOMMENDED',
        '# TODO LIST UPDATE REQUIRED - You MUST include the task_progress parameter in your NEXT tool call.',
        '# TODO LIST UPDATE REQUIRED',
    ]
    leftovers = [lit for lit in _literal_markers if lit in s]

    if leftovers and not stage_a_hit:
        # Blank each backtick-template whose body contains a leftover marker.
        for lit in leftovers:
            idx = s.find(lit)
            while idx != -1:
                start = s.rfind('`', 0, idx)
                end = s.find('`', idx)
                if start != -1 and end != -1 and (end - start) < 4000:
                    s = s[:start] + '``' + s[end + 1:]
                    changes.append(
                        "Patch 3B (task_progress suppression): blanked template body containing %r" % lit[:40]
                    )
                else:
                    break
                idx = s.find(lit)
        changes.append(
            "Patch 3B (task_progress suppression): WARNING - Stage A missed; literal-body "
            "fallback applied. Inspect the extension for a restructured injector."
        )
    elif leftovers and stage_a_hit:
        # Expected: the dead template literals remain in the bundle but are only reachable
        # through the now-blanked map. Informational, not a failure.
        changes.append(
            "Patch 3 (task_progress suppression): note - %d template literal(s) still present "
            "in bundle but unreachable (map blanked)." % len(leftovers)
        )

for c in changes:
    print(c)

# Emit a machine-greppable status line so the shell wrapper can log WARNINGs.
if any('WARNING' in c for c in changes):
    print("PATCHER_STATUS=WARNING")
else:
    print("PATCHER_STATUS=CLEAN")

if s != original:
    open(path, 'w', encoding='utf-8').write(s)
    print("Patches written to disk")
else:
    print("No changes made (all patches already present or patterns not found)")
PYEOF
)
PY_RC=$?
echo "$PATCH_OUT"

# --- Log every WARNING line from the patcher (idea #28114) ---
while IFS= read -r _line; do
    case "$_line" in
        *WARNING*) log "PATCHER WARNING: $_line" ;;
    esac
done <<< "$PATCH_OUT"

if echo "$PATCH_OUT" | grep -q 'PATCHER_STATUS=WARNING'; then
    log "WARNING: patcher reported a degraded match. Cline may have renamed the reminder-template map. Review the WARNING lines above."
    osascript -e "display notification \"Cline patcher hit a WARNING on v$VERSION. Check /tmp/cline-extension-patch.log\" with title \"Cline Extension Patcher\" sound name \"Basso\"" 2>/dev/null
fi
if [ "$PY_RC" -ne 0 ]; then
    log "ERROR: Python patcher exited $PY_RC. Restoring backup."
    cp "$BACKUP" "$EXT_JS"
    exit 1
fi

# --- Verify JS syntax ---
if ! node --check "$EXT_JS" 2>/dev/null; then
    log "ERROR: JS syntax check failed. Restoring backup."
    cp "$BACKUP" "$EXT_JS"
    exit 1
fi
log "JS syntax check: OK"

# --- Verify markers ---
RECONNECT_OK=0
YOLO_OK=0
TASKPROGRESS_OK=0
grep -q 'Auto-reconnected stdio MCP' "$EXT_JS" && RECONNECT_OK=1
grep -q 'maxConsecutiveMistakes:{default:10}' "$EXT_JS" && YOLO_OK=1
grep -q 'recommended:""' "$EXT_JS" && TASKPROGRESS_OK=1

log "Verification: reconnect=$RECONNECT_OK yolo=$YOLO_OK task_progress=$TASKPROGRESS_OK"

if [ "$RECONNECT_OK" = "1" ] && [ "$YOLO_OK" = "1" ] && [ "$TASKPROGRESS_OK" = "1" ]; then
    log "SUCCESS: All three patches applied to Cline v$VERSION"
    log "ACTION NEEDED: RELOAD VS CODE (Cmd+Shift+P → Developer: Reload Window)"
    osascript -e "display notification \"Patches applied to Cline v$VERSION. RELOAD VS CODE now: Cmd+Shift+P → Reload Window\" with title \"Cline Extension Patcher\" sound name \"Glass\"" 2>/dev/null
    exit 0
elif [ "$RECONNECT_PATCHED" = "0" ] || [ "$YOLO_PATCHED" = "0" ] || [ "$TASKPROGRESS_PATCHED" = "0" ]; then
    log "PARTIAL/FAIL: Some patches did not apply. Check /tmp/cline-extension-patch.log"
    osascript -e "display notification \"Partial patch on Cline v$VERSION. Check log.\" with title \"Cline Extension Patcher\" sound name \"Basso\"" 2>/dev/null
    exit 1
fi

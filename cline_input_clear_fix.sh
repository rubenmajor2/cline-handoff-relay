#!/bin/bash
# cline_input_clear_fix.sh
#
# Re-applies the chat-input-clear bug fix to whatever Cline version is
# currently installed at ~/.vscode/extensions/saoudrizwan.claude-dev-*.
# Cline auto-updates blow away the patch, so launchd runs this hourly.
#
# Source bug: webview useEffect on (api_req_started + command_output) calls
#   setInputValue("") in the middle of the user's typing. Affects 3.82.0 and
#   probably earlier. Open upstream issues #5160, #8248, #9141, #9453 — all
#   unfixed as of 3.82.0 (latest).
#
# What we do: remove ONLY `r.setInputValue("")` from that one expression.
# The image/file clears (`setSelectedImages([])`, `setSelectedFiles([])`)
# stay because those ARE supposed to clear after a real send.
#
# Idempotent: if the buggy pattern isn't found, we assume already-patched
# (or upstream finally fixed it) and exit clean.
#
# 2026-05-08 — initial. See .clinerules/31-cline-input-clear-fix.md.

set -uo pipefail

LOG=/tmp/cline-input-clear-fix.log
ts() { date '+%Y-%m-%d %H:%M:%S %Z'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG" >&2; }

# Find the newest installed Cline.
CLINE_DIR=$(ls -td ~/.vscode/extensions/saoudrizwan.claude-dev-*/ 2>/dev/null | head -1)
if [[ -z "$CLINE_DIR" ]]; then
    log "no Cline extension found — nothing to patch"
    exit 0
fi
WEBVIEW="${CLINE_DIR%/}/webview-ui/build/assets/index.js"
if [[ ! -f "$WEBVIEW" ]]; then
    log "webview bundle not found at $WEBVIEW — Cline layout changed?"
    exit 0
fi

# Buggy pattern (3.82.0 minified shape). If upstream changes the bundling
# this no-ops, which is the right behavior — better silent skip than wrong patch.
OLD='(r.setInputValue(""),r.setSelectedImages([]),r.setSelectedFiles([]))'
NEW='(r.setSelectedImages([]),r.setSelectedFiles([]))'

if ! grep -qF "$OLD" "$WEBVIEW"; then
    if grep -qF "$NEW" "$WEBVIEW"; then
        log "already patched: $WEBVIEW"
    else
        log "buggy pattern NOT found and no patched marker — Cline bundling changed, skipping"
    fi
    exit 0
fi

# Patch with python (handles byte-exact replacement, no shell quoting risk).
python3 - "$WEBVIEW" "$OLD" "$NEW" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(path, "rb").read()
ob = old.encode("utf-8"); nb = new.encode("utf-8")
n = data.count(ob)
if n != 1:
    print(f"ABORT — expected exactly 1 match, found {n}", file=sys.stderr)
    sys.exit(1)
backup = path + ".bak-" + __import__("time").strftime("%Y-%m-%d-%H%M%S") + "-cline-input-clear-fix"
open(backup, "wb").write(data)
open(path, "wb").write(data.replace(ob, nb))
print(f"patched {path} ({len(data)} -> {len(data)-len(ob)+len(nb)} bytes)")
print(f"backup: {backup}")
PY
RC=$?
if [[ $RC -eq 0 ]]; then
    log "patched $WEBVIEW"
else
    log "patch failed rc=$RC"
fi
exit 0

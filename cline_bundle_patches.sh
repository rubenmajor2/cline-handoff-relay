#!/bin/bash
# cline_bundle_patches.sh — self-heal for dist/extension.js patches
# Applies YOLO-prevention patches to the Cline extension host bundle.
# Run by launchd hourly (com.ruben.cline-bundle-patches.plist).
# Survives Cline auto-updates by re-detecting the latest extension dir.
# Rules: .clinerules/34 (webview patch pattern), .clinerules/41 (post-deploy)
# Source incident: 2026-05-12 idea #3385 (no-tool-use cascade) + #3386 (path gate)

set -uo pipefail
LOG=/tmp/cline-bundle-patches.log

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*" >> "$LOG"; }

EXT_DIR=$(ls -d ~/.vscode/extensions/saoudrizwan.claude-dev-*/dist/ 2>/dev/null | sort -V | tail -1)
if [ -z "$EXT_DIR" ]; then
    log "No Cline extension found, skipping"
    exit 0
fi

EXT="$EXT_DIR/extension.js"
if [ ! -f "$EXT" ]; then
    log "extension.js not found at $EXT, skipping"
    exit 0
fi

python3 - "$EXT" << 'PYEOF'
import sys, hashlib, os

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

sha_before = hashlib.sha256(content.encode()).hexdigest()[:16]
changes = 0
already = 0

# PATCH 1 (#3385): Forceful no-tool-use re-prompt to break timeout cascade
old1 = '[ERROR] You did not use a tool in your previous response! Please retry with a tool use.'
new1 = '[ERROR] You did not use a tool in your previous response! You MUST call a tool NOW. Do NOT write prose. If a command timed out, immediately call attempt_completion OR switch to a different tool. Writing prose instead of calling a tool will kill this task.'
sentinel1 = 'You MUST call a tool NOW.'

if sentinel1 in content:
    already += 1
elif old1 in content:
    content = content.replace(old1, new1, 1)
    changes += 1
    print(f'PATCH 1 (noToolsUsed): applied')
else:
    print(f'PATCH 1: MISS (text changed in new version?)')

# PATCH 2 (#3386): Server path prefix gate before file write
old2 = 'this.relPath=r?.displayPath??e;let s=this.editType==="modify";'
new2 = ('this.relPath=r?.displayPath??e;'
        'if(this.absolutePath&&/^\\/(var|etc|opt|usr|sys|proc)\\//.test(this.absolutePath))'
        'throw new Error("SERVER PATH BLOCKED: "+this.absolutePath+" — use emsu-operations SSH/MCP. '
        'write_to_file only works on local Mac paths.");'
        'let s=this.editType==="modify";')
sentinel2 = 'SERVER PATH BLOCKED'

if sentinel2 in content:
    already += 1
elif old2 in content:
    content = content.replace(old2, new2, 1)
    changes += 1
    print(f'PATCH 2 (path gate): applied')
else:
    print(f'PATCH 2: MISS (text changed in new version?)')

if changes > 0:
    with open(path, 'w') as f:
        f.write(content)
    sha_after = hashlib.sha256(content.encode()).hexdigest()[:16]
    print(f'Written. sha before={sha_before} after={sha_after} new_changes={changes} already_applied={already}')
elif already > 0:
    print(f'All patches already applied (already={already})')
else:
    print(f'No patches applied and no sentinels found — Cline may have updated, manual review needed')
PYEOF

log "cline_bundle_patches.sh complete for $EXT"

# 2026-05-29 — neuter YOLO kill branch (Opus 4.8 529 bursts were tripping tasks dead).
# Re-key the kill condition to a nonexistent setting so it never fires; task pauses+asks instead.
for EXT in "$HOME"/.vscode/extensions/saoudrizwan.claude-dev-*/dist/extension.js; do
  [ -f "$EXT" ] || continue
  if grep -q 'getGlobalSettingsKey("yoloModeToggled")){let T=' "$EXT"; then
    cp "$EXT" "$EXT.bak-yolo-neuter-$(date +%Y%m%d%H%M%S)"
    sed -i '' 's/getGlobalSettingsKey("yoloModeToggled")){let T=/getGlobalSettingsKey("__yoloDisabledByRuben__")){let T=/' "$EXT"
    echo "[bundle-patches] neutered YOLO kill branch in $EXT"
  fi
done

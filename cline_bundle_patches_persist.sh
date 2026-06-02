#!/bin/bash
# cline_bundle_patches_persist.sh
#
# Re-applies the family of Cline bundle patches after any Cline auto-update.
# Cline 3.82+ auto-updates wipe the extension dir, losing all our patches.
# This script runs hourly via launchd and reapplies whatever is missing.
#
# Patches managed (as of 2026-05-12):
#   1. INPUT_CLEAR_FIX     — webview, kills setInputValue("") mid-typing
#       (see also: ~/Documents/Cline/cline_input_clear_fix.sh, .clinerules/34)
#   2. SUBAGENT_MODEL_PICKER — dist/extension.js, adds prompt_N_model param
#       (see: subagent-model-picker.md)
#   3. SUBAGENT_MODEL_PARSER — webview parser, adds model field to items
#       (marker /*SAM26*/, see: .clinerules/53)
#   4. SUBAGENT_MODEL_BADGE  — webview renderer, displays [haiku-4-5] badge
#       (marker /*SAMR26*/, see: .clinerules/53)
#
# Idempotent: each patch checks for its own marker before applying.
# Reversible: backups at <bundle>.bak-pre-<patchname>-<date>.
#
# 2026-05-12 — initial. Source: cline_7b-phase3-analysis session.

set -uo pipefail

LOG=/tmp/cline-bundle-patches-persist.log
ts() { date '+%Y-%m-%d %H:%M:%S %Z'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG" >&2; }

# Find the newest Cline install.
EXT_DIR=$(ls -td ~/.vscode/extensions/saoudrizwan.claude-dev-* 2>/dev/null | head -1)
if [[ -z "$EXT_DIR" ]]; then
    log "no Cline install found, exit"
    exit 0
fi

DIST="$EXT_DIR/dist/extension.js"
WEBVIEW="$EXT_DIR/webview-ui/build/assets/index.js"

if [[ ! -f "$DIST" ]] || [[ ! -f "$WEBVIEW" ]]; then
    log "missing dist or webview bundle at $EXT_DIR — Cline install incomplete?"
    exit 0
fi

log "checking patches in $EXT_DIR"

# ── PATCH 1: input-clear-fix ────────────────────────────────────
# Defer to the existing dedicated script (already handles this).
if [[ -x ~/Documents/Cline/cline_input_clear_fix.sh ]]; then
    bash ~/Documents/Cline/cline_input_clear_fix.sh >> "$LOG" 2>&1 || true
fi

# ── PATCH 2: subagent_model_picker (in dist/extension.js) ────────
# Marker: presence of "prompt_1_model" in the bundle.
if grep -q "prompt_1_model" "$DIST" 2>/dev/null; then
    log "patch2 (model_picker): present"
else
    log "patch2 (model_picker): MISSING — need to re-apply manually (no template script yet)"
    # TODO: ship a re-apply script when we have a known-good diff captured.
    # For now, log and continue. The .bak file at .bak-pre-model-picker-* lets us
    # diff and re-create the patch if needed.
fi

# ── PATCH 3: subagent_model_parser (webview) ───────────────────
# Marker: /*SAM26*/
if grep -q "SAM26" "$WEBVIEW" 2>/dev/null; then
    log "patch3 (model_parser): present"
else
    log "patch3 (model_parser): MISSING — re-applying..."
    if [[ -x /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_model_badge.py ]] || [[ -f /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_model_badge.py ]]; then
        python3 /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_model_badge.py >> "$LOG" 2>&1 || \
            log "patch3 re-apply FAILED"
    else
        log "patch3 re-apply script /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_model_badge.py not found"
    fi
fi

# ── PATCH 4: subagent_model_badge (webview renderer) ────────────
# Marker: /*SAMR26*/
if grep -q "SAMR26" "$WEBVIEW" 2>/dev/null; then
    log "patch4 (model_badge): present"
else
    log "patch4 (model_badge): MISSING — re-applying..."
    if [[ -f /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_renderer.py ]]; then
        python3 /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_renderer.py >> "$LOG" 2>&1 || \
            log "patch4 re-apply FAILED"
    else
        log "patch4 re-apply script not found"
    fi
fi

# ── PATCH 5: subagent_provider_aware (dist/extension.js) ────────
# Marker: /*SAP26*/ — enables router: prefix on prompt_N_model for 7B-LoRA
if grep -q "SAP26" "$DIST" 2>/dev/null; then
    log "patch5 (provider_aware): present"
else
    log "patch5 (provider_aware): MISSING — re-applying..."
    if [[ -f /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_provider_aware.py ]]; then
        python3 /Users/rubenmajor/Documents/Cline/bundle_patches/patch_subagent_provider_aware.py >> "$LOG" 2>&1 || \
            log "patch5 re-apply FAILED"
    else
        log "patch5 re-apply script not found"
    fi
fi

# ── PATCH 6: mistake-limit respects setting (dist/extension.js) ──
# Root cause of the 2026-05-31 $67 YOLO burn: the bundle shipped (or a prior
# patch left) a HARDCODED `consecutiveMistakeCount>=99` that ignored the user's
# maxConsecutiveMistakes setting. A prose-without-tool loop then ran 99 strikes
# (~$67) instead of obeying the =3 cap. This restores the setting-driven read so
# cline_settings.json actually governs the limit. See cline_task_ledger 2026-05-31.
SETTING_READ='consecutiveMistakeCount>=this.stateManager.getGlobalSettingsKey("maxConsecutiveMistakes")'
if grep -qF "$SETTING_READ" "$DIST" 2>/dev/null; then
    log "patch6 (mistake-limit-respects-setting): present"
else
    log "patch6 (mistake-limit-respects-setting): MISSING — re-applying..."
    cp "$DIST" "$DIST.bak-pre-mistakelimit-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    python3 - "$DIST" >> "$LOG" 2>&1 <<'PYEOF' || log "patch6 re-apply FAILED"
import sys,re
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
setting='consecutiveMistakeCount>=this.stateManager.getGlobalSettingsKey("maxConsecutiveMistakes")'
# replace any hardcoded numeric threshold (e.g. >=99 or >=3) with the setting read
s2=re.sub(r'consecutiveMistakeCount>=\d+', setting, s, count=1)
if s2!=s and s2.count(setting)>=1:
    open(p,"w",encoding="utf-8").write(s2); print("patch6 applied: hardcoded threshold -> setting-driven")
else:
    print("patch6: no hardcoded numeric threshold found (already setting-driven or shape changed)")
PYEOF
fi

# ── PATCH 7: YOLO auto-recover (no hard "Task failed" death) ─────
# Ruben 2026-05-31 "I just don't want any yolos" (without disabling auto-approve).
# Converts the YOLO-mode mistake-limit KILL into a bounded auto-recovery: reset the
# counter + inject a firm "emit a tool now" steer, up to 8 reprieves, then stop with a
# cost-cap message. Transient no-tool blips self-recover (no YOLO shown); a hopeless
# task still stops so it can't burn unbounded. Patcher: ~/.cline-tools/patch_yolo_autorecover.py
if grep -qF "yoloReprieves" "$DIST" 2>/dev/null; then
    log "patch7 (yolo-autorecover): present"
else
    log "patch7 (yolo-autorecover): MISSING — re-applying..."
    if [[ -f /Users/rubenmajor/.cline-tools/patch_yolo_autorecover.py ]]; then
        python3 /Users/rubenmajor/.cline-tools/patch_yolo_autorecover.py >> "$LOG" 2>&1 || log "patch7 re-apply FAILED"
    else
        log "patch7 re-apply script ~/.cline-tools/patch_yolo_autorecover.py not found"
    fi
fi

log "done"
exit 0

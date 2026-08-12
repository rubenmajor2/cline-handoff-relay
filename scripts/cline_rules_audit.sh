#!/usr/bin/env bash
#
# cline_rules_audit.sh -- Rules-system integrity auditor + real-time lint
#
# Checks ~/Documents/Cline/Rules/ + Rules-archive/ for:
#   L0  per-file pre-write lint (G1-G7) on every .md in Rules/  [real-time write filter]
#   A1  file count in Rules/ (hardfloor + meta cap)
#   A2  per-rule size (G7 hard caps: hardfloor >12KB block, meta >20KB block)
#   A3  total Rules/ directory size
#   A4  HARDFLOOR_SLUGS drift — any .md in Rules/ that is neither in HARDFLOOR_SLUGS nor META_FILES
#   A5  rule-number collisions — duplicate NNN- prefixes in Rules-archive/
#   A6  counter drift — .clinerule_counter vs highest actual rule number in archive
#
# Runs nightly at 3:15 AM PT via launchd (com.emsu.cline-rules-audit) AND is
# invoked by the same plist's WatchPaths on every Rules/ save. Posts alerts to:
#   - /tmp/cline_rules_audit.log (always)
#   - macOS notification (on alert, unless --quiet)
#
# Exit 0 always (advisory alerts, never hard-fail the cron). Per _INDEX.md.
#
# Usage: cline_rules_audit.sh [--quiet]   (--quiet = log only, no notification)

set -uo pipefail

RULES_DIR="$HOME/Documents/Cline/Rules"
ARCHIVE_DIR="$HOME/Documents/Cline/Rules-archive"
COUNTER_FILE="$RULES_DIR/.clinerule_counter"
LOG="/tmp/cline_rules_audit.log"
QUIET="${1:-}"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')

# ----------------------------------------------------------------------
# HARDFLOOR_SLUGS + META_FILES — READ FROM THE GENERATED MANIFEST (idea #25151)
# ----------------------------------------------------------------------
# 2026-08-08 RCA: this script used to carry its OWN hardcoded copy of the list,
# the FOURTH copy alongside clinerules-mcp/src/index.ts, .pre-write-lint.sh, and
# the Rules/ dir itself. Its copy was the stalest (10 rules while 20 were on disk),
# so A4 "drift" fired on legitimate hardfloor rules as false positives while the
# REAL divergence (the MCP registry reporting 9 hardfloor rules) went undetected
# for ~2 weeks. An auditor holding its own stale copy of the thing it audits can
# only ever compare the directory to itself. It now reads the same manifest every
# other consumer reads, and A7 below does the actual cross-source comparison.
MANIFEST="${RULES_DIR}/.hardfloor-manifest"
SYNC_SCRIPT="$HOME/Documents/Cline/scripts/sync_hardfloor_manifest.sh"
[ -x "$SYNC_SCRIPT" ] && "$SYNC_SCRIPT" --quiet >/dev/null 2>&1

read_manifest_section() {
    [ -f "$MANIFEST" ] || return 0
    awk -v want="[$1]" '
        /^\[/ { insec = ($0 == want); next }
        insec && NF && $0 !~ /^#/ { print }
    ' "$MANIFEST"
}

HARDFLOOR_SLUGS=()
while IFS= read -r line; do [ -n "$line" ] && HARDFLOOR_SLUGS+=("$line"); done < <(read_manifest_section hardfloor)
META_FILES=()
while IFS= read -r line; do [ -n "$line" ] && META_FILES+=("$line"); done < <(read_manifest_section meta)


ALERTS=()

log()  { echo "[${TIMESTAMP}] $*" >> "$LOG"; }
warn() { log "WARN: $*"; echo "WARN: $*" >&2; }
note() { log "NOTE: $*"; }

log "=== Rules integrity audit ==="

# --- L0 per-file pre-write lint (real-time write filter) ---
# On every WatchPaths fire, lint every .md in Rules/ so broken/colliding/oversized
# rules are caught the moment they land (not just drift-detected by A1-A6 below).
LINT="$RULES_DIR/.pre-write-lint.sh"
if [ -f "$LINT" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        case "$f" in
            *.md) /bin/bash "$LINT" "$f" >>"$LOG" 2>&1 || true ;;
        esac
    done < <(ls "$RULES_DIR"/*.md 2>/dev/null)
fi

# --- A1 file count (expected count derived from the manifest, not a stale constant) ---
MD_COUNT=$(ls "$RULES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
EXPECTED_COUNT=$(( ${#HARDFLOOR_SLUGS[@]} + ${#META_FILES[@]} ))
note "A1 file-count: ${MD_COUNT} .md files in Rules/ (manifest expects ${EXPECTED_COUNT})"
if [ "$MD_COUNT" -ne "$EXPECTED_COUNT" ]; then
    ALERTS+=("A1 file-count: ${MD_COUNT} .md files in Rules/ but manifest lists ${EXPECTED_COUNT}. Re-run sync_hardfloor_manifest.sh.")
fi

# --- A2 per-rule size (G7) ---
while IFS= read -r f; do
    [ -f "$f" ] || continue
    slug=$(basename "$f" .md)
    bytes=$(wc -c < "$f" | tr -d ' ')
    is_hf=0; is_meta=0
    for hf in "${HARDFLOOR_SLUGS[@]}"; do [ "$slug" = "$hf" ] && is_hf=1; done
    for mf in "${META_FILES[@]}"; do [ "$slug" = "$mf" ] && is_meta=1; done
    if [ "$is_hf" = "1" ] && [ "$bytes" -gt 12288 ]; then
        ALERTS+=("A2 G7 hard-size-cap: hardfloor rule $slug is ${bytes} bytes (>12KB)")
    elif [ "$is_meta" = "1" ] && [ "$bytes" -gt 20480 ]; then
        ALERTS+=("A2 G7 hard-size-cap: meta file $slug is ${bytes} bytes (>20KB)")
    fi
done < <(ls "$RULES_DIR"/*.md 2>/dev/null)

# --- A3 floor total (aligned to the ENFORCED G8 gate, and counting what LOADS) ---
# Was: du -sk with a 250KB threshold that matched nothing the lint gate enforces,
# and du counts the whole dir including dotfiles. G8 blocks at 153600 bytes of
# non-dotfile content. An auditor whose thresholds disagree with the enforced gate
# reports "clean" while writes are being rejected. These now match exactly.
TOTAL_KB=$(du -sk "$RULES_DIR" 2>/dev/null | cut -f1)
FLOOR_BYTES=$(find "$RULES_DIR" -maxdepth 1 -type f ! -name '.*' -exec cat {} \; | wc -c | tr -d ' ')
# 2026-08-12: the audit previously hardcoded 153600, diverging from .pre-write-lint.sh
# which reads the .g8-floor-cap override (default 160000). An auditor that ignores the
# override false-alerts every night after Ruben raises the cap. Match the lint gate.
G8_CAP=160000
[ -f "$RULES_DIR/.g8-floor-cap" ] && G8_CAP=$(tr -dc '0-9' < "$RULES_DIR/.g8-floor-cap")
G8_WARN=$(( G8_CAP * 85 / 100 ))
note "A3 floor-total: ${FLOOR_BYTES} bytes always-loaded (G8 warn ${G8_WARN}, block ${G8_CAP})"
if [ "${FLOOR_BYTES:-0}" -gt "${G8_CAP}" ]; then
    ALERTS+=("A3 floor-total: Rules/ is ${FLOOR_BYTES} bytes, PAST the G8 hard block of ${G8_CAP}. Rules/ writes are being REJECTED right now.")
elif [ "${FLOOR_BYTES:-0}" -gt "${G8_WARN}" ]; then
    ALERTS+=("A3 floor-total: Rules/ is ${FLOOR_BYTES} bytes (G8 warn ${G8_WARN}). Trim soon.")
fi
STRAY=$(find "$RULES_DIR" -maxdepth 1 -type f ! -name '.*' \( -name '*.bak*' -o -name '*~' \) 2>/dev/null | wc -l | tr -d ' ')
if [ "${STRAY:-0}" -gt 0 ]; then
    ALERTS+=("A3 stray-backups: ${STRAY} backup file(s) in Rules/ are injected into EVERY window. Move them to Rules-backups/.")
fi

# --- A4 HARDFLOOR_SLUGS drift (G6) ---
while IFS= read -r f; do
    [ -f "$f" ] || continue
    slug=$(basename "$f" .md)
    is_hf=0; is_meta=0
    for hf in "${HARDFLOOR_SLUGS[@]}"; do [ "$slug" = "$hf" ] && is_hf=1; done
    for mf in "${META_FILES[@]}"; do [ "$slug" = "$mf" ] && is_meta=1; done
    if [ "$is_hf" = "0" ] && [ "$is_meta" = "0" ]; then
        ALERTS+=("A4 G6 drift: '$slug' is in Rules/ but neither hardfloor nor meta — belongs in Rules-archive/")
    fi
done < <(ls "$RULES_DIR"/*.md 2>/dev/null)

# --- A7 CROSS-SOURCE hardfloor drift (idea #25151, the check that was missing) ---
# A4 above compares the directory against the manifest, which is derived FROM the
# directory, so it can never catch a consumer that disagrees. THIS check compares
# the manifest against what the MCP registry actually indexed. That divergence is
# what went undetected for ~2 weeks: the MCP reported 9 hardfloor rules while 20
# were on disk, so rules 119/120/143/144/259/267/161/297/99-subagent were loaded
# into every window but flagged as not-binding.
MCP_DB="$HOME/.clinerules-mcp/index.sqlite"
if [ -f "$MCP_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    MCP_HF=$(sqlite3 "$MCP_DB" "SELECT COUNT(*) FROM rules WHERE is_hardfloor=1;" 2>/dev/null || echo "ERR")
    MANIFEST_HF=${#HARDFLOOR_SLUGS[@]}
    note "A7 cross-source: manifest=${MANIFEST_HF} hardfloor, MCP index=${MCP_HF}"
    if [ "$MCP_HF" != "ERR" ] && [ "${MCP_HF:-0}" -ne "$MANIFEST_HF" ]; then
        ALERTS+=("A7 CROSS-SOURCE DRIFT: manifest lists ${MANIFEST_HF} hardfloor rules but the MCP registry indexed ${MCP_HF}. Rules are loading into every window while being reported as not-binding. Fix: node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only")
    fi
    # Per-slug comparison so the alert names the specific offender, not just a count.
    for hf in "${HARDFLOOR_SLUGS[@]}"; do
        got=$(sqlite3 "$MCP_DB" "SELECT is_hardfloor FROM rules WHERE slug='${hf}';" 2>/dev/null)
        if [ -z "$got" ]; then
            ALERTS+=("A7 cross-source: '${hf}' is in Rules/ but MISSING from the MCP index entirely.")
        elif [ "$got" != "1" ]; then
            ALERTS+=("A7 cross-source: '${hf}' is a hardfloor rule on disk but the MCP index has is_hardfloor=${got}. It loads every window but nothing treats it as binding.")
        fi
    done
else
    note "A7 cross-source: skipped (MCP index or sqlite3 unavailable)"
fi

# --- A5 rule-number collisions in archive (only real .md files) ---
COLLISIONS=$(ls "$ARCHIVE_DIR"/*.md 2>/dev/null | xargs -n1 basename | grep -oE '^[0-9]+' | sort | uniq -d)
if [ -n "$COLLISIONS" ]; then
    for num in $COLLISIONS; do
        ALERTS+=("A5 collision: rule number ${num} has multiple files in Rules-archive/: $(ls "$ARCHIVE_DIR"/${num}-*.md 2>/dev/null | xargs -n1 basename | tr '\n' ' ')")
    done
fi
note "A5 collisions: ${COLLISIONS:-none}"

# --- A6 counter drift ---
if [ -f "$COUNTER_FILE" ]; then
    COUNTER_VAL=$(cat "$COUNTER_FILE" 2>/dev/null | tr -d ' \n')
    # Cap at 999: some archive files are named after IDEA ids (e.g. 16925-*.md),
    # not rule numbers. Counting those made A6 claim the counter was "behind" by
    # ~16,000 every night since forever, which is noise that trains you to ignore
    # the audit. Rule numbers are 3 digits or fewer.
    HIGHEST=$(ls "$ARCHIVE_DIR"/*.md 2>/dev/null | xargs -n1 basename | grep -oE '^[0-9]+' | awk '$1 < 1000' | sort -n | tail -1)

    note "A6 counter: file=${COUNTER_VAL}, highest-archive-rule=${HIGHEST:-none}"
    if [ -n "$HIGHEST" ] && [ -n "$COUNTER_VAL" ]; then
        if [ "$COUNTER_VAL" -lt "$HIGHEST" ]; then
            ALERTS+=("A6 counter-drift: .clinerule_counter=${COUNTER_VAL} but highest archive rule #=${HIGHEST}. Counter is behind — next rule creation will collide. Fix: echo \$((HIGHEST)) > $COUNTER_FILE")
        fi
    fi
else
    ALERTS+=("A6 counter-missing: $COUNTER_FILE does not exist")
fi

# --- A7 gate telemetry (idea #25906, Ruben approved 2026-08-12) ---
# Reads the clinerules MCP violations table (~/.clinerules-mcp/index.sqlite) so the
# rule-91 gate's fire-rate is visible nightly WITHOUT manual queries. Every call to
# clinerules_validate_completion logs a row (evidence contains R317_UNVERIFIED_STATE /
# R317_REVERSAL_LOG / SELF_CONTRADICTING_DISPOSITION / MISSING_PICKUP_PROMPT, etc).
# This makes the 24h win/loss and the top failure codes part of the routine audit.
MCP_DB="$HOME/.clinerules-mcp/index.sqlite"
GATE_24H=""
GATE_PASS=""
if [ -f "$MCP_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    GATE_24H=$(sqlite3 "$MCP_DB" "SELECT COUNT(*) FROM violations WHERE recorded_at >= datetime('now','-1 day');" 2>/dev/null | tr -d ' ')
    GATE_PASS=$(sqlite3 "$MCP_DB" "SELECT COUNT(*) FROM violations WHERE recorded_at >= datetime('now','-1 day') AND evidence LIKE 'VALIDATION_PASS%';" 2>/dev/null | tr -d ' ')
    [ -z "$GATE_24H" ] && GATE_24H=0
    [ -z "$GATE_PASS" ] && GATE_PASS=0
    GATE_FAIL=$(( GATE_24H - GATE_PASS ))
    note "A7 gate-telemetry: ${GATE_24H} completion validations in 24h - ${GATE_PASS} passed, ${GATE_FAIL} failed"
    if [ "$GATE_24H" -gt 0 ] && [ "$GATE_FAIL" -gt 0 ]; then
        sqlite3 "$MCP_DB" "SELECT evidence FROM violations WHERE recorded_at >= datetime('now','-1 day') AND evidence NOT LIKE 'VALIDATION_PASS%';" 2>/dev/null \
        | while IFS= read -r ev; do
            echo "$ev" | grep -oE '[A-Z][A-Z0-9_]+:' | sed 's/:$//'
        done | sort | uniq -c | sort -rn | head -8 \
        | while read -r cnt code; do
            note "A7   failure-code ${code} x ${cnt}"
        done
    fi
    if [ "$GATE_24H" -eq 0 ]; then
        note "A7   (no validations in the last 24h)"
    fi
else
    note "A7 gate-telemetry: skipped (sqlite3 or MCP db unavailable)"
fi

# --- Report ---
ALERT_COUNT=${#ALERTS[@]}
if [ "$ALERT_COUNT" -gt 0 ]; then
    warn "ALERTS: ${ALERT_COUNT}"
    for a in "${ALERTS[@]}"; do
        warn "$a"
    done
    SUMMARY="RULES AUDIT: ${ALERT_COUNT} alert(s) — see /tmp/cline_rules_audit.log"
    if [ "$QUIET" != "--quiet" ]; then
        osascript -e "display notification \"$SUMMARY\" with title \"Cline Rules Audit\" subtitle \"${ALERT_COUNT} alerts\" sound name \"Basso\"" 2>/dev/null || true
    fi
else
    SUMMARY="RULES AUDIT: clean (files=${MD_COUNT}, size=${TOTAL_KB}KB, counter=${COUNTER_VAL:-?})"
    note "CLEAN: $SUMMARY"
fi

echo "$SUMMARY"
log "$SUMMARY"
exit 0
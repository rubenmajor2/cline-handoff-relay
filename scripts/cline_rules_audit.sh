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

# Hardfloor slugs (must match .pre-write-lint.sh HARDFLOOR_SLUGS exactly)
HARDFLOOR_SLUGS=(
    "00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds"
    "01-voice-and-persona"
    "02-no-apologies-in-student-emails"
    "29-agents-act-on-confidence-tier"
    "41-post-deploy-call-the-tool-do-not-narrate"
    "91-every-completion-needs-pickup-prompt"
    "119-mandatory-context-compress"
    "120-context-is-not-an-excuse"
    "143-prose-loop-circuit-breaker"
    "144-no-write-to-file-on-server-paths"
)
# Meta files allowed in Rules/ (must match .pre-write-lint.sh META_FILES exactly)
META_FILES=("_INDEX" "_RULE_TREE" "EXECUTE_ORDER_66" "99-yolo-prevention-learned")

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

# --- A1 file count ---
MD_COUNT=$(ls "$RULES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
note "A1 file-count: ${MD_COUNT} .md files in Rules/ (cap 14)"
if [ "$MD_COUNT" -gt 14 ]; then
    ALERTS+=("A1 file-count: ${MD_COUNT} .md files in Rules/ exceeds cap of 14 (10 hardfloor + 4 meta)")
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

# --- A3 total Rules/ size ---
TOTAL_KB=$(du -sk "$RULES_DIR" 2>/dev/null | cut -f1)
note "A3 total-size: ${TOTAL_KB} KB in Rules/ (warn 180KB, alert 250KB)"
if [ "${TOTAL_KB:-0}" -gt 250 ]; then
    ALERTS+=("A3 total-size: Rules/ is ${TOTAL_KB} KB (>250KB alert threshold)")
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
    HIGHEST=$(ls "$ARCHIVE_DIR"/*.md 2>/dev/null | xargs -n1 basename | grep -oE '^[0-9]+' | sort -n | tail -1)
    note "A6 counter: file=${COUNTER_VAL}, highest-archive-rule=${HIGHEST:-none}"
    if [ -n "$HIGHEST" ] && [ -n "$COUNTER_VAL" ]; then
        if [ "$COUNTER_VAL" -lt "$HIGHEST" ]; then
            ALERTS+=("A6 counter-drift: .clinerule_counter=${COUNTER_VAL} but highest archive rule #=${HIGHEST}. Counter is behind — next rule creation will collide. Fix: echo \$((HIGHEST)) > $COUNTER_FILE")
        fi
    fi
else
    ALERTS+=("A6 counter-missing: $COUNTER_FILE does not exist")
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
#!/usr/bin/env bash
#
# cline_rules_audit.sh — Nightly audit of ~/Documents/Cline/Rules/ for bloat
#
# Per orchestrator_idea #15268. Makes the 2026-06-25 Rule 91 bloat fix durable.
# The .pre-write-lint.sh G5/G6 gates prevent NEW bloat on write, but don't
# alert when existing rules grow or when files accumulate. This script closes
# that gap by running nightly and posting to ops chat 55 on drift.
#
# Checks:
#   1. File count in Rules/ (10 hardfloor + 3 meta = 13 max)
#   2. Each hardfloor rule size (8KB soft warn, 12KB hard alert)
#   3. Total Rules/ directory size (180KB warn, 250KB alert)
#   4. Every .md in Rules/ is in HARDFLOOR_SLUGS or META_FILES (no drift)
#   5. Every slug in HARDFLOOR_SLUGS has a corresponding .md file
#
# Exit codes: 0 = clean, 1 = warnings, 2 = alerts (posts to chat 55)
#
# Usage: cline_rules_audit.sh [--quiet]
#   --quiet: log only, don't post to ops chat (for manual runs)

set -uo pipefail

RULES_DIR="$HOME/Documents/Cline/Rules"
LINT_SCRIPT="$RULES_DIR/.pre-write-lint.sh"
LOG="/tmp/cline_rules_audit.log"
QUIET="${1:-}"

# Ops chat posting via the ruben-control MCP (queue mechanism)
post_ops() {
    local msg="$1"
    if [ "$QUIET" != "--quiet" ]; then
        # Use the ruben-control MCP via the WOPR API queue
        curl -s -X POST "http://localhost:8765/mcp" \
            -H "Content-Type: application/json" \
            -d "{\"tool_name\":\"send_ops_message\",\"arguments\":{\"message\":\"$msg\"}}" \
            > /dev/null 2>&1 || true
    fi
    echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] OPS: $msg" >> "$LOG"
}

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

log "=== Cline Rules Audit started ==="

ALERTS=()
WARNINGS=()

# --- Check 1: File count ---
FILE_COUNT=$(ls "$RULES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
log "File count: $FILE_COUNT (max 13)"
if [ "$FILE_COUNT" -gt 13 ]; then
    ALERTS+=("ALERT: $FILE_COUNT .md files in Rules/ (max 13 = 10 hardfloor + 3 meta). Non-hardfloor rules must move to Rules-archive/.")
fi

# --- Check 2: Per-rule size (skip meta files — they're navigation, not rules) ---
META_SLUGS="_INDEX _RULE_TREE EXECUTE_ORDER_66"
for f in "$RULES_DIR"/*.md; do
    [ -f "$f" ] || continue
    slug=$(basename "$f" .md)
    size=$(wc -c < "$f" | tr -d ' ')
    log "Rule $slug: ${size} bytes"
    # Skip meta files from size cap (they're navigation maps, allowed larger)
    is_meta=0
    for m in $META_SLUGS; do [ "$slug" = "$m" ] && is_meta=1; done
    if [ "$is_meta" = "1" ]; then
        # Meta files: warn at 16KB, alert at 20KB (they're navigation, not rules)
        if [ "$size" -gt 20480 ]; then
            ALERTS+=("ALERT: meta file $slug is ${size} bytes (>20KB). Trim the navigation map.")
        elif [ "$size" -gt 16384 ]; then
            WARNINGS+=("WARN: meta file $slug is ${size} bytes (>16KB). Consider trimming.")
        fi
    else
        # Hardfloor rules: warn at 8KB, alert at 12KB
        if [ "$size" -gt 12288 ]; then
            ALERTS+=("ALERT: $slug is ${size} bytes (>12KB hard cap). Trim or move addenda to Rules-archive/. See Rules-archive/29-case-law.md + 41-addenda.md for the trim pattern.")
        elif [ "$size" -gt 8192 ]; then
            WARNINGS+=("WARN: $slug is ${size} bytes (>8KB soft cap). Consider trimming.")
        fi
    fi
done

# --- Check 3: Total directory size ---
TOTAL_KB=$(du -sk "$RULES_DIR" 2>/dev/null | cut -f1)
log "Total Rules/ size: ${TOTAL_KB}KB"
if [ "$TOTAL_KB" -gt 250 ]; then
    ALERTS+=("ALERT: Rules/ is ${TOTAL_KB}KB (>250KB hard cap). Bloat will dilute model attention.")
elif [ "$TOTAL_KB" -gt 180 ]; then
    WARNINGS+=("WARN: Rules/ is ${TOTAL_KB}KB (>180KB soft cap)")
fi

# --- Check 4: Extract HARDFLOOR_SLUGS + META_FILES from lint script ---
if [ ! -f "$LINT_SCRIPT" ]; then
    ALERTS+=("ALERT: .pre-write-lint.sh missing from Rules/")
else
    # Extract slugs from HARDFLOOR_SLUGS array
    HARDFLOOR_SLUGS=$(awk '/^HARDFLOOR_SLUGS=\(/,/^\)/' "$LINT_SCRIPT" | grep '"' | sed 's/.*"\(.*\)".*/\1/')
    # META_FILES are hardcoded (matching .pre-write-lint.sh)
    META_FILES="_INDEX _RULE_TREE EXECUTE_ORDER_66"

    # Check 4a: Every .md in Rules/ should be in HARDFLOOR_SLUGS or META_FILES
    for f in "$RULES_DIR"/*.md; do
        [ -f "$f" ] || continue
        slug=$(basename "$f" .md)
        is_allowed=0
        echo "$HARDFLOOR_SLUGS" | grep -qx "$slug" && is_allowed=1
        echo "$META_FILES" | grep -qw "$slug" && is_allowed=1
        if [ "$is_allowed" = "0" ]; then
            ALERTS+=("ALERT: $slug.md is in Rules/ but NOT in HARDFLOOR_SLUGS or META_FILES. Either add to HARDFLOOR_SLUGS or move to Rules-archive/.")
        fi
    done

    # Check 4b: Every slug in HARDFLOOR_SLUGS should have a file
    for slug in $HARDFLOOR_SLUGS; do
        if [ ! -f "$RULES_DIR/${slug}.md" ]; then
            ALERTS+=("ALERT: $slug is in HARDFLOOR_SLUGS but has no .md file in Rules/")
        fi
    done
fi

# --- Report ---
if [ ${#ALERTS[@]} -gt 0 ]; then
    log "=== AUDIT FAILED: ${#ALERTS[@]} alerts ==="
    for a in "${ALERTS[@]}"; do log "$a"; done
    msg="Cline Rules Audit ALERT (${#ALERTS[@]} issues):"
    for a in "${ALERTS[@]}"; do msg="$msg\n$a"; done
    msg="$msg\n\nRun cline_rules_audit.sh --quiet for full log. Fix bloat per _INDEX.md."
    post_ops "$msg"
    exit 2
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    log "=== AUDIT WARN: ${#WARNINGS[@]} warnings ==="
    for w in "${WARNINGS[@]}"; do log "$w"; done
    exit 1
else
    log "=== AUDIT PASSED: $FILE_COUNT files, ${TOTAL_KB}KB, all hardfloor <=8KB ==="
    exit 0
fi
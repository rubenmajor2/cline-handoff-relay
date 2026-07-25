#!/usr/bin/env bash
#
# .pre-write-lint.sh — Pre-write lint for ~/Documents/Cline/Rules/*.md
#
# Per orchestrator_idea #5346 (P1, approved) + #5348 (P1, approved, hardfloor gate).
# Designed to be called against a single .md file before it lands. Outputs:
#   - exit 0 + nothing       -> lint passed
#   - exit 0 + warnings      -> soft fail; warnings on stderr
#   - exit 2 + hard-block    -> file rejected
#
# Companion to clinerules-mcp (idea #5344). Same 5 gates the nightly audit cron
# enforces, so a rule that ships clean here will pass the audit too.
#
# Five gates:
#   G1 embed-sim          — close-paraphrase to existing rule body (Jaccard >0.55 = warn, >0.75 = block)
#   G2 section-length     — body >8 KB or any single section >4 KB = warn
#   G3 phrase-redundancy  — "this rule exists" / "the bright-line rule" appears >3x in same file = warn
#   G4 source-incident    — non-hardfloor file MUST contain "Source incident" / "## Source" / "## Last updated" = warn
#   G5 hardfloor          — adding/changing a hardfloor rule (in HARDFLOOR_SLUGS) requires Ruben review (block unless --override)
#
# Usage:
#   .pre-write-lint.sh /path/to/29-foo.md [--override]
#
# Designed to be called from an fswatch listener that runs on every save under Rules/.

set -uo pipefail

FILE="${1:-}"
OVERRIDE="${2:-}"
RULES_DIR="$HOME/Documents/Cline/Rules"
LOG="/tmp/clinerules-lint.log"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "usage: .pre-write-lint.sh /path/to/rule.md [--override]" >&2
    exit 1
fi

# Only lint files under Rules/
case "$FILE" in
    "$RULES_DIR"/*) ;;
    *) exit 0 ;;
esac

SLUG=$(basename "$FILE" .md)
ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
glog() { echo "[$(ts)] $SLUG: $*" >> "$LOG"; }
warn() { echo "WARN $SLUG: $*" >&2; glog "WARN: $*"; }
fail() { echo "FAIL $SLUG: $*" >&2; glog "FAIL: $*"; exit 2; }
ok()   { glog "OK"; }

# ----------------------------------------------------------------------
# Atomic next-number claim for Clinerule IDs
# ----------------------------------------------------------------------
# Thread-safe helper that returns the next available integer rule number.
# Uses flock(1) on a hidden counter file so multiple concurrent Cline
# windows cannot claim the same number at the same time.
#
# Usage:
#   NEXT_NUM=$(get_next_rule_number)
#   mv my-rule.md "${NEXT_NUM}-my-slug.md"
get_next_rule_number() {
    local COUNTER_FILE="${RULES_DIR}/.clinerule_counter"

    # Initialise counter file at 0 if it does not exist yet
    [ -f "$COUNTER_FILE" ] || echo "0" > "$COUNTER_FILE"

    # Acquire an exclusive flock on a companion lock file
    local LOCK_FD=200
    exec 200>"${COUNTER_FILE}.lock"
    flock ${LOCK_FD}

    # Read -> increment -> write back atomically
    local LAST_NUM NEXT_NUM
    LAST_NUM=$(cat "$COUNTER_FILE")
    NEXT_NUM=$(( LAST_NUM + 1 ))
    echo "$NEXT_NUM" > "$COUNTER_FILE"

    # Release the lock
    flock -u ${LOCK_FD}

    # Return the new number to the caller
    echo "$NEXT_NUM"
}

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
    "259-cline-tasks-stay-in-cline-not-chat55"
    "267-orchestrator-executor-offload-and-reconcile"
    "99-subagent-verify-before-claim"
)

# --- G5 hardfloor (runs first; immediate block) --------------------------
is_hardfloor=0
for hf in "${HARDFLOOR_SLUGS[@]}"; do
    if [ "$SLUG" = "$hf" ]; then is_hardfloor=1; break; fi
done
if [ "$is_hardfloor" = "1" ] && [ "$OVERRIDE" != "--override" ]; then
    # Hardfloor rule edits require explicit --override flag (so Ruben sees them)
    warn "Hardfloor rule edit detected. Re-run with --override after Ruben review:"
    warn "  .pre-write-lint.sh '$FILE' --override"
    fail "G5 hardfloor: blocked. Hardfloor rules need explicit override flag."
fi

# --- G6 non-hardfloor-in-Rules-dir (idea #14205) -------------------------
# Prevents non-hardfloor rules from accumulating in Rules/ and bloating every
# window's system prompt. Only HARDFLOOR_SLUGS + meta files may live here.
# Any other .md file in Rules/ is rejected — it belongs in Rules-archive/.
# This is the durable fix for the 2026-06-23 bloat root cause (10 non-hardfloor
# Frankenstein rules had piled into Rules/, diluting model attention on rules
# 91/41/etc.). Bypass with --override only for a legitimate one-off.
META_FILES=("_INDEX" "_RULE_TREE" "EXECUTE_ORDER_66" "99-yolo-prevention-learned")
is_meta=0
for mf in "${META_FILES[@]}"; do
    if [ "$SLUG" = "$mf" ]; then is_meta=1; break; fi
done
if [ "$is_hardfloor" = "0" ] && [ "$is_meta" = "0" ] && [ "$OVERRIDE" != "--override" ]; then
    fail "G6 non-hardfloor-in-Rules: '$SLUG' is not a hardfloor rule and not a meta file. Non-hardfloor rules belong in ~/Documents/Cline/Rules-archive/, not Rules/. Either (a) move the file to Rules-archive/, or (b) if this is a genuine new hardfloor rule, add '$SLUG' to HARDFLOOR_SLUGS above first (needs Ruben's call per _INDEX.md). Re-run with --override only for a intentional one-off bypass."
fi

# --- G2 section-length + G7 hard size cap (2026-06-25) -------------------
# G2 (existing): warn at >8KB. G7 (new): BLOCK at >12KB for hardfloor rules,
# >20KB for meta files. This is the durable fix for the Rule 91 bloat root
# cause — rules that metastasize through addenda creep now fail the lint
# gate on write, forcing the trim-then-archive pattern. Per idea #15268.
BYTES=$(wc -c < "$FILE" | tr -d ' ')
if [ "$BYTES" -gt 8192 ]; then
    warn "G2 section-length: file is $BYTES bytes (>8 KB). Consider splitting."
fi
# G7 hard size cap (2026-06-25): hardfloor rules >12KB = block, meta >20KB = block
if [ "$is_hardfloor" = "1" ] && [ "$BYTES" -gt 12288 ]; then
    fail "G7 hard-size-cap: hardfloor rule $SLUG is $BYTES bytes (>12KB). Bloat root cause (2026-06-25 Rule 91 investigation). Trim the core gate + move addenda/case law to Rules-archive/<N>-case-law.md. See Rules-archive/29-case-law.md + 41-addenda.md for the trim pattern. Re-run with --override only for Ruben-approved one-off."
elif [ "$is_meta" = "1" ] && [ "$BYTES" -gt 20480 ]; then
    fail "G7 hard-size-cap: meta file $SLUG is $BYTES bytes (>20KB). Trim the navigation map."
fi
# Largest single section (## or ### heading to next heading)
MAX_SECTION=$(awk '
    /^##+ / { if (sec) print length(sec); sec=""; next }
    { sec = sec $0 "\n" }
    END { if (sec) print length(sec) }
' "$FILE" | sort -n | tail -1)
if [ -n "$MAX_SECTION" ] && [ "$MAX_SECTION" -gt 4096 ]; then
    warn "G2 section-length: largest section is $MAX_SECTION bytes (>4 KB)."
fi

# --- G3 phrase-redundancy ------------------------------------------------
for phrase in "this rule exists" "the bright-line rule" "the bright line rule" "self-check before"; do
    n=$(grep -c -i "$phrase" "$FILE" || true)
    if [ "$n" -gt 3 ]; then
        warn "G3 phrase-redundancy: '$phrase' appears $n times. Tighten."
    fi
done

# --- G4 source-incident (skip hardfloor; they don't need it) -------------
if [ "$is_hardfloor" = "0" ]; then
    if ! grep -q -i -E "(source incident|## source|## last updated|^Source:)" "$FILE"; then
        warn "G4 source-incident: no 'Source incident' / '## Source' / '## Last updated' citation found."
    fi
fi


# --- G8 floor-total cap (2026-07-25, idea #19125) ---------------------------
# The always-loaded Rules/ dir is injected into EVERY window's system prompt.
# Cline's Xle() compacts a 200K model at 160,000 tokens, so an oversized floor
# arms auto-condense on turn 1 and can never be disarmed (33-50% of Opus spend
# went to writing summaries before this gate existed). Block growth past 150KB.
FLOOR_BYTES=$(find "$RULES_DIR" -maxdepth 1 -name '*.md' -exec cat {} \; | wc -c | tr -d ' ')
if [ "$FLOOR_BYTES" -gt 153600 ]; then
    fail "G8 floor-total: Rules/ is $FLOOR_BYTES bytes (>150KB). This is the always-loaded system-prompt floor. Move non-hardfloor content to Rules-archive/ before adding more. See _INDEX.md 2026-07-25 floor trim."
elif [ "$FLOOR_BYTES" -gt 131072 ]; then
    warn "G8 floor-total: Rules/ is $FLOOR_BYTES bytes (>128KB warn). Trim soon."
fi

# --- G1 embed-sim (Jaccard similarity over 4-grams of words) -------------
# Cheap proxy for "did we just write something paraphrased of an existing rule?"
# Block at >0.75, warn at >0.55. Skip self.
python3 - "$FILE" "$RULES_DIR" "$SLUG" <<'PYEOF'
import sys, os, re, glob

target_path, rules_dir, target_slug = sys.argv[1], sys.argv[2], sys.argv[3]

def tokenize(text):
    return re.findall(r"[a-z0-9]+", text.lower())

def shingles(toks, k=4):
    return set(tuple(toks[i:i+k]) for i in range(len(toks)-k+1))

def jaccard(a, b):
    if not a or not b: return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0

try:
    target_text = open(target_path, encoding="utf-8").read()
except Exception:
    sys.exit(0)
target_shingles = shingles(tokenize(target_text))
if len(target_shingles) < 20:
    sys.exit(0)  # too short to bother

worst_slug = None
worst_jacc = 0.0
for path in glob.glob(os.path.join(rules_dir, "*.md")):
    slug = os.path.basename(path)[:-3]
    if slug == target_slug: continue
    try:
        other = open(path, encoding="utf-8").read()
    except Exception:
        continue
    j = jaccard(target_shingles, shingles(tokenize(other)))
    if j > worst_jacc:
        worst_jacc = j
        worst_slug = slug

if worst_jacc >= 0.75:
    print(f"FAIL {target_slug}: G1 embed-sim Jaccard {worst_jacc:.2f} vs {worst_slug} (>=0.75 = block). Merge or rewrite.", file=sys.stderr)
    sys.exit(2)
elif worst_jacc >= 0.55:
    print(f"WARN {target_slug}: G1 embed-sim Jaccard {worst_jacc:.2f} vs {worst_slug} (>=0.55 = warn). Consider tightening.", file=sys.stderr)
PYEOF
G1_RC=$?
if [ "$G1_RC" = "2" ]; then
    glog "G1 hard-block triggered (Jaccard >=0.75)"
    exit 2
fi

# --- Reindex the MCP so the change is queryable immediately --------------
# (best-effort, non-fatal)
node /Users/rubenmajor/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only > /dev/null 2>&1 &

ok
exit 0
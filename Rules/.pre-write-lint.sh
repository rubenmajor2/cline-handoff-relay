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

# ----------------------------------------------------------------------
# HARDFLOOR_SLUGS + META_FILES — READ FROM THE GENERATED MANIFEST
# ----------------------------------------------------------------------
# idea #25151 (2026-08-08): these used to be TWO hardcoded arrays here, which
# were copies 2 and 3 of a set that also lived in clinerules-mcp/src/index.ts and
# in the Rules/ dir itself. The 2026-07-25 floor trim updated only some copies, so
# the MCP reported 9 hardfloor rules while 20 were on disk, and rules 119/120/143/
# 144/259/267/161/297/99-subagent were loaded into every window but flagged as NOT
# binding. The divergence survived ~2 weeks because nothing compared the copies.
#
# Both arrays are now DERIVED from .hardfloor-manifest, which is itself generated
# from the directory listing by scripts/sync_hardfloor_manifest.sh. Adding a rule
# file is the ONLY action needed. There is no second list to forget.
MANIFEST="${RULES_DIR}/.hardfloor-manifest"
SYNC_SCRIPT="$HOME/Documents/Cline/scripts/sync_hardfloor_manifest.sh"

# Regenerate first so the manifest always reflects the CURRENT directory.
# (Cheap: a directory listing. Keeps the gate honest even if someone hand-added a file.)
[ -x "$SYNC_SCRIPT" ] && "$SYNC_SCRIPT" --quiet >/dev/null 2>&1

read_manifest_section() {
    # $1 = section name, e.g. "hardfloor" or "meta"
    [ -f "$MANIFEST" ] || return 0
    awk -v want="[$1]" '
        /^\[/ { insec = ($0 == want); next }
        insec && NF && $0 !~ /^#/ { print }
    ' "$MANIFEST"
}

HARDFLOOR_SLUGS=()
while IFS= read -r line; do
    [ -n "$line" ] && HARDFLOOR_SLUGS+=("$line")
done < <(read_manifest_section hardfloor)

MANIFEST_META=()
while IFS= read -r line; do
    [ -n "$line" ] && MANIFEST_META+=("$line")
done < <(read_manifest_section meta)

# Fallback: if the manifest is unreadable, derive from the directory directly
# rather than falling back to a stale hardcoded list (that is the bug we fixed).
if [ ${#HARDFLOOR_SLUGS[@]} -eq 0 ]; then
    warn "manifest missing or empty, deriving hardfloor set from directory listing"
    for f in "$RULES_DIR"/*.md; do
        [ -e "$f" ] || continue
        b=$(basename "$f"); s="${b%.md}"
        case "$b" in *.bak*|*~|._*) continue ;; esac
        case "$s" in _*|EXECUTE_ORDER_66|REQUIREMENT_IDEA_AUTO_FILE|99-yolo-prevention-learned) continue ;; esac
        HARDFLOOR_SLUGS+=("$s")
    done
fi


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
# META_FILES comes from the manifest [meta] section (idea #25151). The old
# hardcoded array here omitted REQUIREMENT_IDEA_AUTO_FILE, so that file would
# have been rejected by G6 despite living in Rules/ and loading every window.
# Any slug starting with '_' is also treated as meta.
META_FILES=("${MANIFEST_META[@]:-}")
if [ ${#MANIFEST_META[@]} -eq 0 ]; then
    META_FILES=("_INDEX" "_RULE_TREE" "EXECUTE_ORDER_66" "REQUIREMENT_IDEA_AUTO_FILE" "99-yolo-prevention-learned")
fi
is_meta=0
case "$SLUG" in _*) is_meta=1 ;; esac
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
# G2b warn-early (2026-08-19, Ruben-approved): hardfloor rules >10KB get an early
# trim warning BEFORE the 12KB G7 block, so trims happen proactively. Source: the
# 2026-08-19 rule-317 reversal-log audit found 5 hardfloor rules between 10-16KB,
# all failing or near-failing G7; a 10KB early warning gives a 2KB trim runway.
if [ "$is_hardfloor" = "1" ] && [ "$BYTES" -gt 10240 ] && [ "$BYTES" -le 12288 ]; then
    warn "G2b warn-early: hardfloor rule is $BYTES bytes (>10 KB). Trim-then-archive NOW to stay ahead of the 12KB G7 block (see _INDEX.md trim-then-archive pattern)."
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


# --- G9 no-override-of-rule-91 (2026-08-08, bug library #2277) --------------
# Source incident: rule 300 was added to the router's _STEERING_HARDFLOOR_FULL
# tier (idea #25155), which injects a rule's ENTIRE text VERBATIM at the TOP of
# the steering system prompt. Rule 300's body contained a "This rule overrides:
# Rule 91 ... PICKUP PROMPT blocks are FORBIDDEN" clause. Measured live: rule 300
# at char 857, the rule-91 PICKUP PROMPT skeleton at char 16,823. Models read the
# override claim ~16K chars BEFORE the rule it overrode and obeyed it. That is a
# live rule-91 regression across every window, produced entirely by RULE TEXT.
#
# The class: any always-loaded rule that (a) claims override authority over a
# hardfloor FORMATTING rule and (b) is positioned above it, WINS. Rule 91 is
# unconditional by design, so nothing may claim to override it.
#
# Also catches the second-order trap: an RCA section that QUOTES the defective
# directive re-arms it, because the text is injected verbatim and a model reading
# a quoted imperative cannot reliably tell "historical example" from "instruction".
# Describe defective directives in prose; never reproduce them literally.
# v2 (2026-08-08, same day): v1 of this gate had TWO defects found by its own
# positive-control test, both worth recording because they are the general traps:
#   (a) v1 matched only the INLINE form ("overrides rule 91"). The ACTUAL defect
#       was a MARKDOWN HEADING + LIST form -- "## This rule overrides:" on one
#       line, "- Rule 91 ..." on the next. A line-oriented grep cannot see that.
#       A gate that misses the exact shape of the incident that motivated it is
#       decorative. Now parses the "overrides:" section across lines.
#   (b) v1's omit-directive regex used [^.]{0,60}, which spanned a semicolon and
#       false-positived on rule 161's cross-ref line ("Rule 91 - pickup prompt
#       format; [queued] banned in dispositions"). Clause boundaries (. ; -- and
#       newline) now terminate the match.
python3 - "$FILE" "$SLUG" <<'G9EOF'
import sys, re
path, slug = sys.argv[1], sys.argv[2]
try:
    t = open(path, encoding="utf-8").read()
except Exception:
    sys.exit(0)

exempt = re.search(r"does\s+NOT\s+override\s+rule\s+91", t, re.I)
fails = []

# (1) Override-claim, INLINE form.
if re.search(r"(overrid|supersed|suspend|waiv)\w*\s+(the\s+)?rule\s+91", t, re.I) \
   or re.search(r"rule\s+91[^.\n]{0,80}(is\s+)?(overrid|supersed|suspend|waiv)", t, re.I):
    if not exempt:
        fails.append("claims override/supersede authority over rule 91 (inline form)")

# (2) Override-claim, HEADING+LIST form -- the shape of the real incident.
#     Any "overrides:" heading/lead-in, then Rule 91 named in the following block.
for m in re.finditer(r"^.{0,80}overrid\w*\s*:\s*$", t, re.I | re.M):
    tail = t[m.end():m.end() + 600]
    block = tail.split("\n##")[0]          # stop at the next heading
    if re.search(r"rule\s*91", block, re.I) and not exempt:
        fails.append("lists Rule 91 under an 'overrides:' heading (heading+list form)")
        break

# (3) Quotable directive to omit/limit the block. Clause boundaries (. ; -- newline)
#     terminate the window so cross-reference lines do not false-positive.
if re.search(r"pickup\s+prompt[^.;\n\u2014]{0,60}(is\s+|are\s+|be\s+)?(forbidden|banned|not\s+required|optional|valid\s+ONLY)", t, re.I) \
   or re.search(r"(omit|skip|drop)\s+the\s+pickup\s+prompt", t, re.I):
    fails.append("contains a sentence that reads as an instruction to omit/limit the PICKUP PROMPT block")

if fails:
    print("FAIL %s: G9 rule-91-supremacy: %s. Rule 91 (PICKUP PROMPT) is UNCONDITIONAL - no rule may override it, and always-loaded rules are injected VERBATIM into every system prompt so even a QUOTED example re-arms the directive. If you mean 'do not DEFER buildable work', say that; the pickup block is a state record, not a deferral. Describe defective directives in prose, never reproduce them literally. If this file legitimately DISCUSSES the relationship it must contain the literal phrase 'does NOT override Rule 91'. See bug library #2277 (2026-08-08 live regression)."
          % (slug, "; ".join(fails)), file=sys.stderr)
    sys.exit(2)
G9EOF
if [ "$?" = "2" ]; then
    glog "G9 rule-91-supremacy hard-block triggered"
    exit 2
fi

# --- G8 floor-total cap (2026-07-25, idea #19125) ---------------------------
# The always-loaded Rules/ dir is injected into EVERY window's system prompt.
# Cline's Xle() compacts a 200K model at 160,000 tokens, so an oversized floor
# arms auto-condense on turn 1 and can never be disarmed (33-50% of Opus spend
# went to writing summaries before this gate existed). Block growth past 150KB.
# 2026-08-08 (idea #25150): G8 used to count ONLY '*.md'. Cline injects EVERY
# non-dotfile in Rules/, so two backup files (_INDEX.md.bak-20260808 and
# .pre-write-lint.sh.bak-20260808, 12,254 bytes) were being loaded into every
# window while G8 reported a floor that did not include them. The gate was
# measuring something other than the thing it was protecting. Now it counts
# what actually loads, and rejects backups living in Rules/ outright.
STRAY_BAKS=$(find "$RULES_DIR" -maxdepth 1 -type f ! -name '.*' \( -name '*.bak*' -o -name '*~' \) 2>/dev/null)
if [ -n "$STRAY_BAKS" ]; then
    warn "G8 stray-backups: backup files in Rules/ are injected into EVERY window. Move them to ~/Documents/Cline/Rules-backups/:"
    while IFS= read -r b; do [ -n "$b" ] && warn "  $(basename "$b") ($(wc -c < "$b" | tr -d ' ') bytes)"; done <<< "$STRAY_BAKS"
fi
FLOOR_BYTES=$(find "$RULES_DIR" -maxdepth 1 -type f ! -name '.*' -exec cat {} \; | wc -c | tr -d ' ')
FLOOR_MD_ONLY=$(find "$RULES_DIR" -maxdepth 1 -name '*.md' -exec cat {} \; | wc -c | tr -d ' ')
# 2026-08-08 (idea #25154): the block was a bare 153600 with no stated derivation,
# so nobody could tell whether hitting it meant "real risk" or "arbitrary number".
# It is now DERIVED from the smallest model window we still run, using Cline's own
# Xle() compaction arithmetic:
#   compaction_threshold(W=200000) = W - 40000 = 160,000 tokens
#   floor must stay well under that or auto-condense arms on turn 1 (the 2026-07-25
#   incident: 139K-169K token floor vs a 160,000 threshold = permanent thrash).
#   Budget the Rules/ dir at 25% of the smallest compaction threshold:
#     160,000 tok * 0.25 = 40,000 tok ~= 160,000 bytes at ~4 bytes/token.
# Override for a deliberate, reasoned change (e.g. if 200K models are retired):
#   echo 196608 > ~/Documents/Cline/Rules/.g8-floor-cap
G8_CAP_FILE="${RULES_DIR}/.g8-floor-cap"
G8_CAP=160000
[ -f "$G8_CAP_FILE" ] && G8_CAP=$(tr -dc '0-9' < "$G8_CAP_FILE")
G8_WARN=$(( G8_CAP * 85 / 100 ))
if [ "$FLOOR_BYTES" -gt "$G8_CAP" ]; then
    fail "G8 floor-total: Rules/ is $FLOOR_BYTES bytes of always-loaded content (cap $G8_CAP), of which $FLOOR_MD_ONLY is .md. This is the system-prompt floor injected into EVERY window. Cap = 25% of the 200K-model compaction threshold (160,000 tok). Move non-hardfloor content to Rules-archive/ and backups to Rules-backups/ before adding more. See _INDEX.md 2026-07-25 floor trim."
elif [ "$FLOOR_BYTES" -gt "$G8_WARN" ]; then
    warn "G8 floor-total: Rules/ is $FLOOR_BYTES bytes (>85% of cap $G8_CAP). Trim soon."

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
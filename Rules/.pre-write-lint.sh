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

HARDFLOOR_SLUGS=(
    "00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds"
    "01-voice-and-persona"
    "02-no-apologies-in-student-emails"
    "29-agents-act-on-confidence-tier"
    "38-ruben-asks-equals-autonomous-or-shipped"
    "41-post-deploy-call-the-tool-do-not-narrate"
    "42-safe-deploy-already-reloads-fpm"
    "91-every-completion-needs-pickup-prompt"
    "92-work-at-the-core-not-bandaids"
    "99-yolo-prevention-learned"
    "118-litellm-restart-via-safe-wrapper"
    "119-mandatory-context-compress"
    "120-context-is-not-an-excuse"
    "135-student-lifecycle-service-sls"
)

# ─── G5 hardfloor (runs first; immediate block) ──────────────────────────
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

# ─── G2 section-length ────────────────────────────────────────────────────
BYTES=$(wc -c < "$FILE" | tr -d ' ')
if [ "$BYTES" -gt 8192 ]; then
    warn "G2 section-length: file is $BYTES bytes (>8 KB). Consider splitting."
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

# ─── G3 phrase-redundancy ─────────────────────────────────────────────────
for phrase in "this rule exists" "the bright-line rule" "the bright line rule" "self-check before"; do
    n=$(grep -c -i "$phrase" "$FILE" || true)
    if [ "$n" -gt 3 ]; then
        warn "G3 phrase-redundancy: '$phrase' appears $n times. Tighten."
    fi
done

# ─── G4 source-incident (skip hardfloor; they don't need it) ─────────────
if [ "$is_hardfloor" = "0" ]; then
    if ! grep -q -i -E "(source incident|## source|## last updated|^Source:)" "$FILE"; then
        warn "G4 source-incident: no 'Source incident' / '## Source' / '## Last updated' citation found."
    fi
fi

# ─── G1 embed-sim (Jaccard similarity over 4-grams of words) ─────────────
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

# ─── Reindex the MCP so the change is queryable immediately ──────────────
# (best-effort, non-fatal)
node /Users/rubenmajor/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only > /dev/null 2>&1 &

ok
exit 0

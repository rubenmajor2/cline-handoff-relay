#!/bin/bash
# push_ledger.sh — sync ~/Documents/Cline/cline_task_ledger.md to WOPR so
# the "Open Tasks" tab on ruben_executor_live.php stays current.
#
# Piggybacks on the existing YOLO learner launchd agent (every 30 min).
# Also called opportunistically by run.sh after write_rule.py.
#
# Parses the markdown ledger into per-row JSON and POSTs it to
#   https://emsuniversity.com/emtskills/api/cline_task_ledger_push.php
# with header X-Ledger-Key.
#
# Server side writes atomically to /var/www/emtskills/data/cline_task_ledger.json.
# Server endpoint is masteradmin-behind-nothing (it's a push endpoint), gated
# by the shared key. Key lives in /etc/emsu/cline_ledger.key on server and in
# this file locally; rotate by editing both.
#
# Exit 0 even on failure so launchd never stops calling us.

set -u
LEDGER="$HOME/Documents/Cline/cline_task_ledger.md"
LOG=/tmp/cline_ledger_push.log
KEY="emsu-cline-ledger-2026-04-22-rj9k3m7q"
ENDPOINT="https://emsuniversity.com/emtskills/api/cline_task_ledger_push.php"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] push_ledger: $*" >> "$LOG"; }

if [ ! -f "$LEDGER" ]; then
    log "no ledger at $LEDGER, skipping"
    exit 0
fi

PAYLOAD=$(/usr/bin/python3 - "$LEDGER" <<'PY'
import json, os, re, sys, socket
path = sys.argv[1]
text = open(path, 'r', encoding='utf-8', errors='replace').read()
rows = []
# Match "- <when> | <task_id> | <topic> | <status> | <cue>"
# Accept 4-5 pipe-separated fields so we don't choke on older rows.
pat = re.compile(r'^-\s+([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*$')

def normalize_task_id(s):
    """Idempotent normalization so historical rows that look almost-identical
    actually collide on collapse. Without this, "#1070" / "1070" / "#1070 "
    / "task vr-emt-skill-station" / "#task vr-emt-skill-station" each become
    different keys on the portal and the ledger never collapses.
    Rules: (1) strip whitespace, (2) drop ALL leading "#" chars, (3) collapse
    inner whitespace to single spaces, (4) lowercase, (5) keep "+" / "," / "-"
    so composite ids stay legible. NEVER store an empty string — empty stays
    empty (the portal treats those as ad-hoc rows by design)."""
    if s is None:
        return ''
    s = s.strip().lstrip('#').strip()
    s = re.sub(r'\s+', ' ', s)
    return s.lower()

# Track raw-vs-normalized so we keep human-readable display + canonical key.
seen_norm = {}
for line in text.splitlines():
    m = pat.match(line)
    if not m:
        continue
    when, task_id, topic, status, cue = [x.strip() for x in m.groups()]
    norm = normalize_task_id(task_id)
    rows.append({
        'when':         when,
        'task_id':      task_id,             # original raw (for display)
        'task_id_norm': norm,                # canonical for collapse
        'topic':        topic,
        'status':       status.lower(),
        'cue':          cue,
    })
out = {
    'source_host': socket.gethostname(),
    'row_count':   len(rows),
    'rows':        rows,
    'markdown':    text,
    'schema_version': 2,                    # so server can detect & use task_id_norm
}
print(json.dumps(out))
PY
)

if [ -z "$PAYLOAD" ]; then
    log "empty payload, skipping"
    exit 0
fi

TMPF=$(mktemp -t cline_ledger_push.XXXXXX)
echo "$PAYLOAD" > "$TMPF"

OUT=$(curl -sS -m 15 -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-Ledger-Key: $KEY" \
    --data-binary @"$TMPF" 2>&1)
RC=$?
rm -f "$TMPF"

if [ $RC -eq 0 ]; then
    log "pushed ok: $OUT"
else
    log "push failed rc=$RC out=$(echo "$OUT" | head -c 400)"
fi

exit 0

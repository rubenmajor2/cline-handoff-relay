#!/bin/bash
# Push YOLO-trip learning patterns to RUBEN orchestrator on WOPR.
#
# Reads ~/Documents/Cline/yolo_learner/patterns.json, extracts key signals,
# and upserts them into orchestrator_learned_patterns server-side tagged
# event_source='cline_learner' so they surface on
# https://emsuniversity.com/emtskills/routes/cline_learner_report.php
# alongside the voice/topic-frequency patterns already being harvested.
#
# Uses the existing SSH config alias 'wopr' + the server's own db() helper.
# No credentials stored locally.
#
# Bidirectional context: server-side cron_harvest_cline_corrections.php
# already reads local ~/Library/.../tasks/*/*.jsonl for voice corrections.
# With this push, both halves of the learning loop are connected.
#
# Called by run.sh after write_rule.py. Exits 0 even on SSH failure so the
# launchd agent never stops the local scan.

set -u
LOG=/tmp/yolo_learner.log
PATTERNS=$HOME/Documents/Cline/yolo_learner/patterns.json

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] push_to_ruben: $*" >> "$LOG"; }

if [ ! -f "$PATTERNS" ]; then
    log "no patterns.json yet, skipping push"
    exit 0
fi

# Build a single-line JSON payload of the signals we want on the server.
# Keeps the SSH-side PHP snippet short & robust.
PAYLOAD=$(/usr/bin/python3 - "$PATTERNS" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
wall = p['all_time']
hist = wall.get('turns_since_user_hist') or []
fast = sum(n for t, n in hist if t <= 2)
turn0 = sum(n for t, n in hist if t == 0)
total = wall['total_trips'] or 0
out = {
    'total': total,
    'last_7d': p['last_7_days']['total_trips'],
    'last_30d': p['last_30_days']['total_trips'],
    'fast_within_2_turns': fast,
    'pct_fast_within_2_turns': round(100*fast/total, 1) if total else 0,
    'turn_zero': turn0,
    'pct_turn_zero': round(100*turn0/total, 1) if total else 0,
    'top_cat': (wall['categories'][0][0] if wall['categories'] else 'unknown'),
    'top_cat_n': (wall['categories'][0][1] if wall['categories'] else 0),
    'top_triple': (wall['triples'][0][0] if wall['triples'] else 'unknown')[:200],
    'top_triple_n': (wall['triples'][0][1] if wall['triples'] else 0),
}
print(json.dumps(out))
PY
)

if [ -z "$PAYLOAD" ]; then
    log "empty payload, skipping"
    exit 0
fi

# Base64-encode so we can pass it through SSH without any quoting headaches.
B64=$(echo -n "$PAYLOAD" | base64 | tr -d '\n')

# Server-side: decode payload, upsert 7 rows into orchestrator_learned_patterns.
# event_type='cline_yolo_learning' so these don't collide with existing
# cline_topic_frequency / cline_delegation_style rows.
REMOTE_PHP=$(cat <<PHP
<?php
require_once '/var/www/emtskills/lib/db.php';
\$pdo = db('portal');
\$raw = base64_decode('${B64}');
\$d = json_decode(\$raw, true);
if (!is_array(\$d)) { fwrite(STDERR, "bad payload\n"); exit(1); }
\$rows = [
    ['yolo_fast_trip_pct',  \$d['pct_fast_within_2_turns'] . 'pct_within_2_turns', \$d['fast_within_2_turns']],
    ['yolo_turn0_trip_pct', \$d['pct_turn_zero'] . 'pct_at_turn_0',                  \$d['turn_zero']],
    ['yolo_top_failure_cat', substr(\$d['top_cat'], 0, 50),                          \$d['top_cat_n']],
    ['yolo_top_triple',      substr(\$d['top_triple'], 0, 50),                       \$d['top_triple_n']],
    ['yolo_total_all_time',  'total',                                                \$d['total']],
    ['yolo_total_last_7d',   'last_7d',                                              \$d['last_7d']],
    ['yolo_total_last_30d',  'last_30d',                                             \$d['last_30d']],
];
\$stmt = \$pdo->prepare(
    "INSERT INTO orchestrator_learned_patterns
        (pattern_hash, event_type, event_source, event_severity,
         keyword_pattern, dominant_action, action_count, total_matches,
         confidence, auto_enabled, last_observed_at, created_at, updated_at)
     VALUES (:h, 'cline_yolo_learning', 'cline_learner', 'info',
             :kw, :act, :n, :n2, :conf, 0, NOW(), NOW(), NOW())
     ON DUPLICATE KEY UPDATE
         keyword_pattern = VALUES(keyword_pattern),
         dominant_action = VALUES(dominant_action),
         action_count    = VALUES(action_count),
         total_matches   = VALUES(total_matches),
         confidence      = VALUES(confidence),
         last_observed_at= NOW(),
         updated_at      = NOW()"
);
\$ok = 0;
foreach (\$rows as \$r) {
    [\$kw, \$act, \$n] = \$r;
    \$n = (int)\$n;
    \$conf = \$n > 0 ? min(0.99, \$n / 100.0) : 0.0;
    \$h = hash('sha256', 'cline_yolo_learning|' . \$kw);
    \$stmt->execute([
        ':h' => \$h,
        ':kw' => \$kw,
        ':act' => (string)\$act,
        ':n' => \$n,
        ':n2' => \$n,
        ':conf' => \$conf,
    ]);
    \$ok++;
}
echo "ok=\$ok total={\$d['total']} 7d={\$d['last_7d']} 30d={\$d['last_30d']}\n";
PHP
)

# Pipe the PHP file via stdin, write to /tmp on server, exec, then remove.
# Robust against quoting edge cases.
OUT=$(echo "$REMOTE_PHP" | ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no wopr \
    "cat > /tmp/yolo_push.php && php /tmp/yolo_push.php; rm -f /tmp/yolo_push.php" 2>&1)
RC=$?

if [ $RC -eq 0 ]; then
    log "pushed to RUBEN ($OUT)"
else
    log "push failed rc=$RC out=$(echo "$OUT" | head -c 200)"
fi

exit 0

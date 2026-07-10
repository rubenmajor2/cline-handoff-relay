#!/usr/bin/env bash
# Repoint Cline anthropicBaseUrl 8787 -> 8788 (through the idle-read proxy).
# Backs up state.vscdb first. Writes result to /tmp/repoint_cline.txt
OUT=/tmp/repoint_cline.txt
: > "$OUT"
DB="/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb"
BK="${DB}.bak-10529-$(date +%Y%m%d%H%M%S)"

cp "$DB" "$BK" 2>>"$OUT" && echo "backup -> $BK" >> "$OUT"

echo "=== before ===" >> "$OUT"
sqlite3 "$DB" "SELECT json_extract(value,'\$.anthropicBaseUrl') FROM ItemTable WHERE key='apiConfiguration';" >> "$OUT" 2>&1

# json_set the anthropicBaseUrl to the proxy port
sqlite3 -cmd ".timeout 5000" "$DB" \
  "UPDATE ItemTable SET value = json_set(value,'\$.anthropicBaseUrl','http://127.0.0.1:8788') WHERE key='apiConfiguration';" >> "$OUT" 2>&1
RC=$?
echo "update rc=$RC" >> "$OUT"

echo "=== after ===" >> "$OUT"
sqlite3 "$DB" "SELECT json_extract(value,'\$.anthropicBaseUrl') FROM ItemTable WHERE key='apiConfiguration';" >> "$OUT" 2>&1
echo "(done)" >> "$OUT"

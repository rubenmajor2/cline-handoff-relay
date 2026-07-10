#!/usr/bin/env bash
# Revert: flip Cline anthropicBaseUrl back to the tunnel :8787 (bypass the proxy).
OUT=/tmp/repoint_revert.txt
: > "$OUT"
DB="/Users/rubenmajor/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/state/state.vscdb"
sqlite3 -cmd ".timeout 5000" "$DB" \
  "UPDATE ItemTable SET value = json_set(value,'\$.anthropicBaseUrl','http://127.0.0.1:8787') WHERE key='apiConfiguration';" >> "$OUT" 2>&1
echo "rc=$?" >> "$OUT"
sqlite3 "$DB" "SELECT json_extract(value,'\$.anthropicBaseUrl') FROM ItemTable WHERE key='apiConfiguration';" >> "$OUT" 2>&1
echo "(reverted to 8787 — reload the VS Code window)" >> "$OUT"
cat "$OUT"

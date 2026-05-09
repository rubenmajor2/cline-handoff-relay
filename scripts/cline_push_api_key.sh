#!/bin/bash
# cline_push_api_key.sh — push Mac canonical Anthropic API key into one-or-more cline-N clones.
# 2026-05-09 11:42 PT — task #1778303827328 idea #1797 Phase 2
# 
# Usage:
#   cline_push_api_key.sh                  # all running cline-N (and cline-poc)
#   cline_push_api_key.sh cline-3 cline-7  # specific clones
#
# Reads key from ~/.ssh/cline-anthropic-key (mode 0600, single line, no trailing newline).
# Writes to BOTH /home/emsuserver/.cline/data/secrets.json AND
#                /home/emsuserver/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/secrets.json
# inside each container, via `ssh artemis "incus exec ..."` so the key never lands on Artemis disk.
#
# Use this AFTER cloning new containers (the spawn script already pushes on first creation),
# OR when Anthropic key rotates and all clones need refresh.

set -euo pipefail

KEY_FILE="$HOME/.ssh/cline-anthropic-key"
if [[ ! -f "$KEY_FILE" ]]; then
  echo "ERROR: $KEY_FILE missing. Save the Anthropic key there (mode 0600)." >&2
  exit 1
fi
KEY=$(cat "$KEY_FILE")
if [[ -z "$KEY" ]]; then
  echo "ERROR: $KEY_FILE is empty." >&2
  exit 1
fi
echo "key bytes: ${#KEY}"

# Determine target list
if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  # All running cline-* containers per Artemis
  mapfile -t TARGETS < <(ssh -o ConnectTimeout=5 artemis 'incus list -c ns -f csv' \
    | awk -F, '/^cline-/ && $2=="RUNNING" {print $1}')
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "no running cline-* containers found"
  exit 0
fi

echo "pushing key to: ${TARGETS[*]}"

for NAME in "${TARGETS[@]}"; do
  echo "--- $NAME ---"
  ssh -o ConnectTimeout=10 artemis "incus exec '$NAME' --env CLINE_API_KEY='$KEY' -- python3 -c '
import json, os
key = os.environ[\"CLINE_API_KEY\"]
for p in [\"/home/emsuserver/.cline/data/secrets.json\", \"/home/emsuserver/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/secrets.json\"]:
    try:
        d = json.load(open(p))
    except Exception:
        d = {}
    d[\"apiKey\"] = key
    try:
        json.dump(d, open(p, \"w\"))
        print(\"  set:\", p)
    except Exception as e:
        print(\"  skip\", p, str(e)[:60])
'" 2>&1 | grep -vF "$KEY" || true
done

echo "done."

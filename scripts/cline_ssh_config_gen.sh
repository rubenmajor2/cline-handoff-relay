#!/opt/homebrew/bin/bash
# cline_ssh_config_gen.sh — auto-generate SSH config block for cline-1..cline-N containers
# Requires bash 4+ (associative arrays). macOS default bash 3.2 won't work; use Homebrew bash.
# 2026-05-09 11:40 PT — task #1778303827328 idea #1797 Phase 2
# 
# Idempotent. Sentinel block strategy: only the lines between BEGIN/END are replaced.
# Hand-edited entries (cline-poc, artemis, wopr) are untouched.
#
# Run on demand or hourly via launchd. Safe.
set -euo pipefail

CFG="$HOME/.ssh/config"
KH="$HOME/.ssh/known_hosts.cline-clones"
TMP=$(mktemp)
BEGIN="# >>> cline-autogen BEGIN — managed by cline_ssh_config_gen.sh"
END="# <<< cline-autogen END"

# Get container IPs from Artemis. 3s timeout. Fall back to deterministic if Artemis is offline.
declare -A IPS
if MAP=$(ssh -o ConnectTimeout=3 artemis 'incus ls -c ns4 -f csv' 2>/dev/null); then
  while IFS=, read -r name state ip4_with_iface; do
    [[ "$name" =~ ^cline-[0-9]+$ ]] || continue
    [[ "$state" == "RUNNING" ]] || continue
    ip=$(echo "$ip4_with_iface" | awk '{print $1}')
    [[ -n "$ip" ]] && IPS[$name]=$ip
  done <<<"$MAP"
fi

# Build new block
{
  echo "$BEGIN"
  echo "# Generated $(date '+%Y-%m-%d %H:%M %Z')"
  for N in 1 2 3 4 5 6 7 8 9; do
    NAME="cline-$N"
    IP="${IPS[$NAME]:-}"
    if [[ -z "$IP" ]]; then
      # fallback: skip emission if we can't resolve (don't pollute config with dead IPs)
      continue
    fi
    cat <<EOF
Host $NAME
  HostName $IP
  User emsuserver
  ProxyJump artemis
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  StrictHostKeyChecking accept-new
  UserKnownHostsFile $KH
EOF
    echo
  done
  echo "$END"
} > "$TMP"

# Replace block in $CFG (or append if first time)
if grep -qF "$BEGIN" "$CFG" 2>/dev/null; then
  awk -v begin="$BEGIN" -v end="$END" -v tmpfile="$TMP" '
    BEGIN { skip = 0 }
    $0 == begin { while ((getline line < tmpfile) > 0) print line; skip = 1; next }
    skip && $0 == end { skip = 0; next }
    !skip { print }
  ' "$CFG" > "${CFG}.new"
  mv "${CFG}.new" "$CFG"
  chmod 600 "$CFG"
else
  echo "" >> "$CFG"
  cat "$TMP" >> "$CFG"
fi

# Ensure separate known_hosts file exists
touch "$KH"
chmod 600 "$KH"

# Cleanup: prune known_hosts entries for cline-N that no longer exist
if [[ -f "$KH" ]]; then
  for N in 1 2 3 4 5 6 7 8 9; do
    NAME="cline-$N"
    if [[ -z "${IPS[$NAME]:-}" ]]; then
      ssh-keygen -R "$NAME" -f "$KH" 2>/dev/null || true
    fi
  done
fi

rm -f "$TMP"
echo "ssh config updated. cline-N entries:"
for N in 1 2 3 4 5 6 7 8 9; do
  NAME="cline-$N"
  echo "  $NAME -> ${IPS[$NAME]:-<unresolved, skipped>}"
done

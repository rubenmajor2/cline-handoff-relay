#!/bin/bash
#
# powerhouse_bootstrap.sh — Run this ON THE POWERHOUSE to start the Cline config merge.
# Created 2026-07-10 by Cline (Cicero) for the Cicero <-> Powerhouse best-of-both-worlds merge.
#
# What it does:
#   1. Enables Remote Login (SSH) if off  (asks for sudo password once)
#   2. Installs Cicero's public keys into ~/.ssh/authorized_keys (passwordless SSH from Cicero)
#   3. Writes a full Cline config inventory to ~/Desktop/POWERHOUSE_CLINE_INVENTORY.md
#   4. Prints machine identity so Cicero knows where to connect
#
set -uo pipefail

echo "=== [1/4] Enabling Remote Login (SSH) ==="
if sudo systemsetup -getremotelogin 2>/dev/null | grep -qi "On"; then
    echo "Remote Login already ON"
else
    sudo systemsetup -setremotelogin on && echo "Remote Login turned ON"
fi

echo ""
echo "=== [2/4] Installing Cicero SSH keys ==="
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
K1='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPTOUMFb0ugliFDdij6bFcqy9kLi+0Y/J6npuPhZS3uN rubenmajor@Rubens-MacBook-Pro.local'
K2='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID42fluMooUnHR9tfkejbh8kk3H/H/jwFMrR5Lg2JMUn cicero-to-maximus'
grep -qF "$K1" ~/.ssh/authorized_keys || echo "$K1" >> ~/.ssh/authorized_keys
grep -qF "$K2" ~/.ssh/authorized_keys || echo "$K2" >> ~/.ssh/authorized_keys
echo "Cicero keys installed ($(grep -c ssh-ed25519 ~/.ssh/authorized_keys) total keys in authorized_keys)"

echo ""
echo "=== [3/4] Writing Cline config inventory ==="
OUT=~/Desktop/POWERHOUSE_CLINE_INVENTORY.md
{
    echo "# Powerhouse Cline Inventory — $(date '+%Y-%m-%d %H:%M %Z')"
    echo ""
    echo "## Machine identity"
    echo '```'
    hostname
    scutil --get ComputerName 2>/dev/null
    scutil --get LocalHostName 2>/dev/null
    system_profiler SPHardwareDataType 2>/dev/null | grep -E "Model|Chip|Cores|Memory|Serial"
    sw_vers
    echo "LAN IP: $(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
    echo '```'
    echo ""
    echo "## ~/Documents/Cline/ top level"
    echo '```'
    ls -la ~/Documents/Cline/ 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## Rules/ (hardfloor)"
    echo '```'
    ls -la ~/Documents/Cline/Rules/ 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## Rules-archive/ count + newest 20"
    echo '```'
    ls ~/Documents/Cline/Rules-archive/ 2>/dev/null | wc -l
    ls -lat ~/Documents/Cline/Rules-archive/ 2>/dev/null | head -22
    echo '```'
    echo ""
    echo "## scripts/"
    echo '```'
    ls -la ~/Documents/Cline/scripts/ 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## Files modified in last 14 days under ~/Documents/Cline/"
    echo '```'
    find ~/Documents/Cline/ -maxdepth 2 -mtime -14 -type f 2>/dev/null | sort
    echo '```'
    echo ""
    echo "## Cline runtime state (~/.cline/data/)"
    echo '```'
    ls -la ~/.cline/data/ 2>/dev/null || echo "MISSING (~/.cline not present)"
    echo '```'
    echo ""
    echo "## globalState.json (full)"
    echo '```json'
    cat ~/.cline/data/globalState.json 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## MCP settings (cline_mcp_settings.json)"
    echo '```json'
    cat ~/Library/Application\ Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## VS Code User settings.json"
    echo '```json'
    cat ~/Library/Application\ Support/Code/User/settings.json 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## VS Code keybindings.json"
    echo '```json'
    cat ~/Library/Application\ Support/Code/User/keybindings.json 2>/dev/null || echo "MISSING"
    echo '```'
    echo ""
    echo "## Cline extension version(s)"
    echo '```'
    ls -d ~/.vscode/extensions/saoudrizwan.claude-dev-* 2>/dev/null
    ls -d ~/Library/Application\ Support/Code/User/globalStorage/saoudrizwan.claude-dev 2>/dev/null
    echo '```'
    echo ""
    echo "## LaunchAgents (Cline/MCP/tunnel related)"
    echo '```'
    ls -la ~/Library/LaunchAgents/ 2>/dev/null | grep -iE "mcp|cline|emsu|tunnel" || echo "none"
    echo '```'
    echo ""
    echo "## MCP tunnel / helper scripts in ~/bin"
    echo '```'
    ls -la ~/bin/ 2>/dev/null | grep -iE "mcp|tunnel|emsu|brave" || echo "none"
    echo '```'
    echo ""
    echo "## Node versions"
    echo '```'
    /opt/homebrew/bin/node --version 2>/dev/null || echo "no homebrew node"
    /opt/homebrew/opt/node@22/bin/node --version 2>/dev/null || echo "no node@22"
    echo '```'
} > "$OUT" 2>&1
echo "Inventory written to $OUT ($(wc -l < "$OUT") lines)"

echo ""
echo "=== [4/4] Identity summary (tell Cicero) ==="
echo "Hostname:  $(hostname)"
echo "LocalHost: $(scutil --get LocalHostName 2>/dev/null)"
echo "LAN IP:    $(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
echo "User:      $(whoami)"
echo ""
echo "DONE. Now go back to the Cline window on Cicero and say:"
echo "  'Powerhouse bootstrap done, IP is <the LAN IP above>'"

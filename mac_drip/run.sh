#!/bin/bash
# mac_drip/run.sh — launchd wrapper for drip.py
# Logs everything to /tmp/cline-mac-drip.log via drip.py itself, plus
# launchd's StandardOutPath / StandardErrorPath. Always exit 0.
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd "$HOME/Documents/Cline/mac_drip" || exit 0
/usr/bin/python3 "$HOME/Documents/Cline/mac_drip/drip.py" >> /tmp/cline-mac-drip.log 2>&1
exit 0

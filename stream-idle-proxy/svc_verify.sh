#!/usr/bin/env bash
OUT=/tmp/svc_verify.txt
: > "$OUT"
PL=/Users/rubenmajor/Library/LaunchAgents/com.emsu.cline-stream-idle-proxy.plist
echo "=== plist ProgramArguments ===" >> "$OUT"
grep -A3 ProgramArguments "$PL" >> "$OUT" 2>&1
echo "=== reload ===" >> "$OUT"
launchctl unload "$PL" 2>>"$OUT"
sleep 1
launchctl load "$PL" 2>>"$OUT"
sleep 3
echo "=== launchctl list ===" >> "$OUT"
launchctl list 2>/dev/null | grep cline-stream-idle-proxy >> "$OUT" 2>&1 || echo "NOT_LOADED" >> "$OUT"
echo "=== stdout log ===" >> "$OUT"; cat /tmp/cline-stream-idle-proxy.log >> "$OUT" 2>&1
echo "=== stderr log ===" >> "$OUT"; cat /tmp/cline-stream-idle-proxy.err >> "$OUT" 2>&1
echo "=== live happy-path through proxy 8788 -> tunnel 8787 -> wopr:4000 ===" >> "$OUT"
curl -s -o /dev/null -w "via-proxy-8788  HTTP=%{http_code} time=%{time_total}s\n" --max-time 20 http://127.0.0.1:8788/v1/models >> "$OUT" 2>&1
curl -s -o /dev/null -w "direct-8787     HTTP=%{http_code} time=%{time_total}s\n" --max-time 20 http://127.0.0.1:8787/v1/models >> "$OUT" 2>&1
echo "(done)" >> "$OUT"

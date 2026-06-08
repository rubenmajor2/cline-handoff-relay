#!/usr/bin/env bash
# Acceptance test for #10529 part 2. Writes all results to /tmp/idle_proxy_test.txt
set -u
cd /Users/rubenmajor/Documents/Cline/stream-idle-proxy
OUT=/tmp/idle_proxy_test.txt
: > "$OUT"

pkill -f stall-server.js 2>/dev/null; pkill -f "stream-idle-proxy/proxy.js" 2>/dev/null; sleep 1
STALL_PORT=9911 node stall-server.js > /tmp/stall.log 2>&1 &
IDLE_MS=8000 CONNECT_MS=8000 PROXY_PORT=8789 UPSTREAM_HOST=127.0.0.1 UPSTREAM_PORT=9911 node proxy.js > /tmp/proxy.log 2>&1 &
sleep 1

dur() { # $1=label  $2=full curl args...
  local label="$1"; shift
  local t0 t1
  t0=$(python3 -c 'import time;print(time.time())')
  local code
  code=$("$@" 2>/dev/null)
  t1=$(python3 -c 'import time;print(time.time())')
  printf '%s :: elapsed=%.1fs :: %s\n' "$label" "$(echo "$t1 - $t0" | bc -l)" "$code" >> "$OUT"
}

{
  echo "=== procs up ==="; cat /tmp/stall.log; cat /tmp/proxy.log; echo
  echo "================ BEFORE: Cline-today behavior = DIRECT to stalled stream ================"
} >> "$OUT"
dur "BEFORE direct /stall-midstream (curl --max-time 30 = curl's OWN wall; Cline has NO such wall so it hangs forever)" \
    curl -s -N --max-time 30 -o /dev/null -w "HTTP=%{http_code}" http://127.0.0.1:9911/stall-midstream

{
  echo
  echo "================ AFTER: through idle-read proxy (idle deadline = 8s) ================"
} >> "$OUT"
dur "AFTER  proxy /stall-midstream (headers+2 chunks then silence -> socket destroyed)" \
    curl -s -N --max-time 60 -o /dev/null -w "HTTP=%{http_code}" http://127.0.0.1:8789/stall-midstream
dur "AFTER  proxy /stall-prebody   (headers only then silence -> socket destroyed)" \
    curl -s -N --max-time 60 -o /dev/null -w "HTTP=%{http_code}" http://127.0.0.1:8789/stall-prebody
dur "AFTER  proxy /stall-preheader (no response at all -> clean 504 retryable)" \
    curl -s    --max-time 60 -o /dev/null -w "HTTP=%{http_code}" http://127.0.0.1:8789/stall-preheader

{
  echo
  echo "================ HAPPY PATH: normal stream passes through cleanly ================"
} >> "$OUT"
dur "HAPPY  proxy /ok (3 chunks + [DONE])" \
    curl -s -N --max-time 60 -o /tmp/ok_body.txt -w "HTTP=%{http_code}" http://127.0.0.1:8789/ok
echo "  /ok body received:" >> "$OUT"; sed 's/^/    /' /tmp/ok_body.txt >> "$OUT"

{
  echo
  echo "================ PROXY LOG (ABORT lines = idle deadline firing) ================"
  cat /tmp/proxy.log
} >> "$OUT"

pkill -f stall-server.js 2>/dev/null; pkill -f "stream-idle-proxy/proxy.js" 2>/dev/null
echo "(done)" >> "$OUT"

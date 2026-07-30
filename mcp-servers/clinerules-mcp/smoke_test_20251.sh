#!/usr/bin/env bash
# smoke_test_20251.sh — verifies idea #20251 structural gate end to end.
#
# Test 1: FAILING result_text  -> gate file MUST be created, check_gate MUST say BLOCKED
# Test 2: PASSING result_text  -> gate file MUST be deleted, check_gate MUST say CLEAR
#
# Drives the MCP over stdio with raw JSON-RPC so we exercise the real handler,
# not a re-implementation of it.

set -uo pipefail
cd "$(dirname "$0")"

TASK_ID="smoke20251"
GATE_FILE="${TMPDIR:-/tmp}clinerules_completion_gate_BLOCKED_${TASK_ID}"
GATE_FILE="${GATE_FILE//\/\//\/}"

rm -f "$GATE_FILE"

DIV=$(node -e 'process.stdout.write(String.fromCodePoint(0x2550).repeat(47))')

# A result_text that FAILS (bare idea number, no brackets, no pickup block)
FAIL_TEXT="Done. Touched #2109 and #1993. Nothing else."

# A result_text that PASSES (full rule-91 block, every number bracketed)
PASS_TEXT="Fix shipped. EXCLUDED: #2109 [deployed] (repro only). EXCLUDED: #1993 [deployed] (repro only).

${DIV}
PICKUP PROMPT (paste into a fresh Cline window)
${DIV}

Pick up task #20251 [proposed] - smoke test of the structural gate

Where we left off (verified 2026-07-30 12:01 PT):
- Gate file logic verified working via this smoke test. #20251 [proposed]

Open threads to drive next:
None - smoke test only.

Reference IDs:
- Ideas filed: #20251 [proposed]
- Files touched: build/index.js

When done, append to cline_task_ledger.md per rule 07, run order 66.
${DIV}"

call_validate () {
  local text="$1"
  node -e '
const { spawn } = require("child_process");
const text = process.argv[1];
const taskId = process.argv[2];
const p = spawn("node", ["build/index.js"], { stdio: ["pipe","pipe","pipe"] });
let out = "";
p.stdout.on("data", d => out += d.toString());
const send = (o) => p.stdin.write(JSON.stringify(o) + "\n");
send({ jsonrpc:"2.0", id:1, method:"initialize", params:{ protocolVersion:"2024-11-05", capabilities:{}, clientInfo:{name:"smoke",version:"1"} } });
setTimeout(() => {
  send({ jsonrpc:"2.0", method:"notifications/initialized", params:{} });
  send({ jsonrpc:"2.0", id:2, method:"tools/call", params:{ name:"clinerules_validate_completion", arguments:{ result_text: text, task_id: taskId } } });
}, 400);
setTimeout(() => {
  const lines = out.split("\n").filter(Boolean);
  for (const l of lines) {
    try { const j = JSON.parse(l); if (j.id === 2) { console.log(j.result.content[0].text.split("\n")[0]); } } catch(e){}
  }
  p.kill();
  process.exit(0);
}, 2500);
' "$text" "$TASK_ID"
}

call_check_gate () {
  node -e '
const { spawn } = require("child_process");
const taskId = process.argv[1];
const p = spawn("node", ["build/index.js"], { stdio: ["pipe","pipe","pipe"] });
let out = "";
p.stdout.on("data", d => out += d.toString());
const send = (o) => p.stdin.write(JSON.stringify(o) + "\n");
send({ jsonrpc:"2.0", id:1, method:"initialize", params:{ protocolVersion:"2024-11-05", capabilities:{}, clientInfo:{name:"smoke",version:"1"} } });
setTimeout(() => {
  send({ jsonrpc:"2.0", method:"notifications/initialized", params:{} });
  send({ jsonrpc:"2.0", id:2, method:"tools/call", params:{ name:"clinerules_check_gate", arguments:{ task_id: taskId } } });
}, 400);
setTimeout(() => {
  const lines = out.split("\n").filter(Boolean);
  for (const l of lines) {
    try { const j = JSON.parse(l); if (j.id === 2) { console.log(j.result.content[0].text.split("\n")[0]); } } catch(e){}
  }
  p.kill();
  process.exit(0);
}, 2500);
' "$TASK_ID"
}

echo "=== TEST 1: FAILING result_text should CREATE the gate file ==="
echo "validate ->  $(call_validate "$FAIL_TEXT")"
if [ -f "$GATE_FILE" ]; then
  echo "gate file ->  PRESENT (correct)"
else
  echo "gate file ->  MISSING (WRONG - patch 1 not working)"
fi
echo "check_gate -> $(call_check_gate)"

echo ""
echo "=== TEST 2: PASSING result_text should DELETE the gate file ==="
echo "validate ->  $(call_validate "$PASS_TEXT")"
if [ -f "$GATE_FILE" ]; then
  echo "gate file ->  STILL PRESENT (WRONG - delete-on-pass not working)"
else
  echo "gate file ->  GONE (correct)"
fi
echo "check_gate -> $(call_check_gate)"

rm -f "$GATE_FILE"
echo ""
echo "Smoke test complete. Gate path used: $GATE_FILE"

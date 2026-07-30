#!/usr/bin/env node
/**
 * patch_gate_20251.js — idea #20251
 *
 * Makes clinerules_validate_completion STRUCTURAL instead of advisory.
 *
 * Root cause (2026-07-30): the validator returned "❌ RULE 91 GATES: N FAILURE(S)"
 * but had zero side effects. Agents read the failure text, then called
 * attempt_completion anyway. Nothing stopped them.
 *
 * Fix:
 *   PATCH 1 — on FAILURE write /tmp/clinerules_completion_gate_BLOCKED_<task_id>;
 *             on PASS delete it.
 *   PATCH 2 — new tool clinerules_check_gate(task_id) that reports BLOCKED/CLEAR.
 *
 * Idempotent: exits 0 with a notice if already patched.
 */
const fs = require('fs');
const path = require('path');

const TARGET = path.join(__dirname, 'build', 'index.js');
let content = fs.readFileSync(TARGET, 'utf8');

if (content.includes('STRUCTURAL GATE (idea #20251)')) {
  console.log('ALREADY PATCHED: build/index.js already contains idea #20251 gate logic. No-op.');
  process.exit(0);
}

fs.writeFileSync(TARGET + '.bak-pre-20251', content);
console.log('Backup written: build/index.js.bak-pre-20251');

// ─── PATCH 1: gate file write on FAILURE / delete on PASS ────────────────────
// Anchor on the validation-telemetry catch inside clinerules_validate_completion,
// which sits immediately after `const pass = failures.length === 0;`.
const passIdx = content.indexOf('const pass = failures.length === 0;');
if (passIdx === -1) {
  console.error('FAIL: could not find "const pass = failures.length === 0;" anchor.');
  process.exit(1);
}

// Find the end of the telemetry try/catch that follows the pass computation.
const catchIdx = content.indexOf('catch', passIdx);
const catchEnd = content.indexOf('}', content.indexOf('{', catchIdx)) + 1;
if (catchIdx === -1 || catchEnd <= 0) {
  console.error('FAIL: could not locate telemetry catch block after pass computation.');
  process.exit(1);
}

const gateBlock = [
  '',
  '    // \u2500\u2500 STRUCTURAL GATE (idea #20251) \u2500\u2500',
  '    // Before this patch the validator was purely ADVISORY: it returned a failure',
  '    // report and did nothing else, so agents read the failures and called',
  '    // attempt_completion anyway. Now a FAILURE writes a gate file that',
  '    // clinerules_check_gate reads, giving the gate a real side effect.',
  '    const gateFile = path.join(os.tmpdir(), task_id',
  '        ? "clinerules_completion_gate_BLOCKED_" + task_id',
  '        : "clinerules_completion_gate_BLOCKED");',
  '    try {',
  '        if (pass) {',
  '            if (fs.existsSync(gateFile)) fs.unlinkSync(gateFile);',
  '        }',
  '        else {',
  '            fs.writeFileSync(gateFile, JSON.stringify({',
  '                blocked: true,',
  '                task_id: task_id || "unknown",',
  '                failures: failures,',
  '                timestamp: new Date().toISOString(),',
  '                message: "attempt_completion is BLOCKED. Fix the failures, re-run clinerules_validate_completion, then clinerules_check_gate."',
  '            }, null, 2));',
  '        }',
  '    }',
  '    catch (e) {',
  '        if (!pass) failures.push("GATE_FILE_WRITE_FAILED: " + e.message);',
  '    }',
].join('\n');

content = content.slice(0, catchEnd) + gateBlock + content.slice(catchEnd);
console.log('PATCH 1 OK: gate file write/delete injected into clinerules_validate_completion.');

// ─── PATCH 2: new clinerules_check_gate tool ─────────────────────────────────
const statsAnchor = 'server.tool("clinerules_stats"';
const statsIdx = content.indexOf(statsAnchor);
if (statsIdx === -1) {
  console.error('FAIL: could not find clinerules_stats tool anchor for PATCH 2.');
  process.exit(1);
}

const checkGateTool = [
  'server.tool("clinerules_check_gate", "PRE-COMPLETION GATE CHECK (idea #20251): reports whether a validation gate file is blocking attempt_completion. Call this AFTER clinerules_validate_completion and BEFORE attempt_completion. BLOCKED means you must fix the listed failures and re-validate. CLEAR means it is safe to ship.", {',
  '    task_id: zod_1.z.string().describe("The Cline task ID whose gate file should be checked."),',
  '}, async ({ task_id }) => {',
  '    const gateFile = path.join(os.tmpdir(), task_id',
  '        ? "clinerules_completion_gate_BLOCKED_" + task_id',
  '        : "clinerules_completion_gate_BLOCKED");',
  '    try {',
  '        if (fs.existsSync(gateFile)) {',
  '            const data = JSON.parse(fs.readFileSync(gateFile, "utf-8"));',
  '            return {',
  '                content: [{',
  '                    type: "text",',
  '                    text: "\\u274c RULE 91 GATE BLOCKED\\n\\nGate file: " + gateFile',
  '                        + "\\nTask ID: " + data.task_id',
  '                        + "\\nFailures: " + (data.failures || []).join("; ")',
  '                        + "\\n\\nattempt_completion is BLOCKED. Fix the failures above, call clinerules_validate_completion again, then re-run this check. Do NOT call attempt_completion while this gate is blocked.",',
  '                }],',
  '            };',
  '        }',
  '        return {',
  '            content: [{',
  '                type: "text",',
  '                text: "\\u2705 RULE 91 GATE CLEAR\\n\\nNo gate file at " + gateFile + ". Safe to call attempt_completion.",',
  '            }],',
  '        };',
  '    }',
  '    catch (e) {',
  '        return {',
  '            content: [{',
  '                type: "text",',
  '                text: "\\u274c GATE_CHECK_ERROR: could not read gate file " + gateFile + ": " + e.message,',
  '            }],',
  '        };',
  '    }',
  '});',
  '',
].join('\n');

content = content.slice(0, statsIdx) + checkGateTool + content.slice(statsIdx);
console.log('PATCH 2 OK: clinerules_check_gate tool injected before clinerules_stats.');

fs.writeFileSync(TARGET, content);

const p1 = (content.match(/STRUCTURAL GATE \(idea #20251\)/g) || []).length;
const p2 = (content.match(/clinerules_check_gate/g) || []).length;
console.log('WROTE build/index.js — verification: patch1 markers=' + p1 + ', check_gate refs=' + p2 + ', bytes=' + content.length);

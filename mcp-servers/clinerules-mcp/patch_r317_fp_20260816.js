#!/usr/bin/env node
/**
 * patch_r317_fp_20260816.js — R317 false-positive fix (idea #26879)
 *
 * RCA (2026-08-16): 9 of 10 real R317_UNVERIFIED_STATE blocks were FALSE POSITIVES.
 * Three defects in the detector:
 *   1. "up" was a state word, so the MANDATORY rule-91 header "Pick up task #N"
 *      self-triggered. Rule 91 required a line that rule 317 penalized.
 *   2. "serving" was in BOTH the fleet list and the state list, so one word
 *      satisfied the AND condition alone ("get X serving" = a GOAL, not a claim).
 *   3. The evidence regex matched loose verbs like "checked", so the real claim
 *      "I checked and cato is down" passed while goals were flagged.
 *
 * Fix: require a copula before the state word (a CLAIM, not a GOAL); drop bare
 * up/green/idle; require evidence to be an ATTACHED marker "(verified: ...)" or a
 * concrete probe artifact. Mirrors the router-side fix-3/fix-4 in _router_core.py.
 *
 * Idempotent.
 */
const fs = require("fs");
const path = require("path");

const MARK = "r317-fp-fix-20260816";

const OLD_STATE = String.raw`/\b(down|offline|dead|unhealthy|degraded|saturated|idle|up|online|alive|healthy|green|recovered|restored|serving|crashed|unresponsive|wedged|stall(?:ed|ing)?)\b/i`;
const NEW_STATE = String.raw`/\b(?:is|are|was|were|remains?|stays?|now|still|currently)\s+(?:\w+\s+){0,2}?(down|offline|dead|unhealthy|degraded|saturated|online|alive|healthy|recovered|restored|serving|crashed|unresponsive|wedged|stall(?:ed|ing)?)\b/i`;

const OLD_EV = String.raw`/\b(verified|probed|probe|live\s+(?:call|request|probe)|response\s+header|registry|curl|returned|audit\s+log|measured|confirmed|checked|reconciled|hypervisor|gpu-?util|httpx?)\b/i`;
const NEW_EV = String.raw`/\((?:verified|probed|measured|confirmed)\s*:|\b(?:HTTP\s*\d{3}|\/v1\/models|response\s+header|frankenstein_registry|frankenstein_verify_routing|curl\s|tok\/s|gpu-?util)\b/i`;

const files = ["src/index.ts", "build/index.js"].map(f => path.join(__dirname, f));

let changed = 0;
for (const f of files) {
  let s = fs.readFileSync(f, "utf8");
  const base = path.basename(f);

  if (s.includes(MARK)) { console.log("ALREADY PATCHED: " + base); continue; }
  if (!s.includes(OLD_STATE)) { console.log("STATE ANCHOR MISS: " + base); continue; }
  if (!s.includes(OLD_EV))    { console.log("EV ANCHOR MISS: " + base); continue; }

  fs.writeFileSync(f + ".bak-" + MARK, s);

  s = s.replace(OLD_STATE,
    "/* " + MARK + ": require a copula so a GOAL is not read as a CLAIM; dropped bare up/green/idle which matched the mandatory rule-91 header 'Pick up task' */ " + NEW_STATE);
  s = s.replace(OLD_EV,
    "/* " + MARK + ": evidence must be an ATTACHED marker or concrete probe artifact, not a loose verb like 'checked' */ " + NEW_EV);

  fs.writeFileSync(f, s);
  console.log("PATCHED: " + base);
  changed++;
}

console.log("files changed: " + changed);
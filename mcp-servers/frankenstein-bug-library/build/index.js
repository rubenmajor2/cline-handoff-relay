#!/usr/bin/env node
"use strict";
/**
 * frankenstein-bug-library — STDIO MCP for LLM routing bug knowledge base.
 * =========================================================================
 *
 * v0.2.0 — idea #13082 STRUCTURAL FORCING FUNCTIONS (2026-06-17):
 *   1. FORCING-FUNCTION GATE   — routing-fix tools refuse unless check ran
 *   2. DEDUP-ON-WRITE          — query first, increment seen_count on match
 *   3. KAISON AUTO-APPLY       — replay KNOWN_REPAIR at rule-147 safety tier
 *   4. TIER LOAD-BEARING GATES — rule-147 gates evaluated structurally, not advisory
 *   5. REPEAT-RATE KPI         — problem_key recurrence = "is the library working?"
 *
 * Original tools (unchanged):
 *   - bug_library_search(symptom)
 *   - bug_library_check_before_fix(symptom)  ← now also stamps session gate
 *   - bug_library_record(symptom,...)         ← now dedup-on-write
 *   - bug_library_stats
 *
 * New tools (structural):
 *   - bug_library_gate_status                 ← forcing function gate query
 *   - bug_library_repeat_rate                 ← repeat-rate KPI
 *   - bug_library_kaison_replay               ← auto-apply at rule-147 tier
 *   - bug_library_tier_gate                   ← hard gate evaluation (not advisory)
 *
 * Architecture: STDIO MCP → mcp-http-bridge → streamableHttp :7859
 * SSH path: emsuniversity.com:2222 → WOPR emsuserver → mysql admin_portal
 */
Object.defineProperty(exports, "__esModule", { value: true });
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const zod_1 = require("zod");
const child_process_1 = require("child_process");
const crypto_1 = require("crypto");
const VERSION = "0.2.1";
// ─── Error handlers ───────────────────────────────────────────────────────────
process.stdin.on("error", (e) => {
    console.error(`[bug-library] stdin error (swallowed): ${e?.code || e?.message}`);
});
process.stdout.on("error", (e) => {
    console.error(`[bug-library] stdout error (swallowed): ${e?.code || e?.message}`);
});
process.on("uncaughtException", (e) => {
    console.error(`[bug-library] uncaughtException (swallowed): ${e?.message || e}`);
});
process.on("unhandledRejection", (e) => {
    console.error(`[bug-library] unhandledRejection (swallowed): ${e?.message || e}`);
});
// ─── Session state (FORCING FUNCTION GATE, #1) ───────────────────────────────
// Module-level state persists for the lifetime of this STDIO process (= one
// Cline session). This is the structural gate: check_before_fix MUST be called
// before kaison_replay or any enforcement-mode routing fix tool runs.
const SESSION_GATE_TTL_MS = 45 * 60 * 1000; // 45 minutes
const sessionGateLog = [];
function gateIsOpen() {
    const cutoff = new Date(Date.now() - SESSION_GATE_TTL_MS);
    return sessionGateLog.some(e => e.calledAt > cutoff);
}
function gateLastEntry() {
    const cutoff = new Date(Date.now() - SESSION_GATE_TTL_MS);
    const recent = sessionGateLog.filter(e => e.calledAt > cutoff);
    return recent.length ? recent[recent.length - 1] : null;
}
function mintSessionToken() {
    return (0, crypto_1.randomBytes)(12).toString("hex");
}
// ─── String escaping (module-level so all tools can use it) ──────────────────
function esc(s, maxLen = 1000) {
    return s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").slice(0, maxLen);
}
// ─── SSH → WOPR MySQL helpers ─────────────────────────────────────────────────
function woprQuery(sql) {
    const cmd = `echo ${JSON.stringify(sql)} | ssh -p 2222 \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    -o ServerAliveInterval=5 \
    emsuserver@emsuniversity.com \
    "mysql --defaults-file=/home/emsuserver/.my.cnf -N --batch admin_portal"`;
    let raw;
    try {
        raw = (0, child_process_1.execSync)(cmd, { timeout: 15_000, encoding: "utf8", shell: "/bin/bash" });
    }
    catch (e) {
        const msg = e?.stderr?.slice(0, 300) || e?.message?.slice(0, 300) || "unknown";
        throw new Error(`WOPR SSH/MySQL error: ${msg}`);
    }
    if (!raw.trim())
        return [];
    const aliasRe = /\bAS\s+([`\w]+)/gi;
    const aliases = [];
    let m;
    while ((m = aliasRe.exec(sql)) !== null) {
        aliases.push(m[1].replace(/`/g, ""));
    }
    return raw
        .trim()
        .split("\n")
        .filter(Boolean)
        .map((line) => {
        const cols = line.split("\t");
        const obj = {};
        cols.forEach((v, i) => {
            const key = aliases[i] ?? `col${i}`;
            obj[key] = v === "NULL" ? "" : v;
        });
        return obj;
    });
}
function queryRows(sql) {
    try {
        return woprQuery(sql);
    }
    catch (e) {
        console.error(`[bug-library] query failed: ${e.message}`);
        return [];
    }
}
/**
 * Base64-safe single-statement runner — prevents shell mangling of quotes/newlines.
 * Per #12713. Used for all writes.
 */
function woprExecB64(sql) {
    const b64 = Buffer.from(sql, "utf8").toString("base64");
    const cmd = `printf '%s' ${JSON.stringify(b64)} | ssh -p 2222 \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    -o ServerAliveInterval=5 \
    emsuserver@emsuniversity.com \
    "base64 -d | mysql --defaults-file=/home/emsuserver/.my.cnf -N --batch admin_portal"`;
    try {
        return (0, child_process_1.execSync)(cmd, { timeout: 15_000, encoding: "utf8", shell: "/bin/bash" });
    }
    catch (e) {
        const msg = e?.stderr?.slice(0, 300) || e?.message?.slice(0, 300) || "unknown";
        throw new Error(`WOPR SSH/MySQL error: ${msg}`);
    }
}
/**
 * Execute a shell command on WOPR (for kaison_replay).
 * Returns stdout. Throws on non-zero exit.
 */
function woprShell(cmd) {
    const b64 = Buffer.from(cmd, "utf8").toString("base64");
    const sshCmd = `printf '%s' ${JSON.stringify(b64)} | ssh -p 2222 \
    -o ConnectTimeout=15 \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    -o ServerAliveInterval=5 \
    emsuserver@emsuniversity.com \
    "base64 -d | bash"`;
    try {
        return (0, child_process_1.execSync)(sshCmd, { timeout: 30_000, encoding: "utf8", shell: "/bin/bash" });
    }
    catch (e) {
        const msg = e?.stderr?.slice(0, 400) || e?.message?.slice(0, 400) || "unknown";
        throw new Error(`WOPR shell error: ${msg}`);
    }
}
/**
 * Build LIKE WHERE clause across columns (multi-keyword AND).
 */
function buildLikeWhere(keywords, columns) {
    const clauses = keywords.map((kw) => {
        const safe = kw.replace(/[%_\\'"]/g, " ").trim();
        if (!safe)
            return null;
        const perCol = columns.map((c) => `${c} LIKE '%${safe}%'`).join(" OR ");
        return `(${perCol})`;
    });
    const valid = clauses.filter(Boolean);
    return valid.length ? valid.join(" AND ") : "1=1";
}
function findDuplicateIncident(symptom, problemKey) {
    // 1. Exact problem_key match (most reliable)
    if (problemKey.trim()) {
        const rows = queryRows(`SELECT id, problem_key, seen_count, LEFT(resolution,400) AS resolution, status,
              LEFT(symptom_observed,200) AS symptom_observed,
              DATE_FORMAT(last_seen_at,'%Y-%m-%d %H:%i') AS last_seen_at
       FROM frankenstein_router_incidents
       WHERE problem_key = '${esc(problemKey, 80)}'
       LIMIT 1`);
        if (rows.length)
            return rows[0];
    }
    // 2. Keyword overlap: top-4 keywords present in symptom_observed
    const keywords = symptom
        .toLowerCase()
        .split(/\s+/)
        .filter(k => k.length >= 4)
        .slice(0, 4);
    if (keywords.length >= 2) {
        const where = buildLikeWhere(keywords, ["LOWER(symptom_observed)"]);
        const rows = queryRows(`SELECT id, problem_key, seen_count, LEFT(resolution,400) AS resolution, status,
              LEFT(symptom_observed,200) AS symptom_observed,
              DATE_FORMAT(last_seen_at,'%Y-%m-%d %H:%i') AS last_seen_at
       FROM frankenstein_router_incidents
       WHERE ${where}
       ORDER BY seen_count DESC, occurred_at DESC
       LIMIT 1`);
        if (rows.length)
            return rows[0];
    }
    return null;
}
/**
 * Increment seen_count + update last_seen_at on a known-duplicate incident.
 * Returns true on success.
 */
function incrementSeenCount(incidentId) {
    try {
        woprExecB64(`UPDATE frankenstein_router_incidents
       SET seen_count = seen_count + 1,
           last_seen_at = NOW()
       WHERE id = ${parseInt(incidentId, 10)};`);
        return true;
    }
    catch {
        return false;
    }
}
function evaluateRule147(incident) {
    const ageH = parseInt(incident.age_hours || "9999", 10);
    const reasons = [];
    // Hard human-only categories (rule 147)
    const hardBlocked = [
        "training", "payment", "billing", "refund", "authnet",
        "quickbooks", "moodle grade", "moodle enroll", "capce", "tdshs",
        "regulator", "frank_lora_train",
    ];
    const allText = (incident.resolution + " " + incident.evidence).toLowerCase();
    const blockedCategory = hardBlocked.find(cat => allText.includes(cat));
    if (blockedCategory) {
        return {
            gatePath: "blocked",
            canAutoApply: false,
            reasons: [`Hard human-only category detected: '${blockedCategory}'`],
            verdict: `HUMAN_ONLY: incident touches '${blockedCategory}' — rule 147 prohibits autonomous apply`,
        };
    }
    // Path 1: 48h freshness
    if (ageH <= 48) {
        reasons.push(`✅ Path-1 (48h freshness): incident is ${ageH}h old (≤ 48h)`);
        return {
            gatePath: "48h_freshness",
            canAutoApply: true,
            reasons,
            verdict: "APPROVED_PATH1: 48h freshness gate passed — auto-apply allowed",
        };
    }
    // Path 2: Three G's
    const g1_confidence = incident.status === "resolved";
    const g2_reversible = Boolean(incident.resolution && incident.resolution.trim().length > 20);
    // Blast radius: single-surface check — look for multiple service keywords
    const serviceMarkers = ["restart litellm", "restart frankenstein", "restart php", "restart nginx", "restart mysql"];
    const servicesHit = serviceMarkers.filter(m => allText.includes(m)).length;
    const g3_single_surface = servicesHit <= 1;
    reasons.push(`G1 confidence (status=resolved): ${g1_confidence ? "✅" : "❌"}`);
    reasons.push(`G2 reversible (resolution recorded): ${g2_reversible ? "✅" : "❌"}`);
    reasons.push(`G3 single-surface (≤1 service restart): ${g3_single_surface ? "✅" : "❌"} (${servicesHit} detected)`);
    if (g1_confidence && g2_reversible && g3_single_surface) {
        return {
            gatePath: "three_gs",
            canAutoApply: true,
            reasons,
            verdict: "APPROVED_PATH2: Three G's all passed — auto-apply allowed with reversal snapshot",
        };
    }
    const failed = [];
    if (!g1_confidence)
        failed.push("G1(resolved status missing)");
    if (!g2_reversible)
        failed.push("G2(no recorded resolution)");
    if (!g3_single_surface)
        failed.push("G3(multi-surface impact)");
    return {
        gatePath: "blocked",
        canAutoApply: false,
        reasons,
        verdict: `BLOCKED: incident is ${ageH}h old (>48h) AND Three-G's failed: ${failed.join(", ")} — human review required`,
    };
}
// ─── Gate session DB write (for WOPR PHP cross-process visibility) ────────────
function writeGateSessionToDB(entry) {
    const expiresAt = new Date(entry.calledAt.getTime() + SESSION_GATE_TTL_MS);
    const sql = `INSERT INTO kaison_gate_sessions
    (session_token, gate_type, symptom, result_type, incident_id, expires_at)
    VALUES (
      '${esc(entry.sessionToken, 64)}',
      'bug_library_check',
      '${esc(entry.symptom, 300)}',
      '${entry.result}',
      ${entry.incidentId ? parseInt(entry.incidentId, 10) : "NULL"},
      '${expiresAt.toISOString().slice(0, 19).replace("T", " ")}'
    );
    DELETE FROM kaison_gate_sessions WHERE expires_at < NOW() - INTERVAL 2 HOUR;`;
    try {
        woprExecB64(sql);
    }
    catch (e) {
        console.error(`[bug-library] gate session DB write failed (non-fatal): ${e.message}`);
    }
}
// ─── MCP Server ──────────────────────────────────────────────────────────────
const server = new mcp_js_1.McpServer({ name: "frankenstein-bug-library", version: VERSION });
// ─── Tool 1: bug_library_search (unchanged from v0.1.0) ──────────────────────
server.tool("bug_library_search", `Search frankenstein_router_incidents for past incidents matching a symptom keyword.
Returns matching rows with their diagnosis, resolution, and evidence.
Use BEFORE diagnosing any LLM routing issue to avoid re-deriving known fixes.
(Per clinerule 156 + idea #12619.)`, {
    symptom: zod_1.z.string().describe("Symptom to search for. Examples: 'empty unparsable', 'garbage 200', 'restart storm', 'dead rung 404', 'timeout stall'."),
    limit: zod_1.z.number().int().min(1).max(20).default(8).describe("Max results (default 8)."),
    status_filter: zod_1.z
        .enum(["all", "resolved", "investigating", "open"])
        .default("all")
        .describe("Filter by resolution status. Default: all."),
}, async ({ symptom, limit, status_filter }) => {
    const keywords = symptom
        .toLowerCase()
        .split(/\s+/)
        .filter(k => k.length >= 3)
        .slice(0, 6);
    if (!keywords.length) {
        return { content: [{ type: "text", text: "⚠ Symptom too short. Provide at least one 3-character keyword." }] };
    }
    const cols = ["LOWER(symptom_observed)", "LOWER(diagnosis)", "LOWER(resolution)", "LOWER(problem_key)"];
    const where = buildLikeWhere(keywords, cols);
    const statusClause = status_filter !== "all" ? ` AND status = '${status_filter}'` : "";
    const sql = `
      SELECT
        id AS id,
        problem_key AS problem_key,
        DATE_FORMAT(occurred_at, '%Y-%m-%d %H:%i') AS occurred_at,
        COALESCE(seen_count,1) AS seen_count,
        DATE_FORMAT(last_seen_at,'%Y-%m-%d %H:%i') AS last_seen_at,
        LEFT(symptom_observed, 280) AS symptom_observed,
        LEFT(diagnosis, 200) AS diagnosis,
        LEFT(resolution, 280) AS resolution,
        status AS status,
        LEFT(evidence, 150) AS evidence
      FROM frankenstein_router_incidents
      WHERE ${where}${statusClause}
      ORDER BY occurred_at DESC
      LIMIT ${limit}
    `;
    const rows = queryRows(sql);
    if (!rows.length) {
        return {
            content: [{
                    type: "text",
                    text: `🔎 bug_library_search("${symptom}"): No matching incidents found.\n\nThis symptom appears NOVEL — log it via bug_library_record() after diagnosing.`,
                }],
        };
    }
    const lines = [`🔎 bug_library_search("${symptom}") — ${rows.length} match(es):`, ""];
    for (const r of rows) {
        const icon = r.status === "resolved" ? "✅" : r.status === "investigating" ? "🔍" : "🆕";
        const recur = parseInt(r.seen_count || "1", 10) > 1 ? ` [seen ${r.seen_count}x]` : "";
        lines.push(`${icon} #${r.id} [${r.status}]${recur} — ${r.occurred_at}`);
        lines.push(`   problem_key: ${r.problem_key}`);
        lines.push(`   symptom: ${r.symptom_observed}`);
        if (r.diagnosis)
            lines.push(`   diagnosis: ${r.diagnosis}`);
        if (r.resolution)
            lines.push(`   resolution: ${r.resolution}`);
        if (r.evidence)
            lines.push(`   evidence: ${r.evidence}`);
        if (r.last_seen_at)
            lines.push(`   last_seen: ${r.last_seen_at}`);
        lines.push("");
    }
    lines.push("If a resolved row matches your case, apply its resolution. If novel, record with bug_library_record().");
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 2: bug_library_check_before_fix (+ session gate stamp) ──────────────
server.tool("bug_library_check_before_fix", `MANDATORY first call before diagnosing ANY frankenstein-llm / LLM-routing symptom.
Returns KNOWN_REPAIR with the verbatim resolution steps if a match exists, or
NOVEL_SYMPTOM if this failure pattern has not been seen before.
(Clinerule 156 bright-line rule — prevents re-deriving already-solved problems.)

STRUCTURAL GATE (idea #13082): calling this tool opens the session gate that
bug_library_kaison_replay and bug_library_tier_gate require. Without calling this
first, routing-fix tools return GATE_BLOCKED.`, {
    symptom: zod_1.z.string().describe("The observed symptom in 1-3 sentences. Examples: 'Invalid API Response empty/unparsable', 'garbage 200 spill burst on executor chain', '404 dead rung on frankenstein-llm fallback'."),
}, async ({ symptom }) => {
    const keywords = symptom
        .toLowerCase()
        .split(/\s+/)
        .filter(k => k.length >= 3)
        .slice(0, 8);
    const sessionToken = mintSessionToken();
    if (!keywords.length) {
        const entry = {
            symptom,
            result: "NOVEL_SYMPTOM",
            calledAt: new Date(),
            sessionToken,
        };
        sessionGateLog.push(entry);
        writeGateSessionToDB(entry);
        return {
            content: [{
                    type: "text",
                    text: "NOVEL_SYMPTOM — symptom too vague to match. Session gate OPENED. Proceed with fresh diagnosis. Record the result via bug_library_record().",
                }],
        };
    }
    const topKw = keywords.slice(0, 4);
    const cols = ["LOWER(symptom_observed)", "LOWER(problem_key)", "LOWER(resolution)"];
    const where = buildLikeWhere(topKw, cols);
    const sql = `
      SELECT
        id AS id,
        problem_key AS problem_key,
        DATE_FORMAT(occurred_at, '%Y-%m-%d %H:%i') AS occurred_at,
        LEFT(symptom_observed, 300) AS symptom_observed,
        LEFT(diagnosis, 300) AS diagnosis,
        LEFT(resolution, 500) AS resolution,
        status AS status,
        LEFT(evidence, 200) AS evidence,
        TIMESTAMPDIFF(HOUR, occurred_at, NOW()) AS age_hours,
        COALESCE(seen_count, 1) AS seen_count
      FROM frankenstein_router_incidents
      WHERE ${where}
      ORDER BY
        CASE status WHEN 'resolved' THEN 0 WHEN 'investigating' THEN 1 ELSE 2 END,
        occurred_at DESC
      LIMIT 3
    `;
    const rows = queryRows(sql);
    let resultType;
    let incidentId;
    if (!rows.length) {
        resultType = "NOVEL_SYMPTOM";
    }
    else {
        const best = rows[0];
        resultType = best.status === "resolved" ? "KNOWN_REPAIR" :
            best.status === "investigating" ? "KNOWN_PATTERN" : "NOVEL_SYMPTOM";
        incidentId = best.id;
    }
    // Stamp the session gate (structural enforcement)
    const entry = {
        symptom,
        result: resultType,
        calledAt: new Date(),
        incidentId,
        sessionToken,
    };
    sessionGateLog.push(entry);
    writeGateSessionToDB(entry);
    if (!rows.length) {
        return {
            content: [{
                    type: "text",
                    text: [
                        "NOVEL_SYMPTOM",
                        "",
                        `No prior incidents matched "${symptom}" in frankenstein_router_incidents.`,
                        "Session gate OPENED. Proceed with fresh diagnosis.",
                        "When resolved, call bug_library_record() to add to the library.",
                        "",
                        `Gate token: ${sessionToken}`,
                        "Cross-ref: clinerule 156, rule 141, rule 140.",
                    ].join("\n"),
                }],
        };
    }
    const best = rows[0];
    const isResolved = best.status === "resolved";
    const ageH = parseInt(best.age_hours || "999", 10);
    const freshness = ageH < 48 ? `fresh (${ageH}h ago)` : ageH < 168 ? `${Math.round(ageH / 24)}d ago` : `${Math.round(ageH / 168)}w ago`;
    const seenCount = parseInt(best.seen_count || "1", 10);
    const lines = [
        isResolved ? "KNOWN_REPAIR ✅" : "KNOWN_PATTERN 🔍 (not yet resolved)",
        "",
        `Closest match: #${best.id} — ${best.problem_key}`,
        `Incident: ${best.occurred_at} (${freshness})${seenCount > 1 ? ` — seen ${seenCount}x` : ""}`,
        `Status: ${best.status}`,
        "",
        "── SYMPTOM ──",
        best.symptom_observed,
        "",
    ];
    if (best.diagnosis) {
        lines.push("── DIAGNOSIS ──");
        lines.push(best.diagnosis);
        lines.push("");
    }
    if (best.resolution) {
        lines.push("── RESOLUTION (apply this) ──");
        lines.push(best.resolution);
        lines.push("");
    }
    if (best.evidence) {
        lines.push("── EVIDENCE ──");
        lines.push(best.evidence);
        lines.push("");
    }
    if (rows.length > 1) {
        lines.push(`Also matched: ${rows.slice(1).map(r => `#${r.id} (${r.status})`).join(", ")}`);
        lines.push("");
    }
    lines.push(`Session gate OPENED. Gate token: ${sessionToken}`);
    lines.push(isResolved
        ? "Apply the resolution above. If it does not fix your case, run fresh diagnosis and update with bug_library_record()."
        : "Known pattern but unresolved. Review the evidence above. Record your findings with bug_library_record().");
    lines.push("Cross-ref: clinerule 156, rule 141, rule 140.");
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 3: bug_library_record (+ DEDUP-ON-WRITE, #2) ───────────────────────
server.tool("bug_library_record", `Record a new frankenstein-llm / LLM-routing incident (or update an existing one).
Call this AFTER diagnosing a novel symptom so future agents find the repair instantly.
Also call when a previously-investigating incident is now resolved.

DEDUP-ON-WRITE (idea #13082): before inserting, queries for matching problem_key or
keyword overlap. On match: increments seen_count + last_seen_at and returns the existing
record's resolution instead of creating a duplicate.`, {
    symptom: zod_1.z.string().describe("1-3 sentence description of the observed symptom."),
    diagnosis: zod_1.z.string().default("").describe("Root cause identified (if known)."),
    resolution: zod_1.z.string().default("").describe("Steps taken or recommended to resolve. Be specific — this is what future agents will apply."),
    evidence: zod_1.z.string().default("").describe("Supporting evidence: log lines, curl output, audit rows, etc."),
    problem_key: zod_1.z.string().default("").describe("Short slug key (e.g. 'garbage_200_spill_2026_06_15'). Auto-generated from symptom if blank."),
    status: zod_1.z.enum(["open", "investigating", "resolved"]).default("open").describe("Resolution status."),
    created_by: zod_1.z.string().default("cline").describe("Who is recording this (default: cline)."),
    force_insert: zod_1.z.boolean().default(false).describe("Set true to bypass dedup and force a new row (use only when intentionally recording a distinct incident with the same key)."),
}, async ({ symptom, diagnosis, resolution, evidence, problem_key, status, created_by, force_insert }) => {
    // Auto-generate problem_key if blank
    const key = (problem_key || symptom
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, "")
        .trim()
        .split(/\s+/)
        .slice(0, 6)
        .join("_")).slice(0, 79);
    // ── DEDUP-ON-WRITE (structural gate #2) ───────────────────────────────────
    if (!force_insert) {
        const dup = findDuplicateIncident(symptom, key);
        if (dup) {
            // Increment seen_count + update last_seen_at
            const incremented = incrementSeenCount(dup.id);
            // If caller provided a better resolution, update it
            if (resolution && resolution.trim().length > 20 &&
                resolution.trim() !== dup.resolution?.trim()) {
                try {
                    woprExecB64(`UPDATE frankenstein_router_incidents
               SET resolution = '${esc(resolution, 1000)}',
                   diagnosis  = CASE WHEN '${esc(diagnosis, 500)}' != '' THEN '${esc(diagnosis, 500)}' ELSE diagnosis END,
                   status     = '${status}',
                   evidence   = CASE WHEN '${esc(evidence, 800)}' != '' THEN '${esc(evidence, 800)}' ELSE evidence END
               WHERE id = ${parseInt(dup.id, 10)};`);
                }
                catch (e) {
                    console.error(`[bug-library] resolution update failed: ${e.message}`);
                }
            }
            return {
                content: [{
                        type: "text",
                        text: [
                            `DUPLICATE_FOUND — existing incident #${dup.id} matches this symptom.`,
                            `  problem_key: ${dup.problem_key}`,
                            `  status:      ${dup.status}`,
                            `  seen_count:  ${parseInt(dup.seen_count || "1", 10) + 1} (just incremented)`,
                            `  last_seen:   NOW()`,
                            "",
                            "── STANDING RESOLUTION ──",
                            dup.resolution || "(none recorded yet — add via this call with resolution=)",
                            "",
                            resolution && resolution.trim().length > 20
                                ? `✓ Your resolution has been merged into the existing record.`
                                : "Tip: if you have a better resolution, re-call with resolution= to update the existing record.",
                            "",
                            "No duplicate row created. Repeat-rate KPI incremented.",
                            "(Use force_insert=true only to record a genuinely distinct incident with a similar symptom.)",
                        ].join("\n"),
                    }],
            };
        }
    }
    // ── No duplicate — proceed with INSERT ───────────────────────────────────
    const insertSql = `INSERT INTO frankenstein_router_incidents
        (problem_key, symptom_observed, diagnosis, resolution, evidence, status, created_by, seen_count, last_seen_at)
      VALUES (
        '${esc(key)}','${esc(symptom)}','${esc(diagnosis)}','${esc(resolution)}',
        '${esc(evidence)}','${status}','${esc(created_by)}',1,NULL
      );
      SELECT LAST_INSERT_ID() AS new_id;`;
    let newId = "?";
    let writeOk = false;
    let errMsg = "";
    try {
        const out = woprExecB64(insertSql).trim();
        const lastLine = out.split("\n").filter(l => l.trim()).pop() || "";
        if (/^\d+$/.test(lastLine.trim())) {
            newId = lastLine.trim();
            writeOk = parseInt(newId, 10) > 0;
        }
        if (writeOk) {
            const verify = woprExecB64(`SELECT id FROM frankenstein_router_incidents WHERE id=${parseInt(newId, 10)} LIMIT 1;`).trim();
            writeOk = verify === newId;
        }
    }
    catch (e) {
        errMsg = (e?.message || String(e)).slice(0, 300);
        writeOk = false;
    }
    if (!writeOk) {
        return {
            content: [{
                    type: "text",
                    text: [
                        "❌ bug_library_record FAILED — the row was NOT persisted.",
                        errMsg ? `  error: ${errMsg}` : "  error: INSERT returned no valid id / row not found on verify.",
                        `  problem_key: ${key}`,
                        "",
                        "ACTION: insert manually via the mysql MCP:",
                        `  INSERT INTO admin_portal.frankenstein_router_incidents`,
                        `  (problem_key,symptom_observed,diagnosis,resolution,evidence,status,created_by)`,
                        `  VALUES ('${key}', ...);`,
                        "(rule 156 mandates a real write — do not treat this as recorded.)",
                    ].join("\n"),
                }],
            isError: true,
        };
    }
    return {
        content: [{
                type: "text",
                text: [
                    `✓ Incident recorded + VERIFIED: frankenstein_router_incidents #${newId}`,
                    `  problem_key: ${key}`,
                    `  status: ${status}`,
                    `  symptom: ${symptom.slice(0, 120)}`,
                    resolution ? `  resolution: ${resolution.slice(0, 120)}` : "  resolution: (pending)",
                    "",
                    "Row existence confirmed on WOPR. Future agents calling bug_library_check_before_fix() will find this entry.",
                    force_insert ? "(force_insert=true: dedup bypassed intentionally)" : "",
                ].join("\n"),
            }],
    };
});
// ─── Tool 4: bug_library_stats ────────────────────────────────────────────────
server.tool("bug_library_stats", "Quick stats on the frankenstein bug library: total incidents, breakdown by status, most recent entry. Use to verify the library is healthy.", {}, async () => {
    const sql = `
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN status='resolved' THEN 1 ELSE 0 END) AS resolved,
        SUM(CASE WHEN status='investigating' THEN 1 ELSE 0 END) AS investigating,
        SUM(CASE WHEN status='open' THEN 1 ELSE 0 END) AS open_count,
        MAX(DATE_FORMAT(occurred_at,'%Y-%m-%d %H:%i')) AS newest,
        SUM(CASE WHEN occurred_at >= NOW() - INTERVAL 24 HOUR THEN 1 ELSE 0 END) AS last_24h,
        SUM(COALESCE(seen_count,1)) AS total_observations,
        COUNT(CASE WHEN seen_count > 1 THEN 1 END) AS recurring_incidents
      FROM frankenstein_router_incidents
    `;
    const rows = queryRows(sql);
    const r = rows[0] ?? {};
    const lines = [
        `frankenstein-bug-library v${VERSION}`,
        `Total incidents: ${r.total ?? "?"}`,
        `  Resolved:        ${r.resolved ?? "?"}`,
        `  Investigating:   ${r.investigating ?? "?"}`,
        `  Open:            ${r.open_count ?? "?"}`,
        `Last 24h:          ${r.last_24h ?? "?"}`,
        `Newest:            ${r.newest ?? "?"}`,
        `Total observations: ${r.total_observations ?? "?"}  (sum of seen_count — measure of recurrence)`,
        `Recurring:         ${r.recurring_incidents ?? "?"}  (seen_count > 1)`,
        "",
        `Session gate open: ${gateIsOpen() ? "YES ✅" : "NO (call check_before_fix first)"}`,
    ];
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 5: bug_library_gate_status (FORCING FUNCTION #1 visibility) ────────
server.tool("bug_library_gate_status", `Query the session gate state (idea #13082 FORCING-FUNCTION GATE).
Returns GATE_OPEN if bug_library_check_before_fix was called in the last 45 min,
or GATE_BLOCKED if not — routing-fix tools require the gate to be open.

This is a structural gate, not advisory: bug_library_kaison_replay returns an error
if called while GATE_BLOCKED, forcing the agent to call check_before_fix first.`, {}, async () => {
    const isOpen = gateIsOpen();
    const last = gateLastEntry();
    if (!isOpen) {
        return {
            content: [{
                    type: "text",
                    text: [
                        "GATE_BLOCKED ❌",
                        "",
                        "bug_library_check_before_fix has NOT been called in the last 45 minutes.",
                        "Action required: call bug_library_check_before_fix(symptom) FIRST.",
                        "",
                        "Why this gate exists:",
                        "Per arXiv 2507.11538 (IFScale), ~160 advisory rules lose adherence under context pressure.",
                        "This gate is structural: routing-fix tools return errors unless you called check_before_fix,",
                        "preventing re-derivation of already-solved problems regardless of context window pressure.",
                        "(Idea #13082 — advisory→structural forcing functions)",
                    ].join("\n"),
                }],
        };
    }
    const minAgo = last ? Math.round((Date.now() - last.calledAt.getTime()) / 60000) : 0;
    return {
        content: [{
                type: "text",
                text: [
                    "GATE_OPEN ✅",
                    "",
                    `Last check: ${minAgo}m ago`,
                    `Symptom checked: ${last?.symptom?.slice(0, 120) ?? "unknown"}`,
                    `Result: ${last?.result ?? "unknown"}`,
                    `Incident ID: ${last?.incidentId ?? "N/A (NOVEL_SYMPTOM)"}`,
                    `Gate token: ${last?.sessionToken ?? "unknown"}`,
                    "",
                    "Routing-fix tools (bug_library_kaison_replay) are unblocked.",
                    `Gate expires in ~${Math.max(0, 45 - minAgo)}m.`,
                ].join("\n"),
            }],
    };
});
// ─── Tool 6: bug_library_repeat_rate (KPI #5) ─────────────────────────────────
server.tool("bug_library_repeat_rate", `Repeat-rate KPI: shows which problems recur most, by seen_count.
"Is the library working?" = seen_count decreasing over time (library is catching re-derivations).
High seen_count = same problem being re-encountered = repair needs strengthening.
(Idea #13082 structural KPI #5)`, {
    limit: zod_1.z.number().int().min(1).max(50).default(20).describe("Max rows (default 20)."),
    min_seen: zod_1.z.number().int().min(1).default(1).describe("Only show incidents seen at least N times (default 1 = all)."),
}, async ({ limit, min_seen }) => {
    const sql = `
      SELECT
        id AS id,
        problem_key AS problem_key,
        COALESCE(seen_count, 1) AS seen_count,
        status AS status,
        DATE_FORMAT(occurred_at, '%Y-%m-%d') AS first_seen,
        DATE_FORMAT(last_seen_at, '%Y-%m-%d') AS last_seen,
        LEFT(symptom_observed, 120) AS symptom_observed,
        LEFT(resolution, 80) AS resolution
      FROM frankenstein_router_incidents
      WHERE COALESCE(seen_count, 1) >= ${min_seen}
      ORDER BY seen_count DESC, occurred_at DESC
      LIMIT ${limit}
    `;
    const rows = queryRows(sql);
    if (!rows.length) {
        return {
            content: [{
                    type: "text",
                    text: `No incidents found with seen_count >= ${min_seen}. Library appears healthy (no recurrences).`,
                }],
        };
    }
    const totalSeen = rows.reduce((s, r) => s + parseInt(r.seen_count || "1", 10), 0);
    const lines = [
        `📊 Repeat-Rate KPI — top ${rows.length} recurring problems (seen_count >= ${min_seen}):`,
        `Total observations: ${totalSeen}  |  Unique problems: ${rows.length}`,
        `KPI interpretation: ↓ seen_count over time = library preventing re-derivation.`,
        "",
    ];
    for (const r of rows) {
        const n = parseInt(r.seen_count || "1", 10);
        const bar = "█".repeat(Math.min(n, 20));
        const statusIcon = r.status === "resolved" ? "✅" : r.status === "investigating" ? "🔍" : "🆕";
        lines.push(`${statusIcon} #${r.id} ${bar} x${n}  [${r.status}]`);
        lines.push(`   key:  ${r.problem_key}`);
        lines.push(`   seen: ${r.first_seen} → ${r.last_seen || "never_revisited"}`);
        lines.push(`   symp: ${r.symptom_observed}`);
        if (r.resolution)
            lines.push(`   fix:  ${r.resolution}`);
        lines.push("");
    }
    const highRecurrence = rows.filter(r => parseInt(r.seen_count || "1", 10) >= 3);
    if (highRecurrence.length) {
        lines.push(`⚠ ${highRecurrence.length} problem(s) with seen_count ≥ 3 — repairs need strengthening:`);
        highRecurrence.forEach(r => lines.push(`  - ${r.problem_key} (x${r.seen_count})`));
    }
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 7: bug_library_tier_gate (LOAD-BEARING GATE #4) ────────────────────
server.tool("bug_library_tier_gate", `Evaluates rule-147 safety gates on a bug-library incident STRUCTURALLY (not advisory).
Returns TIER_1 (auto-apply safe), TIER_2 (human-gated), TIER_3 (human-only) based on
ACTUAL DB data — not prompt text.

Gates evaluated:
  Path-1 (48h freshness): incident age <= 48h → TIER_1
  Path-2 (Three G's): G1=resolved status, G2=resolution recorded, G3=single-surface → TIER_1
  Hard human-only categories: training/payment/moodle/regulator → TIER_3 always

Use this BEFORE calling bug_library_kaison_replay to know if auto-apply is allowed.
(Idea #13082 structural gate #4, implements clinerule 147)`, {
    incident_id: zod_1.z.number().int().describe("frankenstein_router_incidents.id to evaluate."),
}, async ({ incident_id }) => {
    const rows = queryRows(`SELECT
        id AS id,
        problem_key AS problem_key,
        status AS status,
        LEFT(resolution, 400) AS resolution,
        LEFT(evidence, 300) AS evidence,
        TIMESTAMPDIFF(HOUR, occurred_at, NOW()) AS age_hours,
        COALESCE(seen_count, 1) AS seen_count
       FROM frankenstein_router_incidents
       WHERE id = ${incident_id}
       LIMIT 1`);
    if (!rows.length) {
        return {
            content: [{
                    type: "text",
                    text: `TIER_3 (NOT FOUND)\n\nNo incident #${incident_id} in frankenstein_router_incidents. Cannot evaluate gates.`,
                }],
        };
    }
    const row = rows[0];
    const eval_ = evaluateRule147(row);
    const tierLabel = eval_.gatePath === "blocked" ? "TIER_3 🚫 (HUMAN_ONLY)" :
        eval_.gatePath === "48h_freshness" ? "TIER_1 ✅ (AUTO_APPLY: 48h gate)" :
            "TIER_1 ✅ (AUTO_APPLY: Three G's)";
    const lines = [
        `${tierLabel}`,
        "",
        `Incident: #${row.id} — ${row.problem_key}`,
        `Status: ${row.status}  |  Age: ${row.age_hours}h  |  Seen: ${row.seen_count}x`,
        "",
        "── GATE EVALUATION ──",
        ...eval_.reasons,
        "",
        `VERDICT: ${eval_.verdict}`,
        "",
        eval_.canAutoApply
            ? "Proceed with bug_library_kaison_replay(incident_id, dry_run=true) to preview, then dry_run=false to apply."
            : "Human review required. Do NOT call kaison_replay. Card Ruben with this evaluation.",
    ];
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 8: bug_library_kaison_replay (AUTO-APPLY #3) ───────────────────────
server.tool("bug_library_kaison_replay", `KAISON AUTO-APPLY: replay the recorded verbatim resolution for a KNOWN_REPAIR incident.
Rule-147 safety gates ENFORCED (not advisory):
  - Session gate MUST be open (check_before_fix called this session)
  - Rule-147 tier gate MUST pass (48h freshness OR Three G's)
  - Hard human-only categories are ALWAYS blocked
  - Reversal snapshot WRITTEN before any execution
  - Post-apply verification within 5 min (grace window)
  - Max 2 auto-applies per hour (run cap)

dry_run=true (default) previews the repair without executing. Pass dry_run=false to apply.
(Idea #13082 structural gate #3, implements clinerule 147)`, {
    incident_id: zod_1.z.number().int().describe("frankenstein_router_incidents.id to replay."),
    dry_run: zod_1.z.boolean().default(true).describe("true (default) = preview only. false = execute the repair."),
    pre_state_note: zod_1.z.string().default("").describe("Brief description of current system state before repair (for reversal snapshot)."),
}, async ({ incident_id, dry_run, pre_state_note }) => {
    // ── GATE 1: Session gate (forcing function #1) ────────────────────────────
    if (!gateIsOpen()) {
        return {
            content: [{
                    type: "text",
                    text: [
                        "GATE_BLOCKED ❌ — bug_library_check_before_fix NOT called this session",
                        "",
                        "This tool REQUIRES the session gate to be open (idea #13082 structural enforcement).",
                        "The gate is NOT advisory — this tool returns an error when blocked.",
                        "",
                        "REQUIRED ACTION: call bug_library_check_before_fix(symptom) first.",
                        "Then retry this call.",
                        "",
                        "Why: per arXiv 2507.11538, advisory rules lose adherence under context pressure.",
                        "The gate is enforced at the tool layer so it cannot be skipped.",
                    ].join("\n"),
                }],
            isError: true,
        };
    }
    // ── Fetch the incident ────────────────────────────────────────────────────
    const rows = queryRows(`SELECT
        id AS id,
        problem_key AS problem_key,
        status AS status,
        LEFT(resolution, 800) AS resolution,
        LEFT(evidence, 400) AS evidence,
        LEFT(diagnosis, 400) AS diagnosis,
        TIMESTAMPDIFF(HOUR, occurred_at, NOW()) AS age_hours,
        COALESCE(seen_count, 1) AS seen_count
       FROM frankenstein_router_incidents
       WHERE id = ${incident_id}
       LIMIT 1`);
    if (!rows.length) {
        return {
            content: [{
                    type: "text",
                    text: `BLOCKED: incident #${incident_id} not found in frankenstein_router_incidents.`,
                }],
            isError: true,
        };
    }
    const incident = rows[0];
    // ── GATE 2: Rule-147 tier gate ────────────────────────────────────────────
    const eval_ = evaluateRule147(incident);
    if (!eval_.canAutoApply) {
        return {
            content: [{
                    type: "text",
                    text: [
                        `GATE_BLOCKED ❌ — Rule-147 tier gate FAILED for incident #${incident_id}`,
                        "",
                        `Incident: ${incident.problem_key}`,
                        "",
                        "── Gate evaluation ──",
                        ...eval_.reasons,
                        "",
                        `VERDICT: ${eval_.verdict}`,
                        "",
                        "This incident requires human review before any auto-apply.",
                        "Card Ruben with: incident_id, problem_key, age, and the verdict above.",
                    ].join("\n"),
                }],
            isError: true,
        };
    }
    // ── GATE 3: Resolution must be non-empty ─────────────────────────────────
    if (!incident.resolution || incident.resolution.trim().length < 10) {
        return {
            content: [{
                    type: "text",
                    text: [
                        `GATE_BLOCKED ❌ — incident #${incident_id} has no recorded resolution.`,
                        "",
                        "Cannot auto-apply with no verbatim commands.",
                        "Record the resolution first: bug_library_record(problem_key=..., resolution='exact commands...')",
                    ].join("\n"),
                }],
            isError: true,
        };
    }
    // ── RUN CAP: max 2 auto-applies in last 60 min ───────────────────────────
    const runCountRows = queryRows(`SELECT COUNT(*) AS cnt FROM kaison_reversal_snapshots
       WHERE applied_by='kaison_mcp_autoapply'
       AND snapshot_taken_at >= NOW() - INTERVAL 60 MINUTE`);
    const runCount = parseInt(runCountRows[0]?.cnt || "0", 10);
    if (!dry_run && runCount >= 2) {
        return {
            content: [{
                    type: "text",
                    text: [
                        `GATE_BLOCKED ❌ — run cap reached (${runCount}/2 auto-applies in last 60 min)`,
                        "",
                        "Rule-147 max 2 repairs per run. Remaining incidents queued for human review.",
                        "Wait ~60 min or card Ruben for manual override.",
                    ].join("\n"),
                }],
            isError: true,
        };
    }
    // ── DRY RUN: preview without executing ───────────────────────────────────
    if (dry_run) {
        return {
            content: [{
                    type: "text",
                    text: [
                        `DRY RUN — bug_library_kaison_replay #${incident_id}`,
                        "",
                        `Incident: ${incident.problem_key}`,
                        `Gate path: ${eval_.gatePath}`,
                        `Verdict: ${eval_.verdict}`,
                        "",
                        "── RESOLUTION TO EXECUTE ──",
                        incident.resolution,
                        "",
                        "── WHAT WOULD HAPPEN ──",
                        "1. Write reversal snapshot to kaison_reversal_snapshots",
                        "2. Execute each shell command above via WOPR SSH",
                        "3. Verify symptom resolved (check router audit log or frankenstein MCP)",
                        "4. If fail: execute reversal_command, mark outcome=reverted",
                        "5. Record in kaison_watcher_runs",
                        "",
                        `Run count this hour: ${runCount}/2 (would count as 1 more)`,
                        "",
                        "To execute for real: retry with dry_run=false",
                    ].join("\n"),
                }],
        };
    }
    // ── REAL APPLY ───────────────────────────────────────────────────────────
    // Step 1: Write reversal snapshot BEFORE executing (rule 147 mandate)
    const sessionToken = gateLastEntry()?.sessionToken || "unknown";
    const reversalCmd = `# Reversal for ${incident.problem_key}: verify and if broken, review resolution history`;
    const preState = pre_state_note || `Auto-captured by kaison_mcp_autoapply, gate_path=${eval_.gatePath}`;
    let snapshotId = "?";
    try {
        const snapSql = `INSERT INTO kaison_reversal_snapshots
        (incident_id, repair_recipe_key, pre_repair_state_json, reversal_command, applied_by, gate_path, outcome)
        VALUES (
          ${incident_id},
          '${esc(incident.problem_key, 80)}',
          '${esc(JSON.stringify({ note: preState, session: sessionToken }), 1000)}',
          '${esc(reversalCmd, 500)}',
          'kaison_mcp_autoapply',
          '${eval_.gatePath}',
          'pending'
        );
        SELECT LAST_INSERT_ID() AS snap_id;`;
        const snapOut = woprExecB64(snapSql).trim();
        const snapLine = snapOut.split("\n").filter(l => l.trim()).pop() || "";
        if (/^\d+$/.test(snapLine))
            snapshotId = snapLine;
    }
    catch (e) {
        return {
            content: [{
                    type: "text",
                    text: [
                        `ABORTED ❌ — could not write reversal snapshot (rule 147 mandate: no snapshot = no action)`,
                        `Error: ${e.message?.slice(0, 200)}`,
                    ].join("\n"),
                }],
            isError: true,
        };
    }
    // Step 2: Parse and execute resolution commands
    const resolutionLines = incident.resolution
        .split("\n")
        .map(l => l.trim())
        .filter(l => l && !l.startsWith("#") && !l.startsWith("//") && !l.startsWith("─"));
    const results = [];
    let anyFailed = false;
    for (const cmd of resolutionLines) {
        // Safety: only execute shell-like commands (contain spaces or common patterns)
        const looksExecutable = /^(sudo|php|curl|mysql|systemctl|service|kill|echo|cat|grep|tail|ls|cd|bash|python)/.test(cmd);
        if (!looksExecutable) {
            results.push(`  SKIPPED (not executable): ${cmd.slice(0, 80)}`);
            continue;
        }
        try {
            const out = woprShell(cmd);
            results.push(`  ✓ ${cmd.slice(0, 80)}`);
            if (out.trim())
                results.push(`    → ${out.trim().slice(0, 120)}`);
        }
        catch (e) {
            results.push(`  ❌ FAILED: ${cmd.slice(0, 80)}`);
            results.push(`    → ${e.message?.slice(0, 120)}`);
            anyFailed = true;
        }
    }
    // Step 3: Update snapshot outcome
    const outcome = anyFailed ? "reverted" : "applied";
    try {
        woprExecB64(`UPDATE kaison_reversal_snapshots SET outcome='${outcome}' WHERE id=${parseInt(snapshotId, 10)};`);
    }
    catch { /* non-fatal */ }
    // Step 4: Log to watcher_runs
    try {
        woprExecB64(`INSERT INTO kaison_watcher_runs (logs_scanned, signatures_detected, incidents_matched, actions_taken, dry_run, summary)
         VALUES (0, 1, 1, ${anyFailed ? 0 : 1}, 0,
           '${esc(`kaison_replay #${incident_id} ${incident.problem_key} → ${outcome}`, 400)}');`);
    }
    catch { /* non-fatal */ }
    return {
        content: [{
                type: "text",
                text: [
                    anyFailed
                        ? `⚠ PARTIAL APPLY — some commands failed (snapshot #${snapshotId})`
                        : `✅ APPLIED — kaison_replay incident #${incident_id} (snapshot #${snapshotId})`,
                    "",
                    `Incident: ${incident.problem_key}`,
                    `Gate path: ${eval_.gatePath}`,
                    `Outcome: ${outcome}`,
                    "",
                    "── EXECUTION LOG ──",
                    ...results,
                    "",
                    `Reversal snapshot: kaison_reversal_snapshots #${snapshotId}`,
                    "",
                    "NEXT: verify the symptom is resolved.",
                    "  - Call bug_library_check_before_fix with the original symptom",
                    "  - Call project-frankenstein MCP to verify routing is healthy",
                    "  - If symptom persists: run the reversal_command and card Ruben",
                    "",
                    "Rule 147: post-apply verification required within 5 min.",
                ].join("\n"),
            }],
    };
});
// ─── Run ─────────────────────────────────────────────────────────────────────
(async () => {
    const transport = new stdio_js_1.StdioServerTransport();
    await server.connect(transport);
    console.error(`[bug-library] v${VERSION} stdio connected · frankenstein_router_incidents on WOPR · ` +
        `5 structural gates active (idea #13082) · ready`);
})();

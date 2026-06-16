#!/usr/bin/env node
"use strict";
/**
 * frankenstein-bug-library — STDIO MCP for LLM routing bug knowledge base.
 * =========================================================================
 *
 * Queries WOPR's frankenstein_router_incidents table over SSH, providing:
 *   - bug_library_search(symptom)         → known matching incidents + repairs
 *   - bug_library_check_before_fix(symptom) → KNOWN_REPAIR or NOVEL_SYMPTOM
 *   - bug_library_record(symptom,...)      → log a new incident
 *
 * Per idea #12619 (approved). Implements clinerule 156: agents MUST call
 * bug_library_check_before_fix before re-deriving ANY LLM routing fix.
 *
 * Architecture: STDIO MCP → mcp-http-bridge → streamableHttp :7859
 * SSH path: 127.0.0.1:2222 → WOPR emsuserver → mysql admin_portal
 */
Object.defineProperty(exports, "__esModule", { value: true });
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const zod_1 = require("zod");
const child_process_1 = require("child_process");
const VERSION = "0.1.0";
// ─── Error handlers (per clinerules-mcp mandatory-pre-flight pattern) ────────
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
/**
 * Execute a SQL query on WOPR admin_portal via SSH tunnel.
 * Returns rows as object arrays (keyed by column alias).
 * Raises on SSH/MySQL failure.
 */
function woprQuery(sql) {
    // We pass SQL via stdin to avoid shell-escaping nightmares.
    // The heredoc approach works reliably with the existing 2222 SSH setup.
    const cmd = `echo ${JSON.stringify(sql)} | ssh -p 2222 \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    -o ServerAliveInterval=5 \
    emsuserver@127.0.0.1 \
    "mysql -N --batch admin_portal"`;
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
    // Parse column names from the SELECT list for labelling
    // Strategy: extract AS aliases from SQL, fall back to col0..colN
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
/**
 * Non-throwing version — returns [] on any failure and logs to stderr.
 */
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
 * Build a LIKE-based WHERE clause across multiple columns.
 * Each keyword must appear in at least one of the columns.
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
// ─── MCP Server ──────────────────────────────────────────────────────────────
const server = new mcp_js_1.McpServer({ name: "frankenstein-bug-library", version: VERSION });
// ─── Tool 1: bug_library_search ───────────────────────────────────────────────
server.tool("bug_library_search", `Search frankenstein_router_incidents for past incidents matching a symptom keyword.
Returns matching rows with their diagnosis, resolution, and evidence.
Use BEFORE diagnosing any LLM routing issue to avoid re-deriving known fixes.
(Per clinerule 156 + idea #12619.)`, {
    symptom: zod_1.z
        .string()
        .describe("Symptom to search for. Examples: 'empty unparsable', 'garbage 200', 'restart storm', 'dead rung 404', 'timeout stall'."),
    limit: zod_1.z
        .number()
        .int()
        .min(1)
        .max(20)
        .default(8)
        .describe("Max results (default 8)."),
    status_filter: zod_1.z
        .enum(["all", "resolved", "investigating", "open"])
        .default("all")
        .describe("Filter by resolution status. Default: all."),
}, async ({ symptom, limit, status_filter }) => {
    const keywords = symptom
        .toLowerCase()
        .split(/\s+/)
        .filter((k) => k.length >= 3)
        .slice(0, 6);
    if (!keywords.length) {
        return { content: [{ type: "text", text: "⚠ Symptom too short. Provide at least one 3-character keyword." }] };
    }
    const cols = [
        "LOWER(symptom_observed)",
        "LOWER(diagnosis)",
        "LOWER(resolution)",
        "LOWER(problem_key)",
    ];
    const where = buildLikeWhere(keywords, cols);
    const statusClause = status_filter !== "all" ? ` AND status = '${status_filter}'` : "";
    const sql = `
      SELECT
        id AS id,
        problem_key AS problem_key,
        DATE_FORMAT(occurred_at, '%Y-%m-%d %H:%i') AS occurred_at,
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
            content: [
                {
                    type: "text",
                    text: `🔎 bug_library_search("${symptom}"): No matching incidents found.\n\nThis symptom appears NOVEL — log it via bug_library_record() after diagnosing.`,
                },
            ],
        };
    }
    const lines = [
        `🔎 bug_library_search("${symptom}") — ${rows.length} match(es):`,
        "",
    ];
    for (const r of rows) {
        const resolved = r.status === "resolved" ? "✅" : r.status === "investigating" ? "🔍" : "🆕";
        lines.push(`${resolved} #${r.id} [${r.status}] — ${r.occurred_at}`);
        lines.push(`   problem_key: ${r.problem_key}`);
        lines.push(`   symptom: ${r.symptom_observed}`);
        if (r.diagnosis)
            lines.push(`   diagnosis: ${r.diagnosis}`);
        if (r.resolution)
            lines.push(`   resolution: ${r.resolution}`);
        if (r.evidence)
            lines.push(`   evidence: ${r.evidence}`);
        lines.push("");
    }
    lines.push("If a resolved row matches your case, apply its resolution. If novel, record with bug_library_record().");
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 2: bug_library_check_before_fix ────────────────────────────────────
server.tool("bug_library_check_before_fix", `MANDATORY first call before diagnosing ANY frankenstein-llm / LLM-routing symptom.
Returns KNOWN_REPAIR with the verbatim resolution steps if a match exists, or
NOVEL_SYMPTOM if this failure pattern has not been seen before.
(Clinerule 156 bright-line rule — prevents re-deriving already-solved problems.)`, {
    symptom: zod_1.z
        .string()
        .describe("The observed symptom in 1-3 sentences. Examples: 'Invalid API Response empty/unparsable', 'garbage 200 spill burst on executor chain', '404 dead rung on frankenstein-llm fallback'."),
}, async ({ symptom }) => {
    const keywords = symptom
        .toLowerCase()
        .split(/\s+/)
        .filter((k) => k.length >= 3)
        .slice(0, 8);
    if (!keywords.length) {
        return {
            content: [
                { type: "text", text: "NOVEL_SYMPTOM — symptom too vague to match. Proceed with fresh diagnosis. Record the result via bug_library_record()." },
            ],
        };
    }
    // Prioritize resolved rows; then investigating; then open
    // Use fewer keywords for broader match (top 4)
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
        TIMESTAMPDIFF(HOUR, occurred_at, NOW()) AS age_hours
      FROM frankenstein_router_incidents
      WHERE ${where}
      ORDER BY
        CASE status WHEN 'resolved' THEN 0 WHEN 'investigating' THEN 1 ELSE 2 END,
        occurred_at DESC
      LIMIT 3
    `;
    const rows = queryRows(sql);
    if (!rows.length) {
        return {
            content: [
                {
                    type: "text",
                    text: [
                        "NOVEL_SYMPTOM",
                        "",
                        `No prior incidents matched "${symptom}" in frankenstein_router_incidents.`,
                        "Proceed with fresh diagnosis. When resolved, call bug_library_record() to add to the library.",
                        "",
                        "Cross-ref: clinerule 156, rule 141 (project-frankenstein MCP first), rule 140 (live headers not files).",
                    ].join("\n"),
                },
            ],
        };
    }
    const best = rows[0];
    const isResolved = best.status === "resolved";
    const ageH = parseInt(best.age_hours || "999", 10);
    const freshness = ageH < 48 ? `fresh (${ageH}h ago)` : ageH < 168 ? `${Math.round(ageH / 24)}d ago` : `${Math.round(ageH / 168)}w ago`;
    const lines = [
        isResolved ? "KNOWN_REPAIR ✅" : "KNOWN_PATTERN 🔍 (not yet resolved)",
        "",
        `Closest match: #${best.id} — ${best.problem_key}`,
        `Incident: ${best.occurred_at} (${freshness})`,
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
        lines.push(`Also matched: ${rows.slice(1).map((r) => `#${r.id} (${r.status})`).join(", ")}`);
        lines.push("");
    }
    lines.push(isResolved
        ? "Apply the resolution above. If it does not fix your case, run fresh diagnosis and update with bug_library_record()."
        : "Known pattern but unresolved. Review the evidence above before re-deriving. Record your findings with bug_library_record().");
    lines.push("Cross-ref: clinerule 156, rule 141, rule 140.");
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Tool 3: bug_library_record ───────────────────────────────────────────────
server.tool("bug_library_record", `Record a new frankenstein-llm / LLM-routing incident (or update an existing one).
Call this AFTER diagnosing a novel symptom so future agents find the repair instantly.
Also call when a previously-investigating incident is now resolved.`, {
    symptom: zod_1.z.string().describe("1-3 sentence description of the observed symptom."),
    diagnosis: zod_1.z.string().default("").describe("Root cause identified (if known)."),
    resolution: zod_1.z.string().default("").describe("Steps taken or recommended to resolve. Be specific — this is what future agents will apply."),
    evidence: zod_1.z.string().default("").describe("Supporting evidence: log lines, curl output, audit rows, etc."),
    problem_key: zod_1.z
        .string()
        .default("")
        .describe("Short slug key (e.g. 'garbage_200_spill_2026_06_15'). Auto-generated from symptom if blank."),
    status: zod_1.z
        .enum(["open", "investigating", "resolved"])
        .default("open")
        .describe("Resolution status."),
    created_by: zod_1.z.string().default("cline").describe("Who is recording this (default: cline)."),
}, async ({ symptom, diagnosis, resolution, evidence, problem_key, status, created_by }) => {
    // Auto-generate problem_key if blank
    const key = problem_key || symptom
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, "")
        .trim()
        .split(/\s+/)
        .slice(0, 6)
        .join("_")
        .slice(0, 79);
    // Escape single-quotes for MySQL inline
    const esc = (s) => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").slice(0, 1000);
    const sql = `
      INSERT INTO frankenstein_router_incidents
        (problem_key, symptom_observed, diagnosis, resolution, evidence, status, created_by)
      VALUES (
        '${esc(key)}',
        '${esc(symptom)}',
        '${esc(diagnosis)}',
        '${esc(resolution)}',
        '${esc(evidence)}',
        '${status}',
        '${esc(created_by)}'
      );
      SELECT LAST_INSERT_ID() AS new_id;
    `;
    const rows = queryRows(sql);
    const newId = rows[0]?.new_id ?? rows[0]?.col0 ?? "?";
    return {
        content: [
            {
                type: "text",
                text: [
                    `✓ Incident recorded: frankenstein_router_incidents #${newId}`,
                    `  problem_key: ${key}`,
                    `  status: ${status}`,
                    `  symptom: ${symptom.slice(0, 120)}`,
                    resolution ? `  resolution: ${resolution.slice(0, 120)}` : "  resolution: (pending)",
                    "",
                    "Future agents calling bug_library_check_before_fix() will find this entry.",
                ].join("\n"),
            },
        ],
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
        SUM(CASE WHEN occurred_at >= NOW() - INTERVAL 24 HOUR THEN 1 ELSE 0 END) AS last_24h
      FROM frankenstein_router_incidents
    `;
    const rows = queryRows(sql);
    const r = rows[0] ?? {};
    const lines = [
        `frankenstein-bug-library v${VERSION}`,
        `Total incidents: ${r.total ?? "?"}`,
        `  Resolved:      ${r.resolved ?? "?"}`,
        `  Investigating: ${r.investigating ?? "?"}`,
        `  Open:          ${r.open_count ?? "?"}`,
        `Last 24h:        ${r.last_24h ?? "?"}`,
        `Newest:          ${r.newest ?? "?"}`,
    ];
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Run ─────────────────────────────────────────────────────────────────────
(async () => {
    const transport = new stdio_js_1.StdioServerTransport();
    await server.connect(transport);
    console.error(`[bug-library] v${VERSION} stdio connected · frankenstein_router_incidents on WOPR via SSH · ready`);
})();

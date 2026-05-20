#!/usr/bin/env node
"use strict";
/**
 * clinerules-mcp — On-demand .clinerules lookup MCP
 * =================================================
 *
 * Replaces loading all 118 .clinerules into every Cline task's system prompt
 * (~972KB / ~243K tokens, ~$3.65/task at Opus pricing). With this MCP +
 * a fail-safe _INDEX.md, Cline fetches rules on demand via clinerules_lookup.
 *
 * Architecture: stdio MCP wrapped by supergateway → streamableHttp on port 7860.
 * Source of truth: ~/Documents/Cline/Rules/*.md (untouched).
 * Index: SQLite + FTS5 at ~/.clinerules-mcp/index.sqlite (rebuilt on startup).
 *
 * Phase 1 tools shipped here:
 *   - clinerules_lookup(rule_id | slug | filename)
 *   - clinerules_search(query, limit?)
 *   - clinerules_list_by_topic(topic)
 *   - clinerules_record_violation(rule_id, task_id, evidence)
 *   - clinerules_reindex()
 *
 * Per orchestrator_idea #5344 (P0, approved).
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const zod_1 = require("zod");
const better_sqlite3_1 = __importDefault(require("better-sqlite3"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
// ─── Configuration ──────────────────────────────────────────────────────────
const HOME = os.homedir();
const RULES_DIR = path.join(HOME, "Documents/Cline/Rules");
// Phase 3 shrinkage (orchestrator_idea TBD): non-hardfloor rules live here
// so Cline's hardcoded recursive walk of RULES_DIR no longer injects them.
// MCP still indexes both directories so clinerules_lookup/search work unchanged.
const ARCHIVE_DIR = path.join(HOME, "Documents/Cline/Rules-archive");
const DB_DIR = path.join(HOME, ".clinerules-mcp");
const DB_PATH = path.join(DB_DIR, "index.sqlite");
const VERSION = "0.1.0";
if (!fs.existsSync(DB_DIR))
    fs.mkdirSync(DB_DIR, { recursive: true });
// Hard-floor rules — always loaded into system prompt (per README).
const HARDFLOOR_SLUGS = new Set([
    "00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds",
    "01-voice-and-persona",
    "02-no-apologies-in-student-emails",
    "29-agents-act-on-confidence-tier",
    "38-ruben-asks-equals-autonomous-or-shipped",
    "41-post-deploy-call-the-tool-do-not-narrate",
    "91-every-completion-needs-pickup-prompt",
    "92-work-at-the-core-not-bandaids",
    "99-yolo-prevention-learned",
]);
function parseRuleId(filename) {
    // "29-agents-act-on-confidence-tier.md" → "29"
    // "00-READ-FIRST-17-force-subagent-use..." → "00-READ-FIRST-17"
    // "EXECUTE_ORDER_66.md" → "EXECUTE_ORDER_66"
    const base = filename.replace(/\.md$/, "");
    const m = base.match(/^(\d+(?:-READ-FIRST-\d+)?)/);
    if (m)
        return m[1];
    return base;
}
function extractTitle(body, fallback) {
    const m = body.match(/^#\s+(.+)$/m);
    return m ? m[1].trim() : fallback;
}
function extractCrossRefs(body) {
    // Find ".clinerules/NN" or "rule NN" or "Rule NN"
    const refs = new Set();
    const patterns = [
        /\.clinerules\/(\d+(?:-READ-FIRST-\d+)?)/gi,
        /\brule[s]?\s+(\d{1,3})\b/gi,
    ];
    for (const re of patterns) {
        let m;
        while ((m = re.exec(body)) !== null) {
            refs.add(m[1]);
        }
    }
    return Array.from(refs).sort();
}
function hasSourceIncident(body) {
    return /(?:source incident|## source|## last updated|^Source:)/im.test(body);
}
function initSchema(db) {
    db.exec(`
    CREATE TABLE IF NOT EXISTS rules (
      rule_id TEXT NOT NULL,
      slug TEXT PRIMARY KEY,
      filename TEXT NOT NULL,
      path TEXT NOT NULL,
      title TEXT,
      body TEXT,
      size_bytes INTEGER,
      size_tokens_est INTEGER,
      cross_refs TEXT,
      last_updated TEXT,
      has_source_incident INTEGER DEFAULT 0,
      is_hardfloor INTEGER DEFAULT 0,
      mtime INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_rules_rule_id ON rules(rule_id);
    CREATE INDEX IF NOT EXISTS idx_rules_hardfloor ON rules(is_hardfloor);

    CREATE VIRTUAL TABLE IF NOT EXISTS rules_fts USING fts5(
      slug UNINDEXED,
      title,
      body,
      tokenize = 'porter unicode61'
    );

    CREATE TABLE IF NOT EXISTS violations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT NOT NULL,
      task_id TEXT,
      evidence TEXT,
      recorded_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );
    CREATE INDEX IF NOT EXISTS idx_violations_rule ON violations(rule_id);

    CREATE TABLE IF NOT EXISTS lookups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT,
      slug TEXT,
      query TEXT,
      via TEXT,
      task_id TEXT,
      looked_up_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
    );

    CREATE TABLE IF NOT EXISTS meta (
      k TEXT PRIMARY KEY,
      v TEXT
    );
  `);
}
function reindex(db, verbose = false) {
    // Phase 3: index BOTH the live Rules/ (small — hardfloors only after shrinkage)
    // AND Rules-archive/ (the non-hardfloor majority that no longer auto-loads
    // into Cline's system prompt). MCP lookups still serve the full corpus.
    const collected = [];
    const walk = (dir) => {
        if (!fs.existsSync(dir))
            return;
        for (const f of fs.readdirSync(dir).sort()) {
            if (!f.endsWith(".md"))
                continue;
            collected.push({ full: path.join(dir, f), filename: f });
        }
    };
    walk(RULES_DIR);
    walk(ARCHIVE_DIR);
    // Dedupe by slug (Rules/ wins over Rules-archive/ if both have same file)
    const seen = new Set();
    const files = collected.filter((c) => {
        const slug = c.filename.replace(/\.md$/, "");
        if (seen.has(slug))
            return false;
        seen.add(slug);
        return true;
    });
    const tx = db.transaction(() => {
        db.exec(`DELETE FROM rules; DELETE FROM rules_fts;`);
        const ins = db.prepare(`
      INSERT INTO rules (
        rule_id, slug, filename, path, title, body,
        size_bytes, size_tokens_est, cross_refs, last_updated,
        has_source_incident, is_hardfloor, mtime
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
    `);
        const insFts = db.prepare(`INSERT INTO rules_fts (slug, title, body) VALUES (?,?,?)`);
        for (const { full, filename: f } of files) {
            const stat = fs.statSync(full);
            const body = fs.readFileSync(full, "utf-8");
            const slug = f.replace(/\.md$/, "");
            const rule_id = parseRuleId(f);
            const title = extractTitle(body, slug);
            const refs = extractCrossRefs(body);
            const sizeBytes = stat.size;
            const sizeTokens = Math.ceil(body.length / 4);
            const hasSrc = hasSourceIncident(body) ? 1 : 0;
            const isHf = HARDFLOOR_SLUGS.has(slug) ? 1 : 0;
            const lastUpdMatch = body.match(/##\s+(?:last\s+updated|Last\s+updated)\s*\n+\s*([\d-]+)/i);
            const lastUpd = lastUpdMatch ? lastUpdMatch[1] : "";
            ins.run(rule_id, slug, f, full, title, body, sizeBytes, sizeTokens, JSON.stringify(refs), lastUpd, hasSrc, isHf, Math.floor(stat.mtimeMs));
            insFts.run(slug, title, body);
        }
        db.prepare(`INSERT OR REPLACE INTO meta (k,v) VALUES (?,?)`)
            .run("last_reindex", new Date().toISOString());
        db.prepare(`INSERT OR REPLACE INTO meta (k,v) VALUES (?,?)`)
            .run("version", VERSION);
    });
    tx();
    const stats = db.prepare(`
    SELECT COUNT(*) AS n,
           COALESCE(SUM(size_bytes),0) AS total_bytes,
           COALESCE(SUM(size_tokens_est),0) AS total_tokens,
           COALESCE(SUM(is_hardfloor),0) AS hardfloor_count
    FROM rules
  `).get();
    if (verbose) {
        console.error(`[clinerules-mcp] reindexed ${stats.n} rules, ${stats.total_bytes} bytes, ~${stats.total_tokens} tokens, ${stats.hardfloor_count} hardfloor`);
    }
    return {
        count: stats.n,
        total_bytes: stats.total_bytes,
        total_tokens: stats.total_tokens,
        hardfloor_count: stats.hardfloor_count,
    };
}
// ─── Bootstrap ─────────────────────────────────────────────────────────────
const db = new better_sqlite3_1.default(DB_PATH);
db.pragma("journal_mode = WAL");
initSchema(db);
const stats = reindex(db, true);
// CLI mode: `node build/index.js --reindex-only`
if (process.argv.includes("--reindex-only")) {
    console.error(JSON.stringify({ ok: true, ...stats }, null, 2));
    process.exit(0);
}
// ─── MCP server ────────────────────────────────────────────────────────────
const server = new mcp_js_1.McpServer({
    name: "clinerules-mcp",
    version: VERSION,
});
function logLookup(rule_id, slug, query, via, task_id) {
    try {
        db.prepare(`INSERT INTO lookups (rule_id, slug, query, via, task_id) VALUES (?,?,?,?,?)`)
            .run(rule_id, slug, query, via, task_id || null);
    }
    catch { /* never fail a lookup on telemetry */ }
}
function violationCount(rule_id) {
    const r = db.prepare(`SELECT COUNT(*) AS n FROM violations WHERE rule_id = ?`).get(rule_id);
    return r.n;
}
function findRule(query) {
    const q = query.trim();
    // Try exact slug
    let r = db.prepare(`SELECT * FROM rules WHERE slug = ?`).get(q);
    if (r)
        return r;
    // Try exact rule_id
    r = db.prepare(`SELECT * FROM rules WHERE rule_id = ?`).get(q);
    if (r)
        return r;
    // Try numeric — strip leading zeros, then "%-" prefix match
    if (/^\d+$/.test(q)) {
        const n = parseInt(q, 10);
        const padded2 = n.toString().padStart(2, "0");
        r = db.prepare(`SELECT * FROM rules WHERE rule_id = ? OR slug LIKE ? OR slug LIKE ? LIMIT 1`)
            .get(n.toString(), `${padded2}-%`, `${n}-%`);
        if (r)
            return r;
    }
    // Try filename
    r = db.prepare(`SELECT * FROM rules WHERE filename = ?`).get(q);
    if (r)
        return r;
    // Try slug prefix (e.g. "29" → "29-agents-...")
    r = db.prepare(`SELECT * FROM rules WHERE slug LIKE ? ORDER BY slug LIMIT 1`)
        .get(`${q}%`);
    if (r)
        return r;
    return null;
}
// ─── Tools ─────────────────────────────────────────────────────────────────
server.tool("clinerules_lookup", "Fetch the full body of a single .clinerules file by rule_id, slug, or filename. Returns rule body + cross-refs + violation count. Use when you need the actual text of a specific rule (e.g. 'lookup rule 29').", {
    rule_id: zod_1.z.string().describe("Rule ID, slug, or filename. Examples: '29', '29-agents-act-on-confidence-tier', 'EXECUTE_ORDER_66'."),
    task_id: zod_1.z.string().optional().describe("Optional Cline task ID for audit telemetry."),
}, async ({ rule_id, task_id }) => {
    const row = findRule(rule_id);
    if (!row) {
        logLookup(null, null, rule_id, "lookup_miss", task_id);
        return {
            content: [{
                    type: "text",
                    text: `No rule found matching '${rule_id}'. Try clinerules_search('${rule_id}') or read ~/Documents/Cline/Rules/_INDEX.md.`,
                }],
        };
    }
    logLookup(row.rule_id, row.slug, rule_id, "lookup_hit", task_id);
    const vc = violationCount(row.rule_id);
    const refs = JSON.parse(row.cross_refs || "[]");
    const header = [
        `📖 Rule ${row.rule_id} — ${row.title}`,
        `Slug: ${row.slug}`,
        `Size: ${row.size_bytes} bytes (~${row.size_tokens_est} tokens) · Hardfloor: ${row.is_hardfloor ? "yes" : "no"} · Source incident: ${row.has_source_incident ? "yes" : "no"} · Violations recorded: ${vc}`,
        refs.length ? `Cross-refs: ${refs.map((r) => `.clinerules/${r}`).join(", ")}` : "Cross-refs: (none parsed)",
        "",
        "──── BODY ────",
        "",
    ].join("\n");
    return { content: [{ type: "text", text: header + row.body }] };
});
server.tool("clinerules_search", "Full-text search across all .clinerules bodies (FTS5 porter stemming). Use when you don't know the rule number — pass keywords like 'tunnel wedged' or 'refund autonomous'. Returns top-N matches with snippets.", {
    query: zod_1.z.string().describe("Search query (keywords, phrases). FTS5 syntax supported."),
    limit: zod_1.z.number().int().min(1).max(20).default(5).describe("Max results (default 5)."),
    task_id: zod_1.z.string().optional().describe("Optional Cline task ID for audit telemetry."),
}, async ({ query, limit, task_id }) => {
    // Sanitize: FTS5 hates unmatched quotes and certain punctuation
    const safe = query.replace(/["']/g, " ").replace(/[^\w\s\-]/g, " ").trim();
    if (!safe) {
        return { content: [{ type: "text", text: `Empty/unsupported query: '${query}'.` }] };
    }
    let rows;
    try {
        rows = db.prepare(`
        SELECT r.rule_id, r.slug, r.title, r.size_tokens_est, r.is_hardfloor,
               snippet(rules_fts, 2, '«', '»', '…', 24) AS snippet,
               bm25(rules_fts) AS score
        FROM rules_fts
        JOIN rules r ON r.slug = rules_fts.slug
        WHERE rules_fts MATCH ?
        ORDER BY score
        LIMIT ?
      `).all(safe, limit);
    }
    catch (e) {
        return { content: [{ type: "text", text: `Search error: ${e.message}. Try simpler keywords.` }] };
    }
    logLookup(null, null, query, "search", task_id);
    if (!rows.length) {
        return { content: [{ type: "text", text: `No matches for '${query}'. Browse ~/Documents/Cline/Rules/_INDEX.md.` }] };
    }
    const out = [`🔎 ${rows.length} match(es) for '${query}':`, ""];
    for (const r of rows) {
        out.push(`• Rule ${r.rule_id} — ${r.title}  (~${r.size_tokens_est} tokens${r.is_hardfloor ? ", hardfloor" : ""})`);
        out.push(`  slug: ${r.slug}`);
        out.push(`  ${r.snippet.replace(/\s+/g, " ").trim()}`);
        out.push("");
    }
    out.push("Use clinerules_lookup(rule_id='<id>') to fetch the full body.");
    return { content: [{ type: "text", text: out.join("\n") }] };
});
server.tool("clinerules_list_by_topic", "List rules matching a topic keyword with a 1-line summary each. Faster than search when you want to scan a domain (e.g. topic='subagent' → all rules about subagent dispatch).", {
    topic: zod_1.z.string().describe("Topic keyword. Matches rule titles, slugs, and first 500 chars of body."),
    limit: zod_1.z.number().int().min(1).max(50).default(15),
}, async ({ topic, limit }) => {
    const t = `%${topic.replace(/[%_]/g, "")}%`;
    const rows = db.prepare(`
      SELECT rule_id, slug, title, size_tokens_est, is_hardfloor,
             SUBSTR(body, 1, 200) AS preview
      FROM rules
      WHERE title LIKE ? OR slug LIKE ? OR SUBSTR(body, 1, 500) LIKE ?
      ORDER BY is_hardfloor DESC, CAST(rule_id AS INTEGER), slug
      LIMIT ?
    `).all(t, t, t, limit);
    if (!rows.length) {
        return { content: [{ type: "text", text: `No rules matching topic '${topic}'.` }] };
    }
    const out = [`📚 ${rows.length} rule(s) matching topic '${topic}':`, ""];
    for (const r of rows) {
        const star = r.is_hardfloor ? "★" : " ";
        const preview = (r.preview || "").replace(/\s+/g, " ").trim().slice(0, 100);
        out.push(`${star} Rule ${r.rule_id} — ${r.title} (~${r.size_tokens_est}t)`);
        out.push(`    ${preview}…`);
    }
    out.push("");
    out.push("★ = hardfloor (always in system prompt). Use clinerules_lookup() for full body.");
    return { content: [{ type: "text", text: out.join("\n") }] };
});
server.tool("clinerules_record_violation", "Record an instance of a .clinerules violation. Used by Cline (and post-task analyzers) to track which rules are tripped most often, so the playbook can adapt.", {
    rule_id: zod_1.z.string().describe("Rule ID or slug."),
    task_id: zod_1.z.string().describe("Cline task ID where the violation occurred."),
    evidence: zod_1.z.string().describe("Brief evidence text (1-2 sentences, what was violated + how)."),
}, async ({ rule_id, task_id, evidence }) => {
    const row = findRule(rule_id);
    const resolvedId = row ? row.rule_id : rule_id;
    db.prepare(`INSERT INTO violations (rule_id, task_id, evidence) VALUES (?,?,?)`)
        .run(resolvedId, task_id, evidence);
    const total = violationCount(resolvedId);
    return {
        content: [{
                type: "text",
                text: `✓ Recorded violation of rule ${resolvedId} for task ${task_id}. Total violations on this rule: ${total}.`,
            }],
    };
});
server.tool("clinerules_reindex", "Rebuild the SQLite + FTS5 index from ~/Documents/Cline/Rules/. Call after editing a rule file. Idempotent.", {}, async () => {
    const s = reindex(db, false);
    return {
        content: [{
                type: "text",
                text: `✓ Reindexed: ${s.count} rules, ${s.total_bytes} bytes, ~${s.total_tokens} tokens, ${s.hardfloor_count} hardfloor.`,
            }],
    };
});
server.tool("clinerules_stats", "Quick stats on the rules corpus + recent lookup activity. Used to verify the MCP is healthy and to track adoption.", {}, async () => {
    const corpus = db.prepare(`
      SELECT COUNT(*) AS n, SUM(size_bytes) AS bytes, SUM(size_tokens_est) AS tokens,
             SUM(is_hardfloor) AS hf, SUM(has_source_incident) AS with_src
      FROM rules
    `).get();
    const lookups24 = db.prepare(`
      SELECT COUNT(*) AS n FROM lookups WHERE looked_up_at >= datetime('now','-1 day')
    `).get();
    const violations30 = db.prepare(`
      SELECT COUNT(*) AS n FROM violations WHERE recorded_at >= datetime('now','-30 day')
    `).get();
    const topLookups = db.prepare(`
      SELECT rule_id, COUNT(*) AS n FROM lookups
       WHERE rule_id IS NOT NULL AND looked_up_at >= datetime('now','-7 day')
       GROUP BY rule_id ORDER BY n DESC LIMIT 5
    `).all();
    const meta = db.prepare(`SELECT * FROM meta`).all();
    const lines = [
        `clinerules-mcp v${VERSION}`,
        `Corpus: ${corpus.n} rules, ${corpus.bytes} bytes, ~${corpus.tokens} tokens.`,
        `Hardfloor: ${corpus.hf} rules. With source-incident citation: ${corpus.with_src}.`,
        `Lookups last 24h: ${lookups24.n}.`,
        `Violations recorded last 30d: ${violations30.n}.`,
        topLookups.length ? `Top 5 looked-up rules (7d): ${topLookups.map(r => `${r.rule_id}(${r.n})`).join(", ")}` : "No lookups yet.",
        `Meta: ${meta.map((m) => `${m.k}=${m.v}`).join(", ")}`,
    ];
    return { content: [{ type: "text", text: lines.join("\n") }] };
});
// ─── Run ───────────────────────────────────────────────────────────────────
(async () => {
    const transport = new stdio_js_1.StdioServerTransport();
    await server.connect(transport);
    console.error(`[clinerules-mcp] v${VERSION} ready · ${stats.count} rules indexed · DB ${DB_PATH}`);
})();

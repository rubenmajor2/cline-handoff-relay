#!/usr/bin/env node
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

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import Database from "better-sqlite3";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

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

if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR, { recursive: true });

// ─── Index builder ──────────────────────────────────────────────────────────

interface RuleRow {
  rule_id: string;       // numeric id from filename prefix ("00", "29", "100", etc)
  slug: string;          // filename without .md
  filename: string;      // full filename
  path: string;          // absolute path
  title: string;         // first H1 (or filename if absent)
  body: string;          // full file content
  size_bytes: number;
  size_tokens_est: number; // body chars / 4 (Opus-ish)
  cross_refs: string;    // JSON array of cited .clinerules/N
  last_updated: string;
  has_source_incident: number; // 1 if "## source" or "## last updated" or "source incident" found
  is_hardfloor: number;  // 1 if in HARDFLOOR_SET
  mtime: number;
}

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

function parseRuleId(filename: string): string {
  // "29-agents-act-on-confidence-tier.md" → "29"
  // "00-READ-FIRST-17-force-subagent-use..." → "00-READ-FIRST-17"
  // "EXECUTE_ORDER_66.md" → "EXECUTE_ORDER_66"
  const base = filename.replace(/\.md$/, "");
  const m = base.match(/^(\d+(?:-READ-FIRST-\d+)?)/);
  if (m) return m[1];
  return base;
}

function extractTitle(body: string, fallback: string): string {
  const m = body.match(/^#\s+(.+)$/m);
  return m ? m[1].trim() : fallback;
}

function extractCrossRefs(body: string): string[] {
  // Find ".clinerules/NN" or "rule NN" or "Rule NN"
  const refs = new Set<string>();
  const patterns = [
    /\.clinerules\/(\d+(?:-READ-FIRST-\d+)?)/gi,
    /\brule[s]?\s+(\d{1,3})\b/gi,
  ];
  for (const re of patterns) {
    let m: RegExpExecArray | null;
    while ((m = re.exec(body)) !== null) {
      refs.add(m[1]);
    }
  }
  return Array.from(refs).sort();
}

function hasSourceIncident(body: string): boolean {
  return /(?:source incident|## source|## last updated|^Source:)/im.test(body);
}

function initSchema(db: Database.Database): void {
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

function reindex(db: Database.Database, verbose = false): {
  count: number;
  total_bytes: number;
  total_tokens: number;
  hardfloor_count: number;
} {
  // Phase 3: index BOTH the live Rules/ (small — hardfloors only after shrinkage)
  // AND Rules-archive/ (the non-hardfloor majority that no longer auto-loads
  // into Cline's system prompt). MCP lookups still serve the full corpus.
  const collected: { full: string; filename: string }[] = [];
  const walk = (dir: string) => {
    if (!fs.existsSync(dir)) return;
    for (const f of fs.readdirSync(dir).sort()) {
      if (!f.endsWith(".md")) continue;
      collected.push({ full: path.join(dir, f), filename: f });
    }
  };
  walk(RULES_DIR);
  walk(ARCHIVE_DIR);

  // Dedupe by slug (Rules/ wins over Rules-archive/ if both have same file)
  const seen = new Set<string>();
  const files = collected.filter((c) => {
    const slug = c.filename.replace(/\.md$/, "");
    if (seen.has(slug)) return false;
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

      ins.run(
        rule_id, slug, f, full, title, body,
        sizeBytes, sizeTokens, JSON.stringify(refs), lastUpd,
        hasSrc, isHf, Math.floor(stat.mtimeMs)
      );
      insFts.run(slug, title, body);
    }

    db.prepare(`INSERT OR REPLACE INTO meta (k,v) VALUES (?,?)`)
      .run("last_reindex", new Date().toISOString());
    db.prepare(`INSERT OR REPLACE INTO meta (k,v) VALUES (?,?)`)
      .run("last_reindex_ts", String(Date.now()));
    db.prepare(`INSERT OR REPLACE INTO meta (k,v) VALUES (?,?)`)
      .run("version", VERSION);
  });
  tx();

  // 2026-07-03 WAL-bloat fix: checkpoint immediately after the big write so
  // WAL frames fold into the main DB right away. Without this, 5 concurrent
  // processes each running this reindex every 5 min grew the WAL to 101 MB,
  // which stalled new-process init (WAL replay on open) → Cline auto-disable.
  try { db.pragma("wal_checkpoint(PASSIVE)"); } catch { /* non-fatal */ }

  const stats = db.prepare(`
    SELECT COUNT(*) AS n,
           COALESCE(SUM(size_bytes),0) AS total_bytes,
           COALESCE(SUM(size_tokens_est),0) AS total_tokens,
           COALESCE(SUM(is_hardfloor),0) AS hardfloor_count
    FROM rules
  `).get() as { n: number; total_bytes: number; total_tokens: number; hardfloor_count: number };

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

// 2026-05-19 v3 fix: install error handlers BEFORE doing anything else.
// supergateway 3.4.3 stateless mode synthesizes one initialize per non-init
// request, which fills stdio buffers and triggers EPIPE/ECONNRESET in the
// child. Without these handlers the node child dies with "Pipe.onStreamRead"
// trace and Cline windows go yellow.
process.stdin.on("error", (e: any) => {
  console.error(`[clinerules-mcp] stdin error (swallowed): ${e?.code || e?.message}`);
});
process.stdout.on("error", (e: any) => {
  console.error(`[clinerules-mcp] stdout error (swallowed): ${e?.code || e?.message}`);
});
process.on("uncaughtException", (e: any) => {
  console.error(`[clinerules-mcp] uncaughtException (swallowed): ${e?.message || e}`);
});
process.on("unhandledRejection", (e: any) => {
  console.error(`[clinerules-mcp] unhandledRejection (swallowed): ${e?.message || e}`);
});

const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");
db.pragma("busy_timeout = 5000");      // wait up to 5s for locks instead of SQLITE_BUSY throw
db.pragma("wal_autocheckpoint = 500"); // checkpoint every ~2MB, not default ~4MB
initSchema(db);

// 2026-07-03: skip the expensive full reindex when no rule file changed.
// Returns true only if any .md in Rules/ or Rules-archive/ has mtime newer
// than the last reindex. Makes the 5-min background interval + 10s post-
// startup reindex a cheap stat-loop no-op 99% of the time, so concurrent
// windows don't pile write load on the shared SQLite WAL.
function needsReindex(): boolean {
  let newestMtime = 0;
  for (const dir of [RULES_DIR, ARCHIVE_DIR]) {
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir)) {
      if (!f.endsWith(".md")) continue;
      try {
        const st = fs.statSync(path.join(dir, f));
        if (st.mtimeMs > newestMtime) newestMtime = st.mtimeMs;
      } catch { /* skip unreadable */ }
    }
  }
  const row = db.prepare(`SELECT v FROM meta WHERE k = 'last_reindex_ts'`).get() as { v?: string } | undefined;
  const lastTs = row?.v ? parseInt(row.v, 10) : 0;
  return newestMtime > lastTs;
}

// CLI mode: `node build/index.js --reindex-only`
if (process.argv.includes("--reindex-only")) {
  const stats = reindex(db, true);
  console.error(JSON.stringify({ ok: true, ...stats }, null, 2));
  process.exit(0);
}

// Phase 3 fix (2026-05-19): defer reindex until AFTER connect(), so the
// MCP child accepts incoming initialize requests from supergateway without
// the 200ms+ startup stall that piles up backlog from multiple Cline
// windows hammering port 7860. The first lookup will already have a
// cached index from any prior run; the deferred reindex catches new rules
// on a 50ms idle delay.
let stats: { count: number; total_bytes: number; total_tokens: number; hardfloor_count: number } = {
  count: 0, total_bytes: 0, total_tokens: 0, hardfloor_count: 0,
};

// ─── MCP server ────────────────────────────────────────────────────────────

const server = new McpServer({
  name: "clinerules-mcp",
  version: VERSION,
});

function logLookup(rule_id: string | null, slug: string | null, query: string | null, via: string, task_id?: string) {
  try {
    db.prepare(`INSERT INTO lookups (rule_id, slug, query, via, task_id) VALUES (?,?,?,?,?)`)
      .run(rule_id, slug, query, via, task_id || null);
  } catch { /* never fail a lookup on telemetry */ }
}

function violationCount(rule_id: string): number {
  const r = db.prepare(`SELECT COUNT(*) AS n FROM violations WHERE rule_id = ?`).get(rule_id) as { n: number };
  return r.n;
}

function findRule(query: string): RuleRow | null {
  const q = query.trim();
  // Try exact slug
  let r = db.prepare(`SELECT * FROM rules WHERE slug = ?`).get(q) as RuleRow | undefined;
  if (r) return r;
  // Try exact rule_id
  r = db.prepare(`SELECT * FROM rules WHERE rule_id = ?`).get(q) as RuleRow | undefined;
  if (r) return r;
  // Try numeric — strip leading zeros, then "%-" prefix match
  if (/^\d+$/.test(q)) {
    const n = parseInt(q, 10);
    const padded2 = n.toString().padStart(2, "0");
    r = db.prepare(`SELECT * FROM rules WHERE rule_id = ? OR slug LIKE ? OR slug LIKE ? LIMIT 1`)
      .get(n.toString(), `${padded2}-%`, `${n}-%`) as RuleRow | undefined;
    if (r) return r;
  }
  // Try filename
  r = db.prepare(`SELECT * FROM rules WHERE filename = ?`).get(q) as RuleRow | undefined;
  if (r) return r;
  // Try slug prefix (e.g. "29" → "29-agents-...")
  r = db.prepare(`SELECT * FROM rules WHERE slug LIKE ? ORDER BY slug LIMIT 1`)
    .get(`${q}%`) as RuleRow | undefined;
  if (r) return r;
  return null;
}

// ─── Tools ─────────────────────────────────────────────────────────────────

server.tool(
  "clinerules_lookup",
  "Fetch the full body of a single .clinerules file by rule_id, slug, or filename. Returns rule body + cross-refs + violation count. Use when you need the actual text of a specific rule (e.g. 'lookup rule 29').",
  {
    rule_id: z.string().describe("Rule ID, slug, or filename. Examples: '29', '29-agents-act-on-confidence-tier', 'EXECUTE_ORDER_66'."),
    task_id: z.string().optional().describe("Optional Cline task ID for audit telemetry."),
  },
  async ({ rule_id, task_id }) => {
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
      refs.length ? `Cross-refs: ${refs.map((r: string) => `.clinerules/${r}`).join(", ")}` : "Cross-refs: (none parsed)",
      "",
      "──── BODY ────",
      "",
    ].join("\n");
    return { content: [{ type: "text", text: header + row.body }] };
  }
);

server.tool(
  "clinerules_search",
  "Full-text search across all .clinerules bodies (FTS5 porter stemming). Use when you don't know the rule number — pass keywords like 'tunnel wedged' or 'refund autonomous'. Returns top-N matches with snippets.",
  {
    query: z.string().describe("Search query (keywords, phrases). FTS5 syntax supported."),
    limit: z.number().int().min(1).max(20).default(5).describe("Max results (default 5)."),
    task_id: z.string().optional().describe("Optional Cline task ID for audit telemetry."),
  },
  async ({ query, limit, task_id }) => {
    // Sanitize: FTS5 hates unmatched quotes and certain punctuation
    const safe = query.replace(/["']/g, " ").replace(/[^\w\s\-]/g, " ").trim();
    if (!safe) {
      return { content: [{ type: "text", text: `Empty/unsupported query: '${query}'.` }] };
    }
    let rows: any[];
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
      `).all(safe, limit) as any[];
    } catch (e: any) {
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
  }
);

server.tool(
  "clinerules_list_by_topic",
  "List rules matching a topic keyword with a 1-line summary each. Faster than search when you want to scan a domain (e.g. topic='subagent' → all rules about subagent dispatch).",
  {
    topic: z.string().describe("Topic keyword. Matches rule titles, slugs, and first 500 chars of body."),
    limit: z.number().int().min(1).max(50).default(15),
  },
  async ({ topic, limit }) => {
    const t = `%${topic.replace(/[%_]/g, "")}%`;
    const rows = db.prepare(`
      SELECT rule_id, slug, title, size_tokens_est, is_hardfloor,
             SUBSTR(body, 1, 200) AS preview
      FROM rules
      WHERE title LIKE ? OR slug LIKE ? OR SUBSTR(body, 1, 500) LIKE ?
      ORDER BY is_hardfloor DESC, CAST(rule_id AS INTEGER), slug
      LIMIT ?
    `).all(t, t, t, limit) as any[];
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
  }
);

server.tool(
  "clinerules_record_violation",
  "Record an instance of a .clinerules violation. Used by Cline (and post-task analyzers) to track which rules are tripped most often, so the playbook can adapt.",
  {
    rule_id: z.string().describe("Rule ID or slug."),
    task_id: z.string().describe("Cline task ID where the violation occurred."),
    evidence: z.string().describe("Brief evidence text (1-2 sentences, what was violated + how)."),
  },
  async ({ rule_id, task_id, evidence }) => {
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
  }
);

server.tool(
  "clinerules_reindex",
  "Rebuild the SQLite + FTS5 index from ~/Documents/Cline/Rules/. Call after editing a rule file. Idempotent.",
  {},
  async () => {
    const s = reindex(db, false);
    return {
      content: [{
        type: "text",
        text: `✓ Reindexed: ${s.count} rules, ${s.total_bytes} bytes, ~${s.total_tokens} tokens, ${s.hardfloor_count} hardfloor.`,
      }],
    };
  }
);


// ── FIX 2 of #19173: get_rule91_template ────────────────────────────────────
// Source incident 2026-07-25: ALL 7 rule-91 gate failures in one window came
// from the model RETYPING the 47-repetition U+2550 divider from memory. Small
// and mid-size models cannot reproduce a long unicode box-drawing run reliably;
// they emit ASCII dashes, short runs, or mixed glyphs. Rule 91 says "copy the
// divider, do NOT retype" but there was nothing to copy FROM at generation time.
// This tool hands back the exact glyphs, and optionally assembles the whole
// block so the model never touches a divider at all.
const R91_DIVIDER = String.fromCodePoint(0x2550).repeat(47);

server.tool(
  "get_rule91_template",
  "FIX 2 of #19173. Returns the EXACT rule-91 PICKUP PROMPT skeleton with real 47-char U+2550 divider glyphs, so you copy rather than retype (every observed rule-91 failure came from retyping the divider from memory). Call with no args to get the blank skeleton. Call WITH the field args to get a fully-assembled, gate-passing block you can paste straight into attempt_completion.",
  {
    task_id: z.string().optional().describe("Real numeric Cline task id or idea id (no placeholders). If omitted you get the blank skeleton."),
    topic: z.string().optional().describe("Short topic line, e.g. 'catch-all idea backlog drive'."),
    where_we_left_off: z.array(z.string()).optional().describe("Bullets. Each should carry a #NNNN [disposition] where relevant."),
    open_threads: z.array(z.string()).optional().describe("Numbered-item bodies. EACH must contain a real #NNNN [tag] or the literal '(human-only decision, no idea)' marker."),
    ideas_filed: z.array(z.string()).optional().describe("e.g. ['#19175 [executing]', '#19176 [queued]']"),
    files_touched: z.array(z.string()).optional().describe("Absolute or repo-relative paths, or ['none'] ."),
    verified_ts: z.string().optional().describe("Timestamp string, e.g. '2026-07-25 18:53 PT'."),
  },
  async ({ task_id, topic, where_we_left_off, open_threads, ideas_filed, files_touched, verified_ts }) => {
    if (!task_id) {
      const skeleton = [
        R91_DIVIDER,
        "PICKUP PROMPT (paste into a fresh Cline window)",
        R91_DIVIDER,
        "",
        "Pick up task #<REAL_NUMERIC_ID> - <topic>",
        "",
        "Where we left off (verified <TIMESTAMP> PT):",
        "- <bullet, every #NNNN gets a [disposition]>",
        "",
        "Open threads to drive next:",
        "1. #<id> [disposition] - <action>",
        "   ...or the single line: None - <reason>",
        "",
        "Reference IDs:",
        "- Ideas filed: #<id> [tag]",
        "- Files touched: <paths, or none>",
        "",
        "When done, append to cline_task_ledger.md per rule 07, run order 66.",
        R91_DIVIDER,
      ].join("\n");
      return {
        content: [{
          type: "text",
          text:
            "RULE 91 SKELETON. Copy the dividers verbatim, they are 47 x U+2550.\n" +
            "Tip: call this tool again WITH the field args and it will assemble a gate-passing block for you.\n\n" +
            skeleton +
            "\n\nHARD BANS: no fake ids (IDEA-001), no bare #NNNN without [tag], no placeholders (#NNNN / <...>), " +
            "no em dashes in ops text, the block must live in the `result` parameter (never task_progress).",
        }],
      };
    }

    const cleanId = String(task_id).replace(/[^0-9]/g, "");
    const bullets = (where_we_left_off && where_we_left_off.length)
      ? where_we_left_off.map((b) => (b.trim().startsWith("-") ? b : `- ${b}`))
      : ["- (no state bullets supplied)"];
    const threads = (open_threads && open_threads.length)
      ? open_threads.map((t, i) => `${i + 1}. ${t.replace(/^\d+\.\s*/, "")}`)
      : ["None - nothing left open."];
    const filed = (ideas_filed && ideas_filed.length) ? ideas_filed.join(", ") : "none";
    const files = (files_touched && files_touched.length) ? files_touched.join(", ") : "none";
    const ts = verified_ts || new Date().toISOString().replace("T", " ").slice(0, 16) + " UTC";

    const assembled = [
      R91_DIVIDER,
      "PICKUP PROMPT (paste into a fresh Cline window)",
      R91_DIVIDER,
      "",
      `Pick up task #${cleanId} - ${topic || "continuation"}`,
      "",
      `Where we left off (verified ${ts}):`,
      ...bullets,
      "",
      "Open threads to drive next:",
      ...threads,
      "",
      "Reference IDs:",
      `- Ideas filed: ${filed}`,
      `- Files touched: ${files}`,
      "",
      "When done, append to cline_task_ledger.md per rule 07, run order 66.",
      R91_DIVIDER,
    ].join("\n");

    // Self-check the assembled block against the same em-dash gate the validator uses,
    // so we never hand back a block that our own validator will reject.
    const warn: string[] = [];
    if (/\u2014|\u2015|\u2e3a|\u2e3b/.test(assembled)) {
      warn.push("WARNING: your supplied text contains em dashes. Rule 01 bans them in ops text. Replace with commas or two sentences.");
    }
    const bareIds = [...assembled.matchAll(/#(\d{3,8})\b(\s*\[)?/g)]
      .filter((mm) => !mm[2]).map((mm) => "#" + mm[1])
      .filter((v, i, a) => a.indexOf(v) === i && v !== "#" + cleanId);
    if (bareIds.length) {
      warn.push(`WARNING: bare idea numbers with no [disposition]: ${bareIds.join(", ")}`);
    }

    return {
      content: [{
        type: "text",
        text: (warn.length ? warn.join("\n") + "\n\n" : "") +
          "ASSEMBLED RULE 91 BLOCK (paste verbatim into the attempt_completion `result` parameter):\n\n" +
          assembled,
      }],
    };
  }
);

server.tool(
  "clinerules_validate_completion",
  "PRE-COMPLETION GATE (idea #16224): Validates that a pending attempt_completion result complies with rule 91 (PICKUP PROMPT block required). Call BEFORE attempt_completion. Returns pass/fail with specific violations — if pass=false, fix the listed failures before shipping.",
  {
    result_text: z.string().describe("The result text you plan to pass to attempt_completion."),
    task_id: z.string().optional().describe("Optional Cline task ID for audit telemetry."),
    task_prompt: z.string().optional().describe("FIX 5 of #19173 (coverage gate): the ORIGINAL task prompt text. When supplied, every #NNNN enumerated in the prompt must also appear in result_text, or the gate FAILS with the missing ids named. Escape hatch: a line matching 'EXCLUDED: #NNNN (reason)' counts as covered."),
  },
  async ({ result_text, task_id, task_prompt }) => {
    const failures: string[] = [];
    const DIVIDER_LEN = 47;
    const DIVIDER_GLYPH = String.fromCodePoint(0x2550);
    const lines = result_text.split("\n");

    // ─── Gate 1 (FIXED 2026-07-03): line-based PICKUP PROMPT block detection ─────
    // BUG WAS: searched for inline substring "═══ PICKUP PROMPT ═══" (3 glyphs + text
    // + 3 glyphs on ONE line). The canonical rule-91 template puts 47-char dividers
    // on their OWN lines with "PICKUP PROMPT (paste into a fresh Cline window)" on a
    // separate line. A perfectly-formatted prompt NEVER contained that inline
    // substring → ALWAYS false-negative (MISSING_PICKUP_PROMPT), while a broken
    // inline short-divider prompt DID contain it → false positive. This made the
    // validator actively harmful (failed correct prompts, rewarded broken ones),
    // so agents learned to ignore it and real violations slipped through.
    //
    // FIX: detect the block structurally — a full 47-char divider, immediately
    // followed by a "PICKUP PROMPT ..." header line, with a closing divider.
    const isFullDivider = (s: string): boolean => {
      const t = s.trimEnd();
      return t.length === DIVIDER_LEN && new RegExp("^" + DIVIDER_GLYPH + "+$").test(t);
    };
    // Find all full-length divider line indices (Gate 2 scan, merged with Gate 1)
    const dividerIndices: number[] = [];
    for (let i = 0; i < lines.length; i++) {
      if (isFullDivider(lines[i])) {
        dividerIndices.push(i);
        const stripped = lines[i].trimEnd();
        for (const ch of stripped) {
          if ((ch as any).codePointAt(0) !== 0x2550) {
            failures.push(`DIVIDER_WRONG_GLYPH: line ${i+1} uses wrong character (U+${(ch as any).codePointAt(0)?.toString(16)}) instead of U+2550.`);
            break;
          }
        }
      } else {
        const stripped = lines[i].trimEnd();
        if (stripped.length > 20 && new RegExp("^" + DIVIDER_GLYPH + "+$").test(stripped)) {
          failures.push(`DIVIDER_WRONG_LENGTH: line ${i+1} divider is ${stripped.length} chars, must be exactly 47 chars of U+2550. Copy the divider from rule 91 template.`);
        }
      }
    }
    // Detect PICKUP PROMPT header on the line immediately after an opening divider
    const pickupHeaderIdx = (() => {
      for (const di of dividerIndices) {
        const hdrIdx = di + 1;
        if (hdrIdx < lines.length) {
          const hdr = lines[hdrIdx].trim();
          if (/^PICKUP PROMPT\b/i.test(hdr)) return hdrIdx;
        }
      }
      return -1;
    })();
    const hasBlock = pickupHeaderIdx !== -1 && dividerIndices.length >= 2;
    if (!hasBlock) {
      failures.push("MISSING_PICKUP_PROMPT: result text does not contain a structurally-valid PICKUP PROMPT block (47-char U+2550 divider, then 'PICKUP PROMPT ...' header, then another 47-char divider). Add the rule-91 pickup prompt before calling attempt_completion.");
    }
    // Gate 2/3: divider pairing + block extraction
    let pickupBlock = "";
    if (dividerIndices.length === 0) {
      failures.push("DIVIDER_MISSING: no valid 47-char U+2550 divider lines found. Pickup prompt requires 47-char U+2550 dividers — copy them from rule 91 template.");
    } else if (dividerIndices.length < 2) {
      failures.push(`DIVIDER_UNPAIRED: only ${dividerIndices.length} full-length divider(s) found — need at least 2 (opening + closing).`);
    } else {
      const firstDiv = dividerIndices[0];
      const lastDiv = dividerIndices[dividerIndices.length - 1];
      pickupBlock = lines.slice(firstDiv, lastDiv + 1).join("\n");
    }
    // Gate 4: literal placeholder tokens (including Unicode dash variants — Violation #17)
    // Catches #NNNN, #0000, #XXXX, <task_id>, AND #— / #– / #― etc. (em-dash placeholders)
    const _dashPlaceholder = /#(?:NNNN|0000|XXXX|<task_id>|<timestamp\s*PT>|(?:[\u2010-\u2015\u2212\u2E3A\u2E3B\-—–]))/i;
    if (_dashPlaceholder.test(pickupBlock)) {
      failures.push("PLACEHOLDER_DETECTED: literal placeholder token found in pickup prompt (#NNNN, #0000, #XXXX, #— em-dash, <task_id>, etc.). Replace with real values — call create_idea for real integer IDs.");
    }
    // Gate 4c (NEW 2026-07-24, Violation #17): open-thread items without real idea numbers
    // Each numbered item under "Open threads" MUST have #<integer> [tag] OR (human-only decision — no idea) marker.
    // Catches the pattern where agents list actionable items as "open threads" with fake/placeholder tags
    // but never call create_idea (Violation #14 + #17 pattern).
    if (pickupBlock) {
      const otMatch = pickupBlock.match(/open\s+threads?\s+to\s+drive\s+next\s*:?\s*\n([\s\S]*?)(?:\n\s*reference\s+ids|\n\s*when\s+done|$)/i);
      if (otMatch) {
        const otSection = otMatch[1];
        // Match numbered list items: "1. ...", "2. ...", etc.
        const items = otSection.split(/\n(?=\d+\.\s)/).filter((s: string) => /^\s*\d+\.\s/.test(s));
        for (const item of items) {
          const hasRealIdea = /#\d{1,8}\s*\[/.test(item);  // #NNNN followed by [
          const hasHumanOnlyMarker = /human-only\s+decision|no\s+idea\)/i.test(item);
          if (!hasRealIdea && !hasHumanOnlyMarker) {
            const firstLine = item.split("\n")[0].trim().slice(0, 80);
            failures.push(`UNFILED_OPEN_THREAD: open-thread item lacks real idea number or human-only marker: "${firstLine}...". Either call create_idea for a real #NNNN [tag], or mark "(human-only decision — no idea)". Listing agent-doable work as an open thread without filing it is a rule-29 + rule-91 violation.`);
          }
        }
      }
    }
    // Gate 4b (NEW 2026-07-03): missing task ID. Rule 91 requires "Pick up task #<real task id> — <topic>".
    // Prior validator only caught LITERAL placeholders (#NNNN), so a prompt that simply OMITTED the
    // task id ("Pick up task — final-notice cleanup") passed while violating rule 91. This catches the omission.
    if (pickupBlock) {
      const taskLineMatch = pickupBlock.match(/^Pick up task\b[^\n]*$/im);
      if (taskLineMatch) {
        const taskLine = taskLineMatch[0];
        if (!/#\d+/.test(taskLine)) {
          failures.push("MISSING_TASK_ID: the 'Pick up task' line has no #<numeric id>. Rule 91 requires 'Pick up task #<real task id> — <topic>'. Add the real Cline task id.");
        }
      } else {
        failures.push("MISSING_TASK_LINE: no 'Pick up task ...' line found in pickup prompt. Rule 91 requires a 'Pick up task #<id> — <topic>' line.");
      }
    }

    if (/see\s+handoff\s+file/i.test(pickupBlock)) {
      failures.push("PICKUP_BY_REFERENCE: 'see handoff file' detected in pickup prompt — the block must be INLINE, not a pointer to an external file.");
    }

    if (/hold\s+until\s+Ruben\s+confirms|wait\s+before\s+acting|pause\s+until|ask\s+first\s+if/i.test(pickupBlock)) {
      failures.push("R91_WAIT_STATE: forbidden wait-state language in pickup prompt.");
    }

    // ── RULE 29 (act-dont-defer) ──
    if (/(?:I.ll|I will)\s+(?:mention this|raise this|flag this)\s+and\s+Ruben\s+(?:decides|can decide|will decide)/i.test(result_text)) {
      failures.push("R29_DECISION_QUEUE: 'I'll mention this and Ruben decides' — act first, report status. No decision queues.");
    }
    if (/(?:the\s+)?(?:fleet|executor|orchestrator|cron)\s+(?:agent\s+)?(?:will|should|can)\s+(?:handle|do|pick\s+up|take\s+care\s+of)\s+(?:it|this|that)/i.test(pickupBlock)) {
      failures.push("R29_DEFER_TO_SYSTEM: deferring to fleet/executor/cron without verifying capability. Verify or act directly.");
    }
    if (/(?:wait\s+for|let)\s+(?:the\s+)?(?:other|parallel|sibling)\s+(?:Cline|agent)\s+(?:window|session)s?/i.test(pickupBlock)) {
      failures.push("R29_PARALLEL_WAIT: waiting for parallel windows forbidden. Each window works independently.");
    }

    // ── RULE 120 (context-is-not-an-excuse) ──
    if (/(?:due\s+to|given|because\s+of|owing\s+to)\s+(?:the\s+)?(?:context|token)\s+(?:constraints?|limitations?|window|size|budget)/i.test(result_text)) {
      failures.push("R120_CONTEXT_EXCUSE: naming context/token limits as reason for doing less. <300K=work fully, >=500K=compress.");
    }
    if (/(?:to\s+conserve|to\s+save|preserving|conserving)\s+(?:context|tokens)/i.test(result_text)) {
      failures.push("R120_CONTEXT_EXCUSE: 'conserving context' is never a valid reason to shortcut.");
    }

    // ── RULE 01 (voice-and-persona) ──
    const looksLikeOps = /\b(?:student|ticket|Jon|Vicky|Moodle|QB|Authnet|externship|NREMT|class|section|instructor|enrollment)\b/i.test(result_text);
    if (looksLikeOps) {
      if (/\u2014|\u2015|\u2e3a|\u2e3b/.test(result_text)) {
        failures.push("R01_EM_DASH: em dashes in ops text. Use commas, parentheses, or two sentences.");
      }
      if (/\b(?:the\s+)?(?:finance|tech|support|dev)\s+(?:department|team)\b/i.test(result_text)) {
        failures.push("R01_FAKE_DEPARTMENT: invoking nonexistent department. Name the person.");
      }
    }

    // ── RULE 02 (no-apologies-in-student-emails) ──
    const looksLikeStudent = /\b(?:Hi|Hello|Dear)\b.*\b(?:student|EMS)/i.test(result_text) || /\b(?:your\s+course|your\s+grade|your\s+exam|your\s+enrollment|your\s+deadline)\b/i.test(result_text);
    if (looksLikeStudent) {
      if (/(?:I(?:.m|\s+am)|we\s+are|we.re)\s+(?:sorry|very\s+sorry)/i.test(result_text)) {
        failures.push("R02_APOLOGY: 'sorry' in student-facing text. Neutral acknowledgement + fix action only.");
      }
      if (/(?:I|we)\s+apologi[sz]e/i.test(result_text)) {
        failures.push("R02_APOLOGY: 'apologize' in student-facing text. Legal exposure — never apologize in writing.");
      }
    }

    // ── FIX 5 of #19173: COVERAGE GATE ──────────────────────────────────────
    // Source incident 2026-07-25: a catch-all window prompt enumerated 39 explicit
    // idea ids. The first attempt_completion accounted for 7 of them and shipped.
    // The existing bare-number scan asks "does every #NNNN in the RESULT have a tag"
    // which passes TRIVIALLY if the agent simply omits most of the numbers. This is
    // the read-side twin: does every #NNNN in the PROMPT appear in the result.
    if (task_prompt && task_prompt.trim().length > 0) {
      const idRe = /#(\d{3,8})\b/g;
      const promptIds = new Set<string>();
      let m: RegExpExecArray | null;
      while ((m = idRe.exec(task_prompt)) !== null) promptIds.add(m[1]);
      const resultIds = new Set<string>();
      idRe.lastIndex = 0;
      while ((m = idRe.exec(result_text)) !== null) resultIds.add(m[1]);
      // Explicit scope-cut escape hatch
      const excludedIds = new Set<string>();
      const exRe = /EXCLUDED:\s*#(\d{3,8})/gi;
      while ((m = exRe.exec(result_text)) !== null) excludedIds.add(m[1]);
      const missing = [...promptIds].filter((id) => !resultIds.has(id) && !excludedIds.has(id));
      if (missing.length > 0) {
        failures.push(
          `COVERAGE_GAP: the task prompt enumerated ${promptIds.size} idea id(s); the result covers ${promptIds.size - missing.length}. ` +
          `Missing ${missing.length}: ${missing.map((i) => "#" + i).join(", ")}. ` +
          `Tag every prompt-enumerated id with a rule-109 disposition, or write "EXCLUDED: #NNNN (reason)" for deliberate scope cuts.`
        );
      }
    }

    // ── FIX 1 of #19173: BARE-NUMBER TAG SCAN (all failures at once) ────────
    // Rule 91 hardfloor: every #NNNN in the ENTIRE result needs a [disposition].
    // Reported as ONE aggregated failure listing every offender, not one-at-a-time,
    // so the agent fixes them in a single round trip instead of N ping-pongs.
    {
      const VALID_TAGS = /^(deployed|executing|queued|blocked|proposed|rejected|superseded|approved|closed|done)$/i;
      const bare: string[] = [];
      const scanRe = /#(\d{3,8})\b(\s*\[([^\]]*)\])?/g;
      let sm: RegExpExecArray | null;
      while ((sm = scanRe.exec(result_text)) !== null) {
        const id = sm[1];
        const tag = sm[3];
        if (!tag || !VALID_TAGS.test(tag.trim())) {
          if (!bare.includes(id)) bare.push(id);
        }
      }
      if (bare.length > 0) {
        failures.push(
          `BARE_IDEA_NUMBERS: ${bare.length} idea number(s) in the result have no valid [disposition] bracket: ` +
          `${bare.map((i) => "#" + i).join(", ")}. ` +
          `Every #NNNN needs one of [deployed|executing|queued|blocked|proposed|rejected|superseded].`
        );
      }
    }

    const pass = failures.length === 0;

    // Log validation
    try {
      db.prepare("INSERT INTO violations (rule_id, task_id, evidence) VALUES (?,?,?)")
        .run("91", task_id || "unknown", pass ? "VALIDATION_PASS: all multi-rule gates passed (R91+R29+R120+R01+R02)" : "VALIDATION_FAIL: " + failures.join("; "));
    } catch { /* telemetry */ }

    if (pass) {
      return {
        content: [{
          type: "text",
          text: "\u2705 RULE 91 GATES: ALL PASSED\n\nDivider: 47 U+2550 chars \u2713\nPickup prompt present \u2713\nNo placeholders \u2713\nNo pickup-by-reference \u2713\nNo wait-state phrases \u2713\n\nSafe to call attempt_completion.",
        }],
      };
    }
    return {
      content: [{
        type: "text",
        text: `\u274c RULE 91 GATES: ${failures.length} FAILURE(S)\n\n${failures.map((f: string, i: number) => `${i+1}. ${f}`).join("\n")}\n\nFix these before calling attempt_completion. The completion is blocked until all gates pass.`,
      }],
    };
  }
);

server.tool(
  "clinerules_stats",
  "Quick stats on the rules corpus + recent lookup activity. Used to verify the MCP is healthy and to track adoption.",
  {},
  async () => {
    const corpus = db.prepare(`
      SELECT COUNT(*) AS n, SUM(size_bytes) AS bytes, SUM(size_tokens_est) AS tokens,
             SUM(is_hardfloor) AS hf, SUM(has_source_incident) AS with_src
      FROM rules
    `).get() as any;
    const lookups24 = db.prepare(`
      SELECT COUNT(*) AS n FROM lookups WHERE looked_up_at >= datetime('now','-1 day')
    `).get() as any;
    const violations30 = db.prepare(`
      SELECT COUNT(*) AS n FROM violations WHERE recorded_at >= datetime('now','-30 day')
    `).get() as any;
    const topLookups = db.prepare(`
      SELECT rule_id, COUNT(*) AS n FROM lookups
       WHERE rule_id IS NOT NULL AND looked_up_at >= datetime('now','-7 day')
       GROUP BY rule_id ORDER BY n DESC LIMIT 5
    `).all() as any[];
    const meta = db.prepare(`SELECT * FROM meta`).all() as any[];
    const lines = [
      `clinerules-mcp v${VERSION}`,
      `Corpus: ${corpus.n} rules, ${corpus.bytes} bytes, ~${corpus.tokens} tokens.`,
      `Hardfloor: ${corpus.hf} rules. With source-incident citation: ${corpus.with_src}.`,
      `Lookups last 24h: ${lookups24.n}.`,
      `Violations recorded last 30d: ${violations30.n}.`,
      topLookups.length ? `Top 5 looked-up rules (7d): ${topLookups.map(r => `${r.rule_id}(${r.n})`).join(", ")}` : "No lookups yet.",
      `Meta: ${meta.map((m:any) => `${m.k}=${m.v}`).join(", ")}`,
    ];
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// ─── Run ───────────────────────────────────────────────────────────────────

(async () => {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // 2026-05-19 v2 fix (Phase 3 follow-up): do NOT reindex at startup.
  // The SQLite index from the previous run is already populated. Any stale
  // entry will be fixed on the next `clinerules_reindex` tool call or by
  // the background interval below. Cline's MCP initialize timeout is short
  // and any startup work (even 200ms) was racing it.
  const initialCount = (db.prepare(`SELECT COUNT(*) AS n FROM rules`).get() as any)?.n ?? 0;
  console.error(`[clinerules-mcp] v${VERSION} stdio connected · ${initialCount} rules from cached index · ready to serve`);

  // Background reindex every 5 min — but ONLY if a rule file actually changed
  // (2026-07-03 WAL-bloat fix). Previously this blindly deleted + re-inserted
  // all 251 rules every 5 min per process; with 5 concurrent windows that was
  // ~25 reindex-tx/min hammering the shared SQLite WAL.
  setInterval(() => {
    try {
      if (!needsReindex()) return;
      stats = reindex(db, false);
    } catch (e: any) {
      console.error(`[clinerules-mcp] background reindex failed: ${e?.message}`);
    }
  }, 5 * 60 * 1000);

  // One reindex 10s after startup — only if the index is stale (another window
  // may have just reindexed). Always run a passive checkpoint to keep WAL small.
  setTimeout(() => {
    try {
      if (needsReindex()) {
        stats = reindex(db, true);
      } else {
        try { db.pragma("wal_checkpoint(PASSIVE)"); } catch { /* non-fatal */ }
      }
    } catch (e: any) {
      console.error(`[clinerules-mcp] post-startup reindex failed: ${e?.message}`);
    }
  }, 10_000);

  // Orphan guard (2026-07-03): when a Cline window closes, the extension host
  // (our parent) exits and we get reparented to launchd (PPID=1). Without this
  // check, orphaned clinerules processes accumulate — each holding the SQLite
  // DB open and running background reindexes against the shared WAL. Detected
  // 3 such orphans (from 12:24-12:32) still alive at 15:56. Self-exit within
  // 30s of parent death so the DB handle is released.
  setInterval(() => {
    try {
      if (process.ppid === 1) {
        console.error(`[clinerules-mcp] parent process gone (PPID=1), exiting to avoid orphan leak`);
        process.exit(0);
      }
    } catch { /* never crash the server on a guard check */ }
  }, 30_000);
})();

# clinerules-mcp

On-demand .clinerules lookup MCP. Replaces the practice of loading all 118
rule files (~972KB, ~243K tokens) into every Cline task's system prompt.

## Why

At Opus pricing ($15/Mtok input), loading 118 .clinerules into every task
costs ~$3.65 per task open. ~30 tasks/day = ~$95/day = ~$2,850/month in
pure rules-context tax before any actual work happens. See
orchestrator_idea #5344.

## Architecture

Same shape as the other EMSU MCPs (kaizen, ruben-orchestrator, etc):
- streamableHttp on localhost
- `@modelcontextprotocol/sdk` + `better-sqlite3`
- TypeScript source in `src/`, compiled to `build/`
- Source-of-truth: `~/Documents/Cline/Rules/*.md` (unchanged)
- Index: SQLite with FTS5 over rule bodies, rebuilt on MCP startup
- Mac port: 7860
- Artemis port: 7860 (via WireGuard, mirror deploy)

## Tools

| Tool | Args | Returns |
|---|---|---|
| `clinerules_lookup` | `rule_id` OR `topic` OR `keyword` | Full rule body + cross-refs + violation count |
| `clinerules_list_by_topic` | `topic` | 5-line summary per matching rule |
| `clinerules_search` | `query` | Top-5 FTS5 fulltext matches |
| `clinerules_record_violation` | `rule_id, task_id, evidence` | OK + new counter value |

## Phases

- **Phase 1 (this skeleton):** `clinerules_lookup(rule_id)` + SQLite index. Smoke-test on Mac.
- **Phase 2:** `clinerules_search` + `clinerules_list_by_topic`.
- **Phase 3:** Shrink system-prompt rule-injection to ~10 hard-floor rules. Measure cost-per-task before/after. Ship to Artemis.

## Hard-floor rules (NEVER move to MCP — must stay in system prompt)

These ~10 rules fire automatically without lookup, so they stay loaded:

- 01-voice-and-persona
- 02-no-apologies-in-student-emails
- 00-READ-FIRST-17-force-subagent-use (the tripwire MUST fire at turn 1)
- 29-agents-act-on-confidence-tier
- 38-ruben-asks-equals-autonomous-or-shipped
- 41-post-deploy-call-the-tool-do-not-narrate
- 91-every-completion-needs-pickup-prompt
- 92-work-at-the-core-not-bandaids
- 99-yolo-prevention-learned (auto-generated playbook)

Estimated hard-floor total: ~50KB (vs 972KB current). 95% reduction.

## Reversal

Stop the MCP service, the system prompt continues loading all 118 .clinerules
files like before. Zero data loss — rules stay on disk as source-of-truth.

# Cline Rules Index (always-loaded, MCP-independent)

This file is the fail-safe TOC for the hardfloor rules + how to query the rest.

**Layout:** the 10 hardfloor rules live in `~/Documents/Cline/Rules/` (auto-loaded every task). All other rules (~220+) live in `~/Documents/Cline/Rules-archive/` and are queryable on demand via the `clinerules` MCP server. (Counts verified 2026-06-25 — bloat cleanup + voice rules restored.)

## Precedence — how to resolve two rules that seem to conflict

Conflicts among these rules are almost always *complementary* (one is the escape-hatch for the other), not contradictory. When two directives appear to clash, resolve in this fixed order:

1. **Rule 143 (prose-loop circuit breaker, v2) overrides everything — at its calibrated threshold.** Count only CONSECUTIVE "you did not use a tool" errors (any successful tool call resets the streak; API hiccups don't count). Strikes 1-3 = recover by emitting a (simpler) tool. At 4 consecutive strikes (or 3 empty MCP results in a row from the same server), the ONLY legal next move is `attempt_completion`. 143 is the exit when recovery keeps failing, not a 2-strike bail.
2. **Lower-numbered hardfloor wins** when two hardfloor rules give conflicting *defaults* (e.g. a 29 "act" default vs a more specific later rule's gate). The lower number is the more foundational floor.
3. **A more specific rule beats a general one** for the case it explicitly names (e.g. 42 "safe_deploy already reloads FPM" beats a general "reload after deploy" instinct).
4. **Hardfloor (this dir) always beats archive.** If an archived rule contradicts a hardfloor rule, the hardfloor rule wins; the archived one is stale — flag it.

If after this order it's still ambiguous, that's a genuine rule defect: act on the safest reversible interpretation per rule 29, then file an idea to fix the conflict.

## How to fetch any rule

1. **Preferred:** `clinerules_lookup(rule_id=N)` — works for hardfloor AND archived rules. Returns full body + cross-refs.
2. **Don't know the number?** `clinerules_search(query="...")` — FTS5 over every rule body. Or `clinerules_list_by_topic(topic="...")` for a topic scan.
3. **MCP down fallback:**
   - Hardfloor: `read_file /Users/rubenmajor/Documents/Cline/Rules/<N>-<slug>.md`
   - Archive: `read_file /Users/rubenmajor/Documents/Cline/Rules-archive/<N>-<slug>.md` (or `ls ~/Documents/Cline/Rules-archive/ | grep -i <topic>`)

## Hard-floor rules (always in system prompt — ★)

These 10 rules govern pre-first-tool-call behavior and on-every-turn safety. Rules 29, 41, and 91 were trimmed 2026-06-25 (case law + addenda archived to `Rules-archive/29-case-law.md` + `41-addenda.md`). Voice rules 01+02 restored to hardfloor per Ruben directive. All other rules are one `clinerules_lookup(rule_id=N)` away via the tree.

| ID | Slug | Size | What it fires on |
|---|---|---|---|
| 00 ★ | force-subagent-use | 11K | Default first move; tripwire every tool call |
| 01 ★ | voice-and-persona | 4K | Ruben voice for iMessage/ops chat |
| 02 ★ | no-apologies-in-student-emails | 4K | No apology language in student email |
| 29 ★ | agents-act-on-confidence-tier | 6K | Act/escalate gate (v3 trimmed) |
| 41 ★ | post-deploy-call-the-tool-do-not-narrate | 5K | Banned narration (v2 trimmed) |
| 91 ★ | every-completion-needs-pickup-prompt | 4K | Binary gate: PICKUP PROMPT block required |
| 119 ★ | mandatory-context-compress | 5K | Token-count thresholds (not percentages) |
| 120 ★ | context-is-not-an-excuse | 4K | Never shortcut due to context |
| 143 ★ | prose-loop-circuit-breaker | 5K | Consecutive no-tool-use recovery |
| 144 ★ | no-write-to-file-on-server-paths | 5K | Pre-write server-path gate |

All other rules (including voice/persona, deploy safety, LLM routing, Frankenstein Doctor, payment handling, etc.) live in the archive and are reachable via the `_RULE_TREE.md` tripwire system — one `clinerules_lookup(rule_id=N)` or `clinerules_list_by_topic(topic="...")` call away.

## Rule Tree & Topic Shortcuts

See `_RULE_TREE.md` (also always-loaded) for the full drill-down tree with trigger keywords for every domain:
- **Communication & Voice** — writing student email, ops chat, iMessage, staff escalation
- **Agent Behavior & Autonomy** — act/escalate decisions, self-supervision, routing to humans
- **Infrastructure, Deploy & Debugging** — deploys, SSH, WOPR, Mac, LiteLLM, FPM
- **Project Frankenstein & LLM Routing** — routing, bug library, Frankenstein Doctor, Kaison
- **Task Hygiene & Context** — completion, context compression, ledger, wrap-up
- **Payments, Refunds & Billing** — QB, Authnet, Affirm, refunds
- **Student Lifecycle & Academics** — Moodle, exams, externship, compliance
- **YOLO & Failure Recovery** — circuit breaker, per-class playbook, timeout handling

The full archive (~230 rules) is in `~/Documents/Cline/Rules-archive/`. Don't try to memorize. Use the tree triggers + MCP.

Common fetch commands:
- `clinerules_lookup(rule_id=146)` — get full rule text by number
- `clinerules_list_by_topic(topic="voice")` — get all rules in a domain
- `clinerules_search(query="...")` — FTS5 search across all rule bodies

## Adding a new rule

Drop the .md in `~/Documents/Cline/Rules-archive/` (or `Rules/` if it's a new hardfloor — needs Ruben's call). The `.pre-write-lint.sh` gate enforces shape. Then:

1. **Update the tree.** Follow `_RULE_TREE.md` §"Adding New Rules": classify the rule into a domain, add its number to the right sub-topic line. A rule not in the tree is invisible to future windows.
2. **Reindex the MCP:**
   ```
   node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only
   ```
3. **Cross-check MCP resources.** If the new rule references any `emsu://reference/` or `emsu://system/` resource, verify it's listed in the tree's Cross-Reference section.

The MCP is the search engine. The tree is the navigation map. New rules need both.

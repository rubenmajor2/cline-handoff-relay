# Cline Rules Index (always-loaded, MCP-independent)

This file is the fail-safe TOC for the hardfloor rules + how to query the rest.

**Layout:** the 12 hardfloor rules + `99-yolo-prevention-learned` (auto-generated meta) live in `~/Documents/Cline/Rules/` (auto-loaded every task). All other rules (~220+) live in `~/Documents/Cline/Rules-archive/` and are queryable on demand via the `clinerules` MCP server. (Counts verified 2026-07-02 — rule 99 added to META_FILES, audit cron + fswatch lint enforcement created, rule 245 collision resolved by renumbering burst rule to 247.)

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

These 12 rules govern pre-first-tool-call behavior and on-every-turn safety. Rules 29, 41, and 91 were trimmed 2026-06-25 (case law + addenda archived to `Rules-archive/29-case-law.md` + `41-addenda.md`). Voice rules 01+02 restored to hardfloor per Ruben directive. All other rules are one `clinerules_lookup(rule_id=N)` away via the tree.

**`99-yolo-prevention-learned`** is NOT a hardfloor rule — it is an **auto-generated meta file** (regenerated every 30 min by `~/Documents/Cline/yolo_learner/write_rule.py` from the YOLO-trips database). It is always-loaded because the per-class failure playbook must be visible in every window (rule 99's whole purpose is pre-empting the exact `fail > fail > fail` triples that kill tasks). It is listed in `META_FILES` in `.pre-write-lint.sh` so G6 does not flag it. Size-capped at 20KB like the other meta files.

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
| 259 ★ | cline-tasks-stay-in-cline-not-chat55 | 4K | No spillover to group chat |
| 267 ★ | orchestrator-executor-offload-and-reconcile | 6K | Offload gate + reconcile-before-completion gate |

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

## Adding a new rule (durable constraints — read before adding)

**Default: new rules go in `~/Documents/Cline/Rules-archive/`, NOT `Rules/`.** Only add to `Rules/` if the rule must fire on every turn (pre-first-tool-call behavior or on-every-turn safety) AND Ruben approves it as hardfloor. The vast majority of rules belong in the archive, fetched on demand via the tree.

### Hard caps (enforced by `.pre-write-lint.sh` + nightly audit cron)

| Constraint | Limit | Enforced by |
|---|---|---|
| Hardfloor rules in `Rules/` | 12 (currently) + 4 meta = 16 files max | G6 gate (block) + nightly audit (alert) |
| Single hardfloor rule size | 8KB warn / **12KB hard block** | G2 (warn) + **G7 (block)** + nightly audit |
| Meta file size (`_INDEX`, `_RULE_TREE`, `EXECUTE_ORDER_66`, `99-yolo-prevention-learned`) | 16KB warn / **20KB hard block** | G7 (block) + nightly audit |
| Total `Rules/` directory | 180KB warn / **250KB alert** | Nightly audit |

### The trim-then-archive pattern (when a hardfloor rule exceeds 8KB)

Rules metastasize through addenda creep (source incidents, case law, per-class elaborations). When a hardfloor rule hits 8KB, trim it:

1. **Extract the core gate** (the binary test the rule fires on — usually 1-2KB)
2. **Move case law + addenda** to `Rules-archive/<N>-case-law.md` (see `29-case-law.md`, `41-addenda.md` for the pattern)
3. **Add a cross-ref** in the trimmed rule: `Full case law + source incidents: Rules-archive/<N>-case-law.md`
4. **Re-run `.pre-write-lint.sh`** to confirm G7 passes (<12KB)
5. **Reindex the MCP**

### Steps to add a new rule

1. **Drop the .md in `~/Documents/Cline/Rules-archive/`** (default) or `Rules/` (only if hardfloor + Ruben-approved).
2. **If adding to `Rules/`:** add the slug to `HARDFLOOR_SLUGS` in `.pre-write-lint.sh` FIRST, or G6 will block the write.
3. **Update the tree.** Follow `_RULE_TREE.md` §"Adding New Rules": classify the rule into a domain, add its number to the right sub-topic line. A rule not in the tree is invisible to future windows.
4. **Reindex the MCP:**
   ```
   node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only
   ```
5. **Cross-check MCP resources.** If the new rule references any `emsu://reference/` or `emsu://system/` resource, verify it's listed in the tree's Cross-Reference section.

### Nightly audit cron (self-healing bloat detection)

`~/Documents/Cline/scripts/cline_rules_audit.sh` runs nightly at 3:15 AM PT via launchd (`com.emsu.cline-rules-audit`). It checks file count, per-rule size, total directory size, HARDFLOOR_SLUGS drift, rule-number collisions (duplicate `NNN-` prefixes), and `.clinerule_counter` vs highest-actual-rule-number drift — posting to ops chat 55 on any alert. This makes bloat + counter drift self-healing instead of requiring a Ruben-initiated investigation. Manual run: `cline_rules_audit.sh --quiet` (log only, no chat post). Created 2026-07-02 (was previously documented but missing — the self-healing detector itself had drifted away).

### Pre-write lint enforcement (fswatch)

`.pre-write-lint.sh` is invoked by an `fswatch` listener (`~/Library/LaunchAgents/com.emsu.cline-rules-audit.plist`, `WatchPaths` on `Rules/`) on every save under `Rules/`. This is the real-time gate that catches collisions, bloat, and counter drift the moment a file lands — before the nightly audit sees it. `fswatch` must be installed (`brew install fswatch`). The listener is loaded by the same launchd plist as the nightly audit. If `fswatch` is absent, the nightly audit still runs but real-time enforcement is lost.

The MCP is the search engine. The tree is the navigation map. The lint gate is the write filter. The audit cron is the drift detector. New rules need all four.

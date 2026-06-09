# Cline Rules Index (always-loaded, MCP-independent)

This file is the fail-safe TOC for the hardfloor rules + how to query the rest.

**Layout:** the 19 hardfloor rules live in `~/Documents/Cline/Rules/` (auto-loaded every task). All other rules (~184) live in `~/Documents/Cline/Rules-archive/` and are queryable on demand via the `clinerules` MCP server. (Counts verified 2026-06-09.)

## Precedence — how to resolve two rules that seem to conflict

Conflicts among these rules are almost always *complementary* (one is the escape-hatch for the other), not contradictory. When two directives appear to clash, resolve in this fixed order:

1. **Rule 143 (prose-loop circuit breaker) overrides everything.** If you have hit 2 "you did not use a tool" errors, or 2 MCP calls returned empty, the ONLY legal next move is `attempt_completion` — even if 00/41/99 say "emit a tool." 143 is the unconditional exit.
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

| ID | Slug | What it fires on |
|---|---|---|
| 00-READ-FIRST-17 ★ | force-subagent-use | Default first move every task; tripwire on every tool call |
| 01 ★ | voice-and-persona | Ops chat voice — Ruben speaking, casual, no em-dash |
| 02 ★ | no-apologies-in-student-emails | Student-facing email composition |
| 29 ★ | agents-act-on-confidence-tier | act/Q-card/escalate gate |
| 38 ★ | ruben-asks-equals-autonomous-or-shipped | Ruben-directed work → status=approved |
| 41 ★ | post-deploy-call-the-tool-do-not-narrate | Banned "Deployed./Now I'll" prose |
| 42 ★ | safe-deploy-already-reloads-fpm | safe_deploy auto-reloads FPM. No systemctl, ever. |
| 91 ★ | every-completion-needs-pickup-prompt | attempt_completion shape |
| 92 ★ | work-at-the-core-not-bandaids | Fix RUBEN, don't fix FOR RUBEN |
| 99 ★ | yolo-prevention-learned | Auto-generated per-failure playbook |
| EXECUTE_ORDER_66 ★ | wrap-up (stub → archive) | Trigger phrases → MCP lookup |
| 118 ★ | litellm-restart-via-safe-wrapper | Never raw `systemctl restart litellm` — use safe wrapper |
| 119 ★ | mandatory-context-compress | context ≥ 30% → check; ≥ 50% → compress now; ≥ 70% → attempt_completion |
| 120 ★ | context-is-not-an-excuse | Context never justifies skipping work — compress or work fully, no middle ground |
| 135 ★ | student-lifecycle-service-sls | Canonical name for the student lifecycle + payment brain (SLS) |
| 137 ★ | build-task-convergence-gate | Declare a Definition-of-Done check first, then loop change→verify→done |
| 140 ★ | verify-llm-routing-from-live-headers | Prove routing with a live header probe, never from file-reads |
| 141 ★ | frankenstein-mcp-verification-gate | Call the project-frankenstein MCP before answering Frankenstein/LLM-routing |
| 142 ★ | no-dead-end-llm-entrypoints | An entrypoint with a long timeout + no fallback is un-deployable |
| 143 ★ | prose-loop-circuit-breaker | After 2 no-tool-use errors, the ONLY legal move is attempt_completion |

## Archive — common topic shortcuts

The full archive (~184 rules) is in `~/Documents/Cline/Rules-archive/`. Don't try to memorize. Use the MCP. Common starting points:

- **Voice / comms / staff escalation:** `clinerules_list_by_topic(topic="voice")` → rules 10, 13, 15, 19, 30, 47, 48, 57, 72, 96, 101, 108, 111
- **Agent behavior / escalation tiers:** `clinerules_list_by_topic(topic="agent")` → rules 12, 22, 23, 36, 42, 46, 49, 53, 54, 56, 65, 66, 67, 68, 69, 73, **117** (Tired Ruben — low-bandwidth autonomous protocol: 5-tier act/queue/file/question/discard model)
- **Infrastructure / debugging / Mac+WOPR:** `clinerules_list_by_topic(topic="cline mac")` → rules 16, 20, 24, 25, 26, 27, 28, 29-mac, 34, 77, 95, 100, 102, 105, **136 (Artemis Arc box access — emsu-operations MCP ssh_command, NEVER raw `ssh artemis` → causes YOLOs)**

- **Task hygiene / wrap-up:** `clinerules_list_by_topic(topic="task")` → rules 03, 04, 05, 06, 07, 09, 52, 109, 113
- **Compliance / regulatory:** `clinerules_list_by_topic(topic="regulator")` → rules 08, 18, 60, 61, 103
- **Payments / Authnet / QB / Affirm:** `clinerules_list_by_topic(topic="payment")` → rules 70, 107, 114
- **YOLO recovery / extension host:** `clinerules_list_by_topic(topic="yolo")` → rules 16, 95, 97, 98, 99

## Adding a new rule

Drop the .md in `~/Documents/Cline/Rules-archive/` (or `Rules/` if it's a new hardfloor — needs Ruben's call). The `.pre-write-lint.sh` gate enforces shape. Then:

```
node ~/Documents/Cline/mcp-servers/clinerules-mcp/build/index.js --reindex-only
```

That's it. The MCP picks it up on next `lookup` / `search`. No manual TOC update required because the MCP IS the TOC.

# 261 — MCP failure classification: 4 modes before declaring "wedge"

Permanent rule. Workspace-scoped. Source incident: 2026-07-08 — Frankenstein Doctor RCA found agents falsely declaring "MCP is wedged" when MCPs were green (Ruben confirmed). Root cause: agents conflated 4 distinct failure modes and cited rule 143 → rule 77, but rule 77 is about LiteLLM router overload, NOT MCP transport.

## The bright-line rule

**Before declaring "MCP is wedged" or pivoting away from an MCP server, classify the failure into exactly one of these 4 modes. Each has a different recovery path.**

| Mode | Symptom | Root cause | Recovery |
|---|---|---|---|
| **A: Server down** | Connection refused, ECONNREFUSED, timeout on connect | MCP server process not running, crashed, or port closed | Check `server_status` / process list. Restart server. Do NOT retry the same call. |
| **B: Session expired** | "No valid session ID", "session not found", 401/403 | Streamable-HTTP session timed out or was invalidated | Re-init the MCP connection (restart connection in Cline settings). Retry the call ONCE after re-init. |
| **C: Transport error** | "result missing", empty body, partial JSON, hang mid-stream | Network instability, Cloudflare 502, supergateway flapping | Check `systemctl NRestarts` on the MCP service. Retry ONCE after 5s. If still failing, pivot to different MCP server. |
| **D: Transient empty** | Empty result on first call, but second call works | Race condition, cold start, momentary blip | Retry ONCE. If second call succeeds, was transient — do NOT declare wedge. |

## The 3-gate check (rule 258 composition — run BEFORE declaring wedge)

**Gate 1: Is the result actually empty?** Check the tool output. Is it `{}`, `null`, `""`, `undefined`, or genuinely missing? If the result has content but isn't what you expected, that's NOT a wedge — that's a query issue.

**Gate 2: Is it stale?** How old is the data? If the MCP returned data but it's from an old timestamp, that's staleness, not wedge. Check `last_heartbeat` or equivalent.

**Gate 3: Cross-source verification.** Before declaring wedge, verify with a DIFFERENT source. If `mysql` MCP fails, try `emsu-operations ssh_command` with a raw SQL query. If BOTH fail with the same error, the underlying service (MySQL) is down, not the MCP transport. If only the MCP fails but SSH works, THEN it's an MCP transport issue.

**All 3 gates must FAIL before declaring wedge.** One empty result is NOT a wedge. Two empty results is NOT a wedge (could be transient). Three empty results with cross-source verification failing = wedge.

## Rule 143 cross-ref fix

Rule 143 line 51 and line 64 previously cited "rule 77 — WOPR tunnel-down: wedged MCP transport." This was BROKEN. Rule 77 is about LiteLLM router overload (`overloaded_error` at `127.0.0.1:8787`), NOT MCP transport. The correct cross-ref is **this rule (261)**. Rule 143 has been updated.

## What does NOT count as "wedged"

- **One MCP call returns empty.** Could be transient (mode D). Retry once.
- **MCP call returns an error.** Could be session expired (mode B). Re-init and retry.
- **MCP call is slow.** Could be the underlying query is slow, not the transport. Add LIMIT, check indexes.
- **MCP settings show green but call fails.** The settings UI shows connection status, not runtime session health. Session can expire while connection shows green (mode B). This is the exact pattern Ruben reported on 2026-07-08.

## Anti-patterns

- ❌ "MySQL MCP connection dropped. Falling back to ssh_command." — Did you classify the failure? Could be mode D (transient). Retry first.
- ❌ "MCP is wedged (rule 143: 3+ MCP failures in a row = switch paths)." — Did you run the 3-gate check? 3 empty results without cross-source verification is NOT wedge.
- ❌ "emsu-operations MCP is wedged (2 failures — rule 77/258)." — Rule 77 is about LiteLLM router, not MCP. Use rule 260. And 2 failures is not enough — run the 3-gate check.
- ❌ Pivoting to a different MCP server after 1 failure. Classify first. Mode D (transient) just needs a retry.

## Cross-references

- Rule 143 — prose-loop circuit breaker (the MCP "result missing" trigger now cites THIS rule, not rule 77)
- Rule 258 — MCP stale/empty data truth gate (the 3-gate check originates here)
- Rule 77 — LiteLLM router overload (NOT MCP transport — do not cite for MCP failures)
- Rule 181 — MCP auto-reconnect before reporting broken
- Rule 222 — MCP down repair and prebuild guard
- Rule 23 — KAIZEN MCP (failure-classifier nurturer — for recurring agent failures, not MCP transport failures)

## Source incident

2026-07-08 — Frankenstein Doctor RCA. Ruben reported: "Cline agents keep saying 'MCP is wedged' but when I check Cline settings, all MCPs are green." Investigation found: (1) agents cited rule 143 → rule 77 for "wedged MCP transport," but rule 77 is about LiteLLM router overload, not MCP; (2) agents declared wedge after 1-2 empty results without running rule 258's 3-gate check; (3) the "No valid session ID" error is mode B (session expired), not transport wedge — the MCP server is healthy, the session just timed out. Filed as idea #16849. This rule created to fix the broken cross-ref and provide the 4-mode classification.

## Last updated

2026-07-08 — initial. Source: Frankenstein Doctor RCA (task #1779). Fixes the rule 143 → rule 77 broken cross-ref. Provides 4-mode classification + 3-gate check before declaring MCP wedge.
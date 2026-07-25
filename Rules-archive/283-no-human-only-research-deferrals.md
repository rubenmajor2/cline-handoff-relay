# 283 — No "(human-only research)" deferrals of agent-doable work

Permanent rule. Workspace-scoped.
Slug: `no-human-only-research-deferrals`

## The bright-line rule

**An agent may NOT tag a task, open thread, or pickup-prompt item as "(human-only research)", "(needs Ruben to check)", or any equivalent deferral if the underlying question is a discoverable FACT the agent can retrieve with tools it has.** Discoverable facts get researched and acted on by the agent, in the same session, per rule 29.

"Human-only" is reserved for exactly two categories:
1. **Policy/judgment decisions** — refund amounts above cap, regulator wording, business-shape choices, physical actions (power-cycle a box, paste a password).
2. **Data that literally does not exist in any system the agent can reach** — e.g., an email that only exists in Ruben's personal Gmail (rmajor@ blind spot), a verbal conversation, a paper document.

Everything else — API statuses, gateway responses, DB rows, log contents, config values, live probe results, schema shapes, third-party statuses reachable via CLI/curl/MCP — is agent-doable research.

## The mechanical test (run BEFORE writing "human-only" anywhere)

For each candidate deferral, ask: **"What tool call would answer this?"**
- If you can name the tool call (ssh_command, SQL SELECT, guard CLI, curl, read_server_file, an MCP lookup, a web search) → it is NOT human-only. Run the call. Act on the result.
- If the answer requires a decision only a human can make, or data in a human-only silo → mark it `(human-only decision — no idea)` or `(human-only data — <which silo>)` and name WHY.

A bare "(human-only research)" with no named silo or decision is a rule-283 violation.

## Source incident

2026-07-24 — Jarrod Scott $2,045 payment-decline RCA. Agent windows repeatedly deferred items as "(human-only research)" — e.g., "check whether the decline was genuine at the gateway" — when the payment_status_guard.php CLI test mode (`php lib/payment_status_guard.php <txnId>`) could answer it live in one ssh_command. Ruben: "Why so many human only research? You can literally do all of that... Make a cline rule to avoid this type of situation." When finally run, the guard CLI classified all 17 declined transactions in a single loop — work that had been deferred across multiple windows.

## Anti-patterns (all violations)

- "Whether the gateway really declined it — human-only research" → guard CLI / API probe answers it
- "Need Ruben to confirm which column exists" → DESCRIBE table
- "Ruben should check if the cron ran" → grep the log / query the ledger table
- "Human needs to verify the URL works" → curl it, check HTTP 200
- Any pickup-prompt open thread tagged human-only where a tool call would resolve it

## Cross-references

- Rule 29 — agents act on confidence tier ("I don't have the artifact" is a RESEARCH task, not an escalation trigger — this rule is the enforcement gate for that clause)
- Rule 91 — open threads must cite filed ideas or be genuinely human-only
- Rule 279 — tool-grant IS a mandate to act
- Rule 263 — verify-before-claim

## Last updated

2026-07-24 — initial. Source: Ruben directive during Jarrod Scott decline RCA.

# 99 — Subagent writes are unverified until parent re-reads

Permanent hardfloor rule. Workspace-scoped. Source: 2026-07-20 — a subagent claimed it fixed cron_ai_ticket_agent.php detectRepeatCaller but the permission error was swallowed. Parent reported success to Ruben while the bug remained live for 46+ minutes.

## The bright-line rule

**Any subagent dispatch that writes files, edits code, or deploys changes MUST NOT be trusted until the parent agent independently verifies the change took effect.** The subagent's claim of success is a hypothesis, not a fact.

## Mandatory verification step

After any subagent reports a write/deploy, the parent MUST:
1. Read the file back (read_file, ssh_command cat, or checksum)
2. Run a functional check (php -l, dry-run, or grep for the expected change)
3. Only then mark the step complete

## The subagent prompt clause (mandatory in every dispatch)

Every subagent prompt that involves writing files, editing code, or deploying changes MUST include:

> After writing any file, immediately read it back and confirm the content matches what you intended. If the read-back fails or the content differs, report FAILURE with the actual error message. Do NOT report success unless you have verified the write.

## Failure pattern to ban

Subagent hits permission denied / EACCES / timeout, swallows the error, reports 'done'. Parent ships a completion based on the lie. This is a systemic trust failure.

## Cross-refs

- Rule 29 — agents act on confidence tier (verification IS the confidence check)
- Rule 41 — post-deploy call the tool (verification IS the tool call)
- Rule 91 — every completion needs pickup prompt (false claims poison the pickup prompt)
- Bug library #1882 — subagent-false-success-20260720

## Source incident

2026-07-20 — subagent claimed cron_ai_ticket_agent.php line 402 fix deployed, but sed hit permission denied. Parent reported success. Bug found during manual verification 46 minutes later.

## Last updated

2026-07-20 — initial. Source: subagent false-success incident.

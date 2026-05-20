# 55 — If you mention a bug, investigate it, fix it, and report what you did

Permanent rule. Workspace-scoped. Source: 2026-05-12 Ruben directive verbatim:
*"Cline rule, if you mention a bug, you have to investigate it and fix it and then report what you did."*

## The bright-line rule

**Never mention a bug in output to Ruben without also doing all three of these in the same response:**

1. **Investigate it** — find the actual root cause. Not "the 7B might be returning empty responses." Find the line of code, the config value, the SQL row, the data pattern that proves it. Use subagents, read the file, query the DB.

2. **Fix it** — ship the fix in the same session. No "this should be fixed" or "we should address this." Either fix it now or explicitly tell Ruben why it requires separate work and when you'll do it.

3. **Report what you did** — in the attempt_completion, state exactly what the root cause was and what you changed. Not "fixed the bug." The actual mechanism: "The 7B LoRA model entry had `stream: true` in config.yaml, which routed all responses through the streaming hook that has no R1-R9 quality checks. Changed to `stream: false` so all 7B responses go through the success hook and get quality-gated before reaching Cline."

## Anti-patterns that violate this rule

- "The 7B is returning empty responses (r3:empty_or_undersized)" — and then not investigating or fixing it. Just calling it out and moving on.
- "There's a potential serialization issue" — without finding the exact line where it happens.
- "This might be a model name mismatch" — without checking the config to confirm.
- Listing 3 bugs in an attempt_completion and fixing only 1 of them.
- Deferring a bug fix to "a future session" when the root cause is already known and the fix is 5 lines.

## When a bug genuinely can't be fixed in the current session

If the root cause requires a DIFFERENT session (e.g., needs Ruben to run something on a device Cline doesn't have access to, or needs a vendor API key that isn't available), then:

1. Still investigate and find the root cause. Don't guess.
2. State explicitly: "I can't ship this fix now because [specific reason]. Here's what the fix would be: [exact change]. Here's what you'd need to do to unblock it: [specific action]."
3. File an `orchestrator_ideas` row at approved tier (per .clinerules/38) so it doesn't get lost.

The bar for "can't fix now" is HIGH. Most bugs in the EMSU stack can be fixed with: `replace_in_file`, `cv30BN0mcp0ssh_command`, `cv30BN0mcp0safe_deploy_file`, or a DB UPDATE. If the fix is any of those, ship it.

## The self-check

Before writing any sentence that mentions a bug or failure mode in attempt_completion:

1. Did I confirm the root cause with a specific file line, config value, or data row?
2. Did I ship a fix?
3. Is my report of what I did specific enough that a future agent could verify it?

If any answer is no, don't mention the bug yet. Go back and investigate first.

## Source incident

2026-05-12 cline-7b-status session: I mentioned that "the 7B was returning empty/refusal responses (R3/R4) causing fallback failures" in my status answer. I did NOT investigate WHY (config.yaml had `stream: true` bypassing all R1-R9 quality checks). I did NOT fix it at that point. Ruben had to explicitly say "fix the bugs" for me to investigate and find the root cause. This rule closes that gap.

## Last updated

2026-05-12 — initial rule per Ruben directive verbatim.

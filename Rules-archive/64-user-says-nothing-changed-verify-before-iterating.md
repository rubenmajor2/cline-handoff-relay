# 64 — When user says "nothing changed" / "still broken", VERIFY before shipping another fix

Permanent rule. Workspace-scoped. Source: 2026-05-13 cline_reports-403-fix.
After my first fix Ruben said "oh wait now it's good." Then he said "still
regressed" and I shipped ANOTHER fix without ever re-checking what the page
actually looked like. That fix (4 `return` guards in unconditionally-required
view files) broke function definitions reports.php needed, making cards
disappear that WERE there. Two regressions deep, ~$50 of Opus tokens, before
I finally launched the browser and saw what was actually wrong.

## The bright-line rule

**When the user replies to my fix with any of these:**
- "nothing changed"
- "still broken"  
- "still missing X"
- "page is the same"
- "still regressed"
- "[same screenshot]"

**My next tool call MUST be a VERIFICATION step, not another fix.** Specifically:

1. If a visual page is involved → `browser_action launch` (per rule 62) WITH a real session (per rule 63 if auth-gated). Look at what's there.
2. If a non-visual surface → query the DB/file/log to confirm current state.
3. ONLY after I've verified the actual current state may I propose another fix.

## What I MUST NOT do

After a "nothing changed" reply:

1. ❌ Immediately read more source code and ship another speculative fix
2. ❌ Assume my last fix was working but a NEW bug surfaced (could be either)
3. ❌ Build a more elaborate scanner / theory / static analysis before checking reality
4. ❌ Apologize and ship another guess in the same turn

The user already told me something is wrong. The cost of finding out WHAT is wrong before shipping is ~$0.05 (one browser launch). The cost of shipping a 2nd wrong fix is another ~$5-20 in tokens AND the user has to come back AGAIN.

## The recovery loop (mandatory after a "nothing changed")

1. **Acknowledge**: "Let me look at what's actually rendering before shipping anything else."
2. **Launch browser** (per rule 62/63) — see what they see.
3. **Diff against expected**: identify the SPECIFIC element/text that's wrong.
4. **Grep for that specific text/element in the source**, not for "patterns that look similar."
5. **Ship the targeted fix**.
6. **Re-launch browser** to verify the fix moved the needle.

## Anti-pattern this rule prevents

The "fix-stacking" failure mode where each iteration adds new code without ever
confirming the previous code worked. By iteration 3 the codebase has 3 patches
on top of each other, two of which may be wrong, and the original bug is still
unfixed. The 2026-05-13 source incident had this exact pattern:
- Fix 1: AI violation view (correct)
- Fix 2: 4 over-aggressive `return` guards (WRONG — broke functions)
- Fix 3: revert + auth hoist (correct but didn't address the real remaining bug)
- Fix 4: exam scheduling view (correct, finally targeting the real bug)
- Fix 5: report_registry null-safe (correct, surfaced by fix 4)

Fixes 2 and 3 were paid for entirely because I didn't verify between fix 1 and them.

## What "verify" actually looks like (concrete examples)

| User says | My verification step BEFORE another fix |
|---|---|
| "page still missing cards" | browser launch + scroll, identify exact missing element |
| "email still not sending" | check `email_outbound_log` for the row, check Postmark API status |
| "cron didn't fire" | check `cron_run_log` / `last_run_at` column |
| "student still showing as enrolled" | DB query the actual Students row, not infer from logs |
| "the AI keeps doing X" | pull the actual conversation row, not theorize about prompt rules |

## Cost framing

A verification tool call is ALWAYS cheaper than another speculative fix call:
- `browser_action` ≈ $0.02-0.05
- DB query via MCP ≈ $0.005-0.02  
- `cat` / `tail` via ssh ≈ $0.001-0.01
- A speculative fix that's wrong ≈ $1-10 in tokens + erodes user trust

The math doesn't even require thinking about it.

## When this rule doesn't apply

- User said "nothing changed BUT now there's a different error: X" → that IS the verification, X is the new target
- User said "page works now but I want to add Y" → different request entirely, not a "still broken" loop
- User explicitly says "just keep trying, I don't have time to look right now" → honor it, but flag the risk

## Cross-references

- Rule 62 — browser-first for visual UI bugs
- Rule 63 — session-bridge endpoint for auth-gated pages
- Rule 41 — post-deploy: call the tool, don't narrate (same family)
- Rule 99 — YOLO prevention (this rule prevents the "no-tool-use > no-tool-use" trip class on repeated user complaints)

## Last updated

2026-05-13 — initial. Source: cline_reports-403-fix-2026-05-13. Ruben after the
fix finally landed: "Some of my having to convince you regarding the browser
issue was annoying. In fact I upgraded to Opus thinking it would help and
spent $75 on this task. Propose some cline rules so this doesn't happen again."

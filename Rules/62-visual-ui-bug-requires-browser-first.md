# 62 — When the user reports a visual/UI bug, launch the browser FIRST. Not curl, not grep, not theory.

Permanent rule. Workspace-scoped. Source: 2026-05-13 cline_reports-403-fix burned
~$75 of Opus tokens over 6+ failed iterations because I kept "diagnosing" reports.php
via `curl -o /dev/null -w '%{http_code}'`, file grep, and PHP-FPM error log
tailing — when the actual bug was a **rendered HTML payload Ruben could see in
his browser** that I had never once looked at.

## The bright-line rule

**When the user reports any of these symptoms, my FIRST tool call after reading
the message MUST be `browser_action` (or building the session-bridge endpoint
from rule 63 if the page is auth-gated):**

- "the page is broken"
- "the page doesn't show X"
- "cards are missing"
- "the header is gone"
- "looks weird"
- "the page is the same"
- "nothing changed"
- "[some part of UI] isn't rendering"
- "I see [specific text] but [other thing]"
- screenshots, page text quotes, anything visual

**The user is describing what their eyes see. Curl returning HTTP 200 or 401 does
not answer their question. PHP `-l` syntax-clean does not answer their question.
A scanner showing "0 dangerous files" does not answer their question. Only
seeing what they see answers their question.**

## What I MUST NOT do as the first move

Banned first moves on visual-UI bug reports:

1. ❌ `curl -s -o /dev/null -w '%{http_code}' <url>` — tells you nothing about rendered content
2. ❌ `php -l <file>` — only proves it parses, not that it renders right
3. ❌ Custom scanner that scans 90+ files for static patterns — proves nothing about runtime
4. ❌ Tailing PHP-FPM log NOTICE lines — those are FPM lifecycle, not errors
5. ❌ Reading 300 lines of source code trying to deduce what would render
6. ❌ "It returned 401, which means it would have rendered fine when logged in" — assumption, not evidence

## What I MUST do first

1. **If the page is public**: `browser_action launch <url>` immediately. Look at the screenshot. Match what I see to what the user described.
2. **If the page is auth-gated**: build the session-bridge endpoint per rule 63 (one-time, ~5 min), then `browser_action launch <bridge_url>`. Same eyes-on diagnosis.
3. **Either way**: scroll through the page (`browser_action scroll_down`) to verify the FULL extent of the bug, not just the first viewport.

Only AFTER I have seen what the user sees do I form a hypothesis and start grepping/curling for the cause.

## What changed from how I was operating before

Old (broken) loop:
- User: "cards aren't showing"
- Me: scan files for patterns that LOOK suspicious
- Me: ship a fix based on a static-analysis hunch
- Me: curl → returns 401 → "fix verified, page returns correct status code"
- User: "nothing changed"
- Me: scan more files, ship more fixes
- User: "nothing changed"
- (repeat 4 more times)

New (correct) loop:
- User: "cards aren't showing"
- Me: open browser with session, look at the page
- Me: see EXACTLY which point the page stops rendering
- Me: grep ONLY for the specific 403/500/exit message I can see in the screenshot
- Me: ship a fix targeting that one specific cause
- Me: re-open browser, verify the fix made the page render further down
- (repeat only if more bugs are downstream)

## Cost calculus

Each browser_action call costs ~$0.01-0.05 (Puppeteer rendering + Anthropic vision tokens). 
Each "theorize from grep" iteration that ships a wrong fix costs 5-10x that AND
burns a YOLO consecutive-mistake slot AND erodes user trust. 

The browser is the cheapest tool on the board for visual bugs. Use it first.

## What this rule does NOT do

- Doesn't apply to backend-only bugs (cron didn't fire, DB row didn't update, email didn't send) — those legitimately need DB/log/code inspection.
- Doesn't apply when the user explicitly says "don't bother launching the browser, just fix X" — honor that.
- Doesn't apply when I'm shipping a known-narrow fix the user already verified visually (e.g. "change the button color to blue").

## Companion rules

- Rule 63 — session-bridge endpoint pattern for auth-gated visual debugging
- Rule 64 — when user says "nothing changed", browser-verify BEFORE iterating more

## Last updated

2026-05-13 — initial. Source: cline_reports-403-fix-2026-05-13 cost ~$75 of Opus
tokens because I would not stop curling and start looking. Ruben directive after
the fix finally landed: "Some of my having to convince you regarding the browser
issue was annoying."

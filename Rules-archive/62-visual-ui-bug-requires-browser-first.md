# 62 — Visual UI bug: browser-verify is mandatory before declaring fixed, even if curl found something

Permanent rule. Workspace-scoped. Source: 2026-05-13 cline_reports-403-fix burned
~$75 of Opus tokens over 6+ failed iterations because I kept "diagnosing" reports.php
via curl/grep/static-scan and shipping fixes without ever looking at the page.
Updated 2026-05-13 PM after Ruben softened the original rule: curl is sometimes
genuinely faster, but the browser is NON-NEGOTIABLE as a verification step
before claiming "fixed."

## The bright-line rule (revised)

**When you report a visual UI bug, browser_action is not always my FIRST move —
sometimes curl/grep is genuinely faster (e.g. I can see the 500 in the log
immediately, or the HTTP code is the diagnostic). BUT the browser is
NON-NEGOTIABLE in these two cases:**

1. **First-tool fallback**: If my initial curl/grep/file-read pass finds nothing
   that matches your described symptom, my NEXT tool call MUST be
   `browser_action`. I do not get to conclude "the page must be fine" or "must
   be your cache" — that's me dismissing your eyes-on report without evidence.

2. **Pre-completion verification**: Before declaring "fixed" / completing the
   task, I MUST `browser_action launch` (with session bridge per rule 63 if
   auth-gated) and see the page rendering correctly. HTTP 200 / 401 is NOT
   verification of a visual bug fix.

The trigger phrases for visual bugs are unchanged:
- "the page is broken"
- "the page doesn't show X"
- "cards are missing"
- "the header is gone"
- "looks weird"
- "the page is the same"
- "nothing changed"
- screenshots or pasted page text from the user

## What I MUST NOT do (still the same)

1. ❌ Conclude "must be a cache issue" without browser verification
2. ❌ Conclude "must be a hallucination" / "I don't see the issue" without
   browser verification
3. ❌ Use HTTP code (200, 401, 403) as proof that a visual bug is fixed
4. ❌ Ship a fix and immediately call attempt_completion without re-launching
   the browser to see the change rendered
5. ❌ "It passes php -l, so it must work" — syntax-clean doesn't mean
   visually-correct

## What changed from the original (overly strict) rule

The first version of this rule said browser MUST be the first tool call,
period. Ruben softened it after one debug round where curl was genuinely the
right first move (he could tell me the exact HTTP code, php-fpm log already
showed the fatal, etc.). The lesson is:

- Curl/grep CAN be the first move when they're genuinely faster — e.g. you
  give me a specific PHP error message in the URL bar, and I can find the file
  in 5 seconds via grep.
- But the browser MUST run if those first moves don't surface a cause matching
  your description. The user reporting a visual symptom is evidence. The
  absence of a hit in grep/curl is NOT counter-evidence — it's just a miss.
- And the browser MUST run before completion. Always.

## The cost calculus (still applies)

- `browser_action` ≈ $0.02-0.05 per call
- A wrong fix that ships because I didn't verify ≈ $5-20 in tokens + your time
- Ratio: ~100:1. The math says always verify.

## Companion rules

- Rule 63 — session-bridge endpoint pattern for auth-gated visual debugging
- Rule 64 — when user says "nothing changed", browser-verify BEFORE iterating more

## Last updated

2026-05-13 (PM update) — softened from "browser MUST be first move" to
"browser MUST be the fallback if curl found nothing AND must run before
completion." Source incident still cline_reports-403-fix-2026-05-13 (where the
overly strict version was originally written + Ruben's same-day pushback that
curl is sometimes faster).

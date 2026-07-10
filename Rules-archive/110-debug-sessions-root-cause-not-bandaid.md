# 110 — In intense debugging sessions, find root cause + spread, don't bandaid

Permanent rule. Workspace-scoped. Source: 2026-05-22 22:33 PT Ruben directive verbatim during cline_wpforms_replay_halt_2026-05-22:

> *"cline rule - identify the root cause rather than make bandaids for issues."*

Companion + extension of .clinerules/92 (work-at-the-core), .clinerules/42 (proactive systemic solutions), .clinerules/85 (prefer systemic fix over spot fix), .clinerules/66 (offer to fix everyone in same situation).

## The bright-line rule

**When in a debugging session — especially one that surfaced from a real student/ops impact — the FIRST thing Cline does after observing the symptom is identify root cause and full SPREAD across the codebase, BEFORE proposing or executing any fix.**

"Find one broken file, patch it, move on" is the bandaid pattern. The complete pattern is:

1. **Reproduce or trace the symptom** to a specific code path + line range
2. **Identify root cause** — not the proximate trigger ("class_format had bad data") but the structural reason ("resolver order is backwards"). Ask "why does this code path exist? why does it accept input this way? what's the source of truth it SHOULD use?"
3. **Search for SPREAD** — `grep -rln` the buggy pattern, look for: copy-paste duplicates, dead variants (_v2/_v3/_v4 files), the same logic in sibling endpoints, the same logic in deployed-elsewhere WordPress plugin copies, cron handlers that call the same resolver, test environments that mirror prod. Dispatch a subagent if scope is wide.
4. **Identify prevention layer** — what code-level invariant, smoke test, KAIZEN classifier, or schema constraint would make this bug class impossible to re-introduce?
5. **THEN propose the fix** — as a multi-deploy plan that covers: the proximate file, all spread copies, the upstream cause, the prevention layer.

## What this rule changes vs prior posture

Before: detect symptom → fix the one file Ruben pointed at → done.

After: detect symptom → trace to root → grep for spread → check upstream + downstream → propose complete fix plan with explicit "and here's how we prevent the next backfill disaster" prevention section.

## The "spread search" checklist (mandatory for medium+ bugs)

For any bug touching >1 student / >1 ticket / >1 hour ago / payment-or-routing-adjacent:

1. **Direct copies/variants:** `ls`/`find` for `_v2.php`, `_v3.php`, `_20251103.php`, `*backup*`, `*old*`, ` 2.php`, ` 3.php` (Plesk-style numbered copies)
2. **WordPress plugin deploys:** `find /var/www/vhosts -name <plugin-file>.php 2>/dev/null` (every Plesk-hosted WP site has its own copy of /wp-content/plugins/...)
3. **Sibling endpoints:** `grep -rln "<same function name>\|<same buggy pattern>" /var/www/emtskills/webhooks/ /var/www/emtskills/routes/ /var/www/emtskills/cron/`
4. **Cron callers:** `crontab -l`, `ls /etc/cron.d/`, `grep -rln "<function name>" /etc/cron.d/`
5. **Test environment:** is there a `/var/www/emtskills/test_emtskills/` mirror that also has the same broken code?
6. **WPForms / external-config copies:** dropdown values, hostname maps, label-to-code mappings often live in BOTH the WP admin UI AND the plugin code AND the server resolver.

Subagent dispatch is the right move for scope-wide grep work. Per .clinerules/00-READ-FIRST-17 this is the default first move for any multi-file investigation.

## The KAIZEN-rule corollary

In any debugging session that ends with a fix:

- File a `kaizen_propose_classifier_rule` invocation against the failure pattern so the system learns the recipe
- File a synthetic smoke test (cron) that asserts the invariant the bug violated
- Add a regression test file if the codebase has a test directory

These are NOT optional polish — they're part of "the fix." A debug session that ships only the proximate file patch and skips classifier+smoke+test is a debug session that will repeat 90 days from now.

## The "and here's how we prevent this class going forward" section

Every attempt_completion on a non-trivial debug task MUST include a "PREVENTION" section that names:

1. The code-level invariant (e.g., "form_id is single source of truth for routing; no fallback")
2. The synthetic test (e.g., "hourly cron POSTs test payload per form_id, asserts Students.Location matches expected")
3. The KAIZEN rule (the pattern the agent now recognizes)
4. The drift detector (the SQL/cron that catches re-introduction)

Without this section, the attempt_completion is incomplete per this rule.

## Anti-patterns this rule kills

- ❌ "Found the bug at line X — patching" (without grepping for spread)
- ❌ "Server-side resolver is wrong, let me fix that" (without checking the WP-plugin upstream that emits the wrong codes in the first place)
- ❌ "Replay v2 will have post-validation" (a bandaid that re-implements correctness in a one-off script instead of fixing the webhook everyone else uses)
- ❌ Closing a task with just a fix, no KAIZEN rule, no smoke cron, no prevention writeup
- ❌ Patching `emt_registration_enrollment_email.php` without checking `_v2/_v3/_v4/_20251103` siblings, the WP plugin map, test_emtskills mirror, ea_completion.php (which has its OWN short-code map), routes/*.php fuzzy-match consumers
- ❌ Subagent skipped on a "wide grep" investigation because "I think I know where it lives"

## Self-check before any debug attempt_completion

1. Did I trace symptom → root cause (structural reason), not just proximate trigger?
2. Did I grep for spread (or dispatch a subagent to do so)?
3. Did I check upstream (form/plugin/UI that emits the bad input) AND downstream (every consumer)?
4. Did I propose a multi-deploy fix when one bug exists in N places?
5. Did I include a PREVENTION section (invariant + smoke + KAIZEN + drift detector)?
6. If no to any of the above → the completion is incomplete. Don't ship it.

## Source incident

2026-05-22 cline_wpforms_replay_halt_2026-05-22:
- Symptom: SD-website registrations landed in Houston/DFW (3 students).
- Initial diagnosis: "webhook resolution order is backwards in emt_registration_enrollment_email.php lines 477-525."
- Bandaid pattern Cline almost shipped: patch that file + write a hardened replay v2 with extra validation.
- Root-cause pattern (what was actually needed):
  1. **Layer 1 root:** WP plugin `$site_locations` map emits short-codes (SD/DFW/CA) — embedded in /var/www/emtskills/webhooks/wordpress-plugin/emsu-registration-webhook.php LINE 43 + deployed to 7+ EMT websites under /var/www/vhosts/
  2. **Layer 2 root:** server resolver order backwards + `getLocationData()` does fuzzy LIKE match instead of exact LocationName lookup keyed on form_id→LocationWebsites
  3. **Spread:** _v2/_v3/_v4/_20251103 sibling files all have the same shortCodeMap; ea_completion.php has its OWN copy of the short-code map (different line); emsu-webhook-connector.php duplicates the map
  4. **Silent failure class:** state-level codes (AZ/CA/TX) intentionally NOT in `$shortCodeMap` because ambiguous (3 locations each) → 131 known failed registrations (74 SD + 48 DFW + others) sitting in /tmp/failed_regs.json before this debug session ever started
- Ruben caught the bandaid pattern: *"identify the root cause rather than make bandaids for issues."* This rule encodes the corrective.

## Root-cause TRACKING requirement (added 2026-06-01 — Ruben: "track and repair the root cause instead of putting on band aids")

Finding the root cause is not enough — it must be TRACKED so it actually gets repaired and so the next agent sees it instead of re-bandaiding. Every debug session that identifies a root cause MUST, before completion:

1. **Record the root cause in a durable, themed tracker** — the domain's master `.md` (e.g. Desktop `STUDENT_ACCESS_ISSUES_TRACKER.md`) as a numbered RC entry with: symptom, mechanism (file:line), spread, fix status (FIXED / staged / OPEN), and the prevention layer. Not just HANDOFF_NOTES (chronological) — the THEMED tracker so the class is greppable.
2. **Distinguish bandaid vs root in the entry itself.** If a per-case spot-fix was applied to stop active harm, label it `SPOT-FIX (bandaid)` and pair it with the `ROOT (open)` line so it's unambiguous the core isn't fixed yet. A spot-fix logged as if it were the root is itself a rule-110 violation.
3. **Surface the tracker from the canonical reference doc.** The themed `.md` must be linked/referenced from `routes/student_status_reference.php` (or the relevant canonical doc) so a human/agent finds it without knowing the Desktop path. Keep the reference doc and the `.md` in sync — update BOTH when a RC opens or closes.
4. **A root cause left only as prose in an attempt_completion is not tracked.** It evaporates when the window closes (see rule 91). Tracked = a row in the themed `.md` + reference-doc pointer.

Self-check addition: "Did I write the root cause into the themed tracker AND point the canonical reference doc at it, with bandaid vs root clearly labeled?" If no → completion incomplete.

## Last updated

2026-06-01 — added root-cause TRACKING requirement (themed-tracker row + reference-doc pointer + bandaid-vs-root labeling). Source: Ruben during the student-access wave: "We should have a cline rule about root causes and bandaids. It's better to track and repair the root cause instead of putting on band aids... need to make sure you are updating the status reference document and the .md doc which should be on the status reference doc."

2026-05-22 22:35 PT — initial.


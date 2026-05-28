# 125 — Email_agent must NOT grant extensions to students who weren't actually delayed. Smart routing, not regex.

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="125")` or `clinerules_search(query="extension granted edward light wrong")`. Companion to .clinerules/29 v3 (act-on-confidence), .clinerules/73 (capability close — grant_extension_tool), .clinerules/124 (no-refund-from-anger).

## The bright-line rule

**The email_agent must NOT send "1 week extension granted" emails (or any extension-grant message) to a student unless ALL of the following are true:**

1. The student's Students.ea_url was retroactively backfilled in the last 30 days (timestamp evidence in orchestrator_event_log OR HANDOFF row), OR there's a verified EMSU-side delay event (a webhook crash row in enrollment_self_heal_log, a stranded-EA replay log entry, etc.), AND
2. The student's MOST RECENT inbound email or ticket contains at least one literal access-loss verb: "locked out", "can't access", "no access", "blocked from", "exam today", "quiz won't open", "can't take exam", "course access", "haven't been able to do", "behind on", or shows a Moodle last_access age > 3 days during their active class window, AND
3. The agent has actually GRANTED the extension (i.e. called `grantStudentExtension` and gotten a `found=true` + at least 1 enrolment extended) — never claim a grant in the email without the DB action.

If any of 1/2/3 fail → do NOT send "extension granted" email. Send a narrower response that addresses only what the student asked for.

## Why this exists

Source incident: 2026-05-28 07:33 PT. During the WPForms 5/13-5/28 shortcode-break recovery cohort, the email_agent sent a "Your EA is now on file + 1 week extension granted" email to **Edward Light** (edlight36@gmail.com). Edward's inbound emails since 5/25 are entirely about (a) Safe Exam Browser not working, (b) confusion about whether BLS/license/background-check/drug-test items block his class access. He NEVER said "locked out" or "can't access" or "behind on." His Moodle was OPEN — he was actively taking quizzes that morning (Chapter 8 Quiz attempts 1-3 between 07:07-07:33 PT, scored 53.8% → 88.5%).

Ruben directive verbatim 2026-05-28 07:52 PT: *"Email agents email to Edward is weird. You have a 1 week extension? He did not ask for that, did he? So it's not regex, it's smart routing here. repair that logic."*

The bug: the email_agent matched on a RAW REGEX flag like `was_stranded_5_13_cohort=true` (a property of being in the backfill cohort) and indiscriminately sent the extension-grant email to everyone in that cohort, regardless of whether the student actually missed any class time. Edward was nominally in the cohort because his EA was retroactively backfilled, but he never lost access — his Moodle stayed open throughout.

## The required smart-routing logic

Replace any boolean cohort flag (e.g. `is_5_13_stranded_cohort`) with a multi-signal check:

```php
function shouldGrantExtensionAndNotify(int $studentId, string $email): bool {
    // 1. EMSU-side delay evidence
    $hasDelayEvent = (
        // a) Students.ea_url was backfilled retroactively
        // (Students.updated_at > Students.ea_completion_date + 24h means retroactive sync)
        retroactive_ea_backfill_in_last_30d($studentId)
        // b) OR enrollment_self_heal_log row in last 14d
        OR self_heal_row_recent($studentId, '14 DAY')
        // c) OR Drive/moodle EA upload happened > 24h after webhook fired
        OR ea_landed_late($studentId)
    );
    if (!$hasDelayEvent) return false;

    // 2. Student-reported impact
    $hasReportedImpact = (
        // a) Most recent inbound contains an access-loss verb
        recent_inbound_mentions_any($email, [
            'locked out', "can't access", 'no access', 'blocked from',
            'exam today', "quiz won't open", "can't take exam",
            'course access', "haven't been able", 'behind on'
        ])
        // b) OR Moodle last_access age > 3 days during active class window
        OR moodle_inactivity_during_class_window($studentId, 3)
    );
    if (!$hasReportedImpact) return false;

    // 3. Don't double-grant
    if (extension_already_granted_within_7d($studentId)) return false;

    return true;
}
```

The agent calls `grantStudentExtension(...)` ONLY if all three signals hit. THEN it sends the extension-confirmation email.

For students who hit signal 1 but NOT signal 2 (got backfilled but didn't complain about access): send a narrower email — "Your EA is on file in our system" — and DO NOT mention extensions. That avoids implying we lost their time when we didn't.

For students who hit signal 2 but NOT signal 1 (complain about access but no EMSU-side delay event): investigate the actual block (Moodle group, prerequisite assignments, course-section mismatch) before promising an extension. Per .clinerules/124, address the actual ask.

## What to do for Edward Light specifically (this is the current bug)

Email_agent should NEVER have sent him the extension email. The right response to his "Fix my courseware access" was:

> "Hi Edward, your Moodle access is fully open — you're at 18.3% complete in the EMT-Texas course and your Chapter 8 quiz attempts are showing up correctly. The BLS card, driver's license, background check, and drug test items you mentioned are externship-phase deliverables (later in the program), not gates on your current coursework. If your specific issue is Safe Exam Browser scoring you 50% on a reading comprehension test, that's a separate ticket — please reply with which exact quiz/section so we can dig in. — EMS University Support"

THAT is the literal-ask reply (rule 124) + the correct-state reply.

## When sending the extension email IS correct (positive case)

For students like Collin Callagher (26913FT-31): his Moodle shows he was attempting quizzes but Chapter 1 stayed locked because grade_item 2590 (Copy of EA Form) was ungraded — admin_portal had ea_url populated but Moodle had no submission. He emailed multiple times this morning about "Quiz 1 Access." Both signals hit:
- Signal 1: ea_url was retroactively backfilled overnight (eligible)
- Signal 2: literal "I cannot access Chapter 1 Quiz" in his email

For Collin the extension email + EA-link + EA-auto-grade was the right combo. For Edward it was wrong.

## Implementation owner

Email_agent's smart-routing layer is in:
- `/var/www/emtskills/lib/EmailAIResponder.php` (response composer)
- `/var/www/emtskills/lib/email_agent/grant_extension_tool.php` (the grant primitive)
- `/var/www/emtskills/cron/cron_ai_email_agent.php` (the dispatch)
- `/var/www/emtskills/lib/StudentStatusSnapshot.php` (lookup-first state gate, idea #892 phase 2)

The fix is in the cohort-selection logic that calls `grantStudentExtension`, which is currently somewhere in the cron or a related composer. File P0 idea to surface and patch — see orchestrator_ideas filing after this rule.

## Cross-refs

- `.clinerules/29 v3` — act-on-confidence + literal-ask
- `.clinerules/124` — no refund-intent-from-anger (sibling concept)
- `.clinerules/02` — no apologies (the misfire to Edward was also borderline apologetic-framing — "we'll give you back the time you lost")
- `.clinerules/73` — capability close (grant_extension_tool is the right tool; routing is the bug)
- `.clinerules/121` + `.clinerules/122` — WPForms 5/13 source incident
- `.clinerules/123` — numbered windows

## Last updated

2026-05-28 — initial. Source: Edward Light extension-email misfire during 2026-05-28 07:33 PT email_agent run (Window 1 of the 5-window cohort-recovery dispatch). Ruben directive: *"it's not regex, it's smart routing here. repair that logic."*

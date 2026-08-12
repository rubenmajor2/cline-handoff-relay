# 319 — Anchor the reported symptom before any lookup

**Severity: TRIPWIRE (pre-first-lookup gate)**
**Created: 2026-08-12 (idea #25944, Ruben approved)**
**RCA bucket of the source incident: scope error**

## The gate

Before the FIRST lookup tool call on any task that hands you a reported artifact
(a screenshot, a forwarded email, a ticket paste, a voicemail transcript, a chat
log), write ONE line naming three things:

1. **The verbatim subject or title** of the artifact.
2. **The symptom in the reporter's own words.**
3. **The data surface that symptom lives on** (which table, which page, which cron).

Every subsequent tool call must be traceable to that line. If you cannot name the
data surface, your first tool call is the one that identifies it, not a student
lookup.

## The substitution ban

A lookup will often surface a DIFFERENT open issue for the same student, and it is
frequently more recent, louder, and easier to fix than the reported one. **That is
a SEPARATE finding. It MUST NOT replace the anchored symptom.**

Report it as an additional finding, fix it if rule 29 says you can, but the task is
not complete until the ANCHORED symptom is resolved or explicitly classified.

**A completion that resolves a different issue than the one reported is a rule-301
steering violation regardless of how well the substitute issue was fixed.** Quality
of the substitute work is not a defense: the reporter's problem is still live.

## The SLS-fingerprint gate

When a lifecycle/state tool returns a WARN whose numbers match the reported symptom,
**that gate is the primary lead and must be drilled before any other thread.**

A student saying "my attendance shows days I do not attend" next to an SLS line
reading `attendance WARN 15/30 (50%)` is not a coincidence: the inflated denominator
IS the symptom, expressed in numbers. Treat the numeric match as a pointer, not as
background noise.

More generally: if the reported symptom and a WARN gate could be two descriptions of
the same underlying fact, assume they are until a probe separates them.

## Anti-patterns

- ❌ Running `check_student` / `check_ticket` first and letting the most RECENT
  ticket define the task. Recency is not relevance.
- ❌ Treating a screenshot as decoration. If Ruben pasted it, its subject line IS
  the task definition.
- ❌ Reading an SLS WARN whose numbers match the complaint and moving past it to a
  different thread.
- ❌ Emailing a student about issue B when they wrote in about issue A, even when B
  is real and worth fixing.

## Source incident (2026-08-12)

Given a screenshot of Kareem Gharaybeh's 2026-06-07 email, subject
**"Attendance Misreflection"**, body: a weekend Union City student sees Mon/Wed/Fri
sessions in his Moodle attendance and has to ask his instructor to record attendance
manually.

The window ran `check_student`, SLS, and `check_student_comms`, latched onto his most
recent ticket (24323, NREMT clearance), diagnosed that thread, and emailed the student
about NREMT clearance plus a CA-psychomotor portal display bug. Both findings were
factually correct. Neither was the reported problem.

The real bug was visible in the screenshot itself and printed in the SLS output the
window had already read: `attendance WARN 15/30 sessions (50%)`. Moodle group 2620
carried 14 attendance sessions on Mon/Wed/Fri 8AM against a `Course_Schedules`
row reading "Saturday & Sunday 9:00AM to 5:30PM". After the fix: 15/17 (88.2%).

Cost: one wrong-issue email to a student, plus the real bug staying live from
2026-06-07 to 2026-08-12 despite being reported on day one.

## Cross-references

- Rule 301 — steering compliance (the newest steer IS the task; this rule is the
  artifact-level version of the same discipline)
- Rule 297 — classify before diagnosing; the SCOPE GATE for quantifying a population
- Rule 317 — reversal MUTEX test; this rule is the causal fix filed by a 317 reversal
- Rule 29 — a separate finding you have tools for gets fixed, not just listed
- Rule 300 — end-to-end delivery; finishing the WRONG task is not finishing

## Last updated

2026-08-12 — initial. Filed as idea #25944 during the rule-317 reversal of the
Kareem Gharaybeh attendance investigation. Companion fix: idea #25942 (day-of-week
validation in the attendance session generator plus a fleet-wide cleanup pass).

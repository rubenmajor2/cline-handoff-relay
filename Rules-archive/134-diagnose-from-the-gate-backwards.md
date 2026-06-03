# 134 — Diagnose from the gate backwards: the Ruben troubleshooting method

Permanent rule. Workspace-scoped. Source: 2026-06-02 Romain Bacou cert-lock session. Ruben walked the diagnosis live and said: *"I want Agents to be more precise like this. Do you see how I did that? Process wise?"* This rule captures that method so every agent troubleshoots a stuck student the same way.

## The core principle

**Start from what the student is actually blocked by, not from a dump of everything.** The authoritative blocker list lives at the gate (the locked certificate / the cert "Not available unless" conditions / the activity-completion restrictions), NOT in the admin grade table. Read the gate first, then chase only the conditions it names.

## The method (6 steps, in order)

1. **Read the gate, not the pile.** Log in AS the student (or open the student-facing cert/activity page) and read the exact "Not available unless..." conditions. That is the precise, ordered, authoritative list of what blocks THIS student. An admin grade dump shows hundreds of rows ("submitted, graded, not passed") — too noisy, too slow, easy to get lost in. The gate gives you 3-5 named conditions. Start there.

2. **Take each blocker one at a time, top to bottom.** Don't fan out. Resolve condition 1, then 2, then 3. Each is independent.

3. **For each blocker, go to the fastest human-visible surface to verify the content exists.** admin_profile.php, view_submission.php, the actual uploaded PDF. The question at this step is binary: *is the student's work actually there and legitimate?* Open the PDF. Look at it. (Ruben literally opened the CV PDFs to confirm they were real.)

4. **Compare content-layer truth vs grade/gate-layer state. The gap IS the bug.** This is the whole method. The student did the work (content layer = good) but the grade/completion layer says 0 / locked / "no files." When those two disagree, you have found the bug — and it is almost never the student's fault. Examples from this session: 10 real PCR PDFs but grade 0 "no files"; 36 timesheet hours but grade 0.00; signed eval but flagged.

5. **Know the actual requirement so you don't over-investigate.** The CV gate needed only ONE passing submission, not all three. Knowing that, Ruben stopped after verifying one. Don't chase completeness the requirement doesn't ask for. If the gate says "marked complete" and one pass marks it complete, one pass is done.

6. **Stay scoped to THIS student's blockers — but flag the systemic bug for the fleet.** Ruben: *"why get distracted."* Don't grade every submission in the account; only the ones blocking the cert. BUT when the gap in step 4 is clearly a code bug (not a one-off), note the blast radius and fix the core per rule 92. Scoped for the student, systemic for the bug. Both, not one.

## Why this beats the default agent behavior

The default agent failure is to start wide (query everything, list every submission, summarize the whole account) and either drown in noise or never reach the actual blocker. Ruben's method is **precise**: gate → named conditions → per-condition content check → content-vs-grade gap. It reaches the root cause in minutes because it never looks at anything the gate didn't name.

The second default failure is to trust the grade/completion layer as truth and tell the student to "re-upload" or "re-sign." That is exactly backwards. When the work is present but the grade is 0, the GRADE is wrong, not the student. Telling a student to redo already-done work (which is why Romain kept re-uploading) is the cardinal sin this method prevents.

## The one-line test before telling a student to do anything

*"Did I open the actual artifact and confirm the work is genuinely missing — or am I trusting a grade/flag that could be a grader bug?"* If you have not looked at the content layer with your own eyes (opened the PDF, read the JSON, counted the hours), you have not earned the right to tell the student they are missing something. Per rule 02, never admit fault to the student, but per this rule, never blame the student for a machine error either.

## Cross-references

- Rule 92 — fix the core, not the symptom (the systemic half of step 6)
- Rule 29 — act on verified evidence (this method IS how you verify)
- Rule 02 — no fault admission / no "re-upload" when the work is present
- Rule 133 — verify before stating

## Source incident

2026-06-02 — Romain Bacou (26806T-10) cert locked on 5 gates. Ruben diagnosed by logging in as Romain, reading the cert's 5 "Not available unless" conditions, and walking each one: opened the PCR/eval/CV PDFs, saw real content, compared against the grade layer showing 0 "no files." Found 3 of 5 gates were the same false "Submission Could Not Be Graded / no files" grader bug — content present, grade wrong. Blast radius: 340 submissions / 236 students hit the same false-fail. He explicitly asked that agents adopt this gate-backwards, content-vs-grade-gap, scoped-but-systemic method.

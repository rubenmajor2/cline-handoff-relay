Rule 303 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 303 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules-archive/303-certificate-blocker-traceback.md

## Amendment (from reversal, 2026-09-02 07:54 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 29482
- RCA bucket: insufficient probe
- Trigger pattern: Agent treated the EXISTENCE of a simplecertificate_issues row as proof the availability tree was satisfied at print time, then explained away contradicting grader rejections as 'happened after, so bot
- Reversal note: Amends step 7 of the 8-step traceback: an issued-certificate row proves a print EVENT occurred, NOT that the tree was satisfied at that instant. When an issued cert conflicts with failing conditions, probe grade_grades_history WHERE timemodified <= <issue epoch> for every grade condition (plus a positive control that finalgrade is populated elsewhere) BEFORE asserting the tree was met. Here cert 46238 issued 16:50:18 while required item 1213 finalgrade was NULL, reaching 1.0 only at 18:30:24 — so 'issued cert overrides later re-eval' was the wrong frame; the correct finding is an out-of-order issuance.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

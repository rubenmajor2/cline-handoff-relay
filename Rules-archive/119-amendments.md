Rule 119 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 119 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/119-mandatory-context-compress.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 1 amendment(s))

## Amendment (from reversal, 2026-08-28 15:49 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: glm53-local-ring-upgrade-20260828
- RCA bucket: stale assumption
- Trigger pattern: compression flow triggered from environment_details percentage against a false (too-small) denominator Y instead of raw X vs the model's real window size
- Reversal note: 2026-08-28 reversal: environment_details displayed '163,525 / 200K tokens used (82%)' and the window began a compression flow at 81%, but the model's real context window is 1M (display later corrected to 'X / 1,000K'). Per rule 119's own text, Y is often a false ceiling reported by the router and only raw X matters; CHECK threshold for a 1M window is 550K, far above the actual usage. Amended behavior: before invoking should_compress_now/cline_compress_session or announcing compression, derive W from a source OTHER than the environment_details denominator when the percentage looks high (the rule's own worked-examples table); a percentage >=75% against a possibly-false Y is a signal to VERIFY the real window, not to compress. The mechanical signal-file check remains primary.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

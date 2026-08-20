
## Mechanical amendments (moved from Rules/301-steering-compliance.md on 2026-08-19 ~18:16 PT, concurrent-window batch)

## Amendment (from reversal, 2026-08-17 14:53 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 26183
- RCA bucket: scope error
- Trigger pattern: Steer cites an existing artifact as a template ("based off the Arizona catalogue") and window builds artifacts FOR that reference state instead of the newly requested states; honor-system re-anchor wi
- Reversal note: Rule 301 mandated "re-anchor in one line" but produced NO artifact, so a re-anchored window was indistinguishable from one that merely intended to; all 32 validator gates fire at completion time, giving zero per-turn brake. Measured 2026-08-17: window ran ~10 consecutive turns building CALIFORNIA artifacts after a steer that named CA/AZ catalogs as REFERENCE ONLY and asked for six NEW FL/WA/OR catalogues, surviving four escalating corrections. Amended rule text now REQUIRES a literal "STEER RE-ANCHOR: deliverable = ... | superseded = ..." line as the first thing in the first turn after any steer, FORBIDS producing new artifacts for anything named as a reference or described as already-done, and REQUIRES writing the deliverable count/list into the re-anchor line when the steer enumerates a set.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

# Rule 119 Case Law — Mechanical Amendment Trail (trim-then-archive, 2026-08-19)

Moved from Rules/119-mandatory-context-compress.md (1 amendment).

## Amendment (from reversal, 2026-08-20 00:52 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787168789833
- RCA bucket: stale assumption
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - should_compress_now returned GREEN (stale 91,555-token status file) -> corrected to COMPRESS based on raw environment_details count 159,443 >= 150,000 threshold | stale assumptio

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

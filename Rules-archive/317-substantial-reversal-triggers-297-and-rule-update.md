# Rule 317 — A Substantial Reversal Within the Window Is a 297: Update the Causal Rule

## The trigger

A **substantial reversal** occurs when a subsequent iteration in the same window concludes the OPPOSITE of the initial iteration's material finding — not a refinement, a flip. Examples:

- Iteration 1: "X is down" → Iteration 4: "X was healthy; the probe was mis-scoped."
- Iteration 1: "student owes $500" → Iteration 3: "payment was applied, balance $0."
- Iteration 1: "ran 17 times, so 17 failures" → Iteration 5: "17 rows, 2 failed."

A reversal is the cheapest, highest-signal learning event available: the initial iteration made an avoidable error WITH the full task context already in hand. Every reversal left un-examined is a trap that will fire again for the next window.

## Mandatory behavior — on detecting a reversal, a rule-297 is NOT optional

Per rule 297 ("Do a 297 means FIX THE CAUSAL RULE, not just write the RCA"), a reversal has THREE deliverables, all in the same window:

1. **Name the reversal.** State explicitly what the initial iteration concluded and what the current iteration concludes, side by side.
2. **Run the rule-297 RCA on the INITIAL mistake** (not the later correction). Classify the initial error into exactly one bucket per rule 297 — here the "bug" is the reasoning error in the initial iteration. Name the specific move that caused it: wrong premise, stale assumption, unread source, insufficient probe, or scope error (see rule 297 SCOPE GATE).
3. **Update the causal rule.** Identify which rule, process, prompt, doc, or expectation let the initial iteration be wrong, and UPDATE it in the same session. A reversal RCA that leaves the causal surface unchanged is incomplete.

## Self-check before closing

*If a fresh agent received the same initial request tomorrow, would it make the SAME initial (wrong) call?* If yes, the causal rule is not fixed — keep going.

## Why this rule exists

Rule 297 makes you classify before you claim. This rule makes the SYSTEM remember when you got the classification wrong. A later-iteration improvement that is not written back to the causal rule is a private insight, not a durable fix. Rule 317 turns the reversal itself into the trigger that makes the rule corpus permanently smarter.

---

**Hardfloor: NO** — fires as a self-check on a conditional event (reversal detection), not on every turn. If Ruben wants it always-loaded, promote to hardfloor.
**Cross-refs:** rule 297 (RCA + causal-rule fix), rule 298 (conflicting-evidence confound table), rule 263 (verify before claim).
**Last updated:** 2026-08-12
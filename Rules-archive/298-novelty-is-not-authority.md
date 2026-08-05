# 298 — Novelty is not authority. Hold conflicting measurements, do not serially adopt them.

Source incident: 2026-08-04, GLM-5.2 ring. One Cline session reported the same metric as
`2.65` → `2.96` → `36.44` → `1.71` → `36.44` → `1.96` → `1.88` tok/s **inside one hour**.
Ruben: *"Why are you regressing so bad so quickly. Like this is baked into you?"*

Cross-refs: rule 297 (classify before claiming), rule 263 (verify before claiming),
rule 299 (a negative result proves your query ran). Bug-library row 2202.

---

## The failure mode

Rule 297 covers claiming from *insufficient* evidence. **This rule covers the opposite and
more dangerous case: claiming from *abundant but conflicting* evidence, by taking whichever
piece arrived last.**

The mechanism is that **each flip is individually justified with real data.** That is exactly
why it evades self-correction. The agent keeps mistaking *"I have new evidence"* for
*"I have better evidence."* Recency gets substituted for evidentiary weight, and because
every step feels like diligence, nothing internally flags the pattern.

It is not laziness. It is a reasoning bug that *looks like* rigor.

## The bright-line rule

**When a new measurement disagrees with one you already have, you may NOT discard the old one
until you have positively invalidated it.** "Something newer disagrees" is not an
invalidation. You must name the specific defect in the losing instrument.

Until then, **both are live hypotheses** and your job is to design the experiment that
separates them, not to pick.

## The mandatory move: build the confound table

The instant you have two conflicting readings, STOP and tabulate them by **confound**, never
by chronology:

| column | why it matters |
|---|---|
| **what is in the measurement path** | a proxy, tunnel, or adapter invalidates timing-derived rates outright |
| **what is actually being counted** | tokens vs SSE frames vs chunks vs requests are different units wearing the same label |
| **sample size** | a 50-sample probe does not outrank a population statistic |
| **who computed it** | a value computed *inside* the system beats an external observer's inference |
| **when** | listed LAST, and it is a tiebreaker only |

The 2026-08-04 table, which resolved a 19x disagreement in one pass:

| instrument | per-token spacing | proxy in path? | sample |
|---|---|---|---|
| vLLM `inter_token_latency` metric | ~530 ms | **no** | 741,122 tokens (population) |
| direct socket trace to the engine | ~474 ms | **no** | ~50 tokens |
| socket trace through the proxy | ~24 ms | **YES** | ~270 chunks |

Two no-proxy instruments converge; the lone outlier is the only one with a proxy, and
`474 / 24.43 = 19.4x` matches a proxy packing ~19 tokens per emitted chunk. **Resolved by
structure, not by recency.**

## Precedence when instruments disagree

1. **Fewest intermediaries wins.** Anything with a proxy in the path is disqualified for
   timing-derived rates. Full stop.
2. **Population beats sample.** A counter the system maintains over its whole lifetime
   outranks any probe you fire, by construction.
3. **Computed-inside beats observed-outside.** The scheduler knows when it emitted a token.
   You only know when one arrived.
4. **Convergence of independent paths is strong evidence FOR.** Two unrelated instruments
   agreeing while a third disagrees means the third has a confound. Do not treat the
   agreement as suspicious coincidence.
5. **Recency is the last tiebreaker, never the first.**

## The corollary failure: re-measuring instead of reasoning

Same incident, immediately after the flip-flopping was called out, the agent's next action
was to **re-run the identical measurement it had taken 90 seconds earlier.** Ruben:
*"You already got the measurement. Why are you looping on this?"*

**Gathering feels like progress. Deciding feels like risk.** So an uncertain agent reaches
for another tool call instead of reasoning about what it already holds.

**The gate:** before any repeat measurement, answer *"what does the data I already have rule
out?"* If you cannot name something new the repeat would tell you, **do not run it.**

## Why this is dangerous, not merely untidy

Wrong numbers become **thresholds**. Thresholds gate **availability**. On 2026-08-04 the
proposed threshold (5 tok/s, reasoned as "a third of the 120Bs") would have marked a
perfectly healthy 1.88 tok/s ring **DOWN 100% of the time, permanently**, causing endless
quarantine, failover, and paid-model spill.

**Any number that becomes a threshold gets a sanity check against the system's own normal
operating range. If the threshold would fire continuously under healthy conditions, the
threshold is wrong, not the system.**

## Structural enforcement, because advice does not survive a fresh context window

Prose rules are forgotten between windows. For any metric that gates production behaviour,
ship an **executable invariants gate** alongside it. Pattern from the source incident:

- `/usr/local/bin/glm_invariants.py` — 8 invariants, live-checked, exits non-zero on
  regression. Names the specific bad threshold in its output.
- `/usr/local/bin/glm_thresholds.py` — **derives** thresholds from the system's own measured
  baseline rather than hardcoding them, so they stay correct when the topology changes.

**Derived thresholds beat hardcoded ones**, because a hardcoded floor that is correct today
becomes either a permanent false alarm or a silently dead check after the next migration.

## Self-check, run when any measurement surprises you

1. Do I already have a conflicting reading? If yes, **build the confound table before writing
   a conclusion.**
2. Can I name the specific defect in the instrument I am about to discard? If no, **I am not
   allowed to discard it.**
3. Am I about to re-run something I already ran? **What would be new?** If nothing, stop.
4. Is this number about to become a threshold? **Would it fire under known-healthy
   conditions?** If yes, the threshold is wrong.
5. Am I treating agreement between independent instruments as suspicious? **That is backwards.**

## Last updated

2026-08-04 — initial. Source: GLM-5.2 five-reversal incident, bug-library row 2202.
Ruben asked whether this was systemic and worth a rule. It is both.

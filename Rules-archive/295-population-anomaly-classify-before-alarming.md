# 295 — A COUNT(*) of "impossible" rows is a hypothesis, not a bug. Classify the population before you alarm.

Source incident: 2026-07-25. Cline ran `SELECT COUNT(*) FROM Students WHERE drop_date < course_start_date`, got **254**, and reported to Ruben that 254 paying students were wrongly locked out by a batch-write bug — filing it P0 and proposing a guard that would have **rejected the write**. Ruben pushed back ("Hmm first verify vs SLS as this seems odd"). Classifying the same 254 took four queries and destroyed the finding:

| Bucket | Count | What it actually was |
|---|---|---|
| Canary/test rows (`email LIKE '%canary%'`, `class_section='CANARY-SECTION'`) | 69 | Not students at all. 27% of the "finding." |
| `transfer_date IS NOT NULL` | 51 | Dropped from class A, transferred to class B. **Completely legitimate.** |
| Multi-enrollment (same email, several rows) | 1 | Normal re-enrollment |
| Dropped ≤14 days BEFORE start | 83 | **A normal business event.** Enroll, then withdraw before day 1. |
| Dropped 14-60 days before start | 39 | Plausible early cancellation |
| Dropped >60 days before start | **11** | The only genuinely suspicious rows |

**The proposed P0 guard would have blocked 122 legitimate withdrawals.** The "bug" was 11 rows, not 254 — a 23x overstatement, and the fix was worse than the disease.

## The gate (run BEFORE reporting any population-level anomaly)

You found N rows matching a "this should be impossible" predicate. **N is a hypothesis. Do not report N to a human until all four checks pass:**

1. **Strip test data.** Filter `%canary%`, `%test%`, `%dummy%`, `CANARY-SECTION`, seeded fixtures. Synthetic rows routinely dominate small anomaly counts.
2. **Name the legitimate business path that produces this shape.** For every "impossible" combination, ask: *"is there a real workflow where this is correct?"* Drop-then-transfer, withdraw-before-start, re-enrollment, backdated correction, refund reversal — these all produce shapes that look wrong to a naive predicate. If you cannot think of one, that is a signal you don't understand the domain yet, not that no path exists.
3. **Bucket by magnitude, not just existence.** "drop_date before course_start" collapses "withdrew 3 days early" (normal) and "dropped before the record existed" (impossible) into one number. Split by `DATEDIFF` and watch the population separate.
4. **Cross-check ONE row against the authoritative state tool.** For students that is `get_student_lifecycle_state` (SLS). If SLS says the student is fine, your predicate is wrong, not the data.

## Find the invariant that is ACTUALLY impossible

The original predicate (`drop_date < course_start_date`) was not an invariant — it has legitimate cases. The real invariant, found only after classification, was:

> **`drop_date < DATE(created_at)`** — a drop cannot precede the existence of the record it is attached to.

Mason Rosales had `drop_date=2026-01-07` on a row `created_at 2026-04-23`. That is genuinely impossible with no legitimate path. **Prefer invariants grounded in causality (an event cannot precede its record) over invariants grounded in business sequence (a drop "should" follow a start).** Business sequence has exceptions; causality does not.

Bonus signal from the same data: 44 of the odd rows had `DAY(drop_date) <= 12`, and swapping day/month on Mason's `01-07` yields `07-01`, which lands correctly after his `06-22` start. A day/month swap is a far more likely mechanism than a phantom batch write — and it points at an input-parsing fix, not a guard.

## Never propose a blocking guard from an unclassified count

A guard that rejects writes is a **production-breaking change**. Before proposing one:
- Enumerate every legitimate case the guard would reject.
- If any exist → the guard is wrong. Use a **warn-only log** plus human review for the ambiguous band, and a hard block only on the causality invariant.

## Severity honesty

Filing 11 rows as P0/254-students is not a harmless overestimate. It steals a P0 slot, inflates the queue depth that every other ETA is computed against, and burns trust — the next real finding gets discounted.

## Self-check

Before writing any sentence of the form "N records are broken":
1. Did I strip test/canary rows?
2. Can I name the legitimate workflow that produces this shape, and did I subtract it?
3. Did I bucket by magnitude instead of reporting one flat count?
4. Did I verify ONE row against the authoritative state tool (SLS for students)?
5. Is my invariant causal ("cannot precede its own record") or merely sequential ("should follow X")?
6. Would my proposed guard reject anything legitimate?

Any "no" → you have a hypothesis, not a finding. Keep it out of the human's inbox until it is one.

## Cross-references

- Rule 281 — execute the real function + DESCRIBE the real table before theorizing
- Rule 263 — verify before claim; no factual claims without tool evidence
- Rule 271 — verify before writing infra claims to durable surfaces
- Rule 29 — act on verified evidence; a wrong P0 is worse than no P0
- Rule 266 — when the instrument misled you, fix the instrument

## Last updated

2026-07-25 — initial. Source: the 254-vs-11 drop_date misdiagnosis, caught by Ruben, not by the agent.

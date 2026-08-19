# Rule 323 — The Truth Protocol (claim discipline for ALL models)

**Created:** 2026-08-19 (Ruben directive: "Making LLMs Smarter — force truth, validation
and review so lower-param models give information as close to Opus as possible").
**Applies to:** every model in the EMSU fleet — Cline windows, executor, orchestrator,
CFA surfaces, 120B pool, GLM ring. Truthfulness is achievable at any parameter count.
**Architecture doc:** `~/Documents/Cline/docs/TRUTH_ENFORCEMENT_ARCHITECTURE.md`

## The protocol (three legal claim states)

Every MATERIAL claim (a statement of fact someone could act on: state, money, dates,
status, counts, deployment, policy) must be in exactly ONE of three states:

1. **PROVEN** — you have evidence from THIS session and you cite it:
   `(verified: <tool name> returned <what it returned>)`.
2. **INFERENCE** — you reasoned it out; label it: `(inference: from <premises>)`.
3. **UNKNOWN** — you say so: "I don't have verified data for X."

A bare assertion — a material claim with none of the three — is INVALID. The
completion gate (R323_NAKED_CLAIM) blocks it for high-stakes classes, and the
truth judge (L4) reviews content before it reaches students.

## The five obligations

1. **GROUND TRUTH FIRST.** If a canonical tool exists for your claim class, CALL IT.
   Answering from memory when a canonical tool exists is a violation, even if your
   memory happens to be right. Known canonical tools: `verify_payment_state`,
   `get_student_lifecycle_state`, `lookup_paperwork_state`, `get_student_360`,
   `check_exam_enforcement`, `frankenstein_verify_routing`, `frankenstein_registry`,
   `check_proctoring_status`, `get_instructor_schedule`. If no tool exists and you
   must answer, state that the claim is unverified-by-tool and label it INFERENCE
   or UNKNOWN.
2. **UNKNOWN IS FREE.** "I don't know / I can't verify this" costs nothing and is
   never a failure. Guessing to avoid admitting ignorance is the exact failure this
   rule exists to kill. When in doubt between claiming and checking, check; when
   checking is impossible, say UNKNOWN.
3. **FRESHNESS.** Facts about mutable state (host up/down, balances, enrollments,
   schedules, queue depths) expire. A fact probed in an EARLIER session is stale by
   default — re-probe this session before re-asserting, or mark it
   `(stale: probed <when>, re-verify before acting)`.
4. **VERIFICATION MUST BE REAL.** A `(verified: ...)` marker must name the tool and
   what it returned (an HTTP code, a number with units, a row, a timestamp, quoted
   output). Markers like `(verified: checked it)` / `(verified: confirmed)` are
   FAKE EVIDENCE and are gate-blocked (R323_FAKE_EVIDENCE). If you did not run the
   probe this session, you do not have a verification.
5. **HIGH-STAKES ANSWERS GET JUDGED.** Before shipping an answer that contains
   money, student status, regulator, or fleet claims, run it through
   `clinerules_truth_judge` (L4 judge layer). A FAIL verdict names the unsupported
   claims; fix them (probe, label, or downgrade to UNKNOWN) and re-judge. A surface
   that cannot reach any judge FAILS CLOSED (rule 320): hold for human, never wave
   through.

## Why this rule exists

Lower-parameter models hallucinate for four structural reasons: memory is cheaper
than tool calls, guessing is never blocked, "I don't know" feels like failure, and
verification markers were previously un-checkable prose. Rules 297/317/321/322
established the obligations for strong models; this rule + its mechanical backstops
(R323 gates + truth_judge) make them enforceable for ALL models. Latency is
acceptable; falsehood is not (Ruben, 2026-08-18).

## Mechanical backstops

- `R323_NAKED_CLAIM` (clinerules_validate_completion): blocks high-stakes bare claims.
- `R323_FAKE_EVIDENCE` (clinerules_validate_completion): blocks prose-only markers.
- `clinerules_truth_judge` (MCP tool → WOPR fleet API `truth_judge` action): stronger
  model reviews content; judge ladder glm-5.2-local → deepseek-v4-pro → glm-5.2,
  never weaker than the model under test. Logged to `truth_judge_log`.
- Kaizen categories `unverified_claim` / `fabricated_evidence` / `stale_fact` feed
  the retry recipes so a caught hallucination changes the next attempt's behavior.

## Cross-refs

- Rule 317 (completion confidence, acquisition gate, reversal loop)
- Rule 297 (classify before claiming; scope gate for counts)
- Rule 263 (verify-before-claim; fleet mutation preflight)
- Rule 320 (automated adjudication fails closed)
- Rule 321 (gaslighting taxonomy — G5 premature completion, G7 confident wrong number)
- Rule 99 (subagent writes unverified until parent re-reads)
- Rule 91 (pickup prompt; every claim in the block carries its state)

## Source

2026-08-19 Ruben directive "Making LLMs Smarter": rules 317-322 were the first pass;
this rule consolidates the claim discipline and attaches the mechanical backstops
(gates + judge + benchmark) so weak models are STRUCTURALLY truthful, not instructed
to be. Shipped components + filed wiring: `docs/TRUTH_ENFORCEMENT_ARCHITECTURE.md`.
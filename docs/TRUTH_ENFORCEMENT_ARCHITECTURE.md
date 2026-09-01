# TRUTH ENFORCEMENT ARCHITECTURE ("VERITAS")

**Created:** 2026-08-19 by Cline (Ruben directive: "Making LLMs Smarter — help me actually achieve this once and for all")
**Status:** Blueprint + shipped components. See "Component inventory" for what is live vs filed.
**Cross-refs:** Rules 297, 317, 321, 322, 323 (truth protocol), 263 (verify-before-claim), 99 (subagent verify), 320 (fail closed)

## The goal

Make lower-parameter models (120Bs, 70B, 7B, GLM ring) deliver answers as close as
possible to Claude-Opus-grade TRUTHFULNESS: reliable, verified, non-hallucinated
information EMSU can act on. Ruben's explicit tradeoff: **latency is acceptable,
falsehood is not.** A slower verified answer always beats a fast fabricated one.

## Why weak models lie (the 4 structural causes)

A lower-parameter model is not "dumber about truth" — it is missing structure that
compensates for weaker training. Four root causes, each needing its own fix:

| # | Cause | Symptom | Fix layer |
|---|-------|---------|-----------|
| 1 | Parametric memory is CHEAPER than a tool call | Answers from stale training data; no reason to probe | L1: ground-truth tools + steering |
| 2 | Guessing is never BLOCKED | Fabricated claims pass every existing gate (gates check format, not content) | L3: content gates |
| 3 | "I don't know" feels like failure | Model guesses instead of admitting ignorance | L2: calibration protocol (UNKNOWN is a legal, zero-penalty state) |
| 4 | Verification claims are not themselves verified | `(verified: checked it)` markers are fabricatable; regex gates accept them | L3b: fake-evidence gate + L4: judge |

**The meta-lesson:** prose rules do not survive contact with weak models. Rules
297/317/321/322 proved this: they are obeyed by Opus-class models and ignored or
gamed by 120B-class models. Every truth obligation must therefore be backed by a
MECHANISM the model cannot talk its way past: a tool that is easier than guessing,
a gate that blocks the output, or a judge that reviews the content.

## The 5 layers

### L1 — GROUND TRUTH FIRST (make the right answer the easy answer)
One-call canonical tools per claim class. Existing proven pattern:
`verify_payment_state`, `get_student_lifecycle_state`, `lookup_paperwork_state`,
`frankenstein_verify_routing`, `check_exam_enforcement`, `get_student_360`.
Governance: when a claim class is answered ad-hoc twice, the third occurrence gets
a canonical tool (file as idea, autonomous tier). The truth protocol (rule 323)
makes calling the canonical tool mandatory when one exists for the claim class.

### L2 — CLAIM DISCIPLINE (three legal states, rule 323)
Every material claim in any model's output exists in exactly one state:
- **PROVEN** — evidence cited (tool name + what it returned), or
- **INFERENCE** — explicitly labeled, with the premises stated, or
- **UNKNOWN** — explicitly stated. "I don't have verified data for X" is a complete,
  respectable answer. It is NEVER a failure state.
A bare assertion (none of the three) is structurally invalid and gate-blocked.

### L3 — GATES (structural detection, completion-time)
In `clinerules_validate_completion`:
- `R317_UNVERIFIED_STATE` (existing): fleet/host state claims need evidence markers.
- `R323_NAKED_CLAIM` (new): high-stakes claim shapes (money, deadlines, student
  status, production deploys) with no evidence marker AND no inference label.
- `R323_FAKE_EVIDENCE` (new): a `(verified: ...)` marker must contain a REAL
  artifact — a known tool name, an HTTP code, a number+unit, a timestamp, a table
  name, or quoted output. `(verified: I checked)` FAILS. This is the
  verification-of-verification: markers can no longer be satisfied by prose.

### L4 — JUDGE LAYER (stronger model reviews weaker model's CONTENT)
`truth_judge`: a review endpoint where a model STRICTLY STRONGER than the one under
test reviews an answer for factual support. Judge ladder (never weaker than judged):
1. `glm-5.2-local` — 744B MoE hex ring, free, local (default judge)
2. `deepseek-v4-pro` — free cloud fallback
3. `glm-5.2` — paid cloud last resort
The judge extracts every factual claim, classifies each PROVEN / INFERENCE /
UNSUPPORTED / CONTRADICTED against the provided evidence, and flags overconfidence,
staleness, and internal contradiction. Returns PASS/FAIL + named issues + required
fixes. Every judgment logged to `truth_judge_log` (the learning/measurement feed).
Wiring (phased): (a) Cline MCP tool — mandatory for completions containing
money/student/regulator/fleet claims; (b) CFA student-facing surfaces pre-send
(email/chat/SMS) — mandatory; (c) executor pre-deploy for student-visible changes.

### L5 — MEASUREMENT + LEARNING LOOP (prove the gap is closing)
- **Truthfulness benchmark** (weekly cron): fixed question set with known ground
  truth per claim class (fleet state, student state, payment, policy). Per-model
  scores: accuracy, calibration (says UNKNOWN when it should), fabrication rate.
  Published scoreboard vs the Opus baseline. THIS is the metric that answers
  "are the 120Bs getting closer to Opus?"
- **Kaizen integration:** hallucination incidents get failure categories
  (`unverified_claim`, `fabricated_evidence`, `stale_fact`) + recipes whose
  planner_input_modifier forces the canonical tool on retry.
- **Rule 317 reversal loop:** every caught falsehood = within-window reversal =
  mandatory RCA + causal-rule amendment (already mechanical via clinerules_amend_rule).

## Component inventory

| Component | Layer | Status (2026-08-19) |
|---|---|---|
| Canonical ground-truth tools (payment/SLS/paperwork/routing) | L1 | LIVE (pre-existing) |
| Rule 323 truth protocol | L2 | SHIPPED this session (Rules-archive) |
| R317_UNVERIFIED_STATE gate | L3 | LIVE (pre-existing) |
| R323_NAKED_CLAIM gate | L3 | SHIPPED this session (clinerules-mcp) |
| R323_FAKE_EVIDENCE gate | L3 | SHIPPED this session (clinerules-mcp) |
| truth_judge fleet-API action + truth_judge_log | L4 | SHIPPED this session (WOPR) |
| clinerules_truth_judge MCP tool | L4 | SHIPPED this session (clinerules-mcp) |
| Steering injection of truth protocol (router_hook.py, all server surfaces) | L1/L2 | FILED (idea) |
| CFA pre-send judge wiring (email/chat/SMS) | L4 | FILED (idea) |
| Truthfulness benchmark cron + scoreboard | L5 | FILED (idea) |
| truth_claims ledger (cross-session evidence cross-ref) | L3 | FILED (idea) |

## What this does NOT claim

- It does not make a 120B reason like Opus. It makes a 120B **behave truthfully**:
  probe before claiming, label inference, admit ignorance, and submit to review.
  Truthfulness is achievable at any parameter count; brilliance is not the target.
- Regex gates alone cannot catch a determined fabrication. The fake-evidence gate
  raises the cost of lazy fabrication; the JUDGE is the actual content check. Gates
  are the cheap first pass, the judge is the real review, the benchmark is the proof.

## Governance

1. Any new recurring claim class gets a canonical tool before a human answers it twice.
2. Any hallucination incident gets: bug-library row + kaizen category + recipe + rule
   amendment if a rule was the causal gap (rule 317 mechanical loop).
3. The benchmark scoreboard is reviewed weekly; a model whose fabrication rate rises
   gets demoted from student-facing surfaces until it recovers.
4. The judge is never weaker than the judged. If GLM ring is down, judge falls back
   to deepseek-v4-pro, then glm-5.2 cloud. A surface that cannot reach ANY judge
   FAILS CLOSED (rule 320): the send is held for human review, never waved through.
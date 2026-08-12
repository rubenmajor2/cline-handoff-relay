# Rule 317 — Completion Confidence: acquire what you would miss; reversals self-correct

**HARDFLOOR** (Ruben directive 2026-08-12). A completion window must be TRUSTWORTHY:
the answer is correct now, and it will still be true AND finished when Ruben checks
later. Two obligations enforce that, plus a stick test.

## Obligation 1 — the ACQUISITION GATE (before attempt_completion, every time)

Before claiming a task done, run a deliberate pass to catch what a weaker model would
miss: enumerate every MATERIAL claim in the answer and re-probe each with a live tool
call. A "from memory" statement is a claim, not a verification. Walk the recurring
wrong-claim domains in this order:

1. **LLM / fleet / routing state — the #1 recurring error.** NEVER recite status from
   memory. Re-probe live: `frankenstein_registry` / `frankenstein_verify_routing` / a
   request whose response headers name the backend (rule 140). If a rule (148, 252,
   280, 315) names a specific probe, run THAT probe, not a substitute.
2. **Deliverable durability.** Re-read every file you wrote; confirm the config is
   actually applied and the process healthy (rules 99, 263, 255). "Saved" is not
   "verified on disk."
3. **Numbers / counts / state.** Scope each one inline (rule 297 SCOPE GATE):
   population, window, what counts as failure.

If a probe CONTRADICTS what you were about to write, you hold a reversal — stop and run
Obligation 2 before completing.

## Obligation 2 — the REVERSAL self-correction (MUTEX test)

A reversal exists when an earlier conclusion in the same window and the new one are
MUTUALLY EXCLUSIVE — both cannot be true. Magnitude is irrelevant. One balance, one
host, one count: a boolean flip fires.

NOT a flip: a scope refinement where both can be true ("17 rows, 2 failed" vs "17 rows"
— both true). Test: "Can both statements be true?" Yes = no fire. No = fire.

On a fire: (1) name the flip; (2) run a rule-297 RCA on the INITIAL mistake, classified
into exactly one bucket — wrong premise / stale assumption / unread source /
insufficient probe / scope error; (3) update the causal rule so the next window does
not repeat it. A hardfloor edit needing Ruben's `--override`: file the exact fix text
as an idea — that filed idea IS the deliverable (rules 161 + 300 drive execution).

**The Reversal Log (mechanical, idea #25888 — Ruben approved 2026-08-12).** Every
completion MUST contain a `# Reversal Log` section. It either says "No reversals this
window" or lists every within-window flip as
`- initial conclusion → corrected conclusion | RCA bucket | causal rule updated (file/slug) or filed idea #NNNN`.
The validator (`clinerules_validate_completion`) BLOCKS a completion with no section
(R317_REVERSAL_LOG) and BLOCKS a flip line missing its RCA bucket. Cost: written ONCE
at completion time — zero per-turn capture, zero ledger file, zero compression risk.
This is the completion-time-only design that closes the per-turn-overhead defect
Ruben flagged in the #25888 approval.

## Termination guarantee (it cannot loop or stall)

- **One flip per state question.** Recording conclusion B ends the question; re-verifying
  B is not a second flip. A second flip needs a NEW state question.
- **Rule 143 circuit breaker applies.** At the bail strike, `attempt_completion` with the
  RCA state recorded in it is the legal exit.
- **Obligation 1 is a pass, not an investigation.** One live probe per material claim.
  If a probe needs a tool you lack, mark that claim "unverified", not silently confident.

## The STICK TEST (final self-check before completing)

Ask: *"If a fresh window re-checked this tomorrow, (a) would it find the answer still
TRUE, and (b) would it find the work still FINISHED?"* If either is no, keep going. If
a human decision is the only blocker, file the exact next step as an idea and name it
explicitly in the completion — nothing left to "come back and find."

---

**Cross-refs:** rule 140 (prove routing via live headers, not files), rule 148 (adapter
routing), rule 297 (RCA + classify + scope gate), rule 298 (confounding-evidence
table), rule 143 (circuit breaker / termination), rule 161 (approved ideas execute),
rule 263 (verify before claim), rule 255 (verify then report), rule 315 (classify host
state before "down"), rule 99 (re-read subagent writes), rule 91 (pre-completion
validation gate).
**Mechanical enforcement:** `clinerules_validate_completion` (rule 91's gate) now
contains the `R317_UNVERIFIED_STATE` check — a completion that asserts LLM/fleet/host
state (down/up/idle/offline/serving/degraded/saturated...) WITHOUT a `(verified: ...)`
marker quoting the live probe is BLOCKED. The gate does not rely on the model
remembering this rule: it is called on every completion and writes a block file on
failure (2026-08-12 Ruben directive: include 317 in the 91 validation).
**Last updated:** 2026-08-12 (scope expanded per Ruben: reversal detection + missed-fact
acquisition + stick test. Original reversal-only rev:
`Rules-backups/317-substantial-reversal-triggers-297-and-rule-update.md`.)
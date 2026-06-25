# 38 — Ruben-asks = autonomous-tier minimum (or ship now per context)

Permanent rule. Workspace-scoped. Source: 2026-05-10 cline_idea-confidence-pipeline-fix-2026-05-10
session, Ruben directive verbatim:

> "if i ask for something in cline specifically or for something to happen,
> that idea needs to be at minimum autonomous approved. If not shipped per
> the context of the conversation."

## The bright-line rule

**When Ruben explicitly asks for something to happen in a Cline session,
the work has TWO valid landing spots:**

1. **Shipped right now** in this Cline session (per .clinerules/29 act-on-confidence
   + .clinerules/37 sink-or-swim). This is the default for anything that
   meets the act-on-confidence gates (high confidence + reversible + small
   blast radius).

2. **Filed as an `orchestrator_ideas` row at minimum `approval_tier=autonomous`** so
   RUBEN's executor picks it up at the next cron tick without further
   approval.

**Never** file Ruben-requested work as `proposed` and walk away. That puts it
at the back of the manual review queue. The default must be ship-or-autonomous.

## What "autonomous-approved" means in this stack

Per `admin_portal.session_handoffs.approval_tier`:
- `pre_approved` — fires immediately without any human gate
- `autonomous` — auto-promoted to executor, no manual review needed
- `approved` — human approved, executor picks up
- `supervised` — human reviews each plan before exec
- `blocked` — never runs

Ruben-requested work goes to `autonomous` minimum. Better still: ship it now.

## How this interacts with the existing rules

- **Rule 29 (act-on-confidence):** if the work is reversible + small blast +
  high confidence, ship NOW. Don't file. Don't ask. Don't wait.
- **Rule 37 (sink-or-swim, no dry-run):** if Ruben said do X, don't propose
  a 24h dry-run. Just do X.
- **Rule 22 (executor self-supervision):** if the work isn't shippable in
  this session (architecture change, multi-step build), file it and
  immediately mark approval_tier=autonomous so RUBEN executor builds it.
  Don't leave it at proposed.
- **Rule 36 (orchestrator self-heal):** if the work IS the orchestrator's
  job class and a self-heal pattern exists, ship NOW per rule 36.

## When this rule does NOT apply

- **Ruben asks a research/diagnostic question** ("why are these unscored?")
  — answer the question, don't auto-ship a fix unless he then asks for it.
- **Ruben asks "your opinion"** — give the opinion, don't ship.
- **Hard rule-29 exclusions** (money, regulator, student-facing email/SMS,
  Moodle gradebook, irreversible external comms) — file as `pending`
  Q-card per rule 12, NOT autonomous. Ruben-asks doesn't override the
  irreversibility check.
- **Pure status check or "tell me what's going on"** — answer + report,
  don't file a chain.

If unsure whether Ruben asked for X to happen vs. asked about X: re-read
his message. If it contains a verb in imperative ("ship", "fix", "wire",
"add", "update", "do", "build", "make", "send"), it's an ask-to-happen.

## Audit trail required

Anything filed under this rule MUST include in the description / commit
message / implementation_notes:

- The Ruben directive verbatim (so future agents see why this is autonomous)
- The session slug (e.g. `cline_idea-confidence-pipeline-fix-2026-05-10`)
- "Per .clinerules/38: Ruben-asked → autonomous tier minimum" so it's
  greppable

## Self-check before walking away from a Cline turn

If Ruben asked for X to happen in this turn, ask:

1. **Did I ship X?** If yes, attempt_completion describes what shipped.
2. **If not shipped**, did I at minimum file an `orchestrator_ideas` row
   AND set `approval_tier=autonomous` (or insert a session_handoffs row
   at that tier directly)?
3. If I left it at `status=proposed` with `approval_tier=approved` or
   lower, I'm violating this rule. Re-do.

## Last updated

2026-05-10 — initial. Source: Ruben caught me filing 3 deferred items as
proposed (P0/P1/P2/P3) without bumping to autonomous-tier. He correctly
pointed out that asking for something IS the human approval — anything below
autonomous adds friction he didn't ask for.

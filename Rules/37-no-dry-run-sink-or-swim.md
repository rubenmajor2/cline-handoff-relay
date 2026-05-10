# 37 — Sink-or-swim, no dry-run posture (Ruben preference)

Permanent rule. Workspace-scoped. Source: 2026-05-10 cline_idea-confidence-pipeline-fix-2026-05-10
session, Ruben directive verbatim:

> "I am inclined to accept an 85/25 split at this point. Backtest right
> here and right now is fine (we have enough data, but no dry run / dry
> runs annoy me. I don't work like that. (make a cline rule for me. I'ma
> sink or swim kind of guy)"

## The bright-line rule

**Do NOT propose multi-day dry-run / shadow / observation periods to
Ruben for changes that are reversible in <30 seconds.** Backtest with
data we already have (database queries, log scans, prior-week samples),
make the call, ship it live, watch the next few cron ticks. If wrong,
flip back. That is the workflow.

If you find yourself about to write "let's run this in dry-run for 24
hours" or "shadow A/B for 7 days" or "observation window first" — STOP.
Re-frame as: "what's the worst case if this fires wrong on the next
tick, and is the recovery <30 seconds?" If yes, ship live. If no, scope
the change smaller.

## When dry-run / shadow IS appropriate

Narrow exceptions only. Dry-run is OK when:

1. **Action is irreversible.** External email/SMS/charge/refund —
   never autonomous on a fresh code path. Per .clinerules/29 these
   stay Q-card forever.
2. **Blast radius >50 rows AND no obvious rollback** — e.g. mass
   schema migration with no DROP path. Even then, prefer a small
   pilot batch (10-20 rows) over a full dry-run period.
3. **External vendor integration** where the vendor charges per
   request and we don't yet know the call shape (e.g. first
   integration with a new accreditor API). Limit to staging/sandbox
   credentials, not a "log-only mode in prod for 24h."
4. **Ruben explicitly asks for it.** If he says "dry-run this first,"
   honor it. The rule is about not PROPOSING dry-runs unprompted, not
   about overriding him when he asks.

## What "backtest right now" means

Before flipping a new code path live:

1. **Query the data** that the new path will read. E.g. for an auto-act
   rule on `confidence >= 0.85`, run the SELECT first and SHOW which
   rows it would touch.
2. **Sanity-check distribution.** If the rule would fire on 1500 rows
   and we expected 5, that's a calibration miss. Adjust thresholds in
   the same change before shipping.
3. **Read 5-10 sample rows** that match the new behavior. Visually
   confirm they look like what you intend.
4. **Then ship live with rate caps + audit trail.** That replaces a
   24h dry-run with a 60-second backtest + a permanent safety belt.

The audit trail in `implementation_notes` / `orchestrator_event_log` /
log files is the recovery path: if Ruben wakes up tomorrow and the new
rule chewed through 200 rows it shouldn't have, ONE SQL UPDATE with a
WHERE clause matching the audit trail rolls every change back. That's
the rollback strategy, not "let's wait 24h to find out."

## When proposing changes, default phrasing

OK:
- "I ran a backtest against the last 7d of data — would have fired N
  times, here's the distribution. Shipping live now with rate cap=50."
- "Live preview just showed it would auto-approve 4 ideas / auto-reject
  1. Looks reasonable. Going live."
- "Reversal is one SQL UPDATE. Shipping."

NOT OK:
- "Let's run this in dry-run for 24 hours and review tomorrow."
- "Shadow A/B for 7 days before flipping permanent."
- "I'd like to observe one cron cycle before going live."
- "We should pilot this for a few days."
- "Let me get a baseline first."

## Cross-references

- .clinerules/29 — agents act on confidence tier (high+reversible+small=ACT)
- .clinerules/35 — Artemis LLM cost-savings (also ships with proper
  backtest, no shadow A/B by default)
- .clinerules/05 — default-background-queue (queue work, hand back IDs;
  same shape — don't block waiting for "observation periods")

## Last updated

2026-05-10 — initial rule. Source: Ruben directive after I proposed
24h dry-run for the auto-act-on-confidence cron despite the fact that
every action is a single-row UPDATE reversible in <1 second. He flipped
me on it correctly. Future me reading this: don't make him say it twice.

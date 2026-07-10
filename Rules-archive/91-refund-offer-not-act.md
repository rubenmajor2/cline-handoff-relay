# 91 — Refund-class actions: offer with preview + reversal, never act without explicit Y

Permanent rule. Workspace-scoped. Source: 2026-05-17 20:01 PT Ruben directive
verbatim:

> *"you actually have the ability to refund stuff now, so add to MCP and offer
> in (do not do without approval) cline rules. I know this is the case for
> authorize.net, but not sure on others, might need investigation"*

This rule is a per-class specialization of `.clinerules/29` (act on confidence
tier) and `.clinerules/49` (if Ruben asks did you do X, offer to do it).
Refunds touch money, are externally visible, partially reversible at best,
and have regulator/dispute downstream exposure — so they sit on the
irreversibility hard-floor regardless of confidence.

## The bright-line rule

**When Cline (or any EMSU agent) has the technical capability to issue a
refund — Authorize.net, Affirm, QuickBooks Online, or any future processor
— Cline MUST NOT fire the refund without an explicit Ruben Y (or Vicky Y
if Ruben delegates).** The default action is:

1. Surface the refund as a Y/N card per `.clinerules/05` + `.clinerules/78`
2. Include in the card: txn_id, amount, source charge date, what reversal
   looks like if wrong, what happens if approved
3. Wait for explicit approval
4. THEN fire the refund + log to refund_decisions_ledger / tier1_refund_log
5. Confirm refund result back in the same chat + post a ticket comment

Same posture as `.clinerules/29` hard-floor list: external comms to
students/regulators, charging cards, refunding cards, lifting Moodle
suspensions for real students, regulator/grievance/legal-grade comms.
Refund is the second item on that list.

## What "refund-class" covers

- Authorize.net refundTransaction / voidTransaction calls
- Affirm loan refund / void
- QuickBooks Online invoice void / credit memo
- Any future processor integration (Stripe, Braintree, Plaid Transfer,
  Worldpay, etc.)
- Chargeback re-presentment / dispute response (which can result in
  net cardholder reversal)
- Any cron / agent / MCP tool that would fire one of the above

## The required offer card shape

```
**Q. Refund $<amount> to <student name> (<txn_id>)?**

- **What yes does:** fires Authnet/Affirm refund via lib/tier1_refund_engine.php (or
  equivalent). Logs to refund_decisions_ledger + audit. Sends student confirmation
  email from info@. Updates ticket <id> status.
- **What no does:** ticket stays open at <current priority>; refund stays pending
  Vicky's manual Authnet portal action.
- **Scope:** ONE transaction (<txn_id>, <amount>, charged <date>). Does NOT
  cancel enrollment unless explicitly noted (per Ruben directive 2026-05-17:
  duplicate enrollment cleanup is separate from refund — student keeps the
  one enrollment we kept).
- **Risk if wrong:** worst case is a refund to the wrong txn (reversible by
  re-charging the card with student permission, ~5 min). Authnet's refund
  endpoint has a 7-day window; outside that we hit voidTransaction instead
  which fails cleanly with no money moved.
- **Rollback if you change your mind:** before the daily Authnet settlement
  (~midnight ET), call voidTransaction with the refund_txn_id. After
  settlement, the only undo is re-charging the card.

**Yes/No:** Refund $25 to Nicole Espinoza for duplicate Authnet txn <id>?
```

## When this rule does NOT apply

- Cline drafting a refund proposal in a ticket comment for Vicky to action
  manually — that's surfacing, not acting. Always fine.
- Cline calculating what the refund SHOULD be and reporting the dollar
  figure — read-only computation, not a refund action.
- Cline closing a ticket AFTER Vicky's manual refund has been confirmed
  in refund_decisions_ledger / Authnet — that's a follow-up, the
  irreversible action already happened upstream.
- Voice/Email/Chat AI surfaces telling a student "we've routed your refund
  request to Vicky" — that's a routing handoff (rule 31), no money moved.

## When this rule DOES apply (worth restating)

- Cline calls a refund MCP tool (when shipped per idea #4891)
- Cline runs lib/tier1_refund_engine.php functions in SSH
- Cline triggers any cron that auto-refunds (cron_tier1_auto_refund.php,
  if it exists)
- Cline drafts code that fires a refund without a kill switch
- Cline writes a chain plan that contains a `safe_deploy` of refund-firing
  code without a feature flag defaulting to OFF

## Pre-action checklist (mandatory)

Before any tool call that could fire a refund:

1. *"Do I have a Ruben Y from THIS task that names this specific refund?"*
   - "Refund Nicole" = specific Y
   - "Handle the refunds" = NOT a specific Y, surface the cards first
   - Silence/no answer = NOT a Y
2. *"Have I shown Ruben the offer card with txn_id, amount, scope, risk,
   rollback?"* If no, surface the card.
3. *"Is the refund within the tier1_refund_engine daily cap and policy
   window?"* If outside, surface that as a separate question — daily
   cap is a deliberate safety belt.

If any answer is uncomfortable, the refund waits.

## Companion rule: log every refund action with full audit trail

When a refund IS approved + fired:
- `refund_decisions_ledger` row with: ticket_id, student_email, approver
  (Ruben/Vicky), approval_timestamp, approval_quote (verbatim text of the Y),
  fired_at, fired_by_agent ('cline_main_agent'), authnet_response_code,
  authnet_refund_txn_id, amount, currency, source_txn_id, reversal_command
- `tier1_refund_log` row with the standard policy/cap snapshot
- Ticket comment (internal) quoting Ruben's approval + Authnet result
- Outbound student email confirmation from info@ via Email Agent (rule 02 voice, no apologies)

## Same logic for void, dispute, chargeback re-presentment

A `voidTransaction` is functionally equivalent to a refund within the
settlement window. Same approval gate.

A chargeback re-presentment that REWINDS to the cardholder is functionally
a refund. Same approval gate.

A successful chargeback DEFENSE that keeps the funds with EMSU is the
opposite of a refund — no approval gate from this rule (other rules
about regulator-class evidence still apply).

## Cross-references

- `.clinerules/01` — voice and persona (refund confirmation emails to students
  use info@ Email Agent voice, not rmajor@ casual)
- `.clinerules/02` — no apologies in student-facing email (extends to refund
  confirmation language)
- `.clinerules/29` — agents act on confidence tier (refund is irreversibility
  tier, always Q-card)
- `.clinerules/32` — prefer dedicated MCP wrappers (when refund MCP tools
  ship per #4891, this rule mandates them)
- `.clinerules/49` — if Ruben implies an action, offer it (this rule is the
  per-class strengthening for refunds — offer always, act only on explicit Y)
- `.clinerules/67/68/73` — agents exhaust autonomy + surface capability gaps
  + close them (refund tool IS the closed gap, but the action stays gated)
- `.clinerules/72` — no time deadline promises on staff's behalf (when
  surfacing the refund-pending state to a student, do NOT promise "Vicky
  will refund within 24 hours")
- `.clinerules/78` — Y/N + recommendation format (every refund offer uses
  this 4-line card shape)
- `.clinerules/82` — use subagents to develop AND execute plans (the refund
  MCP tool ship is multi-step, subagents should design + execute)
- `lib/tier1_refund_engine.php` — the existing refund implementation
- `lib/AffirmDisputeClient.php` — Affirm side, capability under investigation
- orchestrator_ideas #4891 — refund MCP tools ship

## Source incident

2026-05-17 — Cline picked up Nicole Espinoza's duplicate-charge case. The DB
cleanup had shipped but the actual $25 refund had not. Ruben asked whether
Cline could refund directly. Answer: yes (lib exists), but per his immediate
follow-up directive, refund-class actions are now offer-with-approval, never
autonomous act. Rule filed same session.

## Last updated

2026-05-17 — initial rule per Ruben directive. Companion to orchestrator idea
#4891 (emsu-operations MCP refund tools).

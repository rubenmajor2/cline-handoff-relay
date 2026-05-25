# 114 — Affirm BusinessTrack API is wired. Use it. Never tell a student to contact Affirm.

Permanent rule. Workspace-scoped. Source: 2026-05-24 Rodolfo Zamot Jr (26514T-09, inv 164791, charge UDMZ-AWVG). Email Agent + RUBEN both concluded "Vicky needs to log into the Affirm merchant dashboard manually" because the codebase had NO live Affirm REST client and config.local.php still held `__RUBEN_PASTE_AFFIRM_API_KEY_HERE__` placeholders. Ruben supplied the production keys verbatim. They are now live and SMOKE-TESTED against UDMZ-AWVG (HTTP 200, status=captured, amount=$1,445).

## The bright-line rule

**When any student says "I paid via Affirm" / "I set up Affirm" / "my Affirm went through" / mentions an Affirm charge_id or checkout_id, the FIRST move is a live Affirm API lookup against that charge_id. Not asking Vicky. Not asking the student to restate facts. Not telling them to contact Affirm.**

EMSU owns the reconciliation. We have the keys. Use them.

## Credentials (canonical, single source of truth)

Live in `/var/www/emtskills/config/config.local.php` as PHP constants:

```php
AFFIRM_API_KEY      = "09OQU2QM92IILNO6"
AFFIRM_API_SECRET   = "Sn3yalSD4sGp51nhkG6QklDXKZ2RuAW1"
```

Base URL: `https://api.affirm.com`
Transaction lookup: `GET https://api.affirm.com/api/v1/transactions/{charge_id}`
JS SDK: `https://cdn1.affirm.com/js/v2/affirm.js`
Auth: HTTP Basic — `curl -u "$AFFIRM_API_KEY:$AFFIRM_API_SECRET"`

**NEVER hardcode these anywhere else.** All callers `require_once __DIR__ . '/../config/config.local.php'` and read the constants.

## Reference call (canonical smoke test)

```bash
curl -sS -u "$AFFIRM_API_KEY:$AFFIRM_API_SECRET" \
  https://api.affirm.com/api/v1/transactions/UDMZ-AWVG
```

Returns JSON with `id`, `status` (captured/authorized/voided/disputed), `amount` in cents, `amount_refunded`, `order_id`, `checkout_id`, `created`, `currency`, `events`.

## Decision tree when a student claims Affirm payment

1. Look up the charge with the canonical curl above using whatever charge_id you have.
2. **status=captured, amount_refunded=0** → EMSU has the money. Reconcile QB invoice (post payment, zero balance, pause reminders, clear suspension). Tell the student "your Affirm payment is confirmed."
3. **status=authorized** → Affirm holding the loan. Tell the student "approved and held, capture on course start."
4. **status=voided / not found** → flow abandoned. Send correct Affirm signup link. Do NOT tell them to contact Affirm.
5. **status=disputed** → STOP. Escalate to Vicky/Ruben immediately. Do not reply to the student.
6. **captured but amount > QB balance** → most likely the +$250 Affirm financing fee surcharge (see refund posture below) or bundled fees. Reconcile the matching invoice line, flag the delta for Vicky.

## Forbidden defaults

- ❌ "Please contact Affirm to resolve this" — we own it
- ❌ "Vicky will check the Affirm dashboard" — the API is wired, call it
- ❌ "Please reply with your confirmation number, dollar amount, date and payment method" when the student already provided in the inbound (rule-101 restate-facts gap)
- ❌ Hardcoding the keys anywhere except config.local.php
- ❌ Skipping the API lookup because there's no `affirm_payment_status_checks` row

## Refund posture (Ruben directive 2026-05-24)

**Affirm refund policy at EMSU is now bright-line:**

1. **Once a student signs up for Affirm AND the first day of classes has started: NO refund. Period.** Not partial, not pro-rated. Affirm's post-2025 policies prevent EMSU from deducting any fees from the loan side, so we cannot eat the cost anymore. Student keeps the loan, EMSU keeps the captured funds, student finishes the course or doesn't.

2. **Prior to the first day of classes:** refund per standard EMSU cancellation policy (registration fee non-refundable, tuition refundable per schedule). Use the normal refund_requests flow.

3. **NEVER respond to a refund request by telling a student "contact Affirm to dispute" or "request a refund through Affirm"** once classes have started. That triggers chargeback/dispute paths that damage the EMSU↔Affirm merchant relationship. If a student asks for a refund on a started Affirm enrollment, escalate to Vicky/Ruben. Do not autonomously initiate reversal on either side.

4. **Affirm invoicing is +$250 over the displayed quote** (Affirm financing fee passed through). When Affirm-captured amount exceeds the QB invoice amount, the most likely explanations (in order):
   - +$250 Affirm financing fee surcharge baked into the loan
   - Student transferred from a lower-priced section into a higher-priced one
   - Bundled materials / additional fees the EA priced separately

   The captured-vs-billed delta is real revenue EMSU received and is NOT refundable to the student. The fix is to add the missing QB line items so the books reflect the truth — NOT to refund the difference.

## What this rule does for refund tickets

When a refund ticket mentions Affirm:
1. Call the Affirm API on the charge_id (status check).
2. Check `Students.course_start_date` — has the course started?
3. **Course started AND captured** → no refund possible. Escalate to Vicky with that explicit summary. Do NOT promise the student anything refund-shaped.
4. **Course not yet started AND captured** → route through normal refund_requests, refund refundable portion only per cancellation policy.
5. **status=disputed** → halt all comms, alert Vicky.

## Self-check before any "tell Vicky" / "tell the student to call Affirm" reply

Ask: *"Do I have a charge_id from Students.affirm_charge_id, ticket body, or inbound?"*

If yes → call the API first. The API answer trumps every other story.

If no → ask the student for ONE thing: "Reply with your Affirm confirmation number (looks like XXXX-XXXX) and we'll resolve this directly." Don't ask for dollar amount / date / method — those are already in QB and the inbound.

## Cross-references

- HANDOFF_NOTES.md: `2026-05-24 — Affirm BusinessTrack API credentials installed (canonical source of truth)` + `2026-05-24 — Bulk Affirm reconciliation (14 students, $13,300)`
- Ticket #5037 (Rodolfo Zamot) — canonical case
- Ideas #6646 (P0, build lib/AffirmLoanStatusClient.php + MCP wrapper, APPROVED), #6647 (P0, extend cron/affirm_reconcile.php, APPROVED, depends on 6646)
- .clinerules/107 — EMSU payment architecture canonical map (Affirm section now points here)
- .clinerules/70 — exhaust Authnet MCP before assuming alternate processor (Affirm is parallel; do not conflate refund flows)
- .clinerules/02 — no apologies in student emails (reconciliation replies follow this)
- .clinerules/92 — work at the core, not bandaids (this rule IS the core fix)
- .clinerules/19 — Cline never authorizes refunds without Ruben/Vicky (NOT changed; tightened for Affirm)
- `lib/AffirmDisputeClient.php` — existing dispute handler; do not call autonomously, only via Vicky

## Last updated

2026-05-24 v2 — added refund posture + $250 financing fee section. Source: Ruben directive during the bulk-reconciliation session. Affirm post-2025 policies mean EMSU can no longer eat refund-side fees; the bright-line "no refund after class start" rule is now an operational truth.

2026-05-24 v1 — initial. Source: Rodolfo Zamot inv 164791 / charge UDMZ-AWVG. Live API smoke test returned HTTP 200 captured $1,445. Ruben supplied keys verbatim.

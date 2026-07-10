# 107 — EMSU payment architecture canonical map (Authnet, QB, Affirm)

Permanent rule. Workspace-scoped. Source: 2026-05-20 cline_emsu-registration-rewrite-v4 session. Ruben caught me building a parallel Authnet reconcile cron (idea #5373, deployed then disabled) because I didn't know about `payment_attribution_queue` + `auto_classify_payer` + `emsu-qb-payment-sync`. Ruben quote: *"should be memorialized in the MCP properly then or placed where it doesn't get lost because i noticed a knowledge gap here in cline sessions on it here and there. Same on Affirm and Quickbooks."*

This rule is the authoritative map. Before any Cline task that touches payments, refunds, attribution, suspensions, or "where is this student's money" questions, read this first.

## The pipeline (Authnet → QB → DB → UI)

```
[Student pays via Authorize.net or Affirm]
            ↓
[Authorize.net settled batch]
            ↓
[cron_authnet_reconciliation.php — every 10 min] (lib/authnet_payment_lookup.php helper)
            ↓
[qb_payment_sync.php → /var/www/emtskills/cron/] writes to QB
            ↓
[qb_invoices + qb_invoice_payments tables in admin_portal]
            ↓
[auto_classify_payer.php] classifies payer relationship
            ↓
[payment_attribution_queue table] surfaces ambiguous attributions
            ↓
[cron_vicky_attribution_nudge.php] works the queue
            ↓
[routes/payment_attribution_queue.php] Vicky's UI
```

## Canonical files / tools / tables

### Authorize.net

- **API lookup library:** `/var/www/emtskills/lib/authnet_payment_lookup.php`
- **Canonical function:** `fetchAuthNetTransactionsByEmail(string $email, string $name='', string $phone=''): array` — returns `[txnId, amount, date, status, invoiceNumber, matchType, paymentMethod, billingName]`
- **DO NOT invent function names** — guessing `authnet_find_transactions_by_email` returns `[]` silently (no error, just empty). That's the #1 trap from idea #5373.
- **Reconciliation cron:** `/var/www/emtskills/cron/cron_authnet_reconciliation.php` (506 lines, every 10 min via `/etc/cron.d/emsu-authnet-reconciliation`)
- **MCP wrappers (PREFER THESE):**
  - `check_authnet_transaction` — exact trans_id lookup
  - `find_authnet_by_email` — billing email match, default 90d
  - `find_authnet_by_name` — first+last name match
  - `verify_payment_state` — RULE 33 AGGREGATOR (Authnet + QB + Affirm + refund-email log in one call). **CALL THIS FIRST** for any payment question.
- **Credentials live in:** `cron_authnet_reconciliation.php` lines 60–62 (`$authnetLoginId='97KTdp94'`, `$authnetTransKey='6Rh7dxjB7T2g38S3'`)

### QuickBooks

- **Sync cron:** `/var/www/emtskills/cron/qb_payment_sync.php` — pulls QB payments into `qb_invoice_payments`
- **Tables (admin_portal):**
  - `qb_invoices` — columns: `id, student_id, student_db_id, qb_invoice_id, qb_doc_number, qb_customer_id, status, total_amount, amount_paid, balance_due, class_section, location, course_method, line_items, drive_file_id, drive_url, pdf_uploaded_at, qb_sync_error, qb_created_at, qb_due_date, qb_txn_date, qb_last_synced_at, created_at, updated_at`
  - `qb_invoice_payments` — columns: `id, qb_invoice_id, qb_payment_id, payment_date, amount, payment_method, cc_trans_id, cc_name_on_acct, cc_status, txn_source, memo, receipt_drive_file_id, receipt_drive_url, receipt_uploaded_at, qb_created_at, created_at`
  - `qb_payments` — separate table, requires elevated DB user (not accessible to `emsuserver`)
- **JOIN pattern (canonical):**
  ```sql
  SELECT s.id, s.email, SUM(qip.amount) AS total_paid
  FROM Students s
  LEFT JOIN qb_invoices qi ON (qi.student_db_id = s.id OR qi.student_id = s.student_id)
  LEFT JOIN qb_invoice_payments qip ON qip.qb_invoice_id = qi.qb_invoice_id
  ```
  Both `qi.student_db_id` (numeric Students.id) AND `qi.student_id` (varchar slug e.g. 26813FT-21) are valid join keys. Use OR to cover both.
- **MCP wrappers:** `check_qb_invoices(student_id)` — returns invoice list + payment status + balance due + payment plan info

### Affirm (BNPL)

- **Library:** `/var/www/emtskills/lib/AffirmDisputeClient.php`, `AffirmPaymentStatusChecker.php`, `affirm_pricing.php`
- **Status checker cron:** `/var/www/emtskills/cron/affirm_payment_status_checker.php` (also: idea-1810 background)
- **MCP wrapper:** `check_affirm_status(student_id_or_email)` — returns most recent affirm_payment_status_checks row with qb_status_json, authnet_status_json, affirm_status_json
- **Reconcile cron:** `/var/www/emtskills/cron/affirm_reconcile.php` (every 2h via `/etc/cron.d/emsu-affirm-reconcile`) — scans WC sites, tags students, clears suspensions

### Payer attribution (who paid for whom)

- **Auto-classifier:** `/var/www/emtskills/cron/auto_classify_payer.php`
- **Tables:**
  - `payer_relationships` — 1 row per unique student+payer+card pair
  - `payment_attribution_queue` — 1 row per ambiguous payment needing Vicky review. Columns: `qb_payment_id, qb_invoice_payment_row_id, student_db_id, student_code, payment_amount, cc_name_on_acct, student_name, proposed_relationship, proposed_confidence, proposed_reason, status (pending|confirmed|dismissed|outreach_sent|resolved), auto_resolved_source, vicky_action_at, agent_outreach_started_at, outreach_channel, outreach_attempts, outreach_token`
- **Nudge cron:** `/var/www/emtskills/cron/cron_vicky_attribution_nudge.php`
- **UI:** `/var/www/emtskills/routes/payment_attribution_queue.php`
- **As of 2026-05-20:** 4659 total rows, 10 pending, 94 resolved, 22 outreach. Active and working.

## Self-check before building anything payment-related

1. **Is there already a cron for this?** `ls /etc/cron.d/ | grep -iE 'payment|authnet|affirm|qb_|attrib'` returns: `emsu-auto-payment-plan`, `emsu-authnet-reconciliation`, `emsu-payer-attribution-weekly-report`, `emsu-payment-suspension-sync`, `emsu-payment-warnings`, `emsu-qb-payment-sync`, `emsu-vicky-attribution-digest`, `emsu-vicky-attribution-nudge`, `idea_1810_affirm_payment_status_checker`, `emsu-affirm-reconcile`. If your idea overlaps any of these, redesign as a delta, NOT a parallel build.

2. **Is the data already in the DB?** Try the canonical JOIN above before calling Authnet API. The QB sync runs every X minutes — fresh data is usually already in `qb_invoice_payments`. Authnet API calls are slow + sometimes timeout.

3. **Does an MCP wrapper exist?** Always prefer `verify_payment_state`, `check_authnet_transaction`, `find_authnet_by_email`, `check_qb_invoices`, `check_affirm_status` over hand-rolled API integration.

4. **Is the function name verified?** `grep -E '^function|^public function' lib/authnet_payment_lookup.php`. Never invent names — they fail silently to `[]`.

## Anti-patterns this rule prevents

- ❌ Building a "v4 Authnet reconcile cron" without checking `cron_authnet_reconciliation.php` already exists (idea #5373, deployed then disabled, 2026-05-20)
- ❌ Calling `authnet_find_transactions_by_email` instead of `fetchAuthNetTransactionsByEmail` (silent empty array)
- ❌ Writing a custom Authnet HTTP request when `verify_payment_state` MCP tool does it in one call with refund-email cross-reference
- ❌ Filing a `payment_attribution_queue` ticket from scratch instead of letting `auto_classify_payer.php` do it via its normal qb_invoice_payments scan
- ❌ Assuming Students.class_section blank = student paid. Run the canonical JOIN — blank usually means pre-EA-completion, no QB invoice yet
- ❌ Asking Vicky to "verify if X paid" — use `verify_payment_state` first, only ping her if the aggregator returns NO Authnet + NO QB + an inbound complaint

## Cross-references

- `.clinerules/33` — Rule 33 aggregator + `verify_payment_state` mandate
- `.clinerules/70` — Always exhaust Authnet MCP before assuming alternate processor
- `.clinerules/92` — Work at the core, not bandaids (the rule whose violation led to this rule)
- `.clinerules/85` — Student issues prefer systemic fix
- `_INDEX.md` — index entry must be added to "Infrastructure / debugging" section

## Last updated

2026-05-20 01:10 PT — initial. Source: cline_emsu-registration-rewrite-v4-verify-2026-05-19. Ruben directive verbatim: "should be memorialized in the MCP properly then or placed where it doesn't get lost because i noticed a knowledge gap here in cline sessions on it here and there. Same on Affirm and Quickbooks." Idea #5373 + #5384 are the source incidents.

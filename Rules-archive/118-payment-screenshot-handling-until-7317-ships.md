# 118 — Payment-screenshot handling for inbound email (interim, until idea #7317 ships)

Permanent rule. Workspace-scoped. Source: 2026-05-26 Ruben directive after Paula Castillo Hi Espino case (26613FT-15) revealed Email Agent was replying blind to attachment content for 30+ days, ~8 inbounds/day in this class (241 in last 30d).

## The bright-line rule (active until orchestrator_ideas #7317 finishes shipping)

When an inbound email has `has_attachments=1` AND the body or subject suggests a payment claim (any of: "paid", "charged", "receipt", "proof of payment", "screenshot", "card was charged", "I attached"), the AI Email Agent — and any other agent reading the inbound — MUST NOT autonomously reply with:

- "Please reply with the dollar amount, payment method, and receipt/transaction confirmation number"
- "Can you re-type the receipt details so we can look it up"
- "We do not show a payment on your account" (when student insists they paid with attachment)

Those replies have been the dominant time-waster. Student re-sends the same screenshot, agent re-asks for retyping, forever loop.

## What to do instead (until #7317 lands)

1. Call `verify_payment_state` MCP for the student (rule 33). This pulls Authnet + QB + Affirm + outbound refund-email confirmations.
2. If `verify_payment_state` returns a matching transaction → autonomous reply confirming the match with trans_id + amount + date.
3. If `verify_payment_state` returns no transaction BUT student claims payment AND has_attachments=1 → **DO NOT** auto-reply with the retype-request loop. Instead:
   - File an internal Q-card / ticket comment to vyu@emsuniversity.com (Vicky) so she can open the screenshot from the staff-MIME forward
   - Auto-acknowledge the student with a one-line holding reply: "we are reviewing your proof of payment, you will hear back within 1 business day"
   - That holding reply is fine on autonomous tier (reversible, no money commitment) per rule 29
4. Never auto-credit / auto-void / auto-post QB invoices based on a screenshot alone. Money posting is irreversible-tier per rule 29, always human-gated.

## Why this rule exists

Postmark webhook (`/var/www/emtskills/routes/postmark_inbound_webhook.php` lines 497-533) decodes attachment base64 only for MIME-forward to staff. It does not write the binary to disk. So no AI agent can see the PNG. Sonnet 4.6 / Haiku / GPT-5.2 all behave the same blind way — they reply fluently to the text body and ignore the existence of the attachment. The fix is idea #7317 (P0, approved, autonomous): persist attachments → Tesseract OCR → 70B extraction → Authnet/QB match → autonomous reply on `matched`.

This rule is the **interim safety net** so we stop digging the hole while the pipeline ships.

## Implementation status (last verified 2026-05-26 14:17 PT)

- ✅ DB schema landed: `payment_evidence_proposals`, `inbound_attachment_ocr`, `email_inbound_log.attachment_paths`, `email_inbound_log.ocr_method`
- ❌ Code not yet shipped: webhook patch, lib/InboundAttachmentOCR.php, lib/PaymentEvidenceExtractor.php, lib/PaymentEvidenceMatcher.php
- ❌ Storage dir not created: /var/www/emtskills/storage/inbound_attachments/
- ❌ Email Agent wire-up pending
- ❌ 30d backfill (241 rows) pending

**To check current status**, query `SELECT COUNT(*) FROM payment_evidence_proposals`. If > 0, pipeline has started writing — sunset this rule when 100% of last-7d payment-context inbounds have a proposal row.

## Sunset trigger

This rule self-deletes once idea #7317 is fully shipped AND backfill batch-1 (20 rows) has been reviewed by Vicky. Verify via:

```sql
SELECT COUNT(*) AS proposals,
       SUM(match_result='matched') AS matched,
       SUM(reviewed_by_human IS NOT NULL) AS reviewed
FROM payment_evidence_proposals;
```

When `proposals > 100` and the reviewed batch-1 looks correct, delete this file and reindex the clinerules MCP.

## Cross-references

- orchestrator_ideas #7317 (P0, approved, autonomous)
- HANDOFF_NOTES.md 2026-05-26 entry "Email Agent payment-screenshot OCR pipeline"
- Reference banner: `/var/www/emtskills/routes/quickbooks_settings.php` (visible to staff on QB page)
- .clinerules/29 (act-on-confidence — money flow human-gated)
- .clinerules/33 (verify_payment_state aggregator)
- .clinerules/74 (local 70B/7B first, $0)
- .clinerules/92 (fix the core, not bandaids — #7317 IS the core fix)
- .clinerules/02 (no apologies in student email — holding reply per this rule does not need an apology either)

## Last updated

2026-05-26 14:17 PT — initial. Source incident: Paula Castillo Hi Espino 26613FT-15 inbound 34987+35061 ($2,445 Boot Camp claim, Authnet 0 hits, screenshot unreadable). Ruben directive: "every single agent" must be aware of this process while #7317 ships.

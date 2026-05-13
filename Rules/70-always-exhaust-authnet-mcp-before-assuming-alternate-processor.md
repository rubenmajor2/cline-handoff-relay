# 70 — Always exhaust Authnet MCP tools before assuming an alternate payment processor

Permanent rule. Workspace-scoped. Source: 2026-05-13 Stephanie Aguirre BLS refund investigation.
Cline concluded "payment may be via Stripe or Square on tucsoncpr.com" purely from training-data
assumption — without ever exhausting the Authnet MCP tools first. EMSU's payment processor is
Authorize.net across all sites including tucsoncpr.com, dallascpr.org, and any WPForms-connected
pages. There is no Stripe or Square integration.

## The bright-line rule

**When investigating any payment, charge, or refund for an EMSU student or BLS student, the
FIRST tool calls MUST be the Authnet MCP tools — not SSH, not raw SQL, and not training-data
assumptions about which processor was used.**

Do NOT conclude "the payment went through a different processor" or "may be Stripe/Square" until
all three Authnet lookups below have been exhausted AND come back empty.

## Required search sequence (run all three before giving up)

```
1. find_authnet_by_email   — use the email on file
2. find_authnet_by_name    — first + last name
3. find_authnet_by_name    — last name only (catches maiden name, middle name, etc.)
```

Each search should use `days_back=120` minimum (180+ if the enrollment date is older).
Do NOT filter by amount on the first pass — cast wide, confirm amount on the result.

If all three return empty:
- Document exactly which searches were run (email used, name used, date range)
- Add those details to the ticket / internal comment for Vicky so she's not starting blind
- Note: "No Authnet transaction found for X under email Y and name Z across N days. Please
  check WPForms entry #NNNN in WordPress admin to find the billing email used at checkout."
- Do NOT say "may be Stripe" or "may be Square" — EMSU does not use those

## Why this rule exists

EMSU's payment infrastructure:
- **Authorize.net** — all EMSU and BLS/CPR sites (emsuniversity.com, tucsoncpr.com,
  dallascpr.org, houstonemt.com, etc.) run WPForms → Authorize.net
- **QuickBooks** — invoicing for EMT program tuition (QB invoices tied to Authnet payments)
- There is NO Stripe, Square, PayPal, or other processor in the EMSU stack

When an Authnet search comes back empty, the most likely explanations are:
1. The billing name/email at checkout differed from the email on file (check WPForms entry)
2. The payment was processed under a family member's name
3. The transaction is older than the search window (increase days_back)
4. The registration was comp'd or invoiced differently

Never jump to "alternate processor" — that conclusion wastes Vicky's time and sends her
looking in places that don't exist.

## Companion rule: always consult relevant MCPs for context

This rule is an instance of a broader principle: before drawing any conclusion about a
student's payment, enrollment, Moodle status, or account state, use the dedicated MCP tools
that have direct access to EMSU's live data. Don't rely on training-data assumptions about
what processor/platform/system EMSU uses.

Specific tools to reach for first on payment questions:
- `find_authnet_by_email` — payment by billing email
- `find_authnet_by_name` — payment by billing name
- `check_authnet_transaction` — if a specific trans_id is known
- `check_qb_invoices` — for EMT program tuition invoices

Per .clinerules/32 (prefer dedicated MCP wrappers): these tools exist, use them before SSH
or assumptions.

## Self-check before any payment conclusion

Before writing "the payment may be via [processor name]" or "no payment found" in any
response to Ruben or any ticket:

1. Did I run `find_authnet_by_email`? What email? What date range?
2. Did I run `find_authnet_by_name`? What name? Did I try the last name alone?
3. If both returned empty, did I document the specific searches in the ticket?
4. Am I about to name a processor EMSU doesn't use? If yes, stop.

## Cross-references

- .clinerules/32 — prefer dedicated MCP wrappers over raw SQL or training-data recall
- .clinerules/67 — agents exhaust available tools before escalating to human
- .clinerules/68 — agents must exhaust tools and surface capability gaps
- Source incident: Stephanie Aguirre (smaguirre99@yahoo.com), ticket 3480, 2026-05-13

## Last updated

2026-05-13 — initial rule. Source: BLS refund investigation where Cline incorrectly
concluded tucsoncpr.com used Stripe/Square without first exhausting the Authnet MCP tools.
Ruben correction: "there is no Stripe or Square, it's WPForms hooked up to our Authorize.net
which you have API access to consult the MCP."

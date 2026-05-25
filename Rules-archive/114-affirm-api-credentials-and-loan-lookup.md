# 114 — Affirm API credentials, base URL, and loan lookup playbook

Permanent rule. Workspace-scoped. Production credentials. Re-stated per Ruben directive 2026-05-25 04:34 PT after I "forgot them" mid-task — they need to live somewhere every agent can find them without re-asking.

## Canonical credentials (production, live)

Source of truth: `/var/www/emtskills/config/config.local.php` on WOPR (already populated, do NOT rotate without coordinated change). Mirrored here for agent discoverability so no agent has to grep the server config to find them.

```
AFFIRM_API_KEY    = 09OQU2QM92IILNO6
AFFIRM_API_SECRET = Sn3yalSD4sGp51nhkG6QklDXKZ2RuAW1
```

Production base URL: `https://api.affirm.com`
NOT `api.global.affirm.com` (that hostname 404s on the list endpoints — Cloudflare-protected mirror of a different surface).

Affirm JS (for any front-end work — checkout widget): `https://cdn1.affirm.com/js/v2/affirm.js`

No sandbox/staging in use — production is the only environment.

## REST API surface

Auth: HTTP Basic, `Authorization: Basic base64(public:private)`.

### Working endpoints (smoke-tested 2026-05-25)

| Method+Path | Returns | Use |
|---|---|---|
| `GET /api/v1/transactions` | List of recent loans/charges | Ruben-canonical primary list endpoint |
| `GET /api/v2/transactions/?limit=200[&created_before=ISO8601]` | `{"transactions":[...], "has_next":bool, "has_prev":bool}`; each tx has `id, status, amount(cents), checkout_id, order_id, created, currency, amount_refunded` | Paginated list (v2) |
| `GET /api/v2/transactions/{id}` | Single tx + events | Per-row recheck |
| `GET /api/v2/checkout/{checkout_id}` | Full checkout incl. `billing.email`, `billing.name.full`, items, merchant, `merchant_external_reference` (WC order_id) | Email resolution: tx list lacks email; must hop through checkout |
| `GET /api/v1/charges/{id}` | Legacy single-charge | Used by AffirmDisputeClient |

### 404 / not available

- `GET /api/v1/charges` (list — not exposed)
- `GET /api/v2/events`

## How `Students.affirm_charge_id` maps to the API

`admin_portal.Students.affirm_charge_id varchar(100) NULL` stores the Affirm transaction id (e.g. `UDMZ-AWVG`, `8RBQ-05EH`, `CHN1-KFG5`) — the same id returned by `/api/v2/transactions/{id}`. NOT the checkout_id, NOT the WC order_id.

Current population (as of 2026-05-25): 173 Students rows have `payment_method='affirm'` OR `affirm_charge_id IS NOT NULL`.

## How to look up an Affirm loan from agent code

### Path A — already have the affirm_charge_id

```php
$auth = 'Basic ' . base64_encode(AFFIRM_API_KEY . ':' . AFFIRM_API_SECRET);
$ch = curl_init("https://api.affirm.com/api/v2/transactions/{$chargeId}");
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Authorization: ' . $auth, 'Accept: application/json'],
    CURLOPT_TIMEOUT => 15,
]);
$resp = curl_exec($ch);
$status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);
```

### Path B — only have the student email (need list+filter)

1. `GET /api/v2/transactions/?limit=200` → list, optionally paginate via `created_before=ISO8601` for older.
2. For each tx, fetch `/api/v2/checkout/{checkout_id}` and read `billing.email`.
3. Match lower-trim(billing.email) against your candidate email.

This double-hop is slow if you have many candidates. **Do NOT inline this in any cron run that holds a lock for the whole detector** — see incident 2026-05-25 04:20 PT where Section 3 of detector v3 hung 3.5min on this lookup. Either:

- Cache the (tx_id → email) map in a local table refreshed on a separate schedule, OR
- Gate the live-lookup behind a feature flag and only run it for high-confidence candidates.

## Existing helpers (current state of disk, 2026-05-25)

- `lib/AffirmDisputeClient.php` — OO REST client (HTTP Basic), `apiCall()`, `readCharge()`, `submitDisputeResponse()`. Hardcodes a mirror of `config.local.php` keys. Use this for single-charge lookups.
- `lib/affirm_payment_status_checker.php` — functional helpers. `apsc_lookup_affirm_by_loan_id()` reads `affirm_final_v6` (table does NOT exist in admin_portal today — function is dead/legacy).
- `lib/AffirmPaymentStatusChecker.php` — newer class wrapper. DB-only (reads Students.affirm_charge_id + qb_invoices, composes reply). Used by the Discord-status-checker.
- `cron/affirm_reconcile.php` — every 2h. WC-postmeta-only (scans `/var/www/vhosts/*/httpdocs/wp-config.php` for `_billing_email` postmeta). Mtime 2026-03-11. **NOT live-API mode yet.**

## Planned (in-progress, idea #6646 silent-ghost x2 as of 2026-05-25)

- `lib/AffirmLoanStatusClient.php` — thin REST wrapper to be written per handoff 8297. Will expose `lookup_affirm_loan($chargeOrEmail)` MCP tool.
- Idea #6647 — patch `cron/affirm_reconcile.php` to use live-API mode (after #6646).
- Idea #6751 — unified Affirm+Authnet+QB CS surface.

When `AffirmLoanStatusClient` lands, **prefer it over inline curl in any new code.**

## Self-check before any Affirm-related work

1. Are these creds already in `config.local.php`? Yes (verified 2026-05-25 04:34). Use them via `AFFIRM_API_KEY` / `AFFIRM_API_SECRET` constants — never hardcode.
2. Am I about to inline an Affirm REST list+checkout double-hop in a cron that holds a lock? If yes, see the perf incident above + use a feature flag default-OFF.
3. Do I have an `AffirmLoanStatusClient.php` available? If yes, use it. If not (current state), use `AffirmDisputeClient::readCharge()` for single-charge lookups; for list+match, accept the perf cost or queue async.

## Cross-references

- `.clinerules/33` — payment architecture canonical map. wpforms_payments is "paid at submit" source of truth for Authnet only; Affirm doesn't fire from WPForms.
- `.clinerules/107` — EMSU payment architecture canonical map (Authnet/QB/Affirm/attribution pipeline).
- HANDOFF_NOTES.md 2026-05-25 03:29 PT + 04:28 PT — full Affirm chain audit + detector perf incident.
- /tmp/affirm_integration_audit.md + /tmp/affirm_wire_chain_review.md on WOPR — subagent-generated deep dives.
- session_handoffs slugs: idea-6646-build-affirmloanstatusclient, idea-6647-extend-cron-affirm-reconcile-p, idea-6751-unified-payments-verification.

## Source incidents

- 2026-05-25 04:34 PT — Ruben directive: "I gave these to you already so I need you to put them in a place where you don't forget them. Perhaps this isn't an MCP somewhere I don't know I don't care but you need to not forget them you need to put them in the team section area somewhere where they could be called by all agents." This rule is the response.
- 2026-05-25 04:20 PT — detector #6824 Section 3 perf incident; rolled back. Affirm REST double-hop was the cost. Section 3 now gated behind kill-switch in /tmp/cron_authnet_paid_no_qb_detector_v3.php (staged for #6838 retry).
- 2026-05-24 (handoff 8278) — original "is Affirm API not wired in to track down student payments" question that birthed the wire chain.

## Last updated

2026-05-25 04:34 PT — initial rule (re-instated after Mac-side Rules-archive copy was missing). Source incident: Cline forgot the keys mid-task after Ruben had given them earlier. Per rule directive, this rule is the durable artifact so no future agent has to re-ask.

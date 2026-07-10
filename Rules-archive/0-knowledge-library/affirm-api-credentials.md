# Affirm BNPL Production API — Credentials Quick Card

**Canonical rule:** `.clinerules/114-affirm-api-credentials-and-loan-lookup.md` (full playbook).
**Server-side mirror:** `/var/www/emtskills/config/config.local.php` constants.
**DB vault registration:** `admin_portal.shared_credential_vault_platforms` WHERE `platform_name='Affirm BNPL Production API'`.

## Keys (production — no sandbox)

```
AFFIRM_API_KEY    = 09OQU2QM92IILNO6
AFFIRM_API_SECRET = Sn3yalSD4sGp51nhkG6QklDXKZ2RuAW1
```

## URLs

- **API Base:** `https://api.affirm.com` (NOT `api.global.affirm.com`)
- **Primary list endpoint:** `https://api.affirm.com/api/v1/transactions`
- **Affirm JS (front-end widget):** `https://cdn1.affirm.com/js/v2/affirm.js`

## Auth header

```
Authorization: Basic base64(AFFIRM_API_KEY:AFFIRM_API_SECRET)
```

## See full playbook
- `.clinerules/114` for endpoint inventory, perf incident notes, existing helpers (`AffirmDisputeClient.php`, `AffirmPaymentStatusChecker.php`), and the planned `AffirmLoanStatusClient.php` (idea #6646 in_progress).

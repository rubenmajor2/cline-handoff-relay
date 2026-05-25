# 115 — When a secret is missing, sweep WordPress plugin options BEFORE asking Ruben

Permanent rule. Workspace-scoped. Source: 2026-05-24 Affirm/Authnet session. Cline diagnosed missing `AUTHNET_API_LOGIN_ID` + `AUTHNET_TRANSACTION_KEY` in config.local.php and filed idea #6655 P0 asking Ruben to paste them. Ruben replied: *"isn't the Authorize.net login ID and transaction key located in WP forms? Why don't you store that somewhere? Literally I can just go in there and take a look but I'm just wondering why you haven't done so yourself? It's a setting in there."* The creds were in the WooCommerce Authorize.Net CIM plugin settings on emsuniversity.com WP (`woocommerce_authorize_net_cim_credit_card_settings` option). I harvested + installed + smoke-tested in 2 minutes.

## The bright-line rule

**When a required secret is a `__RUBEN_PASTE_*_HERE__` placeholder in `/var/www/emtskills/config/config.local.php` (or any equivalent), the FIRST move is a sweep of WordPress plugin options across all vhost sites. Only after that returns nothing do you ask Ruben.**

EMSU runs 100+ WordPress sites under `/var/www/vhosts/*/httpdocs/`. Many vendor plugins store their API keys in `${prefix}options` rows. Those are canonical, current, and usually already-rotated correctly because the WP plugins actively use them. Asking Ruben for a value that's sitting in a WC option is wasteful and creates friction.

## Where secrets are commonly stored

| Secret class | WP location | option_name pattern |
|---|---|---|
| Authorize.Net | WooCommerce Authnet CIM plugin | `woocommerce_authorize_net_cim_credit_card_settings` (serialized array with `api_login_id`, `api_transaction_key`) |
| Stripe | WC Stripe plugin | `woocommerce_stripe_settings`, `_wc_stripe_*` |
| Mailchimp | MC4WP plugin | `mc4wp_api_key`, `mailchimp_woocommerce_*` |
| Twilio | per-site SMS plugin | `wp_twilio_*`, `wp_sms_settings`, `*_twilio_*` |
| Facebook / Meta | FB for WooCommerce, Pixel plugins | `facebook_for_woocommerce_*`, `wc_facebook_*`, `pixel_*` |
| Google APIs | Various | `google_*`, `*_api_key`, `geolocation-google-places-api-key` |
| Postmark | Postmark for WP | `postmark_settings`, `*_postmark_*` |
| Discord | Discord notify plugin | `*_discord_*`, `*_webhook_*` |

## The canonical sweep command

```bash
for wpconf in /var/www/vhosts/*/httpdocs/wp-config.php; do
  WPCONF=$(sudo -n cat "$wpconf" 2>/dev/null)
  dbname=$(echo "$WPCONF" | grep -oP "DB_NAME[^)]+'\K[^']+" | head -1)
  dbuser=$(echo "$WPCONF" | grep -oP "DB_USER[^)]+'\K[^']+" | head -1)
  dbpass=$(echo "$WPCONF" | grep -oP "DB_PASSWORD[^)]+'\K[^']+" | head -1)
  pfx=$(echo   "$WPCONF" | grep -oP "table_prefix.*?'\K[^']+" | head -1)
  [ -z "$dbname" ] && continue
  mysql -h127.0.0.1 -u"$dbuser" -p"$dbpass" "$dbname" -N -B -e "
    SELECT '$dbname' AS site, option_name, LEFT(option_value, 600) FROM ${pfx}options
    WHERE option_name LIKE '%<KEYWORD>%' OR option_value LIKE '%<NAME-OF-FIELD>%';" 2>/dev/null
done
```

Replace `<KEYWORD>` with the integration name (e.g. `authnet`, `stripe`, `mailchimp`, `twilio`, `meta`, `facebook`). Always grep both option_name AND option_value because serialized arrays bury the secret in option_value.

## Decision tree

When config.local.php has a `__RUBEN_PASTE_X_HERE__` placeholder:

1. **Identify the integration.** What service is X for? (Authnet, Stripe, Mailchimp, etc.)
2. **Sweep WP options.** Use the canonical sweep above with the right keyword.
3. **If found:** smoke-test the credentials against the actual API before pasting into config.local.php. Confirm HTTP 200 / expected response. Document the WP source in HANDOFF so re-harvest is possible after rotation.
4. **If not found in WP:** check `.env*` files in `/var/www/emtskills/`, environment variables (`env`), Plesk vault, then ask Ruben as a last resort.
5. **Always document the canonical home** in the HANDOFF entry so future agents skip the rediscovery cost.

## Safety rules

- **Read-only against WP databases.** Never UPDATE or DELETE WP options. We're harvesting, not writing.
- **Sandbox-test before promoting.** If WP has both a sandbox `test_api_login_id` and a production `api_login_id`, use the production one ONLY if config.local.php is for production. EMSU is single-tenant production; this is almost always the right move but verify.
- **Don't re-publish secrets in chat.** When reporting back to Ruben, summarize ("found, installed, smoke-tested OK") instead of pasting the cred values into iMessage / discord / public ticket comments.
- **Smoke-test before claiming "wired."** A pasted cred that 401s is worse than a clearly-empty placeholder because it silently fails downstream MCP wrappers.

## Examples (this incident)

- `AUTHNET_API_LOGIN_ID` placeholder in config.local.php → sweep WP `LzDe7pTO_options` on emsuniversity.com → found in `woocommerce_authorize_net_cim_credit_card_settings` serialized array → smoke-test `getSettledBatchListRequest` against api.authorize.net → HTTP 200 → paste into config.local.php → done in 2 minutes.

## Cross-references

- .clinerules/114 — Affirm canonical playbook (paired rule for the parallel payment rail; keys were NOT in WP for that one because Affirm uses BusinessTrack which is a separate merchant portal)
- .clinerules/70 — Authnet exhaust pattern (THIS rule's discovery is what makes 70 actually work)
- .clinerules/107 — EMSU payment architecture canonical map
- .clinerules/92 — work at the core, not bandaids (sweeping WP IS the core fix; asking Ruben is the bandaid)
- .clinerules/29 — act-on-confidence (sweep is read-only + reversible = always ship)
- HANDOFF entry 2026-05-24 — Authnet API creds harvested from WordPress

## Last updated

2026-05-24 — initial. Source: Ruben directive during Affirm session (verbatim above). Authnet creds harvested from `LzDe7pTO_options` on emsuniversity.com WP and installed + smoke-tested. Lesson: sweep before asking.

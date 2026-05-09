# 33 — Meta (Facebook + Instagram) business app onboarding: never derive again

Permanent rule. Workspace-scoped. Source: 2026-05-09 cline_meta_m0_credentials. Took
~3.5 hours of clicking, plus 2 yolos and a verifier loop, to land EMSU's first FB/IG
agent OAuth. Most of that time was Meta UX gotchas that aren't documented anywhere
obvious. This rule encodes the playbook so the next FB/IG/WhatsApp/Threads onboarding
takes ~10 min, not half a day.

## When this rule fires

Any time we onboard a new Meta-platform integration (Facebook Page, Instagram Business
account, WhatsApp Business, Threads, Marketing API ads, etc.). Same UX traps apply
across all four surfaces because they share Meta App Dashboard + Business Manager.

## The single most important thing

**Skip the OAuth dialog. Use a System User token.** Meta's `dialog/oauth` flow on a
fresh business app fails with "this app isn't available — needs at least one supported
permission" no matter how many times you fix the perm config. It is genuinely broken
in 2026. The fix isn't to make OAuth work — it's to use the System User token path,
which bypasses the OAuth dialog entirely.

Why this works: when the business owns the assets (Page, IG, ad account), Meta lets
Business Manager admins mint never-expiring System User tokens directly. No OAuth, no
SMS verification on the System User itself, no App Review.

## The 8-step recipe (lands a working token in ~10 min)

### Pre-reqs (one-time per business, ~3 min)

1. **You must be Admin on the Meta App.** The app creator is auto-admin. To verify:
   developers.facebook.com/apps/<APP_ID>/roles/roles → "Administrator" badge.
2. **You must be Admin on the Business Manager.** Verify at business.facebook.com →
   gear icon → Business Settings → Users → People.
3. **Your personal phone in `facebook.com/settings → Mobile` must be current.** Meta
   uses this for some verification steps. If it shows an old number, update it FIRST
   before starting (set new as primary, then delete old). Don't delete old until new
   is primary or you can lose 2FA.
4. **All required perms must be `ready_for_testing` on the App Dashboard's Use Cases.**
   This is the OAuth-flow prep that's not strictly needed for System User but doesn't
   hurt and unblocks future OAuth path if needed.

### Step 1 — Create the System User

URL: https://business.facebook.com/settings/system-users

Click `+ Add` → modal:
- **Name:** `emsu page mgmt` (or similar — see name-validator gotcha below)
- **Role:** `Admin` (NOT Employee — Employee tokens cap at 60 days)
- Click `Create System User`

#### CRITICAL — Name field validator gotchas

Meta runs TWO hidden validators on the Name field that surface as ONE misleading error
("you can't use that many capital letters"):

1. **Capital letter check** — too many uppercase letters → reject
2. **Restricted words check** — words like `Admin`, `Manager`, `Mgmt`, `Owner`, `SU`,
   `Bot`, `Service` → reject

Both fail with the same "capital letters" error message. Lowercase + plain words always
passes. `emsu page mgmt` works. `EMSU Page Mgmt SU` fails (caps + Mgmt + SU). If
`emsu page mgmt` is somehow rejected, try `emsu page` or just `emsu`.

The Role dropdown is a SEPARATE field with its own validator that accepts Admin fine.
Don't confuse the two.

### Step 2 — Assign Page asset to the System User

Click into the new System User row. In the right panel:

- Click `+ Add Assets` → "Pages" tab
- Search/select the FB Page
- Toggle `Manage Page` ON (highest privilege)
- Click `Save Changes`

### Step 3 — Assign Ad Account (if running ads)

Same flow:
- Click `+ Add Assets` → "Ad Accounts" tab
- Select the ad account → toggle `Manage Ad Account` ON → Save

If you don't run ads yet, skip this step. Token still works for posting, comments, DMs.

### Step 4 — Assign Instagram (if linked to FB Page)

If `@<igusername>` IG Business is linked to the FB Page in Meta Business Suite:
- Click `+ Add Assets` → "Instagram Accounts" tab
- Select the IG Business account → toggle `Manage Instagram Account` ON → Save

If IG isn't in the modal, skip — the IG account isn't linked yet. Linking is a
separate Business Suite step (Business Suite → Settings → Instagram Linked Accounts).

### Step 5 — Add System User as ADMIN on the App

This is the gotcha that gives "No permissions available" on Generate Token if missed.

URL: https://business.facebook.com/latest/settings/apps?business_id=<BUSINESS_ID>&selected_asset_id=<APP_ID>&selected_asset_type=app

Or navigate: Business Settings → Accounts → Apps → click the app.

Then on the right panel:
- Click `Assign access` (blue button)
- Pick `System users` tab if available (may be default)
- Select the System User you just created
- Role: Admin (or "Manage app" / "Full control" — pick the highest)
- Click Save

This is the second time you're granting Admin — first was Page-level (Step 2), this is
App-level (Step 5). Both required.

### Step 6 — Generate the token

Back to https://business.facebook.com/settings/system-users → click the System User →
top-right `Generate token`.

Modal flow:
- **App:** select the right app
- **Token Expiration:** **Never** (CRITICAL — anything else gives a short-lived token)
- **Permissions:** check the perms you need from the list. For full FB+IG agent:
  - `ads_management`
  - `ads_read`
  - `business_management`
  - `instagram_basic`
  - `instagram_content_publish`
  - `instagram_manage_comments`
  - `instagram_manage_messages`
  - `pages_manage_ads`
  - `pages_manage_engagement`
  - `pages_manage_metadata`
  - `pages_manage_posts`
  - `pages_messaging`
  - `pages_read_engagement`
  - `pages_read_user_content`
  - `pages_show_list`
  - `read_insights`
- Click `Generate Token`

Modal shows the token ONCE. Format: `EAAxxxxx...` ~200+ chars starting with EAA. COPY
IMMEDIATELY. If you close without copying, revoke + regenerate (cheap — no harm).

### Step 7 — Phone verification dialog (if it appears)

Sometimes Generate Token throws a "Confirm phone number" dialog with a LOCKED field
showing whatever number is on your personal FB account. If the field shows an old
number you no longer have access to:

- Close the dialog
- Go to facebook.com/settings → Mobile → add current cell → verify with code → set
  primary → delete old
- Retry Generate Token — dialog will now show the new number

This is per-user (your personal FB), not per-business. The 800 business number is for
customer-facing display, not for Meta's verification.

### Step 8 — Write to vault + verify

Token in hand. Write to encrypted vault on EMSU server:

```bash
ssh emsuserver@76.167.100.188 -p 2222 "php -r \"
require '/var/www/emtskills/config.local.php';
require '/var/www/emtskills/lib/MetaCredentials.php';
\\\$pdo = new PDO('mysql:host=localhost;dbname=admin_portal;charset=utf8mb4','adminportal','iV84o80^y',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
\\\$v = new MetaCredentials(\\\$pdo);
\\\$id = \\\$v->upsert('emsu_main', ['page_access_token' => 'EAAxxx...', 'status' => 'active', 'expires_at' => null, 'last_refresh_error' => null]);
echo 'WROTE id=' . \\\$id . PHP_EOL;
\""
```

Then verify with debug_token + me/accounts:

```bash
TOK='EAAxxx...'
APP="<APP_ID>|<APP_SECRET>"
curl -sG "https://graph.facebook.com/v19.0/debug_token" --data-urlencode "input_token=$TOK" --data-urlencode "access_token=$APP" | python3 -m json.tool
curl -sG "https://graph.facebook.com/v19.0/me/accounts" --data-urlencode "access_token=$TOK" --data-urlencode "fields=id,name,instagram_business_account{id,username}" | python3 -m json.tool
curl -sG "https://graph.facebook.com/v19.0/<PAGE_ID>" --data-urlencode "fields=id,name,fan_count,category" --data-urlencode "access_token=$TOK" | python3 -m json.tool
```

Expected:
- debug_token: `is_valid: true`, `expires_at: 0` (never), `type: SYSTEM_USER`, scopes
  list contains all the perms you checked
- me/accounts: returns the Page row + IG business account if linked
- Page smoke: returns Page name + fan_count

Then UPDATE meta_credentials with page_name, ig_business_account_id, ig_username,
scopes_json from the responses. Close the M0 chain in session_handoffs.

## What does NOT work

These wasted hours of clicking 2026-05-09. Avoid:

1. **OAuth dialog flow** (`/dialog/oauth?client_id=...&scope=...`) — fails with "this
   app isn't available" on any new business app. Don't bother.
2. **OAuth dialog with config_id** (`/dialog/oauth?config_id=...`) — works in the
   browser-agent's smoke test but still fails for actual production OAuth callbacks
   in 2026. The config_id flow is for "Login with Facebook" SSO scenarios, not for
   token-mint on EMSU's own assets.
3. **Adding perms to the Use Cases tab without also adding them to the Business Login
   Configuration's Permissions tab** — both surfaces have to agree. Easier to just
   skip OAuth entirely.
4. **Privacy Policy URL + ToS URL fixes** — required for App Review submission, not
   needed for System User. Skip unless we ever submit for App Review.
5. **Phone verification on the business 800 number** — Meta only accepts personal
   mobile in this flow. Per-user, not per-business.
6. **System User Name with capital letters or role/title words** — see Step 1 gotchas.

## What to write in the EMSU server (durable code paths)

Already implemented (don't redo):

- `lib/MetaCredentials.php` — libsodium-encrypted vault, `upsert` / `getDecrypted` /
  `recordRefresh` methods, scopes split into dev_scopes() + advanced_scopes() + 
  required_scopes() with META_APPROVED_SCOPES override
- `routes/meta_admin.php` — admin UI to view + Reconnect (still useful for adding
  more admin-level users in the future via OAuth)
- `routes/meta_oauth_start.php` — Business Login config_id flow (feature-flagged
  fallback to legacy scope= flow)
- `routes/meta_oauth_callback.php` — exchanges code for long-lived Page token
- `api/meta_leadgen_webhook.php` — FB Lead Ads webhook receiver
- `config.local.php` — META_APP_ID, META_APP_SECRET, META_WEBHOOK_VERIFY_TOKEN,
  META_APPROVED_SCOPES, META_BUSINESS_LOGIN_CONFIG_ID

## Token rotation

System User tokens never expire, but if you need to rotate (security review,
compromise, etc.):
1. business.facebook.com/settings/system-users → click the System User → Revoke tokens
2. Generate New Token (same flow as Step 6)
3. Run Step 8 to write the new token to vault

The old token gets invalidated server-side by Meta within seconds of revoke. Vault
write replaces the encrypted blob immediately.

## When to fall back to OAuth dialog

The System User path covers 99% of EMSU's needs (we own the Page + IG + ad accounts).
The OAuth dialog flow is only needed if:

- We want to act on a Page/IG owned by a third party (e.g. another business hires us
  to manage their FB)
- We need user-attribution-grade audit trail (System User shows up as "EMSU Page Mgmt"
  in Page audit logs, not "Ruben Major")

Both rare. If they come up, see meta-m0-credentials-oauth chain history for the
patches we landed (config_id flow, Privacy URL, App Review submission steps). But
default to System User.

## Cross-references

- `lib/MetaCredentials.php` — vault implementation
- `~/Desktop/META_*.md` files — the diagnostic trail from 2026-05-09 (preserve for
  archaeology, but this rule supersedes them)
- `session_handoffs.slug='meta-m0-credentials-oauth'` — chain that landed M0 on 2026-05-09
- `orchestrator_ideas` #917 (FB) + #918 (IG) — the marketing agent product concept

## Last updated

2026-05-09 — initial rule. Source: cline_meta_m0_credentials, completing M0 OAuth/
credentials chain for EMSU FB Page (id 183356331739746, 66.5K followers) + IG Business
(emsuniversityllc, id 17841408283819351). System User token written to vault, never
expires, all 16 FB+IG scopes granted. Dispatcher unblocked M1-M7 chains.

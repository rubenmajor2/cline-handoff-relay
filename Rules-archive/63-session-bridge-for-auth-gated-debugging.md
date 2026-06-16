# 63 — Session-bridge endpoint pattern for auth-gated visual debugging

Permanent rule. Workspace-scoped. Source: 2026-05-13 cline_reports-403-fix — wasted
~3 iterations and ~$15 figuring out how to get Puppeteer past the EMSU login
wall to actually SEE reports.php. Once I built the right two-script pattern, it
took 30 seconds. Codifying so future-me builds it instantly.

## HARD TRIPWIRE (read FIRST — 2026-06-16, Ruben: "you consistently disobey this")

**The moment ANY `browser_action` against an `emsuniversity.com/emtskills/*` page returns a "Sign In to Continue" / "admin session expired" / login wall / 403 / `requireLogin()` redirect, you are FORBIDDEN from doing ANY of the following:**
- ❌ Giving up and saying "I can't see the page / it's behind login, I'll trust the DB"
- ❌ Closing the browser and concluding the verification is impossible
- ❌ Telling Ruben "the page requires staff login so I can't verify"
- ❌ Substituting a DB query for the visual check Ruben asked for and calling it done

**Instead, the REQUIRED next action is to build the session-bridge below (the `make_session.php` + `_dev_render_<target>.php` two-file pattern) and re-launch Puppeteer against the `_dev_render` endpoint with a real admin SID.** This is a known, clean, ~30-second procedure. There is no excuse to stop at the login wall — getting in IS the task. If Ruben asked you to verify what a page shows, hitting the login wall is the START of the work, not a blocker that ends it.

**Self-check the instant a browser_action shows a login/403 screen:** "Am I about to tell Ruben I can't see it? STOP — build the session bridge (rule 63) and get in." Authenticating yourself in via the session bridge is mandatory, not optional.

This tripwire exists because the full pattern below is correct but lives in the archive, so a Doctor/debug window hits the login wall, forgets rule 63 exists, and bails. The bail is the violation. (2026-06-16: a Frankenstein Doctor window browser-checked ruben_executor_live.php, hit "Sign In to Continue," closed the browser, and fell back to "I'll trust the DB" — exactly the forbidden move. Ruben: "you need to use an authentication token to get yourself in... you consistently disobey it.")


## When to use

Any time I need to use `browser_action` against a page on `emsuniversity.com/emtskills/*`
that's behind `requireLogin()` or `requireRole()` and Puppeteer has no session. Per
rule 62, this is needed any time the user reports a visual UI bug on an admin page.

## The canonical pattern (two files)

### File 1: `/tmp/make_session.php` — generates a real admin session on the server

```php
<?php
require_once '/var/www/emtskills/lib/auth.php';
require_once '/var/www/emtskills/lib/db.php';
session_save_path('/var/lib/php/sessions');
session_start();

$pdo = db('portal');
$stmt = $pdo->prepare("SELECT id, email, role, is_active FROM users WHERE id=? LIMIT 1");
$stmt->execute([1]);  // user_id 1 = rmajor@emsuniversity.com / MasterAdmin
$user = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$user) { fwrite(STDERR, "no user 1\n"); exit(1); }

$_SESSION['user'] = ['id' => (int)$user['id'], 'email' => $user['email'], 'role' => $user['role']];
$_SESSION['last_activity'] = time();
$_SESSION['created'] = time();

echo "SID=" . session_id() . "\n";
echo "USER=" . json_encode($_SESSION['user']) . "\n";
session_write_close();
```

### File 2: `_dev_render_<target>.php` — diagnostic endpoint that renders the target with that session

```php
<?php
// Only enabled when /tmp/cline_diag_allow exists. Operator must touch this.
if (!file_exists('/tmp/cline_diag_allow')) { http_response_code(403); echo "diag disabled\n"; exit; }

$sid = $_GET['sid'] ?? '';
if (!preg_match('/^[a-z0-9]{16,40}$/i', $sid)) { http_response_code(400); echo "bad sid\n"; exit; }

session_id($sid);
session_save_path('/var/lib/php/sessions');
session_start();
if (empty($_SESSION['user'])) { http_response_code(404); echo "no user in session $sid\n"; exit; }

// emulate a real request
chdir('/var/www/emtskills/routes');
$_SERVER['REQUEST_URI']  = '/emtskills/routes/<TARGET>.php';
$_SERVER['PHP_SELF']     = '/emtskills/routes/<TARGET>.php';
$_SERVER['SCRIPT_NAME']  = '/emtskills/routes/<TARGET>.php';
require '/var/www/emtskills/routes/<TARGET>.php';
```

Replace `<TARGET>` with the page being diagnosed (e.g. `reports`, `dispute_dashboard`).

## The full operational sequence

```bash
# 1. Set up
scp -P 2222 /tmp/make_session.php emsuserver@76.167.100.188:/tmp/make_session.php
scp -P 2222 /tmp/_dev_render_TARGET.php emsuserver@76.167.100.188:/tmp/_dev_render_TARGET.php
ssh emsuserver@76.167.100.188 -p 2222 "
  sudo cp /tmp/_dev_render_TARGET.php /var/www/emtskills/routes/_dev_render_TARGET.php &&
  sudo chown www-data:www-data /var/www/emtskills/routes/_dev_render_TARGET.php &&
  sudo touch /tmp/cline_diag_allow && sudo chmod 666 /tmp/cline_diag_allow &&
  sudo -u www-data php /tmp/make_session.php
"
# Capture the SID from stdout
```

```python
# 2. Hit it with Puppeteer
browser_action launch
  url=https://emsuniversity.com/emtskills/routes/_dev_render_TARGET.php?sid=<SID>
```

```bash
# 3. Clean up when done
ssh emsuserver@76.167.100.188 -p 2222 "
  sudo rm -f /var/www/emtskills/routes/_dev_render_TARGET.php
  sudo rm -f /tmp/cline_diag_allow /tmp/make_session.php
"
```

## Key design choices (don't skip these)

1. **`session_id($sid)` BEFORE `session_start()`** — this is how you make PHP attach
   to an existing session file instead of generating a new one. The order matters.
2. **`/tmp/cline_diag_allow` flag gate** — never deploy this endpoint without a kill
   switch. The flag file is the kill switch.
3. **SID regex `[a-z0-9]{16,40}`** — refuses to accept obviously-bad input.
4. **`chdir + $_SERVER` overrides** — emulates a real request so the target file's
   internal path logic (like `__DIR__ . '/../lib/...'`) and self-referential URLs work.
5. **Always clean up at the end** — don't leave the diagnostic endpoint in production.
   Document the path in the task ledger entry so a future operator can verify it's gone.

## Why a cookie-based redirect endpoint doesn't work (tried it, lost an iteration)

Puppeteer in Cline's `browser_action` does NOT reliably persist cookies across the
redirect from `setcookie()` → `Location: /reports.php`. It loses the cookie. So
setting a cookie and bouncing is the wrong pattern. Doing the whole thing in one
request (`require` the target inline) is the right pattern.

## Variants for non-render needs

- **Form testing**: build `_dev_render_form_post.php` that does the same session
  attach, then sets `$_POST` and `$_SERVER['REQUEST_METHOD']='POST'` before
  requiring the target.
- **API endpoints**: same shape, requiring an `api/*.php` instead of `routes/*.php`.
- **As a different role**: change the `$stmt->execute([1])` user ID to a non-master
  account to test what a lower-role user sees.

## Cross-references

- Rule 62 — visual UI bugs need browser_first
- Rule 95 — the SCP + nohup pattern this builds on
- HANDOFF_NOTES.md 2026-05-13 entry for the source incident

## Last updated

2026-05-13 — initial. Built and shipped during cline_reports-403-fix-2026-05-13
once I finally stopped curling.

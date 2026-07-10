# Rule 16925 — MetaCredentials Key Migration Pattern (#16818 root cause)

Source: #16818 — 2026-07-09 META_VAULT_KEY decrypt investigation
Last updated: 2026-07-09 18:47 PT

## What happened
- Meta OAuth credentials were encrypted in May 2026, before META_VAULT_KEY existed
- MetaCredentials.php fell back to ANTHROPIC_API_KEY for encryption
- 2026-07-08: META_VAULT_KEY was added to config.local.php (line 456) — a different key
- Once defined, META_VAULT_KEY took precedence — decrypt failed on all 3 accounts

## Finding the real key
1. Try ANTHROPIC_API_KEY (config.local.php ~line 316) as fallback
2. deriveFallbackKey() computes key from ANTHROPIC_API_KEY
3. Key derivation: hash('sha256', 'emsu-meta-vault-v1|' . rawKey, true)

## The fix (deployed 2026-07-09)
- decrypt(): tries primary key first; falls back to deriveFallbackKey(); returns plaintext
- decryptAndMigrate(): decrypts then re-encrypts with primary key + persists to DB

## Key locations on WOPR
| Key | File | Line | Status |
|---|---|---|---|
| META_VAULT_KEY | config.local.php | 456 | Added 2026-07-08 (64-char hex) |
| ANTHROPIC_API_KEY | config.local.php | ~316 | Original fallback (108 chars) |
| META_VAULT_KEY env | Not set | N/A | getenv returns false |

## DO NOT
- Claim stored creds are "unrecoverable" without trying ANTHROPIC_API_KEY fallback
- Route to human for OAuth re-run before testing decryptAndMigrate()
- Remove the ANTHROPIC_API_KEY fallback from deriveFallbackKey()
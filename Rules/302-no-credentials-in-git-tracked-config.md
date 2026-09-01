# Rule 302 — No Credentials in Git-Tracked Config

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS**
**Created: 2026-08-11**

## Core Principle

Credentials (API keys, tokens, secrets, passwords, auth tokens, webhook signing secrets, database passwords) MUST NEVER be stored as plaintext strings in any git-tracked file. The Postmark spam incident of 2026-08-10 occurred because the Postmark server token was committed as a bare string in `config/config.local.php`, a git-tracked file. A threat actor discovered the token and used it to send ~119.5K spam messages through the EMSU Postmark account.

Every credential MUST live in exactly one of three approved locations, checked in this order:
1. A gitignored secrets file (e.g., `config/secrets.php`)
2. An environment variable read via `getenv()` or `env()` at runtime, with a fallback ONLY to a clearly-marked placeholder
3. A dedicated vault/secrets-manager path with zero git exposure

If a credential reference appears in a git-tracked file, it MUST be a constant name (e.g., `POSTMARK_ACCOUNT_TOKEN`), a `getenv()` call with fallback to a placeholder string like `'__RUBEN_PASTE_...__'`, or a `require_once` of the gitignored secrets file. NEVER a bare string that equals the credential value.

## Violations are diagnosed as:
1. A `define('SOME_SECRET', 'actual-value')` in any file not listed in `.gitignore`
2. A database password, API key, or token stored as a bare string in any returned config array
3. A credential value committed to git that was rotated from a live service
4. A placeholder `__RUBEN_PASTE_...__` that was accidentally committed with the real value instead

## Mandatory behavior:
- Before writing ANY credential (key, token, secret, password) to a file, the window MUST check whether that file is git-tracked (`git ls-files FILEPATH` or equivalent). If tracked, the write is forbidden. Use the gitignored secrets file or env vars instead.
- When rotating a credential exposed in git, the window MUST (a) rotate the credential at the provider, (b) place the new value in the gitignored secrets file, (c) replace all bare-string references in tracked files with the constant name, and (d) verify zero raw hits via `grep -rn 'VALUE' --include='*.php' --exclude-dir=vendor --exclude='*.bak*'`
- A file containing credentials MUST be listed in `.gitignore` AND must never have been committed. If it was previously committed, `git rm --cached` it AND rotate the credential.
- Database password arrays in config files are covered by this rule; they belong in the secrets file or env vars.

## Relationship to other rules:
- Complements Rule 144 (no write_to_file on server paths) — the credential write destination must pass both 144 and 302 gates
- Complements Rule 300 (end-to-end delivery) — a credential sweep is not complete until grep returns zero hits outside the secrets file
- Postmark incident #297 root-cause class; this rule is the causal fix preventing recurrence

## Enforcement:
- Any new `define()` or config array entry containing a live credential string (not a placeholder) in a git-tracked file is a direct violation
- Pre-deploy grep audit can flag violations; HARD-FLOOR means the deployment is blocked until cleaned
- Reindex/restart is not required; this file is always-loaded via the hardfloor manifest

## Regulator-response discipline (from 5 amendments, trail in Rules-archive/302-case-law.md)

The TDSHS reversal cluster (2026-08-17 through 2026-08-19) appended five amendments
here; they are archived for size, distilled below. Before ANY regulator filing
(TDSHS/AZDHS/BPPE/CAPCE):

1. **Answer the allegation actually made and nothing else.** Before including any
   paragraph, name the sentence in the complaint it responds to; if no such sentence
   exists, delete it. "For completeness" is the tell of a volunteered subject.
2. **Dissect, don't reconstruct.** Quote the allegation, split it into elements; for
   each, ask what provision it cites (if none, say so) and answer ONLY that element.
   Where it lacks a date/act/party, say it is not sufficiently particular — the
   burden of particularizing is the agency's, not ours.
3. **Never argue a negative about the regulatory landscape.** Do not characterize
   what an authority does/doesn't contain, enumerate what is absent, or invite the
   agency to identify a provision. State only the notice objection. Read BOTH the
   agency's authority and the program's own catalog/syllabus/self-study first.
4. **Aggregate claims about the agency use the agency's own dated artifacts**
   (send timestamps, letter dates, docket entries) — NEVER our internal row-creation
   dates. One false verifiable date destroys the whole argument's credibility.
5. **Section headings in neutral record vocabulary** ("The Program Record",
   "Present Status") — never quote, paraphrase, or echo allegation language.

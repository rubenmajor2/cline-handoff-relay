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
## Amendment (from reversal, 2026-08-17 22:28 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: scope error
- Trigger pattern: Arguing to a regulator that no standard exists, without first reading the program's own catalog/syllabus/self-study/student disclosures for a self-imposed standard the agency could substitute
- Reversal note: TDSHS packet argued that Chapter 157 does not prescribe an externship interval and invited the Department to identify a provision that does. Ruben flagged the exposure: a filing that argues no external standard exists invites the agency to hold the licensee to its OWN published standards instead, and the program had not read its catalog, syllabus, self-study or signed student disclosures to know what timelines they state. Amendment: in any regulator filing, do NOT characterise what an authority does or does not contain, do NOT enumerate what is absent from it, and do NOT invite the agency to identify a provision. State only the notice objection: a licensee is entitled to know the provision it is measured against, and the burden of identifying it rests with the agency. A negative claim about the regulatory landscape is a claim like any other and requires reading BOTH the agency's authority and the program's own published documents first.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 23:59 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: scope error
- Trigger pattern: Including a defense on a subject the complaint never raised, justified as completeness or pre-emption
- Reversal note: The TDSHS response to control 1080261886 carried a paragraph explaining that no externship placement request existed for the student, framed as being "for completeness." The complaint makes no externship allegation at all; it alleges wrong-dated-class enrollment and a first-week lockout. Ruben: "if the complaint says nothing about externships in 886 then no need to mention it." Volunteering a defense to an uncharged subject puts that subject in the agency's file, invites follow-up on it, and signals that the licensee considers it live. Amendment: a regulator filing answers the allegation actually made and nothing else. Before including any paragraph, name the sentence in the complaint document it responds to; if no such sentence exists, delete the paragraph. This applies to favorable facts as much as unfavorable ones, since a volunteered subject is a volunteered subject regardless of which way it cuts. "For completeness" and "so the Department is not left to infer" are the tells that a

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

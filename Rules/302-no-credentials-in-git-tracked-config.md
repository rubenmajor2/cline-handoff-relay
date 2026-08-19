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

## Amendment (from reversal, 2026-08-18 01:14 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: scope error
- Trigger pattern: Answering a vague regulator allegation with an exhaustive internal reconstruction instead of dissecting it element by element and naming what the agency must particularise
- Reversal note: Given a two-sentence, dateless complaint alleging wrong-class enrollment and a first-week lockout, I built a 5,000-character evidentiary answer volunteering an internal activity name, a completion gap, our own imperfect sweeps, and a self-blame narrative. Ruben: "you didn't dissect the complaint properly ... it doesn't require the degree of information that you required because it was not asked for ... we need to get more information from the state in order to properly respond. That is on them to provide to us not us to even ask for." Amendment, a COMPLAINT DISSECTION method to run before drafting any regulator response: (1) quote the allegation and split it into its discrete elements; (2) for each element ask what provision it is said to violate, and if the letter does not name one, say so; (3) for each element ask what the record shows and answer ONLY that element; (4) where the allegation lacks a date, an act, or a party, state that it is not sufficiently particular to answer and id

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 05:20 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: unread source
- Trigger pattern: Computing an aggregate/pattern claim about an external party's conduct from internal row-creation timestamps instead of the party's own dated artifacts
- Reversal note: The TDSHS packet's aggregate-burden section asserted to a regulator that "the Department opened eleven separate complaint matters ... on a single day." The email_inbound_log shows four distinct transmittal dates: 7/16 (1810, 1811, 1813, 1815), 7/27 (1815, 1887, 1869), 8/3 (1915, 1890), 8/5 (1916, 1917, 1886). The claim was built from the compliance_deadlines row-creation date (all rows created 2026-08-05, the day WE catalogued them) rather than from the agency's own send timestamps. Amendment: any aggregate or pattern claim made TO an agency about that agency's conduct must be computed from the agency's own dated artifacts (email send timestamps, letter dates, docket entries), never from our internal row-creation or ingest dates. Our created_at records when we noticed a thing, not when the agency did it. A single false verifiable date in a burden argument destroys the credibility of the entire argument, because the agency holds the authoritative copy of its own send log and will check 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 22:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787123639000
- RCA bucket: wrong premise
- Trigger pattern: Drafting regulator-response section headings that restate or echo the charged allegation language instead of neutral record vocabulary
- Reversal note: TDSHS 810/811: a draft response used section headings that restated the allegations in the program's own voice ("Ability to reach a person", "Information from the automated assistant", "Follow-up on tickets"). A heading that names the allegation advertises it: the reader scans the heading list and reads the program's response outline as a catalogue of accusations. Amendment: regulator-response section headings must be NEUTRAL record-vocabulary ("The Program Record", "Present Status", "Complainant of Record") and must never quote, paraphrase, or echo the allegation language; the allegation is answered in body text that states record facts, never named in a heading.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

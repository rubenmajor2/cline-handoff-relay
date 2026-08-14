# 320 — Automated adjudication fails CLOSED. A verdict nothing produced is never written.

**Applies:** any code path where a machine writes a finding, recommendation, verdict,
status, or disposition that affects a person (student, employee, applicant), especially
grievances, dismissals, refunds, suspensions, and anything a regulator could later read.

**Source incident:** 2026-08-13 grievance-clock investigation. One recurring cron error
opened onto three distinct defects in the same family, described below. Bug library
#2337, #2338, #2339. Ideas #26205, #26207, #26208, #26210.

## The three gates

### Gate 1 — Failure to EVALUATE is not a finding of DEFICIENCY

When an evaluation throws, the result is *unknown*, not *adverse*. Never push an
infrastructure error token into the same array the caller reads as substantive findings.

```php
// WRONG — the caller cannot tell our outage from the subject's defect
} catch (PDOException $e) {
    $result['failures'][] = 'database_error';
}

// RIGHT — carry the distinction, and gate the consequence on it
} catch (PDOException $e) {
    $result['infra_error'] = true;
    $result['failures'][] = 'database_error';
}
// ...and at the top of the action that has the consequence:
if (strpos($failures, 'database_error') !== false) {
    logMessage("[INFRA-BLOCK] not dismissed: internal fault, says nothing about the filing");
    return false;
}
```

**The test, before writing any adverse outcome:** *does every element of the evidence
that justifies this outcome describe the SUBJECT, or does some of it describe MY OWN
system?* Any element in the second category disqualifies the automated action.

What this looked like live: `cron_grievance_admin_completeness.php` read two tables that
do not exist, so every grievance evaluated to `database_error`, which the caller treated
as "form deficient" and routed to `autoDismissGrievance()` — status `admin_dismissed`
plus a rejection email to the student. The only thing preventing wrongful dismissals was
a *second* bug (an `audit_log` INSERT naming columns that do not exist) whose exception
rolled back the dismissal transaction. **Two bugs cancelling out is not a safety
mechanism.** Fixing either one alone would have armed the other.

### Gate 2 — A stub must fail closed, never return a plausible answer

A function that cannot do its job returns an error. It does not return the answer that
would have been convenient.

```php
// WRONG — ships, looks fine, writes fiction onto a person's record
function callVisionModel(string $model, string $prompt): array {
    // Simulated call. In production, integrate with Frankenstein-LLM API.
    return ['recommendation' => 'complete', 'reason' => 'All required fields are present.'];
}

// RIGHT
function callVisionModel(string $model, string $prompt): array {
    error_log('callVisionModel is not implemented; refusing to fabricate a verdict');
    return ['recommendation' => null, 'error' => 'model not wired'];
}
```

Two independent copies of exactly the wrong version were live and had stamped a verdict
onto seven student grievances. Those values then satisfied the downstream confidence
branch that selects a disposition.

**Detector — use this on any AI-written column, it needs no code reading:**

```sql
SELECT <rationale_col>, <written_at_col>, COUNT(*)
FROM <table> GROUP BY 1, 2 HAVING COUNT(*) > 1;
```

N identical rationales sharing one timestamp is fabrication, not analysis. A real
per-document model read cannot produce byte-identical prose for different documents in
the same second. (Live: 7 rows, same string, all at `2026-07-28 12:50:42`.)

**When you find fabricated values already on records:** patching the source is half the
job. Write a provenance note to the record's history table saying what the stored value
is, that no model produced it, and whether any decision actually relied on it. The
records outlive the bug, and someone will read them later believing a machine evaluated
them.

### Gate 3 — Instrumentation never shares a try block with the work it measures

A counter that measures the work must not be able to prevent the work.

```php
// WRONG — a metric query inside the transaction's try block
try {
    $ok = $this->advance($id);              // the actual work
    $metric = $pdo->query("SELECT COUNT(*) ...");  // throws -> advance() is aborted
} catch (Throwable $e) { ... }

// RIGHT — the metric owns its own failure
try { $metric = $pdo->query("..."); } catch (Throwable $e) { error_log(...); }
```

Live: a `policy_context_present` counter in `cron_grievance_disposition_clock.php`
selected a column that has never existed. Because it sat inside the per-record try
block, the exception aborted the *advancement* — grievances were silently frozen at
`pending_admin_complete` for ten days while the cron logged the same SQL error every
fifteen minutes.

## Two smells that predict this whole family

1. **A cron that logs the same error every run.** Ten days of identical fifteen-minute
   log lines and nobody read one. If you are looking at a cron, `tail` its log and check
   whether the last N entries are the same string.
2. **Errors swallowed into a JSON `errors[]` array or `error_log`.** Every defect here
   was "handled" — that is exactly why none surfaced. An error that is caught and
   summarized into a field nobody reads is invisible.

## Self-check before shipping any automated decision path

1. Can an exception from MY system produce an adverse outcome for the subject? → Gate 1.
2. Does every function in this path actually do the thing its name says? → Gate 2.
3. Is any query in the transaction's try block there only to count something? → Gate 3.
4. If this runs on a timer, will a persistent failure be *visible* to a human, or only
   logged?

## Cross-references

- Rule 29 — agents act on confidence tier (a fabricated verdict is negative confidence)
- Rule 263 — verify before claim
- Rule 281 — schema-truth gate (`DESCRIBE` before you trust a column name)
- Rule 297 — classify before alarming; RCA must fix the causal rule
- Rule 302 — regulator-response doctrine (these records become regulator-facing)
- Rule 146 — frankenstein-llm is the one router; never hardcode a vendor model id
  (`determineVisionModel()` returned the literal string `'sonnet-5-vision'`)

## Last updated

2026-08-13 — initial. Source: grievance disposition-clock investigation; six phantom
schema identifiers, two fabrication stubs, one fail-open dismissal path.

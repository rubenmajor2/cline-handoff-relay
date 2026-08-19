# Rule 323 — Bug Library Research: Dynamic Search + Community Search in Failure/Retry

**Severity: HARD-FLOOR for failure diagnosis**
**Created: 2026-08-19 (Ruben directive: "cline rule proposed on how to research the bug library using the process i recommended (dynamic search + community search) as part of the failure/retry process")**
**Cross-refs: Rule 156 (bug library check before fix), Rule 262 (2-strike tripwire), Rule 297 (classify before diagnosing), Rule 305 (multi-angle sweep)**

## Core principle

When a failure occurs, the bug library is the FIRST research stop — but only if you
search it correctly. A single keyword grep misses 80% of relevant incidents because
the same failure gets described in different words. This rule mandates the
**dynamic search + community search** process Ruben recommended.

## The 2-strike tripwire (when this fires)

**After 2 consecutive failures of the same tool/command/query type, STOP retrying.**
The next action MUST be bug library research using this process. A 3rd retry of the
same shape without research is a rule violation.

## PART 1: Dynamic search (the library itself)

**Dynamic = multiple angles, not one keyword.** The same incident gets described as:
- "empty unparsable response"
- "garbage 200"
- "router returned nothing"
- "completion missing"

One keyword misses the others. Run AT LEAST 3 search angles:

### Angle 1: Symptom keywords
```
bug_library_search(symptom="<the error message or visible symptom>")
```
Use the EXACT error text first, then paraphrase.

### Angle 2: Component keywords
```
bug_library_search(symptom="<component> <failure mode>")
```
Examples: "router timeout", "adapter empty", "ring NCCL", "tunnel refused"

### Angle 3: Domain browse
```
bug_library_browse(domain="<relevant domain>")
```
Domains: agent-execution, routing-infrastructure, model-instance, infrastructure,
student-ops, voice-telephony, training-llm, payment-finance

### Angle 4: The check-before-fix gate (MANDATORY)
```
bug_library_check_before_fix(symptom="<1-3 sentence symptom description>")
```
Returns KNOWN_REPAIR (apply the recorded resolution) or NOVEL_SYMPTOM (proceed to
community search). This opens the session gate for any routing-fix tools.

## PART 2: Community search (outside the library)

**The library only contains what WE have seen.** For novel symptoms, search the
community before inventing a diagnosis:

### GitHub issues
```
search_code(q="<error message or component> repo:<relevant repo>")
```
Or use brave_web_search:
```
brave_web_search(query="<error message> site:github.com")
```

### Stack Overflow / forums
```
brave_web_search(query="<error message> site:stackoverflow.com")
```

### Vendor docs / known issues
```
brave_web_search(query="<component> <version> known issues <symptom>")
```

### The 3-source minimum
For any novel failure, consult AT LEAST 3 sources before diagnosing:
1. Bug library (all 4 angles above)
2. GitHub issues for the component
3. One community source (Stack Overflow, vendor docs, forums)

## PART 3: The research output format

After research, state:
1. **Library match found?** YES (incident #, resolution) / NO (novel)
2. **Community match found?** YES (source, link/summary) / NO
3. **Classification per rule 297:** by-design / transient / real bug / unknown
4. **Next action:** apply known repair / implement community fix / diagnose novel

## PART 4: Recording novel findings

If the failure is NOVEL and you diagnose it:
```
bug_library_record(
  symptom="<1-3 sentences>",
  diagnosis="<root cause>",
  resolution="<steps taken or recommended>",
  evidence="<log lines, probe output>",
  status="resolved" or "open"
)
```

**Keyword-rich recording (rule 305):** Include ALL the words a future searcher might
use. "empty response" AND "garbage 200" AND "router returned nothing" if they all
describe the same thing. The record is only useful if future searches find it.

## PART 5: Integration with retry logic

**The failure/retry loop becomes:**

```
Attempt 1 fails → retry once (transient?)
Attempt 2 fails (same shape) → STOP
  → bug_library_check_before_fix (gate)
  → dynamic search (4 angles)
  → community search (3 sources)
  → classify per rule 297
  → apply known repair OR implement community fix OR diagnose novel
  → record if novel
Attempt 3+ only after research complete
```

**Banned:** 3+ retries of the same command shape without research. That's not
persistence, that's burning tokens on a solved problem.

## Source incidents
- 2026-08-19: Ruben directive for this rule
- 2026-08-08: Rule 305 multi-angle sweep added after single-keyword misses
- 2026-06-20: Rule 262 2-strike tripwire after repeated same-shape retries

## Last updated
2026-08-19 — initial, per Ruben directive.
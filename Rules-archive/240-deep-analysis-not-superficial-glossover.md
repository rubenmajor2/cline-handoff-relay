# 161 — Deep analysis, not superficial glossover: applies to ANY investigation/debugging/status task

Source: 2026-06-18 Round 4 Frankenstein stress test. Ruben caught the agent doing superficial "is it alive / is it green" heartbeat checks for 60+ minutes while a 26% error rate and 2-hour completion times went undiagnosed. Ruben: "No you just did a superficial glossover. You didn't actually look." Then: "can you apply something like this widely?" -- YES. This rule generalizes the lesson beyond Doctor sessions to ALL analysis work.

## The bright-line rule

**When asked "what's going on with X" / "analyze X" / "why is X slow/broken/failing" -- the answer MUST be a root-cause diagnosis with evidence, NOT a surface status report.**

Surface status = counting, "is it up," "X are alive," HTTP 200s, "load is N." Deep analysis = WHY it's behaving that way, classified by category, with per-item breakdown and a bandaid-vs-core-fix judgment.

The agent that answers "12 things are running, all green" when asked to analyze a problem has not analyzed anything. It has counted.

## The deep analysis checklist (run for ANY investigation task)

When investigating a problem (slow system, failing pipeline, stuck process, degraded service, anomaly), the answer must address:

1. **Distribution, not just totals.** Don't say "26% error rate." Say "26% error rate, but it's BIMODAL: 0% on simple cases, 80% on complex cases." Averages hide the real story. Break the population into groups and show how each behaves.

2. **Classification, not just counts.** Don't say "48 errors." Say "48 errors = 17% no-tool-use + 8% legitimate failures + 4% garbage args." Different error types have different root causes and different fixes. A raw count is useless for diagnosis.

3. **Per-item breakdown.** Don't say "windows are slow." Say "conv_A: 28% error rate, 106s avg gap; conv_B: 0% error rate, 8s gap." Identify WHICH items are the problem and how they differ from the healthy ones.

4. **Root cause classification.** Is the problem (a) the component itself (model quality, code bug), (b) saturation/load, (c) a config/wiring issue, (d) an upstream dependency, or (e) data/input? Name the actual mechanism, not the symptom.

5. **Bandaid vs core fix.** Per rule 92: is the proposed fix treating the symptom (restart the service, retry, increase a timeout) or the disease (fix the model, fix the code, fix the wiring)? Say which. A bandaid that "makes it work for now" is not a fix -- name the core fix even if the bandaid is the interim step.

6. **Trend, not snapshot.** Per rule 29 Q#7: is this getting better or worse over time? A single reading is misleading. Compare before/after, or over a time window.

## What counts as "superficial" (banned as the ONLY answer to an analysis request)

- "It's up / all green / N alive" -- a liveness count, not a diagnosis
- "HTTP 200" / "service active" -- service-alive checks miss quality/behavior issues
- "Load is 6.4" / "N items in queue" -- a metric without interpretation
- "Looks fine" / "seems healthy" -- no evidence
- A single aggregate number ("26% error rate") with no breakdown

These are FINE as supporting data. They are NOT a complete answer to "analyze this" or "what's going on."

## The methodology (how to actually do deep analysis)

1. **Pull the raw data, not the summary.** Get the per-item records (audit log rows, individual error messages, per-conversation turns), not just the aggregate count.
2. **Group and classify.** Bucket the data by type, by outcome, by severity. Compute per-group rates.
3. **Find the outliers.** Which items are worst? Which are best? What's different between them?
4. **Form a hypothesis about the mechanism.** Why would the worst items behave that way? Test it against the data.
5. **Distinguish correlation from cause.** "Large context = high errors" might be wrong if some large-context items are clean. Dig until you find the real driver (e.g. error accumulation, not size).
6. **Name the core fix.** What change would actually eliminate the root cause, not just mask it?

## When the answer reveals a separate task

If the deep analysis uncovers something that needs its own window/effort (a broken pipeline, a config fix, a code change), produce a spawn-window prompt per rule 91 addendum (context transfer + priority directive + evidence package + verification criteria + cross-ref to parent). Don't bury the finding in prose -- make it actionable.

## The self-check before answering any "analyze X" / "what's going on" request

1. *Did I report WHY, or just WHAT?* If only counts/status, I haven't analyzed.
2. *Did I break the population into groups, or give one average?* Averages hide the story.
3. *Did I classify the errors/symptoms by type?* Raw counts don't diagnose.
4. *Did I name the root cause mechanism, not just the symptom?*
5. *Did I distinguish bandaid from core fix?*
6. *Would Ruben say "you didn't actually look"?* If maybe -- look deeper.

## Source incident

2026-06-18 Round 4 stress test. Agent spent 60+ min reporting "3 alive, fleet GREEN, C:200 A:200" while windows took 2 hours to complete tasks Claude does in 15-30 min. Only when forced to "actually look" did the agent find: 26.4% error rate, bimodal distribution (0% simple / 80% complex), death spiral mechanism (error accumulation), model-quality root cause (not fleet health), and a broken training pipeline. Ruben: "can you apply something like this widely?" This rule is the general-purpose answer.

## Cross-references

- Rule 158 addendum -- the Doctor-session-specific version of this (deep analysis during babysitting)
- Rule 91 addendum -- spawn-window prompts (when analysis reveals a separate task)
- Rule 92 -- work at the core, not bandaids (the fix-classification half of this rule)
- Rule 29 Q#5/Q#7 -- verification by re-running the failing case + trend not snapshot
- Rule 140 -- prove claims with live evidence, not file-reads (the evidence half)

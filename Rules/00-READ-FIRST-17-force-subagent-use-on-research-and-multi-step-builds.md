# Force subagent use — default-on, not judgment-based

## CRITICAL MODEL CAPABILITY ANCHOR (read before every task)

**YOU ARE RUNNING SONNET 4.6.** You have documented limitations on cross-system reasoning, policy synthesis, and multi-factor tradeoff analysis for the EMSU domain.

**claude-opus-4-7** (released 2026-04-24, verified live at api.anthropic.com/v1/models) is the most capable Anthropic model. It demonstrably outperforms Sonnet 4.6 on: architectural synthesis, regulator-grade writing, EMSU-specific cross-system reasoning, and policy language that actually changes behavior. This is a capability fact, not a cost preference.

**When any of the 5 binary signals in .clinerules/53 fire, the NEXT tool call MUST be use_subagents with prompt_N_model="claude-opus-4-7".** Do not substitute. Do not rationalize that "this probably doesn't need Opus." The rationalization is the failure mode.

The string to use verbatim: `"claude-opus-4-7"`

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> ## ⚠️ LIVE VIOLATION COUNTER — auto-updated every 30 min
> 
> **This rule is being violated.** Detector ran at 2026-05-14 11:35:30 PDT.
> 
> - last 7 days: **583** violation(s)
> - last 30 days: **2394** violation(s)
> - all-time: **2394** violation(s)
>
>   - explicit Ruben asks for subagent ignored (30d): **222**
>   - research/multi-step questions answered without subagent (30d): **2172**
>
> If you (Cline) are reading this rule, you are part of the count. The detector
> at `~/Documents/Cline/rule_violations/scan.py` looks at every Cline task on
> this Mac and flags should-have-but-didn't cases. Ruben gets a text when the
> burst rate jumps. **Don't add to the count.**
>
> Counters are stamped in by `~/Documents/Cline/rule_violations/write_rule.py`.
> Edit anywhere outside the BEGIN/END markers; this block is regenerated.
<!-- RULE_VIOLATION_COUNTERS:END -->
## v2 — 2026-05-03 21:35 PT — replaced "5 mandatory categories" with default-on gate (RE-APPLIED after rebase clobber)

The previous version of this rule said "subagent use is MANDATORY for these 5 categories" and required me to judge whether the current task fit one of them. Counter ran at 1562 violations / 30d, then 1575 after my first v2 commit got clobbered by a rebase autostash that re-applied v1. The diagnosis post-mortem (rule 17 vs. rule 95): rule 95 self-corrects (the 30s tool wall kills the task in front of me, I feel the pain immediately). Rule 17 doesn't (I answer from my own context, ship something plausible, no immediate signal). Adding more "MANDATORY" prose doesn't move the needle — same trap rule 09's chat-AI guardrail post-mortem identified ("rule lives in prompt → AI ignores → re-confirm rule → next chat same thing").

So this rewrite removes the judgment step. The default is "dispatch a subagent." The exceptions are a short, mechanical list of "obviously trivial" cases. That's the opposite of v1's framing.

## The default

**At the start of every new Cline task, before any other non-trivial tool call, my default first move is `use_subagents`.** Not "consider it." Not "if it fits one of 5 categories." The default — the thing I do unless an exception below clearly applies.

If I'm not sure whether the exception applies, I dispatch the subagent. False positives (one extra subagent call on a task that didn't strictly need it) cost ~30-60 seconds and a few cents. False negatives (skipping a subagent on a task that needed one) cost a wrong answer shipped to Ruben, which is the failure mode driving the 1575 number.

**The cost framing matters.** A subagent fan-out costs Ruben ~$0.05-0.30 per dispatch on Sonnet-class. The thing it prevents — me iterating the same wrong-direction fix 3-5 times before you catch it — is what actually wastes money. Each wrong iteration burns its own token cost AND your time. So subagents save money in net, not by being free, but by killing iteration loops.

## The exception list (skip subagents only if the task is one of these)

Skip subagents ONLY if the task is in one of these clearly-trivial categories:

1. **Single-file single-edit.** Ruben said "change X to Y in file Z" or "add this one line." One `replace_in_file` or `write_to_file` and done. (If the edit needs research first to know what the right value is — that's not this category, dispatch the subagent.)
2. **Single-command status check.** "What's the load on Artemis right now," "is the cron running," "show me the last 5 commits." One `execute_command` returns the answer. (If the answer requires synthesizing across multiple sources — not this category.)
3. **Mid-conversation continuation.** Ruben is actively waiting on a quick reply to a follow-up in the same back-and-forth, AND the answer is fully determined by what's already in this conversation's context. (If I'd need to look something up to answer — not this category.)
4. **Pure restatement / formatting.** "Reword this email," "format this as a table," "translate this PHP error to plain English." No new information needed.
5. **Already-dispatched.** I already called `use_subagents` earlier in this same task and the new turn is just acting on those results.

That's the entire exception list. **Five categories of "skip OK." Anything else → dispatch.**

The bar for "trivial" is genuinely trivial. If I find myself thinking "this is probably trivial enough" — that's the signal that it isn't, dispatch. If I find myself wanting to "answer from training knowledge" — dispatch. If I find myself wanting to "make a quick architectural call and ship the fix" — dispatch.

## When Ruben explicitly asks

If Ruben says any of "use subagent," "use subagents," "parallel research," "I want you to verify," "have a subagent look," "dispatch subagents," or any close variant — dispatch IMMEDIATELY. Not after one more tool call. Not after "let me first check X." The very next tool call MUST be `use_subagents`. If he asked twice in the same task, dispatch AND apologize for not doing it the first time.

This is non-negotiable and overrides every exception above. If he asked, the answer is yes.

## How to dispatch (the mechanic)

`use_subagents` accepts up to 5 prompts in parallel. Use the parallelism — don't dispatch 1 when 5 concerns are independent. Each prompt should be:

- Self-contained (the subagent doesn't have my context)
- Specific in deliverable ("return synthesis: A, B, C")
- Bounded in scope (don't ask one subagent to research the whole problem)
- Pointed at concrete sources where possible (specific GitHub issue URLs, doc pages, repos, file paths)

For multi-step builds, the canonical 5-prompt pattern is:
1. Research the underlying mechanism / upstream constraint
2. Plan subsystem A's config + deploy steps
3. Plan subsystem B's config + deploy steps
4. Plan subsystem C's config + deploy steps
5. Plan migration + rollback + smoke tests

For research, the canonical pattern is:
1. Search official docs + vendor FAQs for the exact claim/error
2. Search GitHub issues + Stack Overflow + community forums for the same
3. Grep the local codebase / known references for prior art
4. (optional) Verify against a second independent source
5. (optional) Synthesize tradeoffs across the prior 4

Then I synthesize and execute.

## Self-check before any non-trivial tool call

Before I call any non-`use_subagents` tool early in a task, ask: *"Is this task in one of the 5 exception categories above?"* If no, my next tool call MUST be `use_subagents`. If I'm halfway through `attempt_completion` on a research/architecture answer that I never dispatched a subagent for, and Ruben didn't say "answer from training" — I'm violating this rule, abandon and dispatch.

## What changed from v1 (for the record)

- **v1 framing:** "MANDATORY for 5 categories — judge if your task fits." Required precision in classification, which is exactly where the 1562+ violations originated.
- **v2 framing:** "Default-on. 5 trivial exceptions." Inverts the burden. False-positive cost is ~$0.05 + 30s; false-negative cost is a wrong answer shipped + iteration loop. Asymmetry favors over-dispatch.
- **Why we didn't pick option A (real-time pager + pre-flight gate):** That was a candidate. It catches misses while Ruben can still course-correct, but adds noise on false-positive task classifications, and doesn't change my behavior — just my visibility. v2 changes the behavior at source. If v2 doesn't move the counter inside ~14 days, escalate to A as well.
- **Rebase incident 2026-05-03 21:10 PT:** the first v2 commit was clobbered by an auto-sync cron rebase (autostash re-applied v1 over v2 with merge conflict markers). v2 has been re-applied here. If this happens again, the fix is to commit + push v2 BEFORE the next cron tick, not rely on autostash to do the right thing.

## Last updated

2026-05-03 21:35 PT — v2 re-applied after rebase clobber. Original v2 ship was 19:30 PT same day.

## 2026-05-12 addendum — MCP-dependent tasks still require policy-research subagents

Source incident: Lydia Seldner CPR reschedule task. The entire task required MySQL MCP queries (bls_students, bls_scheduled_classes, bls_class_types, bls_class_enrollments, tickets) — operations subagents cannot perform per .clinerules/53. The main agent did all work serially without dispatching any subagents. This was a rule 17 violation.

**The gap this addendum closes:** When primary task work is MCP-dependent (DB queries, ticket creation, iMessage sends), the "subagents can't do MCP" fact does NOT exempt the task from subagent use. There is almost always a parallel policy-research component that IS greppable from local files (.clinerules, HANDOFF_NOTES, local repo) and should run in a subagent while the main agent handles MCP calls.

**The rule:** For any EMSU operational task that re**The rule:** For any EMSU operational task that re**The rule:** For any EMSU operational task that re**The rule:** For anyity determin**The rule:** For any EMSU operational task that re**The rule:** F say?)

→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→ Dispatch a→  + what action the AI is authorized to take autonomously vs. what requires Vicky/Jon.
```

This costs $0.001-0.005 and runs in parallel. It ensures the policy determination is evidence-based (from .clinerules text) rather than recalled from training, and it surfaces edge cases the main agent might miss while focused on DB queries.

**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip sk):**
**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip subagents entirely because "all I need to do is run**What NOT to do:** Skip sk):**
start; if passed → Vicky." That policy clarity would have guided which DB fields to check first (class_datestart; if passed → Vicky." That policy clarity would have guided which DB fields to check first (class_datestart; if passed → Vicky." That policy clarity would have guided which DB fields to check first (class_datestart; if passed policy-research component eligible for parallel subagent execution. Ruben directive: "also make corrective action to cline rules to ensure proper subagent usage."


## 2026-05-12 addendum — MCP-dependent tasks still require policy-research subagents

Source incident: Lydia Seldner CPR reschedule task. The entire task required MySQL MCP queries (bls_students, bls_scheduled_classes, bls_class_types, bls_class_enrollments, tickets) — operations subagents cannot perform per .clinerules/53. The main agent did all work serially without dispatching any subagents. This was a rule 17 violation.

**The gap this addendum closes:** When primary task work is MCP-dependent (DB queries, ticket creation, iMessage sends), the "subagents can't do MCP" fact does NOT exempt the task from subagent use. There is almost always a parallel policy-research component that IS greppable from local files (.clinerules, HANDOFF_NOTES, local repo) and should run in a subagent while the main agent handles MCP calls.

**The rule:** For any EMSU operational task that requires BOTH:
1. MCP operations (main agent only — DB queries, ticket operations, student lookups), AND
2. Policy/eligibility determination (is this AHA? what's the reschedule window? what does rule X say?)

→ Dispatch at least 1 subagent (`claude-haiku-4-5`) to grep .clinerules + verify the policy at the SAME TIME the main agent starts its first MCP call. The subagent prompt shape:

```
Read /Users/rubenmajor/Documents/Cline/Rules/ for any rules about [topic].
Specifically check: [rule numbers that might apply].
Return: the exact policy + any edge cases + what action the AI is authorized to take autonomously vs. what requires Vicky/Jon.
```

This costs $0.001-0.005 and runs in parallel. It ensures the policy determination is evidence-based (from .clinerules text) rather than recalled from training, and it surfaces edge cases the main agent might miss while focused on DB queries.

**What NOT to do:** Skip subagents entirely because "all I need to do is run some SQL queries." SQL queries are the mechanism; the policy decision is the point. The policy decision is always subagent-eligible because .clinerules files are on the local Mac filesystem.

**Applied example (what should have happened on the Lydia task):**

```
Dispatching Haiku 4.5 for prompt 1 (grep .clinerules for CPR/BLS/AHA reschedule policy,
what actions AI can take autonomously vs. routes to Vicky),
while main agent queries bls_students + bls_class_enrollments + bls_class_types.
```

The subagent would have immediately confirmed: "non-AHA class = free reschedule IF before class start; if passed → Vicky." That policy clarity would have guided which DB fields to check first (class_date vs. class_type) rather than discovering them sequentially.

## Last updated (rule 17)

2026-05-12 — addendum added. Source: Lydia Seldner CPR reschedule incident. Rule 17 violation: no subagents dispatched on an EMSU ops task despite a clear policy-research component eligible for parallel subagent execution. Ruben directive: "also make corrective action to cline rules to ensure proper subagent usage."

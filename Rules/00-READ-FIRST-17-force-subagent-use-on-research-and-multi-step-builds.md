# Force subagent use — default-on, not judgment-based

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> ## ⚠️ LIVE VIOLATION COUNTER — auto-updated every 30 min
> 
> **This rule is being violated.** Detector ran at 2026-05-07 12:52:09 PDT.
> 
> - last 7 days: **1815** violation(s)
> - last 30 days: **1815** violation(s)
> - all-time: **1815** violation(s)
>
>   - explicit Ruben asks for subagent ignored (30d): **117**
>   - research/multi-step questions answered without subagent (30d): **1698**
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

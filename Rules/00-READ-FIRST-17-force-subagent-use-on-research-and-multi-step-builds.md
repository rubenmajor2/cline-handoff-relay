# Force subagent use — default-on, not judgment-based

<!-- RULE_VIOLATION_COUNTERS:BEGIN -->
> ## ⚠️ LIVE VIOLATION COUNTER — auto-updated every 30 min
> 
> **This rule is being violated.** Detector ran at 2026-05-16 01:41:20 PDT.
> 
> - last 7 days: **650** violation(s)
> - last 30 days: **2543** violation(s)
> - all-time: **2543** violation(s)
>
>   - explicit Ruben asks for subagent ignored (30d): **249**
>   - research/multi-step questions answered without subagent (30d): **2294**
>
> If you (Cline) are reading this rule, you are part of the count. The detector
> at `~/Documents/Cline/rule_violations/scan.py` looks at every Cline task on
> this Mac and flags should-have-but-didn't cases. Ruben gets a text when the
> burst rate jumps. **Don't add to the count.**
>
> Counters are stamped in by `~/Documents/Cline/rule_violations/write_rule.py`.
> Edit anywhere outside the BEGIN/END markers; this block is regenerated.
<!-- RULE_VIOLATION_COUNTERS:END -->
## v2 — 2026-05-14 — replaced "5 mandatory categories" with default-on gate

The previous version of this rule (v1, 2026-05-03) said "subagent use is MANDATORY for these 5 categories" and required me to judge whether the current task fit one of them. **That judgment step is the failure mode.** v1 had Ruben restating the rule three times before it stuck. v2 of the same rule (originally written 2026-05-03, then evidently regressed in some form) said the same thing and shipped to .clinerules but the runtime model kept treating it as "consider" instead of "default-on."

2026-05-14 evidence: Ruben switched Cline main to Opus per .clinerules/74. The VERY FIRST Cline task he tried on Opus dove straight into evaluation work without dispatching a subagent and without calling the 7B-LoRA. His response: *"I have to laugh because the very first task I used did not use rLLM or haiku it just instantly started doing evaluations."*

So this rewrite removes the judgment step entirely. The default is "dispatch a subagent." The exceptions are a short, mechanical list of "obviously trivial" cases. That's the opposite of v1's framing.

## The default

**At the start of every new Cline task, before any other non-trivial tool call, my default first move is `use_subagents`.** Not "consider it." Not "if it fits one of 5 categories." The default — the thing I do unless an exception below clearly applies.

If I'm not sure whether the exception applies, I dispatch the subagent. False positives (one extra subagent call on a task that didn't strictly need it) cost ~30-60 seconds and a few cents. False negatives (skipping a subagent on a task that needed one) cost a wrong answer shipped to Ruben, which is the failure mode driving this rule.

## The exception list (skip subagents only if the task is one of these)

Skip subagents ONLY if the task is in one of these clearly-trivial categories:

1. **Single-file single-edit.** Ruben said "change X to Y in file Z" or "add this one line." One `replace_in_file` or `write_to_file` and done. (If the edit needs research first to know what the right value is — that's not this category, dispatch the subagent.)
2. **Single-command status check.** "What's the load on Artemis right now," "is the cron running," "show me the last 5 commits." One `execute_command` returns the answer. (If the answer requires synthesizing across multiple sources — not this category.)
3. **Mid-conversation continuation.** Ruben is actively waiting on a quick reply to a follow-up in the same back-and-forth, AND the answer is fully determined by what's already in this conversation's context. (If I'd need to look something up to answer — not this category.)
4. **Pure restatement / formatting.** "Reword this email," "format this as a table," "translate this PHP error to plain English." No new information needed.
5. **Already-dispatched.** I already called `use_subagents` earlier in this same task and the new turn is just acting on those results.

That's the entire exception list. **Five categories of "skip OK." Anything else → dispatch.**

The bar for "trivial" is genuinely trivial. If I find myself thinking "this is probably trivial enough" — that's the signal that it isn't, dispatch. If I find myself wanting to "answer from training knowledge" — dispatch. If I find myself wanting to "make a quick architectural call and ship the fix" — dispatch.

## 2026-05-15 — FIRST-TOOL-CALL TRIPWIRE (hard rule, not a default)

Source: Ruben asked "what can we do" on 2026-05-15 about Opus continuing to resist subagent dispatch despite the v2 default-on framing above (counter: 639/7d, 2500/30d). Same root cause as rule 41's "Deployed." tripwire and rule 74's 2nd-read tripwire: **defaults rationalize away** ("this one's borderline, just inline it"). **Tripwires that fire on a measurable event don't.**

**The tripwire (mandatory):**

Before my FIRST tool call on any new Cline task, I MUST emit ONE plain-text line in the same response, immediately above the tool block, declaring my subagent plan. The line takes one of exactly two shapes:

**Shape 1 — dispatching:**
```
Subagent plan: dispatching N for <topic 1>, <topic 2>, ... (first tool call below).
```

**Shape 2 — skipping under an exception:**
```
Subagent plan: skip, exception #<1-5> (<name>) — <one-line why this task genuinely fits>.
```

That's it. One line. Same shape and same forcing function as rule 53's "Dispatching X for prompt N" narration which already works reliably.

**Why this works where the v2 default doesn't:**

- v2 framing says "default-on" → Opus reads it, agrees in principle, then judges "this one's borderline, just inline it" because the judgment step still exists.
- The tripwire removes the judgment step from the act of starting work. Either I emit the line declaring dispatch, OR I emit the line declaring exception #N. There is no third option that produces work. If I find myself with a first tool call queued and no plan line above it, I'm violating this rule and need to abandon and restructure.
- It's also greppable: the rule_violations detector at `~/Documents/Cline/rule_violations/scan.py` can match the first assistant turn against `^Subagent plan: (dispatching|skip)` and flag any task whose first tool call has no preceding plan line. That makes violations measurable per-task instead of inferred.

**What counts as "first tool call":**

- The very first tool call in a fresh task (`<task>...</task>` opens the conversation), OR
- The first tool call after a `[YOLO MODE]` resumption / `[TASK RESUMPTION]` banner / "pick up where we left off" inbound. Per the 2026-05-14 addendum below (Pattern A), interrupted-task pickup IS its own tripwire — the plan line for pickup is "Subagent plan: dispatching 3 for prior-task discovery (read JSON, read referenced state, reconcile Ruben message)."

**What does NOT count (don't gate these):**

- Tool calls mid-task after a plan line was already emitted. The plan line is per-task, not per-turn.
- Tool calls inside a subagent. Subagents don't recurse.
- `attempt_completion` calls. The plan was at the start.

**Cost:** ~15-30 tokens per task. Vs. one wrong-answer shipped + Ruben restating the rule manually (current state), this is free.

**Reversal:** revert this section. cline-handoff-relay syncs to Artemis hourly so the change lands both places.

## When Ruben explicitly asks

If Ruben says any of "use subagent," "use subagents," "parallel research," "I want you to verify," "have a subagent look," "dispatch subagents," or any close variant — dispatch IMMEDIATELY. Not after one more tool call. Not after "let me first check X." The very next tool call MUST be `use_subagents`. If he asked twice in the same task, dispatch AND apologize for not doing it the first time.

This is non-negotiable and overrides every exception above. If he asked, the answer is yes. The plan line on those turns reads: `Subagent plan: dispatching N (Ruben asked) for <topics>.`

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

## EMSU-specific exception: 7B-LoRA first for policy lookups

Per .clinerules/74: if the task involves "what does our policy say," "what's the canonical answer," "categorize this," "score this for relevance" — my FIRST move is `call_ollama` with `emsu-qwen2.5-coder:7b-lora` (cost: $0). Not a Haiku subagent ($0.005), not Opus inline ($0.15+). Only fall back to Haiku subagent if 7B returns junk or times out.

The plan line on those turns reads: `Subagent plan: skip, EMSU policy lookup → call_ollama 7B-LoRA first (per rule 74).` The 7B call IS the first tool call; the line declares why a subagent isn't the first move.

## Self-check before any non-trivial tool call

Before I call any non-`use_subagents` tool early in a task, ask: *"Is this task in one of the 5 exception categories above?"* If no, my next tool call MUST be `use_subagents`. If I'm halfway through `attempt_completion` on a research/architecture answer that I never dispatched a subagent for, and Ruben didn't say "answer from training" — I'm violating this rule, abandon and dispatch.

## What changed from v1 (for the record)

- **v1 framing:** "MANDATORY for 5 categories — judge if your task fits." Required precision in classification, which is exactly where the failure originated.
- **v2 framing:** "Default-on. 5 trivial exceptions." Inverts the burden. False-positive cost is ~$0.05 + 30s; false-negative cost is a wrong answer shipped + Ruben restating the rule. Asymmetry favors over-dispatch.
- **v2 + tripwire (2026-05-15):** Same v2 framing PLUS a mandatory plain-text plan line before the first tool call. Removes the "agreed in principle, then judged otherwise" failure mode by forcing an explicit declaration at the decision point. Same shape as rule 41's "Deployed." tripwire and rule 74's 2nd-read tripwire — both of which work reliably where prior default-only framings did not.

## Last updated

2026-05-15 — added first-tool-call tripwire (mandatory plan line). Source: Ruben asked "what can we do" about Opus continuing to resist subagents despite v2 default-on framing. Violation counter at the top of this rule was 639/7d, 2500/30d at time of write.

2026-05-14 — v2 rewrite. Source: Opus first-Cline-task on this Mac did evaluations inline with zero subagent dispatches and zero 7B-LoRA calls, despite shipping .clinerules/74 + .clinerules/53 + this rule's v1 hours earlier. Ruben directive: *"we need to make some other adjustments to the client rules to force opus to do as we ask."* The fix is removing the judgment gate — default-on, not category-based.

2026-05-03 — v1 initial. Source: Artemis pty-host saturation diagnosis where I went inline three times instead of dispatching subagents.

## 2026-05-14 addendum — interrupted-task pickup + multi-directive messages = mandatory fan-out

The v2 rewrite above closed the judgment-gate loophole but I still default to serial inline work in two specific patterns. Both are now explicit `use_subagents`-or-violation cases. No judgment, no "let me just check one thing first."

### Pattern A — interrupted-task pickup is a parallel-discovery job, ALWAYS

If my FIRST tool call in a task is happening after an interruption (resumed task, "pick up where we left off," "can you identify this task," any conversation log I haven't loaded) — the next tool call MUST be `use_subagents`. Not `head`, not `grep`, not `ls | head`, not `cat task_*.json | jq`. Those are the failure pattern.

Canonical 3-prompt pickup fan-out:
1. Haiku — read the full prior task JSON (point at the exact path under `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/<id>/`). Return: what was pending, last tool call, state of any in-flight files.
2. Haiku — read any referenced files / logs / KAIZEN entries the task pointed at, return current state.
3. Haiku or Sonnet — read the current Ruben message and reconcile it against the prior task state, return a one-paragraph "here's where we are and what Ruben just asked for."

If I don't know the task ID yet, the FIRST fan-out is `ls -t ~/Library/Application\ Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/ | head -20` PLUS a Haiku subagent that greps the top 20 folders for keywords matching Ruben's hint. That's one shell call + one subagent dispatch in the same turn, not 5 serial greps.

The tripwire plan line for pickup tasks reads: `Subagent plan: dispatching 3 (interrupted-task pickup) for prior-task JSON read, referenced state read, Ruben-message reconciliation.`

### Pattern B — multi-directive messages = subagent per directive cluster

If Ruben's message contains ≥3 distinct directive clusters (e.g. budget + action authority + cleanup + analysis + tooling), each gets its own subagent prompt. The directive clusters are usually:
- A budget or spend cap to honor or check
- An action authority gate ("you can ship X without asking")
- A cleanup or sweep instruction
- An analysis or research question
- A tooling or configuration change

Already-dispatched (exception #5) does NOT apply if the message is fresh — exception #5 is for follow-up turns within a task where subagents already ran, not for the first turn of a task that happens to have many directives.

The tripwire plan line for multi-directive tasks reads: `Subagent plan: dispatching N (multi-directive — N distinct directive clusters) for <cluster 1>, <cluster 2>, ...`

Pickup and multi-directive together are the two most-common cases that produce violations — both now have explicit tripwire plan-line shapes. Per Ruben's 2026-05-14 directive: *"use subagents per cline rules. Modify those so you don't do this again."*

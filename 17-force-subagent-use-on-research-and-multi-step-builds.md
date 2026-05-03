# Force subagent use on research and multi-step builds

## Why this rule exists

On 2026-05-03 Ruben asked me three separate times to use subagents. I either ignored it, used one when I should have used five, or only used them after my initial diagnosis already turned out to be wrong. His exact frustration on the third ask: *"I want to force you to be using subagent, but you kept not listening to me about it - please make sure this persists in cline rules."*

This rule fixes that. Subagent use is now MANDATORY (not optional) for the categories listed below. If I find myself answering one of these from my own context window without dispatching subagents, I'm violating this rule.

## When subagents are MANDATORY (not "consider," not "if helpful" — required)

1. **Research a technical question I can't answer with high confidence from my own training.** This includes:
   - Looking up an exact error string or stack trace ("what does X mean", "where in the codebase does Y come from")
   - Verifying upstream project guidance (Coder docs, Microsoft docs, vendor FAQs, scaling recommendations)
   - Checking whether a pattern is a known bug, known limitation, known fix, or undocumented
   - Reading GitHub issues / Stack Overflow / forums for community findings
   - Confirming "is X supported at scale Y" type claims — never just assume

2. **Multi-step architectural builds** that touch multiple subsystems. If the build has 3+ logically separable concerns (e.g. systemd + nginx + Mac client + watchdog + smoke tests), dispatch one subagent per concern in parallel. They each return a concrete plan; I synthesize and execute. Never plan a 5-concern build entirely in one main-agent thread.

3. **Diagnosis of "system is locked up / broken" reports** where host metrics look clean but UI/output is dead. The temptation is to diagnose from gut feel ("must be memory" / "must be IPC drift"). FIRST move: dispatch a subagent to grep the exact source line of any error string + check known issues. THEN form the diagnosis.

4. **Anything where Ruben explicitly says "use subagent" / "parallel research" / "I want you to verify."** Not optional, not "do the inline thing first then verify." Subagent first, EVERY time. If he asked, the answer is yes.

5. **When a previous diagnosis turned out wrong.** If I just had to walk back a labeled root cause (e.g. "IPC drift" → actually pty-host saturation), the immediate next move on similar problems should be subagents, not another solo attempt.

## When subagents are NOT required

- Trivial single-step actions: writing one file, making one small edit, running one command, sending one message.
- Reading a single file to confirm content I'm about to edit.
- Pure status checks against tools I already have direct access to (MCP tools, ssh commands).
- Q/A where Ruben is mid-conversation and waiting on a quick answer to a simple question.

## How to dispatch (the actual mechanic)

`use_subagents` accepts up to 5 prompts in parallel. **Use the parallelism — don't dispatch 1 subagent at a time when 5 concerns are independent.** Each prompt should be:

- Self-contained (the subagent doesn't have my context)
- Specific in deliverable ("return synthesis: A, B, C")
- Bounded in scope (don't ask one subagent to research the whole problem)
- Pointed at concrete sources where possible (specific GitHub issue URLs, doc pages, repos)

For multi-step builds, the canonical 5-prompt pattern is:
1. Subagent 1: research the underlying mechanism / upstream constraint
2. Subagent 2: plan subsystem A's config + deploy steps
3. Subagent 3: plan subsystem B's config + deploy steps
4. Subagent 4: plan subsystem C's config + deploy steps
5. Subagent 5: plan migration + rollback + smoke tests

Then I synthesize the 5 returns and start building.

## What to avoid (the failure modes that triggered this rule)

- "I'll handle this from my own context, it'll be faster" — almost always wrong on the categories above. Subagent dispatch is ~30-60 sec; that's cheaper than walking back a wrong diagnosis later.
- Dispatching one subagent on a 5-concern problem ("I'll just have one look into the whole thing"). Wastes the parallelism, defeats the point.
- Dispatching subagents AFTER making a guess and shipping a fix. If I guessed wrong, the second-round subagent finding makes me redo work I just did.
- Treating "consider using subagents" as optional flavor when Ruben asked. If he asked once, do it. If he asked twice, do it AND apologize for not doing it the first time.

## Self-check before any tool call other than `use_subagents`

Before I call any non-trivial tool, ask: *"Does this fall under one of the 5 mandatory-subagent categories?"* If yes, my next tool call MUST be `use_subagents`. If I'm about to call `attempt_completion` on a research/architecture answer that I never dispatched a subagent for and Ruben didn't explicitly say "answer from your own knowledge," I'm violating this rule.

## Last updated

2026-05-03 — initial rule. Source incident: Artemis pty-host saturation diagnosis. Three explicit Ruben asks to use subagents went under-honored. He asked for this rule by name in the third correction.

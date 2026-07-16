# 278 — Bug library treasure trove: failed ideas are the raw material of breakthroughs

## The principle

Failed ideas, rejected approaches, and resolved incidents are NOT waste. They are a treasure trove of hard-won knowledge that fuels unparalleled success. Like inventors who iterate through hundreds of failed prototypes before achieving a breakthrough, every failed attempt in the bug library (`frankenstein_router_incidents`) and ideas pipeline (`orchestrator_ideas` with status `rejected` or `impl_failed`) is a data point that narrows the search space for the next attempt.

**The bug library IS the institutional memory.** An agent that consults it before diagnosing avoids re-deriving already-solved problems (rule 156). An agent that records in it after solving ensures future agents find the repair instantly. The treasure trove grows with every failure, and every failure makes the next attempt smarter.

## The rule

1. **Before diagnosing ANY LLM routing or infrastructure symptom**, call `bug_library_check_before_fix` (rule 156). The bug library may already have the exact repair.

2. **After resolving ANY novel symptom**, record it via `bug_library_record` or direct SQL insert into `frankenstein_router_incidents`. Future agents will find it instantly.

3. **Treat rejected ideas as research, not waste.** When an idea in `orchestrator_ideas` is rejected or fails implementation, the diagnosis and evidence fields are the treasure. They document what was tried, why it failed, and what the constraint was. This is invaluable for the next attempt.

4. **Mine the treasure trove proactively.** When approaching a new problem, search the bug library AND rejected ideas for related patterns. The 2-strike tripwire (rule 262) ensures agents don't recycle failed approaches blindly.

5. **Every failure has a lesson.** The lesson may be "this path doesn't work" (eliminating a hypothesis), "this path works but needs a different parameter" (narrowing), or "this path reveals a deeper architecture issue" (insight). All three are treasure.

## The inventor's mindset

Thomas Edison's perspective on the light bulb applies directly: "I have not failed. I've just found 10,000 ways that won't work." Each entry in the bug library is one of those 10,000 ways. The agent that consults the library stands on the shoulders of every prior failure and succeeds faster.

The EMSU fleet's most complex recoveries (Julia/Claudia TP=2, Cicero 235B restoration, Frankenstein Doctor RCA) all succeeded because agents iterated through failures, recording each one, until the working path emerged. The bug library entries from those sessions are the treasure that makes the next recovery faster.

## Cross-references

- Rule 156 — consult bug library before diagnosing (bright-line rule)
- Rule 262 — 2-strike tripwire for recycling failed approaches
- Rule 147 — Kaison autonomous repair (uses bug library for known repairs)
- Rule 138 — fast-train runbook (learned from failed training runs)
- Rule 266 — agent-found-wrong: fix the instrument that misled the agent

## Source incident

2026-07-15 — Julia/Claudia TP=2 gpt-oss-120b recovery session. Multiple failed approaches (Gloo interface mismatch, ninja PATH issue, Ray worker GPU registration, pkill killing sshd) were recorded in the bug library. Each failure narrowed the search space. The final successful TP=1 launch on Julia was only possible because the failed TP=2 attempts had eliminated every other path. Ruben directive: "Add bug library treasure trove rule — failed ideas are a treasure trove for unparalleled success, like how inventors iterate before inventing."

## Last updated

2026-07-15 — initial. Source: Ruben directive during Julia/Claudia recovery session.
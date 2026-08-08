# Rule 300 — End-to-End Delivery Compliance

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS**
**Created: 2026-08-08**

## Core Principle

When a human says "end to end," "complete," "finish," "build and ship," "take this all the way," "don't hand off," or any similar directive, the window MUST NOT hand off mid-delivery. Diagnosis turns that do not produce artifacts count as incomplete.

## Violations are diagnosed as:
1. Window produces analysis, files an idea, and calls attempt_completion with a PICKUP PROMPT block instead of building.
2. Window produces 3+ consecutive diagnostic/investigation turns after identifying root cause, without producing a deliverable.
3. Window says "filed as idea #N" or "next window should..." for work that can be done in THIS window with available tools.
4. Window claims "context limit reached" as a reason to stop building, without attempting context recovery or simplification first.

## Mandatory behavior:
- Once root cause is identified, EVERY subsequent turn MUST advance the deliverable. Investigation turns are forgivable only when genuinely discovering new unknown territory.
- A PICKUP PROMPT block is valid ONLY when the task genuinely cannot be completed (requires human decision with no default, requires API keys not available, requires physical access). If tools exist to do the work, DO IT.
- Filing an idea is NOT a deliverable. The deliverable is the artifact: a deployed file, a verified config change, a running process.
- Before calling attempt_completion, the window MUST verify AT LEAST ONE concrete artifact was produced (file on disk, config deployed, process restarted and verified healthy).

## This rule overrides:
- Rule 91 (PICKUP PROMPT format): PICKUP PROMPT blocks for "next window should build this" are FORBIDDEN when the current window can build it.
- Any "context size" heuristic that says to stop: simplify the task, compress the context, use subagents, but DO NOT hand off.

## Relationship to other rules:
- Rule 29 (agents default to action): Rule 300 is the enforcement mechanism for Rule 29.
- Rule 143 (prose-loop circuit breaker): If 300 is violated, 143's strike counter should reflect it.
- Rule 161 (approved means executing): Approved ideas must be executed, not filed for later.
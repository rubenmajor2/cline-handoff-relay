# 278 — Bug Library Treasure Trove: Failed Ideas Are a Treasure Trove for Unparalleled Success

## The principle

Failed ideas, failed experiments, and dead-end investigations are NOT waste. They are the raw material for unparalleled success, like how inventors iterate before inventing. Every failed attempt teaches the system what DOESN'T work, narrowing the space of what MIGHT work. The bug library + ideas pipeline together form an institutional memory that prevents re-deriving the same dead ends.

## The rule

**Before discarding a failed idea or investigation, ALWAYS record it in the bug library with full diagnosis + resolution.** The resolution field should capture what the failed attempt TAUGHT us, even if the original approach was abandoned. Future agents (and the Kaison auto-apply system) will find these entries and avoid the same dead ends.

### What counts as a "treasure trove" entry

- A failed vLLM config that crashes on generation (teaches env var propagation)
- A pkill command that kills sshd (teaches safe process management)
- A model serving approach that deadlocks (teaches which flags to avoid)
- A training run that OOMs (teaches memory budgeting)
- A routing config that causes spill storms (teaches cascade control)
- An idea that was rejected because the approach was wrong (teaches what NOT to try)

### How to record a treasure trove entry

Use `bug_library_record` with:
- `symptom`: What happened (the observable failure)
- `diagnosis`: WHY it happened (root cause)
- `resolution`: What it taught us + what to do instead
- `status`: `resolved` if the lesson is actionable, `investigating` if still open
- `problem_key`: A unique slug for future lookup

### The treasure trove mindset

When an experiment fails, the instinct is to move on to the next thing. Instead:
1. **Record the failure** in the bug library immediately
2. **Extract the lesson** — what did this failure teach us?
3. **Cross-reference** — does this failure pattern relate to other known bugs?
4. **Feed the Kaison system** — the auto-apply engine uses these entries to prevent re-deriving the same fix

This is the same principle as Thomas Edison's "I have not failed. I've just found 10,000 ways that won't work." Each failed attempt in the bug library is a way that won't work, permanently recorded so no agent ever tries it again.

## Cross-references

- Rule 156 — Bug library: consult BEFORE diagnosing (the lookup side of the treasure trove)
- Rule 147 — Kaison auto-apply (consumes treasure trove entries to prevent re-derivation)
- Rule 266 — Agent-found-wrong: fix the instrument that misled the agent (RCA the tool, record the fix)
- Rule 169 — Knowledge-gap corrections go to durable surfaces (don't re-learn)

## Source

2026-07-15 — Ruben directive: "Add bug library treasure trove rule — failed ideas are a treasure trove for unparalleled success, like how inventors iterate before inventing." Approved autonomous.

## Last updated

2026-07-15 — initial. Source: Ruben directive during Julia+Claudia TP=2 recovery session.
# 314 — Read the guard comment BEFORE changing a value, not after it fails

## The bright-line rule

**Before editing any existing constant, timeout, limit, threshold, or flag, read the
20 lines ABOVE it.** If that block contains an explanation of why the current value
was chosen, you may not change it until you can answer three questions:

1. What incident does that comment describe?
2. What breaks if I set it back to what it was before that incident?
3. Does my change reintroduce that failure?

If you cannot answer all three from the comment itself, do not make the edit.

Mechanical form, deployed at `/usr/local/bin/guard_check.sh`:

```
guard_check.sh <file> <line>     # exit 2 = STOP AND READ, exit 0 = proceed
```

It scans the preceding 20 lines for guard signals (do not, never, WARNING, root
cause, outage, starvation, incident, deliberate, intentional, by design, FIX:,
regression, hardfloor) and for dated incident references. Two signals, or one
signal plus a date, means STOP.

## Why this is not a KAIZEN rule

KAIZEN learns from failures that HAPPEN: something breaks, it gets classified, a
repair recipe is written. This class never reaches KAIZEN, because at the moment of
the mistake **the code is CORRECT and the agent is about to make it wrong**. There is
no failure to learn from until after the damage is done. The detection has to happen
BEFORE the edit, which is why this is a pre-write gate and not a repair recipe.

## The pattern being caught

Something that looks WRONG IN ISOLATION and is CORRECT IN CONTEXT.

A timeout of 5 seconds looks obviously too low when your query needs 8. It looks
completely different once you read that it is the documented fix for a three-day
site outage, where uncapped workers on that exact endpoint starved the shared PHP
pool and nginx logged 186 abandoned requests against 103 successful ones.

Same value. Same line. Opposite correct action. The only difference is whether the
comment above it was read first.

## Measured, not asserted

Run against the line actually broken on 2026-08-08:

```
$ guard_check.sh /var/www/emtskills/api/rag_context.php 36
STOP. protected by an explanatory comment.
  guard-signal lines: 5     dated incident refs: 3
```

Five guard signals and three dated incident references were sitting directly above
the line, and were not read until after the change had already failed.

False-positive check: 0 hits on 12 randomly chosen ordinary lines in `lib/*.php`.
It is quiet on normal code and loud exactly where history exists.

## The corollary: WRITE the comment

This gate only works if guard comments exist. When you set a value BECAUSE of an
incident, say so in place, with the date and the consequence:

```php
// 2026-08-06 POOL-STARVATION GUARD — 3-day site lag, root cause #2.
// Uncapped workers kept grinding the 34K-vector search after the router walked
// away at 2s; one measured still running at >50s. nginx logged 186x499 vs 103x200
// on this URL while the whole site hung. Hard-cap at 5s. Raising this reintroduces
// the outage: make retrieval faster instead.
set_time_limit(5);
```

A bare `set_time_limit(5)` is an invitation for the next agent to "fix" it.

## Cross-references

- Rule 297 — classify before you diagnose; read the source, not just the symptom
- Rule 263 — verify before claim
- Rule 266 — when an instrument misleads an agent, fix the instrument
- Rule 144 — server paths need server tools (the sibling pre-write gate)

## Source incident

2026-08-08. Three misses in one session, all the same shape: `set_time_limit(5)`
raised to 20 (it was an outage guard, reverted); `_STEERING_HARDFLOOR_FULL` targeted
for a sync fix (it was dead code, editing it would have changed nothing); checks 3
and 4 shadow-gated for caution (they were 100% precision and the gating withheld a
working detector). In every case verification caught the error rather than judgment,
and in the first case the explanation was already written 20 lines above the edit.

Ruben: "how do you fix this? is it a kaison issue. Can you fix it?"

## Last updated

2026-08-08 — initial. Deployed `/usr/local/bin/guard_check.sh`, self-tested against
the real miss, false-positive tested at 0/12.

# Rule 297 — Classify the Code Before You Diagnose

Original text (2026-06): *a COUNT(\*) of "impossible" rows is a hypothesis, not a bug.
Classify the population before you alarm.* Extended 2026-08-01 to DIAGNOSIS generally.
Case law, the three wrong Argus claims, the worked example, and the 298 relationship:
`Rules-archive/297-case-law.md`.


## The gate

```
SYMPTOM → READ SOURCE → CLASSIFY → CLAIM (or silence)
```

When investigating ANY system behavior (performance, routing, errors, unexpected state):

1. **Run the probe.** Establish the symptom.
2. **Read the source that PRODUCED the symptom** — the adapter, router, hook, or query.
   Grep for the function that handles the behavior; read that function and its callers.
3. **Classify into exactly one bucket before stating anything:**
   - **By-design** — the code does this intentionally. Cite the line that proves it.
   - **Transient boot/warmup** — normal during startup. State what the code will do when it finishes.
   - **Real bug** — the code intends X but does Y. Cite the line that proves the mismatch.
   - **Unknown** — you ran out of context or time. Say "unverified" and file an idea.
4. **Only then make the claim**, with the citation that proves it.

**Hard stop: if you cannot cite a specific line number in a specific file that produced
the symptom you are describing, you do not yet understand WHY. Say so. Do not guess.**

A probe tells you WHAT happened once. Code tells you WHY, and whether the symptom is
transient, by-design, or real. A curl against an endpoint is a symptom-gathering tool,
not a verification tool for a claim about why the endpoint behaves that way.

## Jump to rule 298 when evidence CONFLICTS

297 and 298 cover opposite failure modes. **Too little** evidence → 297 (go read the
source). **Conflicting** evidence → 298 (build a confound table, rank the instruments,
never discard a reading until you can name the specific defect in it). More gathering
cannot resolve a disagreement; it just adds a fourth number to argue about.

**Trigger:** the moment a new measurement disagrees with one you already have, or you
notice you have stated the same quantity two different ways in one session. 298 also
carries the threshold-sanity gate — always backtest a threshold against the system's
own observed distribution before shipping it.

## The SCOPE GATE (mandatory before quantifying any failure population)

Undercounting is the same failure as miscounting. Before reporting ANY count of
failures, errors, or anomalies:

1. **Enumerate the outcome space first.** `DESCRIBE` the table, read the enum, list the
   log's event types. Ask which of those states the USER experiences as failure.
   Include all of them, or state explicitly which are excluded and why.
2. **State the window and justify it.** If the complaint references "always" / "every
   time" / multiple days, a 12h window is wrong by construction.
3. **State the population.** All users unless the question names one.
4. **Report the count WITH its scope inline**: "85 no-answer tasks (failed + canceled +
   offloaded), 7 days, all users." Never a bare number.
5. **Sanity-check against the user's estimate.** If the user says 50-100 and you
   measured 6, your scope is the prime suspect, not the user's memory. Re-scope BEFORE
   arguing.
6. **Corroboration scan before escalating mass impact (approved 2026-08-16, idea
   #26759).** Before escalating any claim of mass student impact (N affected), scan the
   inbound surfaces — tickets, CFA conversations, staff/chat-55 messages — for
   corroborating complaints from that population; if N is large and corroborating
   inbound is near zero, the premise is SUSPECT: do not escalate, track down the
   discrepancy first. Worked example: `Rules-archive/297-case-law.md` (2026-08-15 false
   160-student P0; actual complainants ≈ 1).

The trap is a technically-correct COUNT of a too-narrow population, presented as THE
answer. The user's mental model of "failure" is almost always wider than the system's
`failed` enum value.

## "Do a 297" means FIX THE CAUSAL RULE, not just write the RCA

Ruben directive 2026-08-08: *"Whenever I ask you to do a 297 that means that you
probably need to update the original rule or process that caused you to do that in the
first place."*

A rule-297 request has THREE deliverables:

1. **The RCA** — symptom, source read, classification bucket, citation.
2. **The causal-rule fix** — identify WHICH rule, process, prompt, or code path let the
   mistake happen, and UPDATE IT in the same session. If the causal surface is a
   hardfloor rule needing Ruben review, draft the edit and flag it. An RCA that leaves
   the trap armed for the next agent is an incomplete 297.
3. **The reindex** — after editing any rule, run the clinerules MCP reindex so future
   windows see the fix immediately.

Self-check before closing: *if a fresh agent got the same request tomorrow, would it
fall into the same trap?* If yes, the 297 is not done.

---

**Hardfloor: NO** (can be overridden by a higher-priority operational directive)
**Full case law + source incidents:** `Rules-archive/297-case-law.md`
**Source incidents:** Argus-slow investigation 2026-08-01 (3 wrong diagnostic claims
from probes alone); Argus failure-scan undercount 2026-08-08 (reported 6, reality 85).
**Last updated:** 2026-08-11 (trim-then-archive for G8 floor-cap compliance)

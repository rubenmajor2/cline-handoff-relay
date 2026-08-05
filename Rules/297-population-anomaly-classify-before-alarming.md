# Rule 297 — Classify the Code Before You Diagnose (strengthened 2026-08-01)

## Original Text (2026-06)
> A COUNT(*) of "impossible" rows is a hypothesis, not a bug. Classify the population before you alarm.

**2026-08-01 STRENGTHENING — this rule now covers DIAGNOSIS, not just SQL anomalies. What went wrong during the Argus-slow investigation:**

## The Failure Pattern (Argus investigation, 2026-08-01)

```
Cline probe → symptom → Cline announces ROOT CAUSE from probe alone
         ↑                      ↑
      (useful)             (destructive — unverified inference)
```

Specifically:

| Claim Made | Actual Code Fact | Cost of Wrong Claim |
|---|---|---|
| "Canary tok_s=999.0 is a hardcoded override" | `_canary_init()` line 648: `"tok_s": 999.0` is the INITIALIZATION SENTINEL for every upstream before first probe | Wasted ~4 turns writing idea #20958 to "remove" a non-existent override |
| "Only 2/3 boxes in pool, federation missing" | Adapter UPSTREAMS has 4 members; `_least_loaded_order()` correctly ranks all of them | Wrote idea #20957 to "restore full pool width" — pool was never narrow |
| "Canary is blind, not detecting dead ring" | Canary measured `tok_s=0.0 decode_live=false` correctly. The ring WAS genuinely not decoding at that moment (mid-warmup after boot at 11:23) | Blamed the canary for correctly reporting a transient boot state |

**Root cause**: every claim was derived from PROBES (curl, canary JSON, systemctl) and NONE from reading the adapter source code. A probe tells you WHAT happened once. Code tells you WHY, and whether the symptom is transient, by-design, or a real bug.

## The FIX — MANDATORY before any diagnostic claim

```
SYMPTOM → READ SOURCE → CLASSIFY → CLAIM (or silence)
```

### When investigating ANY system behavior (performance, routing, errors, unexpected state):

1. **RUN the probe** — establish the symptom
2. **READ the relevant source code** — the adapter/router/hook that PRODUCED that symptom
3. **CLASSIFY the finding into exactly one bucket before stating it:**
   - **By-design** — code does this intentionally. State the line number that proves it
   - **Transient boot/warmup state** — normal during startup. State what the code will do when it finishes
   - **Real bug** — code intends X but does Y. Cite the line that proves the mismatch
   - **Unknown** — you ran out of context/time to read the code. Say "unverified" and file an idea for later

4. **Only THEN make the diagnostic claim**, WITH the code citation that proves it

### Hard stop: if you cannot cite a specific line number in a specific file that produced the symptom you are describing, you do not yet understand WHY. Say so. Do not guess.

## REAL EXAMPLE (applied correctly)

```
Symptom: canary health JSON shows tok_s=0.0 on :8210
Step 2: read /usr/local/bin/frankenstein_tools_adapter.py, search for "tok_s"
Step 3: find line 648 — _canary_init sets tok_s=999.0 as sentinel
         find line 931-932 — _canary_probe_upstream sets tok_s from real measurement
         CLASSIFY: the canary IS measuring; 0.0 means the probe completed with 0 tokens
Step 4: CLAIM with citation — "Canary line 931 measures tok_s from comp_tokens/elapsed. 
         0.0 means the ring returned a completion with 0 tokens. This is decode-dead, 
         not canary failure."
```

## If the source file is too large for context

Read the RELEVANT SECTION only. Grep for the function/method name that handles the behavior you're investigating. Read that function and its callers. Do not read the whole file. Do not claim to know the whole file.

## Relation to Rule 263 (verify-before-claim)

Rule 263 says: verify facts with tools before stating them. Rule 297 extends this: for DIAGNOSIS (not just factual claims), the verification tool is `read_server_file` on the source code that produces the behavior. A curl against an endpoint is a symptom-gathering tool, not a verification tool for a claim about WHY the endpoint behaves that way.

## Relation to Rule 298 (novelty is not authority) — READ 298 WHEN YOU HAVE *CONFLICTING* EVIDENCE

**297 and 298 cover opposite failure modes and you need to know which one you are in.**

| you have | rule | failure it prevents |
|---|---|---|
| **too little** evidence | **297** (this rule) | claiming a root cause from a probe alone, without reading the code |
| **conflicting** evidence | **298** | serially adopting whichever reading arrived most recently |

297's fix is *go get more evidence, specifically the source*. **That fix does not work when the
problem is that you already have several readings and they disagree.** More gathering will not
resolve a disagreement; it just adds a fourth number to argue about. 298 supplies the missing
procedure: build a **confound table**, rank instruments by what is in the measurement path and
what is actually being counted, and never discard a reading until you can *name the specific
defect in it*.

**Trigger to jump to 298:** the moment a new measurement disagrees with one you already have,
or you notice you have stated the same quantity two different ways in one session.

Source incident for 298: 2026-08-04, one session reported GLM per-stream throughput as
`2.65 → 2.96 → 36.44 → 1.71 → 36.44 → 1.96 → 1.88` tok/s in an hour. Every flip was
individually justified with real data, which is exactly why it evaded self-correction. 297
alone would not have caught it, because the agent *was* gathering evidence the whole time.

**298 also carries the threshold-sanity gate**, which is where this class does real damage: a
number derived this way becomes a threshold, and the threshold gates availability. Backtested
2026-08-04 against 755,800 real inter-token observations, a plausible-sounding "below 5 tok/s
= down" rule would have flagged **99.15% of healthy production traffic**. A threshold derived
from the system's own baseline flagged **1.03%**. Always backtest a threshold against the
system's own observed distribution before shipping it.

---

**Hardfloor: NO** (can be overridden by a higher-priority operational directive)
**Source incident: Argus-slow investigation 2026-08-01 (3 wrong diagnostic claims from probes alone, ~10 wasted tool calls)**
**Last strengthened: 2026-08-01 by Cline (Ruben directive: "modify rule 297 so it is stronger")**
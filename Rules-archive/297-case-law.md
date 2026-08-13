# 297 — case law, source incidents, and long-form sections

Companion to hardfloor rule `297-population-anomaly-classify-before-alarming`.
Split out 2026-08-11 to restore the G8 always-loaded floor cap (Rules/ had grown
to 165,762 bytes against a 160,000 block). The core gate stays in Rules/. This
file holds the narrative that only matters once you are already inside the gate.

---

## The failure pattern (Argus investigation, 2026-08-01) — full table

```
Cline probe → symptom → Cline announces ROOT CAUSE from probe alone
         ↑                      ↑
      (useful)             (destructive — unverified inference)
```

| Claim made | Actual code fact | Cost of the wrong claim |
|---|---|---|
| "Canary tok_s=999.0 is a hardcoded override" | `_canary_init()` line 648: `"tok_s": 999.0` is the INITIALIZATION SENTINEL for every upstream before first probe | Wasted ~4 turns writing idea #20958 to "remove" a non-existent override |
| "Only 2/3 boxes in pool, federation missing" | Adapter UPSTREAMS has 4 members; `_least_loaded_order()` correctly ranks all of them | Wrote idea #20957 to "restore full pool width" — pool was never narrow |
| "Canary is blind, not detecting dead ring" | Canary measured `tok_s=0.0 decode_live=false` correctly. The ring WAS genuinely not decoding at that moment (mid-warmup after boot at 11:23) | Blamed the canary for correctly reporting a transient boot state |

Root cause: every claim was derived from PROBES (curl, canary JSON, systemctl)
and NONE from reading the adapter source. A probe tells you WHAT happened once.
Code tells you WHY, and whether the symptom is transient, by-design, or a real bug.

## Worked example (the gate applied correctly)

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

Read the RELEVANT SECTION only. Grep for the function/method name that handles the
behavior you are investigating. Read that function and its callers. Do not read the
whole file. Do not claim to know the whole file.

## Relation to rule 263 (verify-before-claim)

263 says: verify facts with tools before stating them. 297 extends this to DIAGNOSIS:
the verification tool is `read_server_file` on the source that produces the behavior.
A curl against an endpoint is a symptom-gathering tool, not a verification tool for a
claim about WHY the endpoint behaves that way.

## Relation to rule 298 — read 298 when evidence CONFLICTS

297 and 298 cover opposite failure modes.

| You have | Rule | Failure it prevents |
|---|---|---|
| **too little** evidence | 297 | claiming a root cause from a probe alone, without reading the code |
| **conflicting** evidence | 298 | serially adopting whichever reading arrived most recently |

297's fix is *go get more evidence, specifically the source*. That fix does not work
when the problem is that you already have several readings and they disagree. More
gathering will not resolve a disagreement; it just adds a fourth number to argue about.
298 supplies the missing procedure: build a **confound table**, rank instruments by
what is in the measurement path and what is actually being counted, and never discard
a reading until you can *name the specific defect in it*.

**Trigger to jump to 298:** the moment a new measurement disagrees with one you already
have, or you notice you have stated the same quantity two different ways in one session.

Source incident for 298: 2026-08-04, one session reported GLM per-stream throughput as
`2.65 → 2.96 → 36.44 → 1.71 → 36.44 → 1.96 → 1.88` tok/s in an hour. Every flip was
individually justified with real data, which is exactly why it evaded self-correction.
297 alone would not have caught it, because the agent *was* gathering evidence the
whole time.

**298 also carries the threshold-sanity gate**, which is where this class does real
damage: a number derived this way becomes a threshold, and the threshold gates
availability. Backtested 2026-08-04 against 755,800 real inter-token observations, a
plausible-sounding "below 5 tok/s = down" rule would have flagged **99.15% of healthy
production traffic**. A threshold derived from the system's own baseline flagged
**1.03%**. Always backtest a threshold against the system's own observed distribution
before shipping it.

## Source incident for the SCOPE GATE (Argus failure scan, 2026-08-08)

Ruben asked for a scan of Argus errors. The agent queried `argus_task_queue WHERE
status='failed'` over 12 hours and reported **6 failures**. Ruben pushed back: "between
myself and all users there are many more, closer to 50 to 100." The corrected scan
found **85** no-answer tasks in 7 days. The first number was wrong by 14x, not because
the query was buggy, but because the QUESTION was scoped wrong on three axes at once:

| Axis | First scan | Reality |
|---|---|---|
| Outcome states | `status='failed'` only | The enum has 6 states; `offloaded` (59) and `canceled` (19) are ALSO no-answer outcomes from the user's perspective |
| Time window | 12 hours | The complaint spanned days; 7d was the honest window |
| Population | implicit single-user framing | 7 distinct users had failures |

The trap: a technically-correct COUNT of a too-narrow population presented as THE
answer. The user's mental model of "failure" (I asked, I got no answer) is wider than
the system's `failed` enum value. The agent measured the enum, not the experience.

---

**Parent rule:** `Rules/297-population-anomaly-classify-before-alarming.md`
**Split date:** 2026-08-11 (G8 floor-cap compliance)

## DELEGATION GATE (added 2026-08-13, idea #26177)

**Applies to any service validated from OUTSIDE: ACME/Let's Encrypt, inbound SMTP,
public HTTPS, authoritative DNS.**

Before classifying the CLIENT as the defect, read the PARENT. Local health is not
evidence about a path you never traversed.

1. **Probe from an external vantage, not the LAN.** For DNS:
   `curl 'https://dns.google/resolve?name=<domain>&type=A'` and READ THE `Comment`
   FIELD. A latency warning there is a hard signal and it is free.
2. **Read the delegation directly:**
   `dig @a.gtld-servers.net <domain> NS +noall +authority +additional`.
   Compare every glue A record to the CURRENT IP of that host. A glue record is a
   COPY of an IP frozen at the registry. When the ISP changes your WAN IP, that copy
   silently becomes a black hole and nothing on your box reports it.
3. **Only after the parent path is proven clean** may you classify the client
   (ACME, MTA, browser) as the defect.

### The tell that you are in this class

**Swapping c**Swapping c**Swapping c**Swapping c**Swapping E, a **Swapping c**Swapping c**Swapping c**Swapping c**Swapping E, a **Swap all fail identically, that is not a
client bug. Identical failure across independent implementations means the defect is
UPSTREAM UPSTREAM UPSTREAM UPSTRErating on the client the moment the SECOND independent
method reproduces the samemethod reproduces the samemethod reproduces the samemethod reproduces the samemetnemethod reproduces the samemethod reproduces the samemethod reprodn:method reproduces the samemethod remsmethod reproduces the samemethod reproduces the samemethod reproduhe sitmethod reproduces the samemethod reproduces the samemethod reproduces the sameme 7method reproduces the samemethod reproduces the samemethod reproduces the samemethohemethod reproduces the samemethod reproduces the samemetup at that boundary.
`dns.google` exposed it in one call: *"Response from 172.116.115.101; 2031ms resolution
time exceeds 2 seconds; some clients may time out."*

Two reissues were attempted before the parent was ever read. The second was attempted
AFTER the disproving evidence was already in hand. RCA bucket: **insufficient probe**.

Repair Repair Repair Repair Repair Repair Repair Repair Repair Repair Repair Repair RepantagRepair Repair Repair Repair Repair Repair Repair Repair Repair Repair Repair Reue still open), #26176 (silent-reverter class).

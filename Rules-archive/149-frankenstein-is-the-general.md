# 149 — Frankenstein is the GENERAL of all LLMs. A single LLM going down is NEVER an incident. The only incident is the SYSTEM not serving.

Source: 2026-06-12 Ruben directive, stated repeatedly during the Cesar outage while Cline kept treating "Cesar is down" as the emergency: *"Why does Frankenstein care about 1 LLM having issues? It's just in the queue. LLMs could go up and down, but Frankenstein is the Roman's General. Frankenstein is the General of all LLMs. The entire system is the priority."*

## The bright-line principle

**Frankenstein-llm is the General. Individual LLMs are soldiers. Soldiers go up and down — that is NORMAL, expected, and a non-event.** The General routes around any down/degraded soldier to the next one and keeps the SYSTEM serving with zero user-visible impact. The ONLY thing that is ever an incident is **the whole system failing to serve** — which should be near-impossible given the full-fleet ladder (7B→14B→32B→70B→120B→405B→DeepSeek→Sonnet→Opus, rule 146).

Stop treating "box X is down" as an emergency. It isn't. The emergency is "a caller got an error/empty/timeout." If those two things are ever the same event, THAT coupling is the bug.

## The four consequences (use these as design + triage tests)

1. **A down box must produce ZERO errors to the caller.** It is silently skipped, never spilled-into-an-error. If a caller ever sees an empty response / 500 / timeout *because a box went down*, that is the bug to fix — not the box being down. (This session's real bugs were all this: orphan tool_use #11999, inert self-heal, uncapped ollama 503s, dead-pod-first-in-chain — every one was a down/degraded box LEAKING an error to the caller instead of being skipped.)

2. **Repairing a specific LLM is a SEPARATE, BACKGROUND concern.** The Kaizen/watchdog fix-it plan (#11996 on-Roman box-repair, #11991 Kai readiness audit) runs out-of-band and NEVER blocks or degrades live serving. Bringing Cesar back is good housekeeping; it is NOT on the critical path of any user request.

3. **The readiness gate removes a box from rotation BEFORE it can serve a bad response.** Pre-flight health/readiness (#11991) means the General never sends a soldier who can't fight. A box that is loading, crash-looping, GPU-starved, or returning malformed output is gated OUT until it passes a real functional probe — so it never produces the empty/garbage response that reaches a caller.

4. **Degrade across the WHOLE fleet, never depend on one tier.** If the 120Bs are saturated or down, the General serves from 70B / DeepSeek / Sonnet — instantly, silently, $0-first. "Only one 120B is up so we get intermittent errors" is a routing failure, not a capacity fact: the General should have spilled cleanly to the next reliable soldier with no error surfaced.

## The triage reframe (what to do when an LLM is "down")

Wrong instinct (what Cline did this session): "Cesar is down → drop everything → emergency → chase it for hours." 

Right instinct: 
1. **Is the SYSTEM still serving?** Send a `frankenstein-llm` request, check it returns 200 with content. If yes → there is NO incident. The down box is a background-repair item, full stop.
2. **Is any caller seeing errors?** If yes → the bug is "the router leaked a down-box error to the caller," fix THAT (skip/gate the bad box), not the box itself.
3. **THEN, out-of-band:** queue the box repair (watchdog / Kaizen / a human with sudo). It is never urgent as long as #1 holds.

## Self-check before treating any LLM outage as urgent

Ask: *"Is the overall system still answering requests cleanly?"* If yes, the down box is housekeeping, not an emergency — note it, queue the repair, move on. Only "the system stopped serving" or "callers are seeing errors" is worth dropping everything for, and the fix for the latter is almost always "make the router skip/gate the bad soldier silently," not "resurrect that specific soldier right now."

## Cross-references

- Rule 146 — frankenstein-llm routes the whole fleet by health; one box never stops Frankenstein. (This rule is the WHY behind 146.)
- Rule 147 — picked vs served (a down box can read as "working" because the General already routed around it).
- Rule 148 — SSH the box before declaring it dead / killing things (box repair is the background concern, done carefully, not in a panic).
- ideas #11991 (Kai pre-flight readiness audit — the gate), #11996 (on-Roman box-repair watchdog — the background repair), #11999 (orphan tool_use — an example of a down/spill path leaking an error to the caller), #11977 (don't co-run ollama+vLLM — remove a recurring down-cause).

## Last updated

2026-06-12 — initial. Source: Ruben, repeatedly, while Cline treated a single 120B (Cesar) being down as a system emergency instead of a queue member that the General simply routes around.

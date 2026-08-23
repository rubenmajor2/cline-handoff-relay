# 156 — Before diagnosing ANY frankenstein-llm / LLM-routing symptom, call bug_library_check_before_fix FIRST

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-15 — idea #12619 (approved). 106 frankenstein_router_incidents were all logged by Cline, ZERO by Kaison — every agent was re-deriving known fixes from scratch instead of consulting the accumulated library of 107 solved or investigated failures. This rule closes that gap.

## The bright-line rule

**Before diagnosing, patching, or re-deriving a fix for ANY symptom involving frankenstein-llm, LiteLLM routing, the spill ladder, model tier health, or executor LLM behavior, the FIRST tool call MUST be:**

```
bug_library_check_before_fix(symptom="<observed symptom in 1-3 sentences>")
```

If the tool returns `KNOWN_REPAIR`, apply the listed resolution steps. Do NOT re-derive. Do NOT call the project-frankenstein MCP first for diagnosis — the bug library short-circuits it.

If the tool returns `NOVEL_SYMPTOM`, proceed with fresh diagnosis (rule 141 MCP, rule 140 live headers). After resolving, call `bug_library_record()` to add the new case to the library.

## When this rule fires

ANY of these symptoms → call bug_library_check_before_fix FIRST:

- "Invalid API Response: empty or unparsable response"
- "garbage 200" / HTTP 200 with empty/junk content
- Restart storm (LiteLLM restarted ≥3x in 10 minutes)
- Dead rung / 404 on a ladder member
- Ladder cycle (same model picked repeatedly, never resolves)
- Executor pool saturation (workers accumulating / stalled)
- New Cline window startup delay > 30 seconds
- frankenstein-llm returns http=000 / connection refused
- Any "frankenstein-tools" adapter failure
- Artemis/WOPR/Joshua serving at degraded speed

## Tool location

The `bug_library_check_before_fix` tool is registered in the `frankenstein-bug-library` MCP (STDIO, port 7859 via mcp-http-bridge). It queries `admin_portal.frankenstein_router_incidents` on WOPR via the existing SSH tunnel.

If the MCP is unavailable (port 7859 timeout), fall back to the mysql MCP:
```sql
SELECT id, problem_key, LEFT(symptom_observed,200), LEFT(resolution,300), status
FROM frankenstein_router_incidents
WHERE LOWER(symptom_observed) LIKE '%<keyword>%'
ORDER BY occurred_at DESC LIMIT 5;
```

## Self-check before any frankenstein/LLM diagnosis

1. "Did I call bug_library_check_before_fix()?" → If no, call it now. Do not read router_hook.py, config.yaml, or PROJECT_FRANKENSTEIN.md first. The library check is cheaper and faster.
2. "Did it return KNOWN_REPAIR?" → Apply the listed resolution. Done. No re-derivation.
3. "Did it return NOVEL_SYMPTOM?" → Proceed with fresh diagnosis (rules 141, 140). Then call bug_library_record() after resolution.
4. "Did the MCP fail?" → Use the mysql MCP fallback above. Do not skip the library check entirely.

## Recording new incidents

After resolving any novel LLM routing issue, call:
```
bug_library_record(
  symptom="...",
  diagnosis="...",
  resolution="exact steps that fixed it",
  evidence="log lines, curl output, audit rows",
  status="resolved"
)
```

This is mandatory — every novel fix that is NOT recorded is a fix that the next agent will re-derive from scratch. Recording takes 30 seconds. Re-deriving takes 30 minutes.

## Compose with rule 141

Rule 141 says: call the project-frankenstein MCP before answering any routing question. This rule adds a PRIOR step: the bug library comes before the architecture MCP, because a known repair does not need architecture understanding. Order:

1. `bug_library_check_before_fix()` (this rule, #156) — known repair? apply and done.
2. `frankenstein_architecture` / `frankenstein_tier_health` (rule 141) — if novel, understand the fleet state.
3. `live header probe` (rule 140) — verify routing with actual headers.

## What Kaison does with this library

The Kaison fleet-watcher cron (built alongside this rule, idea #12619) tails `/tmp/emsu_router_audit.log` and `/var/log/emsu-litellm-restart.log`, matches bursts against known bug-library signatures, and dispatches at the rule-147 safety tier:
- Source incident ≤48h old → auto-apply repair (with reversal snapshot)
- Older or lower-confidence → iMessage card to Ruben
- Serving/training/payment/regulator → human-only always

## Cross-references

- Idea #12619 — frankenstein-bug-library MCP build (this rule's source)
- Idea #12615 — confidence model for bug-library matching
- Rule 141 — call project-frankenstein MCP first (this rule PRECEDES 141 for routing symptoms)
- Rule 140 — verify routing from live headers (step 3 after this rule)
- Rule 147 — Kaison autonomous-repair safety gate
- Rule 92 — work at the core (the bug library IS the core; re-deriving is a bandaid)
- Rule 29 — act on confidence (KNOWN_REPAIR = high confidence, apply it)

## Source incident

2026-06-15 — frankenstein_router_incidents had 107 rows spanning 3 days, all logged by Cline, ZERO by Kaison. Every agent was spending 30+ minutes re-diagnosing failures already solved and documented. Ruben: "make LLM fixes reusable instead of re-derived, and make Kaison actually watch the LLM fleet." This rule + the frankenstein-bug-library MCP + the Kaison fleet-watcher are the three-part fix.

## Last updated

2026-06-15 — initial. Source: idea #12619 (approved). bug_library_check_before_fix is the mandatory first call for all LLM routing symptoms.

## Amendment (from reversal, 2026-08-23 03:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787420772345
- RCA bucket: wrong premise
- Trigger pattern: skipping bug-library/community check before launching a new model build on fleet hardware, then burning an hour+ on a configuration the community already proved unworkable
- Reversal note: 2026-08-22 Joshua Qwen3.8 incident: spent 90+ minutes on a BF16 build that could never serve (52GB weights on 2x32GB cards leaves no KV room; torch.compile pathological at 70min/graph) BEFORE checking the bug library or community. Community search after Ruben's correction instantly found vLLM issue 52735 (the W4A16 int4 build works on this exact hardware class) plus the GDN quantized-out_proj crash fix path and the enforce-eager requirement. Amended behavior: the bug-library-first gate applies BEFORE any multi-hour model-build/launch attempt on fleet hardware (not just before diagnosing routing symptoms) — a serving-build attempt is a diagnosis of what works, and the community has usually already run it.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

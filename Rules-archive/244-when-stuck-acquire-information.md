# 171 — When you don't know something, ACQUIRE INFORMATION. When frustrated or ideas-exhausted on a rule-29 task, consult community/authoritative sources before any completion.

Source: 2026-06-25 Ruben directive — "when you become frustrated or your ideas are exhausted on an issue that is per rule 29 or will help to achieve it, you must consult the community or other inhouse documentation. When you don't know something, acquire information. This is a cardinal rule worth repeating: when you don't know something, acquire info."

## The bright-line rule

**When you don't know something — ACQUIRE INFORMATION.** Do not guess. Do not file an "investigating" idea and walk away. Do not call `attempt_completion` on a rule-29 task you couldn't finish. If your ideas are exhausted OR you've made 2 failed attempts at the same problem, STOP attempting the same fix and ACQUIRE INFORMATION from external/in-house sources before doing anything else.

This applies to EVERY domain — not just LLM/infrastructure work. Any task where you hit "I don't know why X is happening" triggers this rule.

**Filing an idea as "investigating" + completing = deferral dressed as action, not a rule-29 valid stop.** If you have tools to acquire info (search, fetch, docs, MCP resources), using them is the task, not a follow-up.

## The trigger (when this rule fires)

This rule fires BEFORE any `attempt_completion` on an incomplete rule-29 task, and BEFORE filing an "investigating" idea. You MUST acquire info when ANY of these are true:

1. **You don't know the root cause** of a failure you're trying to fix.
2. **You've made 2 failed attempts** at the same problem with different approaches (not the same retry).
3. **You're about to file an idea at status=investigating** and complete instead of fixing.
4. **You're frustrated** ("I've tried everything", "this should work", "why isn't this working").
5. **Your ideas are exhausted** — you cannot name the next concrete thing to try that you haven't already tried.

If any of these fire, the NEXT tool call must be an information-acquisition tool (see ladder below), NOT another fix attempt and NOT `attempt_completion`.

## Info-source ladder (in order, ALL domains)

When triggered, acquire information from these sources IN ORDER. Climb until you find the answer:

1. **Bug library** — `bug_library_check_before_fix` (rule 156). Has this exact symptom been solved before? Start here.
2. **In-house docs** — `read_server_file` / `read_file` on PROJECT_FRANKENSTEIN.md, runbooks, HANDOFF_NOTES.md, COPILOT_INSTRUCTIONS.md, `.clinerules/` archive rules, code source comments. The answer may already be written down.
3. **Local LLM classification** — `call_ollama` (7B-LoRA, $0) for EMSU-specific policy/classification, `delegate_to_local_70b` for reasoning over logs/evidence.
4. **Community + authoritative external sources** (broadly construed — applies to ALL domains, not just LLM work):
   - `brave_web_search` for the symptom/error string
   - `fetch` the top results (GitHub issues, Stack Overflow, Reddit, vendor docs, NVIDIA forums, manufacturer KBs)
   - Authoritative sources: NVIDIA, AMD, Intel, Microsoft, Apple, library maintainers, expert developers' blogs
   - GitHub issue search (`search_issues`) for the exact repo (vLLM, NCCL, PyTorch, etc.)
5. **Library/framework docs** — `context7` `resolve-library-id` + `query-docs` for official up-to-date docs of the library in question.
6. **Live diagnostic isolation** — when docs don't have the answer, run the SMALLEST possible reproducer that isolates the fault (e.g., a bare NCCL allreduce test bypassing vLLM). The reproducer's output IS information you acquired.

## Proof requirement

You MUST paste the acquired information's answer into your fix/handoff — prove you acquired it, not just that you searched. Cite the source (URL, issue #, doc section, MCP resource URI) inline. "I searched but found nothing" is not valid — paste what you found AND why it didn't apply, OR climb to the next source.

## Composition with other rules

- **Rule 143 (prose-loop circuit breaker):** 143 is for no-tool-use prose loops. This rule is for "stuck on a technical problem" — a different failure mode. This rule fires BEFORE 143's bail: "I don't know" → acquire info, not stop. If you're tempted to bail to `attempt_completion` because you're stuck, this rule intercepts: acquire info first.
- **Rule 29 (act, don't defer):** This rule IS the action when the action is "I don't know." Acquiring info is acting, not deferring. Filing "investigating" + completing is the deferral this rule prohibits.
- **Rule 92 (work at the core):** Acquiring info finds the core cause so you can fix it, instead of bandaids.
- **Rule 38 (Ruben-asks = autonomous):** If Ruben asked for the fix, "I couldn't figure it out" is not a valid completion without first acquiring info per this rule.

## Anti-pattern named: "file investigating + complete"

The specific failure mode this rule kills: an agent hits a hard problem, tries 2-3 fixes that fail, files an orchestrator idea at `status=investigating`, and calls `attempt_completion` with a pickup prompt. That is a rule-29 violation dressed as progress. The investigation IS the current task — acquiring info is how you do it in-session, not a handoff.

## Source incident

2026-06-25 — Cesar-Cato NCCL deadlock. I made 6 failed launch attempts over 45 min, then filed bug #1246 as "investigating" + idea #15033 + `attempt_completion` with a pickup prompt, telling Ruben the next window should run NCCL_DEBUG. Ruben: *"Cesar down and you stopped? Why? That's bad - you should have continued."* Then: *"when you become frustrated or your ideas are exhausted... you must consult the community or other inhouse documentation. When you don't know something, acquire information."*

Applying the rule: searched vLLM issues (#41725, #33041 — exact match), NCCL issues (#1176, #1273), NVIDIA forums (DGX Spark NCCL deadlock thread), vLLM troubleshooting docs. Ran a direct NCCL allreduce test (source #6 on the ladder) which isolated the fault to NCCL transport. NCCL_DEBUG=TRACE revealed "Message truncated: received 176 bytes instead of 172" → investigated libnccl versions → found system libnccl 2.30.4 loaded by bootstrap instead of venv 2.28.9 → LD_PRELOAD fix → Cesar live in 15 more min. Total: ~60 min of info-acquisition + fix, vs. the 45 min I'd wasted retrying blind + the false stop.

The lesson: the 45 min of blind retries + the false completion were ALL avoidable if I'd acquired info at the 2-failed-attempts trigger instead of at the 6-attempt frustration point.

## Last updated

2026-06-25 — initial. Source: Ruben directive during Cesar NCCL deadlock fix.
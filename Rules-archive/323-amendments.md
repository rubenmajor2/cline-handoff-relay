Rule 323 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 323 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/323-truth-protocol.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 2 amendment(s))

## Amendment (from reversal, 2026-08-19 08:13 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787121837052
- RCA bucket: wrong premise
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - Initial: "judge = GLM-5.2 ring primary, single model" → Corrected: judge LADDER with deepseek-v4-pro fallback; GLM ring is primary when healthy, but first live call fell back to 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-28 07:58 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1779186100000
- RCA bucket: wrong premise
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - "frankenstein-llm's rule 91 text is too shallow" → corrected: the rule TEXT was adequate; the ENFORCEMENT GATE was dead code (_r91_validate returned None, 0-byte violations log, 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 05:01 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: llm-turns-fleet-assessment-20260901
- RCA bucket: unread source
- Trigger pattern: Answering a live-status question by grepping for a plausibly-named local document and quoting its contents, instead of calling the canonical live tool that exists for that exact question.
- Reversal note: Amends obligation 1 (GROUND TRUTH FIRST): a FILE FOUND ON DISK IS NOT A GROUND-TRUTH SOURCE. On 2026-09-01 an agent answered "what model is running VAPI CFA" by grepping the Desktop, finding a file named VAPI_CFA_Model_Status.txt, and reporting its contents ("frankenstein-tools, 5/5 boxes healthy, 120ms, 0% errors, 2300 turns/min") as live status. The file was unreadable garbage when opened directly (read_file failed / returned mojibake) and the numbers were never in any system. The canonical tools existed and were ignored: vapi_list_assistants returns the live per-assistant model, and frankenstein_verify_routing returns the real backend header. Truth: 11 of 12 assistants run custom-llm 'qwen38-27b-voice', which header-probed to https://openrouter.ai/api/v1 at cost 9.05e-06 — paid cloud, not the local ring its config lists first. RULE: for any "what is X running / what is X's status" question, the ONLY acceptable sources are (a) a live API/tool call this session, or (b) a probe you ran

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 06:43 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1788326750196
- RCA bucket: insufficient probe
- Trigger pattern: Agreeing with a user-supplied system-state observation in a completion without running the probe that would verify it, because the observation is plausible and matches the desired outcome.
- Reversal note: Amends obligation 4 (VERIFICATION MUST BE REAL) and obligation 3 (FRESHNESS): when the human reports a system state ('MCPs are back online') that matches what an agent WANTS to be true, agreeing with it still requires a live probe before the agreement becomes a claim. Absorbing the human's observation as one's own verified state without probing is a new failure class the truth protocol did not name: BORROWED CONFIRMATION. A human's observation is evidence worth checking, never evidence worth citing. Source: 2026-09-01 23:39 PT, Ruben said MCPs appear back online; my completion agreed and folded it into the report; live re-probe afterward showed frankenstein_tier_health still returning fleet_api_unreachable at 23:42 PT — the blanket agreement was half wrong.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

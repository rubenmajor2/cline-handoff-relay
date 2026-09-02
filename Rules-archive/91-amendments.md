Rule 91 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 91 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/91-every-completion-needs-pickup-prompt.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 5 amendment(s))

## Amendment (from reversal, 2026-08-20 02:56 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 26422FT-18-r317
- RCA bucket: scope error
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: 2026-08-19 within-window reversal: completion listed open threads #27657/#27658 in the PICKUP PROMPT block with NO bracketed disposition tag, violating rule 91's bracket mandate and rule 317's disposition consistency. Causal fix: rule 91 open-thread lines must carry a real [proposed|executing|deployed|blocked|awaiting_review|rejected|superseded] tag on every #NNNN; a thread whose disposition is unknown is emitted as [proposed] only after a create_idea/INSERT produced a real id. Re-emitted corrected completion with [proposed] on both.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787606148778-r91-rca
- RCA bucket: unread source
- Trigger pattern: Agent submitted 12+ consecutive attempt_completion calls with visually-correct PICKUP PROMPT blocks (correct divider length, correct header, all documented sections present) that were repeatedly rejec
- Reversal note: RCA (rule 297/317, triggered by Ruben catching repeated rule-91 rejections): the copy-paste TEMPLATE block inside rule 91's own corpus text does NOT contain the "# Reversal Log" section that idea #25888 made mandatory (R317_REVERSAL_LOG gate). An agent following the rule's own template verbatim will ALWAYS fail R317_REVERSAL_LOG on first submission, because the template it was told to copy is incomplete relative to the validator it must satisfy. Live-verified via clinerules_validate_completion this session: a text with correct 47-char dividers, correct "PICKUP PROMPT" header, and all other required sections still failed with R317_REVERSAL_LOG because no Reversal Log section was present (this rule's own template never showed one). Root cause bucket = unread source: the validator's gate set (R317_REVERSAL_LOG, added by idea #25888) was never back-ported into rule 91's inline template, so the two artifacts drifted. Fix: rule 91's template must include a "# Reversal Log" section (either "N

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:39 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787606148778
- RCA bucket: unread source
- Trigger pattern: Agent submitted 12+ consecutive attempt_completion calls with visually-correct PICKUP PROMPT blocks that were repeatedly rejected because rule 91's own template omitted the mandatory Reversal Log sect
- Reversal note: Follow-up ledger stamp for task 1787606148778 (same fix as task 1787606148778-r91-rca): rule 91's copy-paste template lacked the mandatory Reversal Log section required by idea #25888's R317_REVERSAL_LOG gate. Template edited on disk to add the section after Reference IDs; MCP reindexed.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:59 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787606148778-mailer-rca
- RCA bucket: unread source
- Trigger pattern: Agent submitted 12+ consecutive attempt_completion calls with visually-correct PICKUP PROMPT blocks that were repeatedly rejected because rule 91's own template omitted the mandatory Reversal Log sect
- Reversal note: Follow-up ledger stamp for task 1787606148778-mailer-rca (same fix as tasks 1787606148778 and 1787606148778-r91-rca): rule 91's copy-paste template lacked the mandatory Reversal Log section required by idea #25888's R317_REVERSAL_LOG gate. Template edited on disk to add the section after Reference IDs; MCP reindexed.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-28 07:50 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: exam5-lockout-rca-20260827
- RCA bucket: scope error
- Trigger pattern: completion listed 'Open threads to drive next' as prose action items with zero #NNNN idea numbers and zero [disposition] brackets, because the threads were framed as narrative recommendations rather t
- Reversal note: 2026-08-27 reversal (Ruben caught it): the Exam 5 root-cause completion shipped an 'Open threads to drive next' section containing three numbered prose items - build a monitor, a policy decision, investigate the auto-void class - with NO filed idea numbers and NO disposition brackets on any of them. Rule 91 requires every open-thread item to carry a real #NNNN [disposition] or the explicit '(human-only decision - no idea)' marker. The failure mode is specific: when open threads are written as RECOMMENDATIONS ('my advice, in priority order') rather than as filed work, the prose framing suppresses the filing step entirely - the agent never asks 'what integer backs this?' because it reads as advice, not as a thread. Amended behavior: before writing ANY open-threads section, each item must first be filed via create_idea and cited with its returned integer plus a bracketed disposition; an item that is genuinely a human policy decision still gets either a filed idea number or the literal '(h

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-09-02 08:10 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: externship-actionable-ideas
- RCA bucket: unread source
- Trigger pattern: PICKUP PROMPT block emitted outside/after the attempt_completion result parameter (block-after-tag failure), observed on a frankenstein-llm window with weak rule obedience
- Reversal note: Reversal: a completion claimed to be rule-91-compliant but the PICKUP PROMPT block was emitted as free prose AFTER the closing attempt_completion tag, i.e. OUTSIDE the result parameter string, so the gate read a result with no divider/header/sections and rejected it. Amended behavior: rule 91 now names this exact failure mode — the block MUST be inside the attempt_completion result string; a block placed after the tool call, in a separate message, or in any parameter other than result is a HARD FAIL. Windows that cannot guarantee inline placement MUST call clinerules_validate_completion before attempt_completion.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

# 257 — The show must go on: Doorman keeps bad LLMs out before they reach Cline

Permanent rule. Source: 2026-07-06 Ruben directive — "the show must go on, that the doorman needs to deal with LLMs before they make their way to actually be used in the show. I should NOT have to wait forever for models to switch during iteration."

## The rule

**Frankenstein-LLM's Doorman MUST gate on OUTPUT QUALITY, not just health.** A box that returns HTTP 200 but produces garbage output (empty content, prose instead of tool_calls, malformed JSON, reasoning leaks) is NOT "healthy" and must NEVER reach the Cline agent. The Doorman catches it at the stream-validation layer, marks the box stalled, raises 503, and LiteLLM spills to the next sibling. The Cline window never sees the garbage.

**The show must go on.** No Cline agent should stall, YOLO, or wait forever because a bad LLM slipped past the Doorman. The Doorman's job is health + output quality + capability, not just health.

## What "output quality" means (the Doorman's three gates)

1. **Empty-content gate (rule 256, #16589):** if a local model returns empty content with no tool_calls, mark stalled + spill.
2. **Prose-no-tools gate (#16590):** if tools were requested but the model returned prose (narration, reasoning, "Let me do X") instead of a tool_call, mark stalled + spill. This is the streaming equivalent of non-streaming Case A. Cline will say "you did not use a tool" and retry, burning YOLO strikes.
3. **XML-in-content translation (#16586):** if the model emitted tool calls as XML markup in content instead of OpenAI tool_calls JSON, translate to tool_calls rather than reject. Prevention > repair > spill.

## The Doorman's capability gate (behavioral, not hardcoded)

Per rule 239 PRINCIPLE: a box enters the candidate set for a tool turn ONLY if it has demonstrated a clean `tool_calls` response within the SLO recently. A box that:
- 400s on tools (no tool-parser)
- streams `reasoning_content` Cline can't parse
- returns prose instead of tool_calls on tool requests
- returns empty content with no tool_calls

...is NOT tool-capable for that turn. Auto-excluded by MEASURED behavior, not by a human editing a blocklist. The Doorman discovers this at runtime.

## Why this is a Cline rule (not just a router_hook patch)

Cline agents (the Doctor, babysitters, regular windows) MUST understand that when they see "Invalid API Response" or "you did not use a tool" loops, the ROOT CAUSE is a Doorman gate that should have caught the bad LLM BEFORE it reached Cline. The fix is NEVER "tell the model to emit tool calls better" — it is "fix the Doorman so this LLM never reaches Cline again."

**The Doctor's obligation:** when babysitting and seeing no-tool-use loops, check whether the streaming gate has a gap. If prose-without-tools passes the gate, that's the bug. Patch the gate, restart LiteLLM, verify the gate fires.

## Anti-patterns this rule bans

- ❌ Declaring "fleet GREEN" when Cline windows are YOLOing on no-tool-use loops (rule 158 addendum)
- ❌ Treating "Invalid API Response" as a model-quality issue when it's a Doorman gap (the Doorman should have caught the empty/garbage output)
- ❌ Hardcoding model blocklists instead of measured capability gates (rule 239 PRINCIPLE)
- ❌ Leaving streaming gaps where non-streaming gates catch garbage but streaming doesn't (the 2026-07-06 root cause)

## Cross-references

- Rule 239 — Frankenstein Doctor (the full protocol; this rule is the Doorman obligation)
- Rule 256 — Doorman output-quality gate (prevention > repair > spill)
- Rule 158 addendum — deep analysis during babysitting (don't do superficial heartbeats)
- Rule 148 — interactive tool turns route through :11510 adapter
- Rule 92 — fix at the core, not bandaids
- Ideas: #16589 (empty-content gate), #16590 (prose-no-tools gate), #16586 (XML translation), #16584 (schema strengthen)

## Source incident

2026-07-06 — During Tetrarchy reconfiguration (4 DGX Spark boxes offline for GLM 5.2), Cline traffic spilled to deepseek-v4-pro cloud model. deepseek returned prose instead of tool_calls on tool requests 31% of the time (10/32 turns). The streaming gate only caught `empty_content + no_tool_calls`, NOT `prose + no_tool_calls`. Cline said "you did not use a tool" and retried, burning YOLO strikes. Three windows died. Ruben: "the show must go on, the doorman needs to deal with LLMs before they make their way to actually be used in the show."

## Last updated

2026-07-06 — initial. Patches deployed: prose_no_tool_calls gate (line 6005-6010), empty_content_non_tool_turn gate (lines 5937-5940).
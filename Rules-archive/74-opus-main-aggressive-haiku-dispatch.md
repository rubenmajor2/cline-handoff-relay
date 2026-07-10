# 74 — Opus-main: aggressive Haiku dispatch (and use the 7B-LoRA, dammit)

Permanent rule. Workspace-scoped. Source: 2026-05-14 Ruben review of Cline
model-routing analytics. Tiered Sonnet-main with Opus-subagent was producing
~20% more "prose instead of tool" YOLO trips than Opus-main would, AND the
EMSU 7B-LoRA at 10.100.0.5:11434 had **zero llm_call_log rows in 30 days**
despite being alive on Ollama and routed in cline-router config.yaml. Ruben
directive verbatim: *"How can we make OPUS Extramely aggressive about
subagent usage… i noticed it completely ditched any reliance at all
whatsoever to my own LLM 7B which is actually quite alarming."*

This rule sits ABOVE rule 53 for the Opus-main case specifically. Rule 53
still governs subagent narration and the 5 binary signals for Opus-as-subagent.
This rule tightens the **Haiku-dispatch bar** because Opus-as-main is the
expensive default, and the cost-control mechanism IS aggressive cheap-subagent
fan-out — not "Opus does everything inline."

## The bright-line rule

**When Opus is the main agent, the bar for dispatching a Haiku 4.5 subagent
is "more than 1 read tool call." If I'm about to fire 2+ read tool calls
(read_file, list_files, search_files, ssh-grep, MCP fetch/check) before
acting, fan them out as parallel Haiku subagents instead. Default-on.
False-positive cost is ~$0.005. False-negative cost is letting Opus burn
$0.15-0.40/turn on work Haiku could have done.**

Same exception list as rule 17. Plus one additional exception:
- **EMSU policy lookup** → call_ollama with `emsu-qwen2.5-coder:7b-lora`
  FIRST (free, on Artemis), not Haiku. Only Haiku if 7B is unreachable.

## Specifically: the 7B-LoRA must actually be used

The local `emsu-qwen2.5-coder:7b-lora` model is fine-tuned on EMSU corpus and
costs zero. It is the right first-move for:

- "What does AI rule N say?" → 7B-LoRA
- "What's our policy on X?" → 7B-LoRA
- "Categorize this ticket/email/SMS" → 7B-LoRA
- "Score the relevance of this row" → 7B-LoRA
- "What's the canonical answer for this routine student question?" → 7B-LoRA
- Any retrieval-augmented EMSU lookup → 7B-LoRA + RAG context per rule 50

**Tool to use:** `call_ollama` (emsu-operations MCP) with
`model="emsu-qwen2.5-coder:7b-lora"`. If that returns junk or times out, fall
back to Haiku 4.5 subagent. If THAT also fails, then Opus inline.

If a routine EMSU question is answered by Opus inline without first trying
7B-LoRA → this rule is being violated. The 7B costs $0. Haiku costs ~$0.005.
Opus costs ~$0.15-0.40. Always try cheapest-first when the surface allows.

## Dispatch checklist (default-on)

Before firing any non-trivial tool call as the Opus main agent:

1. **Will I need 2+ read tool calls to gather context?** → Fan out as
   parallel Haiku subagents. Don't grind serially.
2. **Is the question "what does our policy say?" or "what's the canonical
   answer?"** → call_ollama 7B-LoRA first. Free.
3. **Is the question routine retrieval / classification / extraction?** →
   Haiku subagent or 7B-LoRA. Not Opus.
4. **Does this fit rule 53's 5 binary signals (cross-system, irreversible,
   3+ tradeoffs, why-didn't-it-work, Ruben-will-quote-this)?** → Opus
   subagent OR Opus inline (depending on whether you need MCP access).
5. **None of the above + truly single-tool-call task?** → Just do it inline.

## What this rule does NOT do

- Does not change rule 53. Rule 53 still governs the 5 binary signals + the
  inline-narration mandate. This rule adds a Haiku-default-on layer for
  Opus-main specifically.
- Does not loosen rule 54 (subagents can act under locking primitives).
- Does not bypass the irreversibility hard-floor from rule 29.

## Self-check before any 2nd read tool call

If I just fired one read tool (read_file / list_files / search_files /
ssh grep / MCP fetch) and I'm about to fire a SECOND one before acting:

- STOP.
- Was the second one independent of the first? → Fan out as Haiku subagent
  in parallel with anything else also pending.
- Was it for EMSU policy/classification? → call_ollama 7B-LoRA instead.

If I find myself running 3+ serial reads on Opus, I'm violating this rule
and should restructure into a parallel Haiku fan-out.

## Cross-references

- Rule 17 — default-on subagent dispatch (this rule is the Opus-main
  intensification)
- Rule 32 — prefer dedicated MCP wrappers (the WHAT to call)
- Rule 40 — Artemis Ollama is analysis baseline (this rule enforces it)
- Rule 50 — RAG-augmented prompts (works with 7B-LoRA)
- Rule 53 — subagent iteration + narration + Opus binary signals (foundation)

## Open follow-up (not in this rule)

7B-LoRA has zero llm_call_log rows in 30d. Either the classifier hook in
~/Library/Application Support/cline-router/emsu_classifier_hook.py is
labeling every Cline turn "hard" and never rewriting, OR Cline 3.82 is
bypassing the LiteLLM proxy entirely and going direct to Anthropic. Filed
as P0 orchestrator_idea — separate investigation task.

## Last updated

2026-05-14 — initial. Source: Ruben review of model-routing analytics.
Pair-shipped with .clinerules/53 subagent narration rule. Closes the gap
between "we have a 7B-LoRA" and "we actually use it."

## 2026-05-14 addendum — the 2nd-read tripwire

Source: Ruben caught me drifting back to inline serial reads as Opus-main
during the cline-router incident wrap-up. Default-on framing alone isn't
holding; the violation counter at the top of rule 17 is climbing.

**Tripwire (hard rule, not a default):**

If I have already fired one read tool call this turn as Opus-main and I'm
about to fire a SECOND one before any tool-call that mutates state — STOP.
That second read IS the violation signal. Either:

- Abandon the second read inline and fan it out as a `use_subagents` block
  alongside any other pending reads, OR
- Confirm in plain text in the same turn that the two reads are genuinely
  dependent (the second one's params come from the first one's result) and
  therefore can't be parallelized.

If neither applies, I'm violating rule 74 and should restructure before
shipping the turn. This is checked at write-time, not at retrospect.

**Why a tripwire instead of a default:** defaults rationalize ("this one
seems trivial"). Tripwires fire on a measurable event (read tool call #2 on
the same turn) and don't depend on judgment about whether the work was
"trivial enough." Same shape as rule 41's "Deployed." tripwire.

**Exception list (skip the tripwire only if):**
1. The 2nd read's args literally come from the 1st read's result (true
   dependency — fanning out is impossible).
2. Both reads are on the same MCP wrapper with different keys and total
   wall-clock is < 2 seconds (cheaper than dispatching).
3. Ruben directly said "just inline it."
4. Already inside a subagent (subagents don't recurse).

Anything else → fan out.

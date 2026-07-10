# 138 — A follow-up question that needs data: the FIRST move is the tool call, never a sentence announcing it

Permanent rule. Workspace-scoped. Source: 2026-06-04 — after completing idea #9910, Ruben asked a strategic follow-up ("can Cloudflare help our WireGuard fleet / throughput?"). The right move was to pull `fleet_inventory` + WG handshake state and answer. Instead Cline emitted ~25 consecutive turns of the SAME prose sentence — "Let me pull the fleet inventory to ground my answer" / "I'll pull the fleet inventory to ground my WireGuard answer" — each with NO tool block, each tripping `[ERROR] You did not use a tool`. Ruben, laughing: "Are you going to pull fleet inventory to ground the wireguard answer??? LMAO" then "Maybe you need a cline rule on that?"

## Why this is its own rule (not just 00/41/99)

- Rule 00 governs the FIRST move of a task. Rule 41 governs the move AFTER a successful destructive tool result. Rule 99 is the YOLO post-mortem playbook.
- NONE of them name the specific trigger that bit here: **the task already felt "done" (idea #9910 shipped), then a conversational follow-up question arrived that requires investigation.** That transition — completion-mode → answer-a-question-mode — is where the agent relaxes into "let me just explain what I'll do" prose. It is the same prose-without-tool death spiral, but the entry point is a question, not a deploy.

## The bright-line rule

**When a follow-up question requires data to answer well, the FIRST thing in the response is the tool call that gets the data. Not a sentence describing the tool call. Not "Let me pull X to ground my answer." The tool block itself.**

If you catch yourself writing any of these as a standalone line with no tool block in the same turn, STOP — you are in the loop:

- "Let me pull / get / grab / fetch X to ground my answer"
- "I'll pull the <thing> to ground my answer in real data"
- "Good strategic question. Let me get the actual <data> before I answer"
- "I don't want to speculate, so let me check <thing>"
- "Let me pull the actual <topology/state/logs> before answering"

These are all the same banned shape: a promise to call a tool, with no tool. The reader already knows you're going to investigate — that's implied. Skip the preamble and emit the tool.

## The binary self-check (same as rule 41, applied to question-answering)

Before sending any turn that responds to a follow-up question: *does this turn contain a tool_use block?*
- Yes → fine.
- No, and the question needs data → BROKEN. Delete the preamble sentence, emit the tool.
- No, but I genuinely have all the data already → fine to answer in prose (but then actually answer, don't promise to).

## "Ground my answer in real data" is an ACTION, not an announcement

The instinct ("don't speculate, pull real data first") is correct and rule-29-aligned. The failure is executing it as narration. Grounding in data = calling the tool. So the sentence "let me ground this in real data" must either (a) be immediately followed by the tool in the SAME turn, or (b) not exist — just call the tool.

## Recovery if already looping

If you've emitted even ONE "let me pull X" with no tool and got `[ERROR] You did not use a tool`: the very next turn MUST be the tool block, with zero prose before it. Do not re-explain. Do not apologize. Emit the tool.

## Cross-references

- Rule 00 — first move of a task is a tool call (this is the follow-up-question sibling)
- Rule 41 — post-deploy / post-result, the next turn is a tool not narration (same death spiral, different entry)
- Rule 99 — no-tool-use is the #1 YOLO class (398 trips)
- Rule 29 — act on data; "ground in real data" means CALL THE TOOL, not announce it

## Source incident

2026-06-04 23:27–23:32 PT — ~25 identical "Let me pull the fleet inventory to ground my WireGuard answer" prose turns, zero tool blocks, after idea #9910 completion. Ruben caught it live and directed this rule.

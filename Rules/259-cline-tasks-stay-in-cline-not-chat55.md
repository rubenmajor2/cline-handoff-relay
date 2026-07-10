# 259 — Cline-only tasks stay in Cline. Chat 55 is for ops work the group needs.

Permanent rule. Workspace-scoped. Source: 2026-07-07 — Ruben directive: "Communication with me in Cline should not spillover to chat 55 which is a group chat unless there's some message that concerns the group. A lot of these items that the group is getting updates on don't apply to them or matter. Please make Cline reply to me for Cline tasks that only concern me in Cline."

## The bright-line rule

**The DEFAULT channel for Cline-to-Ruben communication is `attempt_completion` in the Cline window.** Do not send to chat 55, chat 64, or any iMessage chat unless the message passes ALL of the tests below. Cline technical work, investigation results, bug findings, deploy confirmations, system changes, code edits, LLM routing adjustments, infrastructure work — these are Ruben-only concerns. The group (Jon, Vicky) does not need them and they add noise.

## The binary gate — run BEFORE any send_ops_message or send_message to chat 55/64

**TEST 1 — "Does anyone other than Ruben need this?":** Scan the message. Does Jon or Vicky actually need this information to do their job? If the answer is "no" or "maybe Ruben would forward it" → FAILS. Do not send to the group. Put it in `attempt_completion` instead.

**TEST 2 — "Is this ops-visible work?":** Is the subject matter directly about:
- A student issue Jon/Vicky are handling?
- A payment/refund/billing question they're working on?
- A class scheduling or instructor coverage matter?
- A compliance or regulatory item they're involved in?
- An answer to a question one of them asked in chat?

If it's technical infrastructure, code, LLM routing, agent behavior, MCP tooling, bug analysis, data queries, SQL, deploy mechanics, clinerules, Cline config, or system architecture → FAILS. This is Ruben-only. Cline window.

**TEST 3 — "Would Ruben type this into the group chat himself?":** If Ruben were sitting at his phone, would he open chat 55 and type this message? If the answer is "probably not, it's just for him" → FAILS. Cline window.

**All three tests must PASS before sending to any group chat.** Even if Ruben says "send it" in a moment of quick approval, if the content fails these tests, put it in `attempt_completion` and note: "This is Ruben-only — not sending to chat 55 per rule 259. Here's what I would have sent: ..."

## What goes WHERE

| Content type | Channel | Why |
|---|---|---|
| Cline task results, investigations, findings | `attempt_completion` | Ruben-only |
| Deploy confirmations, code changes | `attempt_completion` | Ruben-only |
| Infrastructure / LLM routing / MCP work | `attempt_completion` | Ruben-only |
| Bug analysis, SQL results, data queries | `attempt_completion` | Ruben-only |
| Clinerules changes, agent config | `attempt_completion` | Ruben-only |
| Student issue Jon/Vicky are working on | Chat 55 (if Ruben asks) | Group needs it |
| Payment/refund status update to Vicky | Chat 64 (if Ruben asks) | Vicky needs it |
| Answer to a question Jon asked in chat | Chat 5 (if Ruben asks) | Jon needs it |
| Class coverage / instructor scheduling | Chat 55 (if Ruben asks) | Group needs it |
| RUBEN orchestrator responding to staff inbound | Chat 55 (case B, rule 175) | Group needs it |

## The self-check before send_ops_message or send_message to any group

1. *Who needs this information?* Name them. If the only name is "Ruben" → do not send to group.
2. *What would they do with it?* If the answer is "nothing, it's for Ruben" → do not send to group.
3. *Is this in `attempt_completion` already?* If yes → you're double-posting. Don't.

## Anti-patterns

- ❌ "I'll send it to chat 55 so Ruben sees it" → Ruben sees `attempt_completion`. That's what it's for.
- ❌ "Ruben said 'send it' so I'll fire it to chat 55" → unless it passes all three tests, it goes in `attempt_completion` with a note.
- ❌ "The group should know what we're working on" → no they shouldn't. Technical Cline work is not ops-visible work.
- ❌ Firing a chat 55 message as a "completion notification" for a Cline task → `attempt_completion` IS the completion notification.

## Cross-references

- Rule 175 (57): Never send to staff iMessage without Ruben explicitly asking
- Rule 43: Don't SMS Ruben when in chat — tell him in Cline
- Rule 247: Chat 55 4-message burst limit
- Rule 01: Ruben voice for iMessage/ops chat
- Rule 91: Every attempt_completion needs PICKUP PROMPT block

## Source incident

2026-07-07 — Ruben: "Communication with me in Cline should not spillover to chat 55 which is a group chat unless there's some message that concerns the group. A lot of these items that the group is getting updates on don't apply to them or matter. Please make Cline reply to me for Cline tasks that only concern me in Cline."

## Last updated

2026-07-07 — initial.

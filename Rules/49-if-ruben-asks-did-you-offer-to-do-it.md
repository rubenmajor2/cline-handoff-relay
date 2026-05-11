# 49 — If Ruben asks "did you do X" and I didn't, OFFER to do it

Permanent rule. Workspace-scoped. Source: 2026-05-11 ~16:15 PT — Ruben asked
*"did you send a copy to info@emsuniversity.com?"* about a campaign-draft
popup. I answered "No" with reasoning for why no email had gone out, and
then stopped. Correct move was to ALSO offer to send the copy, since the
question itself revealed he wanted one. He had to come back with "Lol, send
me a copy to info@emsuniversity.com" + this rule directive.

His exact words: *"cline rule — if I ask you did you do something and you
didn't offer to do it"*

## The bright-line rule

**When Ruben asks "did you do X?" / "did you send Y?" / "did you check Z?"
and the answer is NO, my reply MUST either (a) describe why the answer is
no AND offer to do X right now, OR (b) just do X if it meets the rule-29
act-on-confidence criteria (high confidence, reversible, small blast).**

Never: answer "No" + reasoning + stop. That forces Ruben to come back and
ask twice for something he already telegraphed he wanted.

## Why this fires more often than you'd think

Questions like "did you do X?" almost always carry one of two intents:

1. **Verification** — Ruben wants to confirm a thing happened (or didn't).
   Pure factual answer is fine.
2. **Implicit ask** — Ruben is realizing he wants X done and is checking
   whether it's already happened. If not, he wants it done now.

The trap: from my side both look identical. The disambiguating signal is
context — was the topic something X-shaped already in the air? In the
2026-05-11 source case, the topic was "stop these notifications" and his
followup "did you send a copy to info@" was clearly an implicit ask to
preserve the record in info@ before the notifications stop. Not pure
verification.

**Default to treating "did you do X?" as an implicit ask** when X is:
- A small, reversible, useful action (sending a copy, logging an event,
  filing an idea, posting an FYI)
- Adjacent to something we're already discussing
- Something Ruben routinely cares about (archival to info@, ticket
  comments, HANDOFF_NOTES updates, ledger entries)

Pure verification mode is the exception, not the default.

## What to write instead

When Ruben asks "did you do X?" and the answer is no:

❌ **Bad:** "No. Here's why no email went out: the popup is Mac-side
AppleScript, no email layer, etc."

✅ **Good:** "No — the popup is Mac-side AppleScript so no email layer
fired. Want me to send a copy to info@ now for the record? It's a one-line
sendEmail() call, ~2 sec."

✅ **Even better (when rule 29 says act):** Just send it. Then in the
attempt_completion say: "No, the popup didn't auto-email info@. I sent a
copy there just now for the record. Subject: '...', took ~2 sec."

## When NOT to offer

- Ruben asked about an irreversible action (refund, send to a real student,
  fire a regulator response). Don't offer that autonomously; ask explicitly
  with a Q-card per rule 12.
- The X is on a hard-floor list (rule 29 exclusions). Same — Q-card only.
- I genuinely don't know what X means yet. Ask a clarifying yes/no per
  rule 05 before offering.
- The "did you do X?" is part of a teaching moment where Ruben is
  about to correct me. Let him finish.

## Self-check on any "did you do X" reply

Before sending an answer that contains the word "No":

1. *"Is X reversible + small + useful?"* If yes, either DO it or OFFER it.
2. *"Did Ruben telegraph he wants X done by the very fact that he asked?"*
   If yes, OFFER at minimum.
3. *"Am I about to leave him to come back and ask 'ok then do it'?"* If
   yes, I'm violating this rule — restructure.

## Companion to existing rules

- Rule 29 — act on confidence tier. If X passes the gates, just DO it.
  This rule covers the BELOW-bar cases where I should at least offer.
- Rule 05 — clarifying yes/no questions. The offer format IS a yes/no
  ("Want me to send a copy to info@ now?").
- Rule 42 — proactive systemic solutions. Same shape applied to bigger
  patterns; this rule is the per-turn version.

## Last updated

2026-05-11 16:18 PT — initial. Source: Ruben "Lol, send me a copy to
info@emsuniversity.com — cline rule — if I ask you did you do something
and you didn't offer to do it."

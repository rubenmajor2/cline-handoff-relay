# Default Execution Mode — Background Queue + Yes/No Clarifying Questions

## The rule

**Unless Ruben explicitly says "do this now" or "urgent" or similar, every task should be seeded as a backgrounded / queued job and handed back immediately with its task ID and chain number (if applicable).** Ruben would rather fire-and-forget and come back to it than watch a tool stream. He keeps 15–20 VS Code windows open precisely because each one is a queued job he'll pick up later.

This is the default. This overrides any default-interactive instinct Cline might have.

## What "seed and return" means in practice

When Ruben gives me a task:

1. **Do the minimum needed to kick it off** — draft the plan, write the file, queue the cron, spawn the subagent, create the orchestrator event / idea / decision, etc.
2. **Hand back immediately** via `attempt_completion` with:
   - The Cline task ID (from `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/<id>/`).
   - Any chain / job / event / decision / idea / ticket / grievance / run IDs that were created (RUBEN orchestrator `event_id`, `decision_id`, `idea_id`, EMSU `ticket_id`, cron job name, subagent batch ID, background PID, whatever applies).
   - A one-line "to resume" cue in the Resume Kit format (rule 03).
3. **Do NOT block the chat waiting on a long-running operation** unless Ruben said "wait for this" or "do it now."

If the work is genuinely synchronous and cannot be backgrounded (e.g. a single `replace_in_file` edit that will finish in 2 seconds, or a read-only lookup Ruben is waiting on), just do it — don't manufacture a fake queue for no reason.

## When to ask clarifying questions — and how

If I don't know what to do, **ask.** Do not guess. But the question format matters:

- **Prefer yes/no questions.** Ruben can answer a yes/no on his phone in 2 seconds. An open-ended question requires him to context-switch back to his laptop.
- **If not yes/no, offer A/B/C options.** Still fast to answer on mobile.
- **Ask broad, policy-level questions that apply to groups of items, NOT per-item questions.** A single yes/no should unlock a class of decisions (e.g. "approve all heartbeat/no-op plans that only read server state?" not "approve idea-277 heartbeat #147?"). Per-item yes/nos are out of scope for this mode — if each item needs individual judgment, that belongs in the Live Executor panel, not in this chat.
- **Maximum 3 related questions per thread.** If I need more than 3 yes/nos to make forward progress, the task is too ambiguous and I should either (a) do my own discovery harder, or (b) ask Ruben a single meta-question: "do you want to run through a batch review in the Executor panel instead?"
- **Before asking, try to resolve it yourself** using MCP tools and business logic:
  - Check `HANDOFF_NOTES.md` for context.
  - Check RUBEN orchestrator state / recent decisions.
  - Check the EMSU database for the student/ticket/invoice/moodle state in question.
  - Check the ideas/decisions pipeline for related pending items.
  - Only after all of that fails should the question go to Ruben.

If I can answer 80%+ of the question from MCP tool context alone, just make the call and ship it — don't ping Ruben for something I could have figured out. If I'm below that threshold, ask.

## Plain-language check

Before sending a yes/no to Ruben, re-read my own question as if I were reading it on my phone at a stoplight. If any of these are true, rewrite:

- The question contains a slug, table name, column name, or numeric ID as the main content. (Those are fine as a reference, but the question itself must be readable without them.)
- The question requires Ruben to remember prior ops context ("DNS flip," "UDM failover," "forbidden_patterns scope") without a one-line explanation.
- A non-engineer family member couldn't roughly paraphrase what's being asked.

Every yes/no question must have a one-line "plain English" summary in the same bullet. If I can't write the plain English without the jargon version, the question isn't ready yet and I should keep digging.

## Question-card format — the "just right" shape

Added 2026-04-24 08:48 PT after Ruben flagged that earlier yes/no questions were too bare-bones to answer without follow-ups, and earlier versions were too long. Target is a card that takes ~15-20 seconds to read on a phone and ends with a yes/no. Every clarifying question should fit this shape:

```
**QN. [5-8 word policy name] — unlocks [N chains / N items]**

- **What yes does:** one sentence, concrete. "RUBEN auto-picks these and runs them without asking." Name the mechanism.
- **What no does:** one sentence, concrete. "These stay on your approval queue, you click each individually."
- **Scope:** what's included (one line) + what's excluded (one line with 2-3 examples of excluded titles/cases so Ruben sees the edge).
- **Risk if wrong:** one sentence about worst-case if RUBEN runs one that shouldn't have been auto-promoted. Name the safety net (e.g., "forbidden-pattern gate still fires at plan time," "all changes reversible in 30 seconds via safe-deploy backup").
- **Rollback cost if you change your mind later:** one sentence. "SQL UPDATE to flip the learned_patterns row off + 10 chains re-downgrade on next cron tick."

**Yes/No:** [actual question, under 20 words, plain English].
```

Keep each field to ONE line. The whole card should fit in a phone screen without scrolling. If a field genuinely needs two lines, it probably needs to be broken into a separate question or the scope is wrong.

**Why these five fields specifically:**
- "What yes / what no does" removes Ruben's need to mentally simulate the outcome.
- "Scope: included + excluded" is the single most helpful field — it shows him the edge cases and lets him say "mostly yes, but exclude X" if needed.
- "Risk if wrong" plus "rollback cost" together let him evaluate blast radius in one glance. These two together are why he can say yes to broad policies without feeling like he's making an irreversible decision.

**What NOT to include in the card** (these belong in the follow-up explanation if he says yes, not in the question):
- The full list of every matching chain (he doesn't want to scroll through 22 titles to say yes to a policy)
- The exact SQL or learned_patterns regex (that's implementation detail)
- Code snippets, file paths, or diffs
- Other policy questions cross-referenced by ID

**If a card won't fit this format**, the question isn't ready. Usually means either (a) the policy is actually multiple policies glued together and needs to be split, or (b) I don't have enough info about the scope and need to do more discovery before asking.

**Good example (matches the format):**

```
**Q1. Student-facing AI wording policy — unlocks 15 chains**

- **What yes does:** RUBEN auto-promotes any chain that only edits AI reply text to pre_approved; runs them when there's capacity, no approval asked.
- **What no does:** these 15 chains stay on the supervised queue, you approve each plan individually on the executor page.
- **Scope:** includes voice/tone/wording/template/opener/scrubber edits in email, SMS, chat, voice AI. Excludes anything marked BLOCKED, anything mentioning billing/Moodle/grades/refunds/payments, and anything that wires new tools vs edits existing replies.
- **Risk if wrong:** worst case a bad reply wording lands in a student email. The voice scrubber + sanitizer still run at send time and block anything weird. Every edit goes through safe-deploy CAS so rollback is one command.
- **Rollback if you change your mind:** set `auto_enabled=0` on the learned_patterns row, future matches stay supervised. Already-promoted chains keep their tier until you manually flip them back (one UPDATE).

**Yes/No:** OK for RUBEN to pre-approve chains that only edit AI reply wording?
```

**Bad example (too bare):**

> Q1. Student-facing AI content rules (22 chains waiting). Every chain is about editing email/SMS/chatbot text. None touch payments or grades. Yes/No: OK for RUBEN to pre-approve student-facing AI text chains?

The bad version is missing the "what no does" + "rollback" + specific examples of what's included/excluded, which forces Ruben to ask follow-up questions before he can answer.

## When to run synchronously (exceptions to the queue default)


Override the queue-by-default rule if any of these are true:

- Ruben said **"urgent," "now," "right now," "ASAP," "immediately,"** or similar.
- Ruben is clearly waiting on the answer in the current message (e.g. he asked "what is X?" — just answer).
- The task is read-only and fast (< 5 seconds total — one `check_student`, one file read, one DB query).
- The task is a single small file edit that completes in one tool call.
- A downstream tool call genuinely depends on the result of the current one (then chain them in the same session, but still hand back IDs at the end).

## What to put in the handback

Every `attempt_completion` for a queued task must include, at minimum:

```
TASK #<cline_task_id> — <short topic>

QUEUED / SEEDED
- <what was kicked off>
- chain IDs: <event_id=X, decision_id=Y, idea_id=Z, ticket_id=N, cron=name, pid=1234, etc.>

TO RESUME / CHECK STATUS
Paste into fresh Cline: "pick up task #<cline_task_id> — check on <chain IDs>"
Or check directly: <the MCP tool + args that will show the current state>

NEXT TRIGGER (if any)
- The cron runs at HH:MM PT and should publish result to <where>.
- Or: awaiting Jon/Vicky response in chat 55.
- Or: awaiting Ruben approval on decision #Y.
```

This is the same Resume Kit from rule 03, just with chain IDs surfaced up front because that's what Ruben needs to check on it later.

## Learning from Ruben's answers

When Ruben answers a clarifying question, check whether the answer is:

- **Specific to this one incident** → just apply it and move on. No rule update needed.
- **Systemic / affects more than this one case** → add it to:
  - This file (`05-default-background-queue-and-clarifying-questions.md`) or the relevant rule file in `/Users/rubenmajor/Documents/Cline/Rules/` if it's a voice/ops/timezone/etc. preference.
  - `HANDOFF_NOTES.md` on WOPR if it affects EMSU ops logic or cron behavior.
  - The RUBEN orchestrator `get_config` / `update_config` key if it affects RUBEN's autonomy or triage.
  - `create_idea` in the orchestrator if it's a feature/improvement that should be tracked in the ideas pipeline.

Rule of thumb: if the same question would come up again in a future task, the answer belongs in a persistent place (rule file, handoff, config). If not, just use it and move on.

## Red-flag phrases that mean I'm violating this rule

- Typing a wall of open-ended questions before doing any discovery: "Do you want me to do X, Y, or Z? How should I handle case A? What about case B? Should I also...?"
- Waiting on a 5-minute cron run while streaming status back to Ruben instead of handing it off and letting him check back.
- Finishing a task without giving back a task ID + chain IDs.
- Asking a clarifying question without first trying MCP tools to self-serve the answer.

## Scope

- Applies to: every new task Ruben kicks off in any Cline window, unless he explicitly overrides with "urgent" / "now" language.
- Does not apply to: pure Q&A he's actively waiting on, or a turn where Ruben is mid-dialogue and it's obvious from context that he wants me to keep going synchronously in this thread.

## Why this rule exists

Ruben runs ops for EMSU + personal + multiple side projects. His working style is parallel-async, not serial-sync. Treating every task as "block the chat until done" is the wrong default — it causes him to leave 20 Cline windows open waiting for tool streams, consumes RAM, and creates context-recovery problems later. Seeding and handing back lets him fire off work and come back to it when he's ready, which matches how he actually operates.

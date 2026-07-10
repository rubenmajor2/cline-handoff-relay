# 81 — RUBEN must respond to ops-chat reports; Cline babysits Ruben + repairs scanner gaps when RUBEN is silent

Permanent rule. Workspace-scoped. Source: 2026-05-15 — Vicky reported in
iMessage Ops Chat 55 at 11:06 AM PT *"team saying they are all not receiving
chat"*. RUBEN orchestrator had 3 critical detections open (issues 855, 859,
860) all with `ruben_replied=false`. RUBEN scanner went silent — no
acknowledgment to Vicky, no auto-action, no nudge to Ruben. Ruben directive
verbatim: *"As this is frequent, I need a rule like the above for whenever
RUBEN is not answering in the iMessage Ops to do the above. But it needs to
be RUBEN, not Cline. Cline needs to prompt ruben to do it and repair any
processes preventing such through the process."*

## The bright-line rule

**When Vicky or Jon raise a system/operational issue in iMessage Ops Chat 55
and the RUBEN orchestrator does NOT reply within ~10 minutes, Cline (in a
side window with Ruben) MUST treat this as a silent-scanner incident and:**

1. **Surface the silent report to Ruben the human** in the Cline chat,
   verbatim quote + age of the silence + RUBEN issue IDs that are unreplied.
2. **Prompt Ruben to act in this exact order** (Ruben does these, NOT Cline,
   NOT chat 55 sends from Cline per rule 57):
   - **Answer Vicky** in chat 55 (Ruben types in iMessage)
   - **Investigate the issue** Vicky reported (Ruben drives, Cline assists)
   - **Resolve the issue** (Ruben drives, Cline assists with tools/MCPs)
   - **Update Vicky** with the resolution (Ruben types in iMessage)
3. **Investigate WHY RUBEN was silent** in parallel. Common causes:
   - Cron stopped (`cron_ruben_autonomous`, `cron_ruben_implement`,
     scanner cron stale 10+h)
   - Anthropic credit exhausted / overloaded (rule 44)
   - LLM router 529 storm (rule 77)
   - Scanner intent gate too strict (it classified Vicky's report as
     "not actionable" when it was actionable)
   - Worker silent death / ext-host OOM (rule 97)
   - MySQL connectivity intermittent (today's #861)
   - Bug Hunter regression on the scanner itself
4. **Repair the gap** so RUBEN handles the NEXT one autonomously. Per rule 67
   (agents exhaust autonomy) + rule 68 (surface capability gaps): if the
   scanner is missing a tool/keyword/threshold, add it.
5. **Seed `orchestrator_learned_patterns` + `failure_repair_recipes`** per
   rule 46. Pattern hash: `ruben_silent_on_ops_chat_55_report`.
6. **File a proactive idea** at autonomous tier per rule 42 if the root cause
   is systemic (e.g. cron heartbeat watchdog missed this class — file an
   idea to extend rule 81's detection to RUBEN's own scanner crons).

## Signal phrases in Chat 55 that should have triggered RUBEN (and didn't)

- "team is not receiving [chat/sms/email]"
- "[X] is down" / "[X] is broken" / "[X] not working"
- "students are reporting [issue]"
- "no one is getting [Y]"
- "still down" / "still broken"
- Any screenshot from Vicky/Jon flagging a system regression
- "can you check [system]?"

If any of these appear in chat 55 and RUBEN's `ruben_replied=false` after
10 min, this rule fires.

## What Cline does NOT do (rule 57 compliance)

- **Cline does NOT message chat 55 directly.** That would violate rule 57.
  Cline surfaces to Ruben in the Cline chat; Ruben types in iMessage.
- **Cline does NOT autonomously "fix" the issue Vicky reported** unless it's
  rule-29 high-confidence + reversible + small + non-irreversible. Most
  chat/SMS/email outage repairs touch external comms — irreversible class.
- **Cline does NOT close the RUBEN issue rows** until Ruben has actually
  replied to Vicky AND the underlying issue is verified resolved.
- **Cline does NOT promise Vicky a timeline on Ruben's behalf** (rule 72).

## What Cline DOES do

- Surfaces silent reports + RUBEN issue IDs to Ruben (this rule's whole point)
- Calls MCP tools to investigate: `check_ruben_state`, `get_ruben_issues`,
  `error_watchdog`, `check_server_logs`, `server_status`,
  `check_telephony_health`, `chat_widget_healthcheck`, etc.
- Diagnoses WHY RUBEN was silent — pulls cron heartbeat, scanner logs,
  `orchestrator_event_log` for the report's timeframe
- Drafts the chat 55 reply for Ruben to copy/paste IF Ruben asks for one
  (per rule 49 — offer if implied)
- Ships the repair (code change, cron unstick, scanner threshold adjustment)
  per rule 29 once Ruben approves
- Seeds learned_patterns + recipes so RUBEN catches the next one

## The verbatim surface format

When Cline detects this state, the FIRST message to Ruben uses this shape:

```
⚠️ RUBEN silent on ops chat report. You need to drive this.

Chat 55 inbound (Vicky/Jon): "[verbatim quote]"
Posted: [timestamp PT] ([age] ago)

RUBEN issues unreplied:
- #[id] — [title] ([severity], [age])
- #[id] — [title] ([severity], [age])

Action sequence (you drive, I assist):
1. Reply to Vicky in chat 55 — draft below if you want it
2. Investigate: [hypothesis + which MCP tools I should call]
3. Resolve: [TBD pending investigation]
4. Update Vicky once fixed

Parallel: I'm investigating why RUBEN was silent. Likely: [hypothesis].
```

Then Cline waits for Ruben's direction, OR proceeds with diagnostic MCP
calls if Ruben is busy answering Vicky.

## Anti-patterns that violate this rule

- ❌ Cline messages chat 55 directly (violates rule 57)
- ❌ Cline tells Ruben "I'll handle it" — Ruben drives the human-facing parts
- ❌ Cline marks RUBEN issues `resolved` without Ruben replying to Vicky AND
  the issue actually being fixed
- ❌ Cline surfaces just the silence without also diagnosing WHY RUBEN was
  silent (the gap repair is the durable fix)
- ❌ Closing the loop without seeding a learned_patterns row + recipe (the
  next silent-scanner event must be auto-caught)

## Self-check before any wrap-up of an ops-chat silent-scanner incident

1. Did Ruben reply to Vicky in chat 55? (Cline can verify via
   `read_messages chat_id=55` after waiting)
2. Did Ruben resolve the underlying issue?
3. Did Ruben update Vicky with the resolution?
4. Did Cline identify WHY RUBEN was silent?
5. Did Cline ship a repair for the gap?
6. Did Cline seed `orchestrator_learned_patterns` row?
7. Did Cline seed `failure_repair_recipes` row?
8. Did Cline file an `orchestrator_ideas` row at autonomous tier if the
   gap is systemic?

If any answer is no, the incident is not closed.

## Cross-references

- Rule 01 — voice and persona (Ruben writes in chat 55, not Cline)
- Rule 10 — staff ticket escalations plain language
- Rule 29 — agents act on confidence tier (chat sends to staff = irreversible)
- Rule 30 — staff-chat context + acknowledgment
- Rule 42 — offer proactive systemic solutions
- Rule 44 — Anthropic outage failover (one possible RUBEN-silent cause)
- Rule 46 — every agent correction loops back to RUBEN + KAIZEN
- Rule 49 — offer to act when implied (chat 55 reply draft for Ruben)
- Rule 57 — NEVER send to staff iMessage without explicit Ruben request
  (Rule 57 governs Cline's behavior; this rule governs RUBEN's behavior —
  they are complementary, not conflicting. Clarified 2026-05-15.)
- Rule 67 — agents act autonomously before human escalation
- Rule 68 — agents exhaust tools + surface capability gaps
- Rule 72 — no time deadline promises on staff's behalf
- Rule 77 — cline-router overload recovery (another possible silent cause)

## Last updated

2026-05-15 12:47 PT — initial rule. Source: Vicky 11:06 AM PT chat-down report
with 3 unreplied critical RUBEN issues. Ruben directive: *"this is frequent,
I need a rule... it needs to be RUBEN, not Cline. Cline needs to prompt ruben
to do it and repair any processes preventing such through the process."*

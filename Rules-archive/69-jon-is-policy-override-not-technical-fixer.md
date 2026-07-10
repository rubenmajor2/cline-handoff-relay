# 69 — Jon is policy/override authority. Agents fix technical issues. Ruben if agents can't.

Permanent rule. Source: 2026-05-13 Davide Decuzzi exam runaround. Cline routed a stuck Moodle quiz attempt to Jon and said "Jon needs to pull mdl_quiz_attempts." Jon is VP of Operations. He does not go into Moodle admin to reset quiz attempts. That's what agents, Ticket Agent, and Cline are for. Ruben: "Jon doesn't check that stuff. Jon is VP of operations, he's not doing technical fixes, the Agents, you and me are doing that."

## The bright-line rule

**Jon's lane = academic POLICY and OVERRIDE decisions.**
**Agents' lane = technical FIXES, including Moodle state repairs.**

| Issue type | Owner | Why |
|---|---|---|
| Student needs retake that policy doesn't allow | Jon | Policy/override decision |
| Student appeal of academic integrity finding | Jon | Policy/override decision |
| Moodle suspension lift (payment cleared, integrity resolved) | Jon or Vicky per existing routing | Per rule 29 irreversibility |
| Grade override (academic judgment call) | Jon | Policy/override decision |
| Stuck/abandoned quiz attempt (technical glitch) | **Ticket Agent first, then Ruben if stuck** | Technical fix — reversible, agents can do this |
| Exam ended early / SEB crash (technical glitch) | **Ticket Agent first, then Ruben if stuck** | Technical fix — reversible, agents can do this |
| Attempt count wrong due to system glitch | **Ticket Agent first, then Ruben if stuck** | Technical fix — reversible, agents can do this |
| Invalid Course Module ID error on exam | **Ticket Agent first, then Ruben if stuck** | Technical fix |
| Any Moodle state issue traceable to a system error | **Ticket Agent first, then Ruben if stuck** | Technical fix |

## The correct escalation ladder for technical exam issues

```
1. Chat AI detects exam technical issue (keyword: "exam ended early",
   "exam closed", "never submitted", "exam crashed", "SEB closed")
   → calls check_exam_enforcement immediately (per rules 32, 67, 68)
   → if abandoned/stuck attempt confirmed:
     creates ticket for TICKET AGENT (category=Technical, NOT routed to Jon)
     tells student: "Your exam details are being reviewed by our team.
     Do NOT start a new attempt until confirmed."

2. Ticket Agent picks up the ticket
   → calls check_exam_enforcement
   → calls ai_stuck_quiz_reset_invocations OR uses stuck_quiz_attempt mechanism
     to attempt the fix
   → if successful: emails student with result + Vicky if warranted
   → if successful: closes ticket
   → if CANNOT fix: escalates to RUBEN (not Jon)

3. RUBEN (or Cline) fixes it
   → uses admin Moodle tools or SSH to directly fix the quiz attempt state
   → closes ticket, emails student

Jon is NOT in this chain for technical fixes. Jon enters the chain only if the underlying issue requires a POLICY DECISION (e.g., student wants additional attempts beyond what policy allows, or the crash is disputed and it's unclear whether it was technical or not — that's a policy judgment, not a technical fix).
```

## Why this distinction matters

- Resetting an abandoned/stuck Moodle quiz attempt is a **database operation**, not a policy decision. It's like clearing a stuck cache. It's reversible. Confidence is high when `check_exam_enforcement` confirms the attempt is in `inprogress` or `abandoned` state AND there's a documented technical trigger (SEB prevented events, page crash, Invalid Course Module ID).
- Routing it to Jon wastes Jon's time on something agents can do in 30 seconds, leaves the student waiting hours instead of minutes, and creates a ticket audit trail that makes the team look incompetent.
- Rule 29's "Moodle gradebook" irreversibility clause applies to **grade changes** (permanently altering what a student scored) — NOT to resetting an abandoned attempt so they can retake. A reset is reversible (the attempt can be re-abandoned), small blast (1 student), high confidence (confirmed technical state). Per Rule 29: ACT.

## What IS a Jon-level call for exam issues

- Student used all allowed attempts, wants one more — Jon decides if policy allows an exception
- Exam integrity flag — Jon decides how to proceed
- Student disputes whether the crash was technical or voluntary — Jon makes the call after Ticket Agent provides the evidence
- Scheduled retake requires a proctor that isn't available — Jon coordinates

## Anti-patterns that violate this rule

- "Jon needs to pull mdl_quiz_attempts" — NO. Agents pull that via check_exam_enforcement.
- "Reassigning to Jon (academic override authority)" for a stuck attempt — NO. Route to Ticket Agent.
- Creating a Technical ticket assigned to Jon — NO. Ticket Agent queue, then Ruben if Ticket Agent can't fix.
- Telling a student "call 800-728-0209" when the issue is technical and can be fixed by the Ticket Agent — NO. Fix it, then tell the student it's fixed.

## The "call 800 number" dodge

Telling a student to call the 800 number is punt behavior. It's fine as a last resort after multiple automated and human attempts have genuinely failed. It is NOT acceptable as the first or second response to a technical issue that can be fixed by a tool. Ruben: "Why say that? Why dodge the call entirely?"

If the Ticket Agent fixes the exam issue, the student gets an email saying it's fixed — not a phone number to call. If human contact is genuinely needed, the agent or staff member should try to call the student (not the reverse), offer to schedule a call, or use chat/email followup — not route the student to a generic hold queue.

## Cross-references

- Rule 29 — agents act on confidence tier (technical fixes are high confidence + reversible + small = ACT)
- Rule 10 — audience routing matrix (Jon for Moodle override → that's the POLICY override column, not technical fixes)
- Rule 67 — agents act autonomously before human escalation
- Rule 68 — agents exhaust tools before escalating, surface capability gaps
- .clinerules/32 — use check_exam_enforcement and ai_stuck_quiz_reset_invocations first
- Idea #3565 — wire stuck_quiz cron + chat AI exam detection end to end

## Last updated

2026-05-13 — initial rule. Source: Davide Decuzzi exam runaround, conv #711. Cline routed stuck Moodle attempts to Jon three times in the same analysis. Ruben: "Jon is VP of operations, he's not doing technical fixes, the Agents, you and me are doing that. That's it."

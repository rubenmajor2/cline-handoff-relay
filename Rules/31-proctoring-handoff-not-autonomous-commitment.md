# 31 — Proctoring scheduling (and any human-owned-SLA work) is a handoff, not an autonomous AI commitment

Permanent rule. Workspace-scoped. Source incident: 2026-05-07 ~15:25 PT —
Hugo Espinoza (26908W-08, hespinoza0532@gmail.com) emailed asking to
schedule his Final Exam retake. The Email AI fired `ai_compiled_rules`
id=233 (proctoring_no_slots) which had it reply on Vicky's behalf with
"you are on the priority list, you will be emailed within 24-48 hours
when a slot opens." Two problems:

1. **Vicky was never CC'd** on the outbound. She had no idea the AI just
   made a 24-48h commitment in her name.
2. **No ticket was created** (outbound 6782 had `ticket_id=NULL`). So
   even the internal queue had no record of the handoff.

Ruben's correction: this is a **handoff** to Vicky, not an autonomous
commitment. Vicky owns scheduling and Vicky owns the SLA. If her SLA
slips, that gets documented to Jon and Cori — but the AI does NOT
promise timing on her behalf, and definitely does NOT make the promise
without her in the CC line.

## The bright-line rule

**Any AI surface that needs to hand work to a human-owned queue (Vicky
for proctoring/CS, Jon for overrides, Cori for exec coverage, Personnel
team for onboarding, etc.) MUST:**

1. **CC the queue owner on the student-facing outbound.** Not BCC. CC.
   The owner needs to see in their own inbox what was just promised so
   they can set their own SLA against it.
2. **Not promise timing the AI doesn't own.** No "within 24-48 hours,"
   no "by tomorrow," no "Vicky will reach out within X." The AI doesn't
   maintain those queues; it can't make those commitments.
3. **Create the matching ticket** at the same time, assigned to the
   queue owner at the right priority. If no ticket gets created, the
   handoff is invisible the moment the email is sent.
4. **Frame the reply to the student as a handoff, not as an
   autonomous answer.** "I've routed your request to [name], they will
   coordinate with you directly." Not "you're on the priority list,
   you'll hear back in [time]."
5. **Escalate at SLA breach, not by hammering.** If the ticket sits
   48+ hours without action, the next outbound on the thread CCs the
   exec backup (Jon for academic, Cori for ops) for visibility — but
   it does NOT bypass Vicky. Just adds visibility.

## Forbidden phrases on any AI-drafted reply about a human-owned queue

- "You will be emailed within 24-48 hours" / "X will reach out within Y"
- "You are on the priority list" (the AI doesn't maintain priority lists)
- "Vicky / Jon / Cori will respond by [time]"
- "Your request will be processed within [window]"
- Any specific deadline or response window for human action

## What to write instead

> "Thanks for reaching out. I've flagged your scheduling request and
> routed it to Vicky Yu, who coordinates proctoring. She will follow
> up with you directly to set up your session. The booking page is
> [URL] — new slots appear there as Vicky adds them, so you can also
> check back there. Keep in mind the 72-hour waiting period between
> Final Exam attempts still applies, and both Safe Exam Browser and a
> live Zoom proctor are required for the retake."

The student gets the routing fact, the self-service fallback (booking
page), and the relevant policy reminders. They do NOT get a timing
promise the AI can't keep.

## Routing pattern (canonical)

| Topic | Owner | CC at handoff | CC at 48h SLA breach |
|---|---|---|---|
| Proctoring scheduling | Vicky (vyu@) | Vicky | + Jon (jthompson@) + Cori (CFrench@) |
| Externship affiliation | Vicky | Vicky | + Jon (per rule 13) |
| Override / waiver / unsuspend | Jon (jthompson@) | Jon | + Ruben |
| Refund / billing dispute | Vicky for QB, Jon for academic | both | + Ruben |
| Personnel / onboarding | Personnel agent / Ruben | as routed | n/a |

## Why this rule exists at the .clinerules level

The systemic fix for THIS incident is in `ai_compiled_rules` id=233 (the
"proctoring_no_slots" rule was rewritten 2026-05-07 to enforce the CC
+ no-timing-promise pattern). But this rule covers the **class** of
problem: AI surfaces making commitments on behalf of human-owned
queues, without those humans in the loop. Future rules covering other
handoff topics (externship coordination, refund routing, override
requests) should follow the same pattern:

1. Frame as handoff, not autonomous answer.
2. CC the owner on the outbound.
3. Create the matching ticket.
4. Don't promise timing the AI doesn't own.
5. SLA-breach escalation adds visibility without bypassing.

## Where this is enforced (code-level, not just prompt-level)

Per `.clinerules/09` and `.clinerules/15`: prompt-level rules can be
ignored at runtime. The actual enforcement for proctoring handoffs is in
PHP code, not just the AI prompt:

1. **`ai_compiled_rules` id=233** (prompt layer) — mandates handoff
   framing in the AI's reply text. `source_correction_ids` includes
   `clinerules:proctoring-handoff-not-commitment-2026-05-07` so the
   nightly recompiler protects it.
2. **`cron/cron_email_responder.php` proctoring-handoff branch**
   (~line 1357, deployed 2026-05-07) — runs INDEPENDENTLY of whether the
   AI prompt fires rule 233. Detects the intent by regex on subject +
   body, then:
   - Auto-creates `tickets` row assigned to Vicky (user_id 2),
     priority High, category Administrative, prefix
     `[Proctoring scheduling]`. Dedupes per student email.
   - Adds `vyu@emsuniversity.com` to the outbound BCC list.
     `sendEmail()` in `lib/mailer.php` has no CC parameter (only BCC),
     so BCC is the closest channel for email-level visibility.
3. **48h SLA-escalation cron** — proposed but NOT yet built. Should
   check for `[Proctoring scheduling]` tickets open without action
   48+ hours and send a single SLA-breach notification CCing Jon +
   Cori. Tracked as orchestrator idea
   `proctoring-sla-48h-escalation-cron-2026-05-07`.

Detection regex (PHP, runs against `strtolower($subject . "\n" . $body)`):

```php
preg_match('/\b(proctoring|proctored|proctor)\b.*\b(slot|session|schedul|book|availab|retake|final)/i', $combined)
|| preg_match('/\b(schedul|book)\w*\b.*\b(retake|final\s*exam|proctor|zoom\s*session)/i', $combined)
|| preg_match('/\b(no|0|zero)\s+(available|open)\s+(slot|session|date|time)/i', $combined)
|| preg_match('/\bnothing\s+available\b.*\b(proctor|schedul|retake|final)/i', $combined)
|| preg_match('/\b(retak|retake|retaking)\b.*\b(my\s+)?final\b/i', $combined)
```

Verified against 10 test cases (positive: "retaking my final", "Re:
retaking my final", "scheduling my retake for my final", "0 available
session", "no available proctoring slots", "I need to book my final
exam", "schedule a zoom session for my retake"; negative: "tuition
refund question", "what is the cost of the course", "where can I find
the syllabus"). All pass.

## Cross-references

- `ai_compiled_rules` id=233 (proctoring_no_slots) — the prompt-level
  enforcement, rewritten 2026-05-07 with this rule's framing.
- `cron/cron_email_responder.php` proctoring-handoff branch — the
  code-level enforcement (Vicky BCC + auto-ticket).
- `lib/mailer.php` `sendEmail()` — note: BCC only, no CC parameter.
  Future improvement: add `$cc` param so handoffs can be true CC.
- `.clinerules/10-staff-ticket-escalations-plain-language.md` — the
  staff-facing tone for Vicky/Jon-bound handoffs.
- `.clinerules/13-signed-affiliation-agreement-vicky-jon-cc.md` —
  same shape for affiliation agreements (Vicky owner, Jon CC).
- `.clinerules/15-no-internal-reasoning-narration-in-student-emails.md`
  — don't narrate the AI's routing decision to the student; just say
  who you routed to.
- `.clinerules/29-agents-act-on-confidence-tier.md` — handoff vs
  autonomous-action framing. Handoffs to a human-owned SLA are NEVER
  the autonomous tier; they're always escalation.

## Source incident

- 2026-05-07 ~13:10 PT: Hugo emails "retaking my final" — AI replies
  with retake instructions (rule 226 fires, fine).
- 2026-05-07 ~13:15 PT: Hugo replies "there's 0 available sessions."
- 2026-05-07 ~15:25 PT: AI fires rule 233 (old version), promises
  24-48h response on Vicky's behalf, no CC, no ticket. Outbound
  6782, inbound 20289.
- 2026-05-07 ~16:15 PT: Hugo replies with availability ("any morning
  before 11am except Saturday"). Inbound 20309. Still no ticket, still
  no Vicky CC.
- 2026-05-07 ~16:33 PT: Ruben caught it. Cline retroactively created
  ticket TKT-20260507-498C5276 (id=2759) routed to Vicky high,
  rewrote rule 233 with handoff framing, pinged Vicky in chat 64,
  shipped this rule.

## Last updated

2026-05-07 — initial rule. Source incident: Hugo Espinoza proctoring
scheduling, outbound 6782, inbound 20289 + 20309.

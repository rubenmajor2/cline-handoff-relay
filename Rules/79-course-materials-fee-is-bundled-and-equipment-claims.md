# 79 — Course materials fee is a BUNDLED package per the Enrollment Agreement, and equipment-not-received claims route to Jon + first-day instructor + Cori

Permanent rule. Workspace-scoped. Source: 2026-05-14 Ruben directive verbatim while reviewing Carson Doan (student_id 8138128, section 26712BC, San Diego CA, course start 2026-05-11) withdrawal email asking the $500 course materials fee be waived because he "did not receive any of the physical course materials":

> *"We do have this policy listed in our agreements - however, it's a bundled package which also includes other items per the EA and is specified exactly on the EA. So I want to make sure you have a good understanding of this logic. Additionally when this is claimed, the student's email needs to be sent to Jon as well as the instructor for the first day of that student's class. Copy Cori on the email as well so they know that there was a report of equipment not received and can followup with the instructor that day who should have distributed it."*

## The bright-line rule

### A — The course materials fee is NOT a refund-per-item line

The dollar amount listed on the EA for "course materials" (commonly the $500 / $497.50 / etc. figure shown to the student at checkout) is a **BUNDLED package**, not a single line for a physical kit. The exact composition is specified on each student's signed Enrollment Agreement (EA) and typically includes ALL of:

- Physical equipment kit (stethoscope, BP cuff, penlight, shears, etc.)
- Digital course materials access (LMS access, video library, practice tests)
- Workbook / textbook access (digital or physical depending on cohort)
- Skills lab supplies allocated to the student
- Online testing platform seat
- Any cohort-specific bundled item listed on that student's EA

**Therefore:** a student saying "I didn't receive the physical materials so waive the $500" is asking us to refund the **bundled package** based on one component. Even if the equipment kit was genuinely not handed out on day 1, the student still received the other bundled items (LMS access, video library seat, etc.) the moment they were enrolled. The kit being missing is a fulfillment issue to fix, not a basis to waive the entire bundle.

**The correct disposition** of a "didn't get physical materials" claim is:

1. Investigate whether the equipment was actually distributed on day 1 (route to first-day instructor + Jon + Cori — see §B below).
2. If the equipment was genuinely not distributed → arrange to ship or hand it to the student. Do NOT waive the bundle fee.
3. If the equipment WAS distributed and the student declined / left early / didn't pick it up → the bundle fee remains in full per the EA.
4. If the student is withdrawing under the published refund schedule, apply THAT schedule (which already accounts for materials fees on its own terms) — do NOT carve out the bundle as a separate waiver.

### B — Required routing when a student claims equipment / materials were not received

Whenever a student communication contains ANY of the following triggers AND references the materials/equipment fee or course kit:

- "I did not receive [any of] the physical course materials"
- "the equipment was not given to me / not provided / not handed out"
- "no one gave me the kit / stethoscope / BP cuff / equipment"
- "the materials were never distributed"
- "I never got the [kit | equipment | materials | textbook]"
- "waive the [materials | equipment | $500 | $497.50] fee because I didn't get..."
- Any equivalent claim that physical course materials/equipment were not handed out

The student-facing reply (or the internal ticket comm chain) MUST include all of the following recipients:

| Recipient | Reason |
|---|---|
| **Student** | Primary addressee |
| **Jon Thompson** — `jthompson@emsuniversity.com` (CC) | VP of Ops, override authority for academic/billing disposition |
| **First-day instructor** for that student's class section | They were responsible for distributing equipment on day 1 — they need to confirm whether it was actually handed out |
| **Corinne French** — `CFrench@emsuniversity.com` (CC) | Operations exec coverage — needs awareness to follow up with the instructor who should have distributed |

### How to identify the "first-day instructor"

```sql
SELECT s.id, s.instructor_user_id, s.instructor_name,
       u.email AS instructor_email
FROM emsu_shifts s
LEFT JOIN users u ON u.id = s.instructor_user_id
WHERE s.section = '<student class_section>'
  AND s.shift_date = '<student course_start_date>'
ORDER BY s.start_time
LIMIT 1
```

If `instructor_user_id` is NULL but `instructor_name` is populated, look up the email via:

```sql
SELECT id, first_name, last_name, email FROM users
WHERE CONCAT(first_name,' ',last_name) = '<instructor_name from emsu_shifts>'
  AND role IN ('Instructor','PD','SiteLead','ExecAdmin')
ORDER BY (email LIKE '%@emsuniversity.com') DESC
LIMIT 1
```

Always prefer the `@emsuniversity.com` address over any personal email when both exist for the same instructor (e.g. Stephen Metz exists as both `stephen.r.metz@gmail.com` user_id 66 AND `smetz@emsuniversity.com` user_id 139 — use the latter).

### What the email to the student should say (voice rules apply)

Per .clinerules/02 (no apologies), .clinerules/15 (no internal-reasoning narration), .clinerules/47 (full URLs), .clinerules/48 (Ruben house style if from rmajor@), .clinerules/72 (no time deadline promises on staff's behalf):

- Acknowledge the claim is being investigated.
- Do NOT promise a specific refund or waiver.
- Do NOT narrate the bundled-fee logic to the student in the response.
- Confirm the matter has been routed to the first-day instructor (named) and that operations leadership is copied.
- Do NOT promise a 24-hour / 48-hour / X-business-day turnaround — just say someone will follow up.

### What goes in the internal ticket comment / staff side

Plain language per .clinerules/10 — Jon + Cori + the instructor are the human readers. Include:

- Student name + section + course_start_date + location
- Quote of the equipment-not-received claim
- Instructor identified for day 1 (with the SQL output)
- Action requested from instructor: confirm whether equipment was distributed to this student on day 1
- Action requested from Vicky if refund/withdrawal also in play: hold any waiver of the materials fee until the instructor confirms
- Reminder that the materials fee is a bundled package (per this rule + the EA)

## Why this rule exists (the bundled-fee misconception)

Multiple withdrawal emails over the last 6 months have used the same script: "I'm withdrawing, please waive the materials fee because I didn't receive the physical materials." Without this rule, an AI or staff member could read that, see the EA line "$500 course materials," and assume the line is refundable on the single basis that physical items didn't change hands. That is wrong on two counts:

1. The $500 line covers more than physical items.
2. Whether physical items DID change hands is an empirical question the first-day instructor can answer in 30 seconds, not a fact the student gets to assert unilaterally.

The combination of routing-to-instructor + Jon + Cori means the equipment claim gets ground-truthed BEFORE any waiver discussion, and Cori has the visibility to follow up with the instructor on day-of distribution practice — which addresses the systemic root cause if the instructor isn't actually handing out kits.

## Implementation on the AI side

When Cline (or the email AI / ticket AI / chat AI) processes a communication matching the trigger phrases in §B:

1. **DO NOT autonomously process a fee waiver** — this is rule 29 irreversibility tier (touches money). Always Q-card or route to Jon for the disposition.
2. **DO autonomously look up the first-day instructor** using the SQL above.
3. **DO route the message** with Jon + first-day instructor + Cori on CC.
4. **DO create a ticket** assigned to Jon (priority High) titled `[Equipment not received - bundled fee dispute] <Student Name>` and include the instructor's email in the ticket extra_ccs field per .clinerules/13's CC pattern.
5. **DO NOT promise the student a specific outcome or timeline** per .clinerules/72.

## Companion: file as curated AI rule with clinerules: prefix

Ship this as an `ai_compiled_rules` row with `source_correction_ids='clinerules:79-course-materials-fee-is-bundled-and-equipment-claims-2026-05-14'` and protected status so the nightly recompiler doesn't nuke it (per .clinerules/15's recompiler protection clause).

## Anti-patterns

- ❌ "Waiving the $500 materials fee since you didn't receive the kit" — never autonomous
- ❌ Replying to the student without CCing Jon, the first-day instructor, AND Cori
- ❌ Asking Cori or Jon to look up which instructor was on day 1 — the AI does that itself per the SQL above
- ❌ Routing to "the materials team" or "the equipment team" — there is no such team; it's the first-day instructor's responsibility per this rule
- ❌ Promising "we'll get back to you within 24 hours" on a fee dispute (rule 72 violation)

## Cross-references

- .clinerules/02 — no apologies in student-facing email
- .clinerules/10 — staff ticket escalations plain language
- .clinerules/13 — staff CC pattern (Vicky + Jon for high-value handoffs; this rule extends the pattern to instructor + Jon + Cori for equipment-distribution claims)
- .clinerules/15 — no internal-reasoning narration; curated `ai_compiled_rules` recompiler protection
- .clinerules/29 — agents act on confidence tier (fee waivers are irreversibility tier, never autonomous)
- .clinerules/47 — full URLs in student-facing emails
- .clinerules/48 — Ruben house style if outbound from `rmajor@`
- .clinerules/67 — agents exhaust autonomy before escalation (look up the instructor before asking a human to)
- .clinerules/68 — agents exhaust tools and surface capability gaps
- .clinerules/72 — no time deadline promises on staff's behalf
- Source incident: Carson Doan (8138128), section 26712BC, San Diego CA, course start 2026-05-11. First-day instructor: Stephen Metz (smetz@emsuniversity.com, user_id 139). Withdrawal email forwarded 2026-05-14 21:59 PT.

## Last updated

2026-05-14 22:08 PT — initial rule per Ruben directive in the Carson Doan withdrawal task.

# 302 — Regulator response doctrine: the AZDHS 7/31 pattern applies to EVERY agency

Source: 2026-07-31 — Ruben directive after transmitting the AZDHS July 2026 consolidated response: "I need the rules for all responses sent to regulators improved here based on my preferences... i need you updating your TDSHS response due next week based on the way we submitted this one today."

Applies to **every** regulator: AZDHS, TDSHS, BPPE, CAPCE, San Diego County EMSA, and any future agency. Derived from 21 revision rounds Ruben walked through on one filing. Every rule below is a correction he actually made.

## THE POSTURE: defensive, not cooperative-confessional

A Notice of Investigation is an adversarial document. The response is a defense, not a compliance checklist.

**Never volunteer an admission.** Banned constructions, all of which Ruben struck by name:
- "That is an EMSU-side placement-assignment failure"
- "It is a program-side failure"
- "EMSU's own records corroborate the platform failure this complaint describes"
- "EMSU does not attribute that to the student"

If our own internal diagnostic says we broke something, that diagnostic is **not** evidence we hand a regulator. Quoting our own ticket system against ourselves is handing them the case.

**Never state what EMSU is prepared to produce.** Use "Course completion of record" stating what the record shows. Not "EMSU is prepared to produce…"

**Every corrective measure closes with:** "offered as continuous improvement and not as an acknowledgment of any deficiency."

## DO NOT REPEAT THEIR NUMBERS

Restating a complainant's figure puts it in the record with our signature under it, even inside a rebuttal. Strip all of:
- Interval arithmetic ("254 days unassigned," "twelve days elapsed," "fifty-four days")
- Third-party counts (BBB grievance counts, "over 85 contact attempts," unnamed classmate reports)
- Any day-count that lets the regulator compute delay

Ruben on the clearance table: *"The enclosure begs the regulator to ask the question as to why it took so long to clear the students."* Show status, never duration.

## DO NOT RESTATE THE ALLEGATION

Do not open each case with a paragraph reciting the charge. Answer it. Ruben: *"Do not repeat 'Allegations as relayed in the Notice.' only respond to them. We don't need to give it more teeth."*

One line in the section header note covers it: "Nothing in this Response adopts any allegation."

Also: **the Department did not say it, the complainant alleged it.** Never write "The Department states the student was failed…" when it is the student's allegation relayed in the Notice.

## DO NOT RECITE THEIR DIRECTIVE

No paragraph mapping their required items to your sections. No "Enclosures:" list block. The enclosures travel with the transmission; announcing them inside the letter frames the filing as a checklist.

## THE FOUR HIGH-VALUE DEFENSES (check every case for these)

**1. The complaint predates the thing it complains about.** Compare the complaint date against `Course_Schedules.course_end_date`. AZDHS 0496: complaint dated 6/7 on a course that ran to 6/24, student finished submitting 6/8 (the day after filing), cleared 6/20 ahead of most classmates. Ruben: *"We were never late on this person."* Lead with the conclusion in a callout.

**2. No provision is cited for the asserted deadline.** When a complaint alleges an interval ("mandated 10 business days") with no rule behind it, say so, then state your position and stop:
> "No statute, rule, or provision imposing that interval is identified in the complaint. EMSU contends that the provisions that do govern are…"

Do **not** write "EMSU is not aware of any provision of [entire code] that fixes such a deadline." That certifies a negative about a whole regulatory scheme and invites them to produce one.

**3. They measure from the wrong milestone.** `scheduled_didactic_completion_date` is not `course_end_date`. Didactic completion is not course completion; field training and documentation remain.

**4. The student never used our grievance process.** Query `grievances`. If zero: "The complaint reached the Department without the student first using the process EMSU publishes for exactly this purpose."

## THE COURTESY FRAMING (students who did not finish on time)

Ruben's exact preferred wording, use this and not a paraphrase:

> "Under the program's published standards this student would not normally have been permitted to sit for the National Registry. Program director discretion was to clear."

**Banned:** "this student should have failed the course." Too blunt, and it concedes an academic determination we never made.

Supporting points: nothing in the rule requires a program to extend a student who did not finish; EMSU extended anyway as a courtesy; the certificate date the complaint treats as delay is the product of an accommodation, not a missed obligation. Highlight it in a callout, do not bury it in a date list.

## PAST-DEADLINE CITATIONS: only genuinely late items

**The deadline is `course_end_date` PLUS the grace period, not the course end date itself.** Cohort ending 2025-12-16 has a submission deadline of 2026-01-16. Items filed on or before the grace date are WITHIN the window and must NEVER be cited as late.

Use `NoiDefenseEvidence::forStudent($slug, $state)`. It carries `SUBMISSION_GRACE_DAYS = 31` and returns `submission_deadline` plus a per-item `late` flag. **The library caught two of my own overclaims** on 2026-07-31 (I asserted two students were late when they were not; it reported late=0 for both). Trust it over hand analysis.

Cite form names and actual dates. Do **not** state the grace period itself, and do not compute day counts.

**Never cite a computed aggregate as a submitted assignment.** "Course Total" is a gradebook rollup, not something a student submits. Cite the Moodle course completion date separately.

## STRUCTURAL REQUIREMENTS

**Names.** Reference matters by agency case number ONLY. Zero complainant, student, instructor, staff, or contractor names in the response body. Names appear only in a roster enclosure where the agency expressly demanded them.

**No internal links.** No `admin_profile.php`, no ticket URLs, nothing auth-gated.

**No em dashes.** Ruben's voice per rule 01. Commas, parentheses, or two sentences.

**Signature.** Canonical file only, per rule 301. Verify with `pdfimages -list`.

## ENCLOSURE PATTERN

| Enclosure | Content | Responds to |
|---|---|---|
| A | Class Rosters, one table per cohort | "names of all students in attendance" |
| B | **Course Catalog (Containing Policies and Procedures)** | "policies and procedures governing the program" |
| Separate file | Issued end-of-course certificates merged in case order | course completion documentation |

Enclosure B is titled **Course Catalog**, not "Policies and Procedures Statement." A catalog is a real published document; a "statement" sounds drafted for the occasion.

Certificates: pull the real issued PDFs, never generate a summary table. `simplecertificate` id 24 is the EMT course certificate; ids 49 and 57 (Reading Comprehension, RT-130) and all CPR/FEMA items are excluded. A student with no certificate row is affirmative proof of non-completion.

## SCOPE DISCIPLINE

When Ruben asks for a document, produce the document. Do not add an enclosure, edit the cover letter, or register a new DB round unless he asked. On 2026-07-31 he asked for a certificates PDF and I built a whole new Enclosure, rewrote the cover letter, and created a DB row. All of it had to be reverted.

## PRE-TRANSMISSION VERIFICATION (run on every PDF)

```
pdftotext <file>.pdf /tmp/v.txt
grep -ciE '<every student/complainant surname>' /tmp/v.txt   # must be 0
grep -c 'admin_profile' /tmp/v.txt                            # must be 0
grep -c $'\u2014' /tmp/v.txt                                  # must be 0 (em dash)
grep -ciE 'should have failed' /tmp/v.txt                     # must be 0
grep -ciE 'EMSU-side|program-side failure' /tmp/v.txt          # must be 0
grep -ci 'better business|contact attempts' /tmp/v.txt         # must be 0
grep -ci 'course total' /tmp/v.txt                             # must be 0
pdfimages -list <file>.pdf | grep -c '256    76'               # must be >= 1 (rule 301)
```
Plus: correct page count, 644 www-data, HTTP 200.

## CATALOG THE TRANSMISSION

After sending, insert a `kind='sent'` row in `compliance_investigation_responses` with recipients, timestamp, every attachment named, and a `posture_notes` entry. If filed late, record the mitigating posture but **never volunteer the lateness to the agency**.

**Round labels live in `compliance_investigation_responses.title`, NOT `summary`.**

## Cross-references

- Rule 01 — Ruben voice, no em dashes
- Rule 02 — no apologies in external correspondence
- Rule 29 — act on verified evidence, answer direct questions inline
- Rule 301 — canonical signature file
- Library: `/var/www/emtskills/personnel/lib/NoiDefenseEvidence.php`

## Source incident

2026-07-31 — AZDHS July 2026 consolidated NOI response, 7 complaint cases, 21 revision rounds. Every rule above is a correction Ruben made to a draft I had already called finished. Transmitted to lawrence.bevins@azdhs.gov cc brent.caswell@azdhs.gov approximately 3 hours past the 7/31 extension deadline.

## Last updated

2026-07-31 — initial.

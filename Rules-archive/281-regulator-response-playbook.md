# 281 — Regulator response playbook (NOI / complaint / inspection POC writing patterns)

Permanent archived rule. Source: 2026-07-20 TDSHS Inspection 5196 + Complaints 1080261810-15 session. Ruben hand-edited the drafted Written Statement in Google Docs; the diff between the agent draft and his edits IS the playbook. Every future regulator-facing draft (NOI response, complaint statement, inspection POC, accreditor correspondence) MUST apply these patterns BEFORE handing Ruben a draft.

## The trigger

Any draft addressed to a state EMS office, licensing board, accreditor (CAPCE, BPPE, TDSHS, AZ DHS, NY BPSS...), or attorney representing one. Fetch this rule first: `clinerules_lookup(rule_id=281)`.

## Document-type gate (what each regulator letter actually requires)

- **Inspection deficiency notice** → requires signed statement + Plan of Correction (Who-by-title / What / How / Ongoing Compliance per area). POC goes ONLY here.
- **Complaint Control Number letter** → requires ONLY "a written statement + any and all documentation... that support or deny the alleged allegations." NO POC. Volunteering a POC on a complaint implies something needed correcting. Title the response "Written Statement."
- **NOI (Notice of Intent)** → full investigation report format (Intro w/ program-highlight paragraphs → per-complaint findings → strengths → POC only if demanded).
- READ the letter's ask verbatim before choosing the format. Do not import the POC habit across document types.

## Ruben's editing patterns (apply proactively, learned 2026-07-20)

1. **Never advertise internal logs/records to a regulator.** Strike sentences like "Every support contact is logged" / "Assistant conversations are logged in full." Advertising log completeness creates production commitments and discovery targets. Only invoke records reactively: "with those specifics the program will produce the corresponding records."
2. **Never concede AI fallibility in a signed regulator document.** Strike "automated responses can contain mistakes." Replace with grounding language: automated assistants "are based upon the controlling enrollment agreement and published program documents the student accepts as a course of their enrollment and the disclaimers they sign." The authority anchor is the signed documents, not an admission the AI errs.
3. **Drop the word "human."** "Human staff" / "backed by human instructors" implicitly adopts the complainant's AI-vs-human framing. Write "support staff," "instructors and staff." Also strike absolutes ("always," "every," "never") that create falsifiable claims — "can reach directly," not "can always reach directly."
4. **Reframe defensive denials as affirmative benefits.** Not "an addition to human access, not a replacement for it" (denial framing repeats the accusation) but "an addition to human access, to help speed assistance for those who may require it" (benefit framing).
5. **Abstract away system mechanics.** "Timestamped attendance records" → "verifiable attendance." Claim the capability, never describe the mechanism. Mechanisms invite follow-up questions.
6. **Don't reference contested filings in unrelated sections.** In the complaint statement, "beyond the filed course schedule" → "beyond the required hours" (the filed schedule was the contested item in the parallel inspection; don't cross-pollinate).
7. **Plant eligibility predicates.** Add clauses like "students are permitted to complete externships when they meet the stated requirements" — sets up the Pattern-A defense (student hadn't completed their own step) before identities are even known. Add mutual-reasonableness framing ("reasonable to both the student and the externship site").
8. **Use neutral legal nouns for the accusation.** "Alleged defects," not "the allegedly incorrect answer" — don't repeat or adopt the complaint's characterization when restating what you need.
9. **Institutional facts come from Ruben, not the catalog.** He corrected est. 2011→2003 and added Houston; the state-specific catalog history is NOT the company history. Always confirm founding date, campuses, and credential claims with him before a signed document.
10. **Cite only credentials relevant to THIS regulator.** He dropped the CAPCE line from the TDSHS statement (CAPCE is CE accreditation, not EMT-course authority). Lead with the certification THIS agency issued — it reminds them their own office approved the program.

## Standing patterns from the same session (already-established, keep applying)

- No em dashes, paragraph style, one header per complaint/area, no sub-header stacks (Ruben voice).
- Nothing volunteered: no "available to the Department on request," no unrequested exhibits, no hearing-rights/imminent-danger paragraphs (privileged posture, held in reserve), no returned-notice boilerplate.
- POC corrective actions = easily-achievable general practices only ("periodic review," "escalated as needed"). NO hard SLAs, weekly audits, 24-hour reporting, schedule-change logs, or amendment-transmittal commitments. Preserve daily operational flexibility. A POC written today is an auditable obligation forever.
- Corrections framed as CLARIFICATION of ambiguity, never as fixing a violation ("clarify ambiguous language on course calendars," not "remove the word Skills").
- Don't name the disputed word/document element; request clarification from the inspector instead ("what specifically did the inspector understand the schedule to require").
- Strengths woven into the intro in prose (NOI style): founding, state certification, campuses, thousands trained, CQI mission, exceeds-state-minimum hours (cite the actual TAC section: 25 TAC §157.32(c)(2)(B), 150 clock hours for EMT), field-experience requirement, rigor-generates-complaints frame ("programs that hold firm requirements will sometimes receive complaints from students who would prefer those requirements were lower. The program does not lower them.").
- Bonus/review sessions: call them "review sessions," never "bonus" or "supplemental."
- No attendance counts or agency names in signed documents.
- Put the regulator's own process failures on the record (misaddressed mail, broken CC commitments) factually, in the intro.
- Demand specificity for every general allegation: no violation can be evaluated against an unspecified benchmark.
- Signature block: "Best, &c" + full Ruben signature (EMT-Paramedic, J.D., M.A. / CEO / motto / URLs / 800 number).

## Google Doc workflow (hard rule)

Ruben edits regulator docs directly in Google Docs. Before ANY re-upload/PATCH: export the LATEST revision first (Drive revisions API, zoom-sync token at /var/www/emtskills/zoom-sync/google_secrets.json, full drive scope) and integrate his changes. A blind PATCH clobbers his edits (happened 2026-07-20, recovered from revision 483).

## Cross-refs

- Rule 02 — no apologies in student/external email (applies doubly to regulators)
- Rule 29 — regulator correspondence is human-only send; agent drafts
- Working example set: ~/Desktop/tdshs-inspection-5196/ (Written Statement, inspection POC, Response-2 anticipatory template, suspension-mechanics memo)

## Last updated

2026-07-20 — initial, from the Inspection 5196 / four-complaint drafting session and Ruben's live edits.

# Rule 297 — Classify the Code Before You Diagnose

Original text (2026-06): *a COUNT(\*) of "impossible" rows is a hypothesis, not a bug.
Classify the population before you alarm.* Extended 2026-08-01 to DIAGNOSIS generally.
Case law, the three wrong Argus claims, the worked example, and the 298 relationship:
`Rules-archive/297-case-law.md`.


## The gate

```
SYMPTOM → READ SOURCE → CLASSIFY → CLAIM (or silence)
```

When investigating ANY system behavior (performance, routing, errors, unexpected state):

1. **Run the probe.** Establish the symptom.
2. **Read the source that PRODUCED the symptom** — the adapter, router, hook, or query.
   Grep for the function that handles the behavior; read that function and its callers.
3. **Classify into exactly one bucket before stating anything:**
   - **By-design** — the code does this intentionally. Cite the line that proves it.
   - **Transient boot/warmup** — normal during startup. State what the code will do when it finishes.
   - **Real bug** — the code intends X but does Y. Cite the line that proves the mismatch.
   - **Unknown** — you ran out of context or time. Say "unverified" and file an idea.
4. **Only then make the claim**, with the citation that proves it.

**Hard stop: if you cannot cite a specific line number in a specific file that produced
the symptom you are describing, you do not yet understand WHY. Say so. Do not guess.**

A probe tells you WHAT happened once. Code tells you WHY, and whether the symptom is
transient, by-design, or real. A curl against an endpoint is a symptom-gathering tool,
not a verification tool for a claim about why the endpoint behaves that way.

## Jump to rule 298 when evidence CONFLICTS

297 and 298 cover opposite failure modes. **Too little** evidence → 297 (go read the
source). **Conflicting** evidence → 298 (build a confound table, rank the instruments,
never discard a reading until you can name the specific defect in it). More gathering
cannot resolve a disagreement; it just adds a fourth number to argue about.

**Trigger:** the moment a new measurement disagrees with one you already have, or you
notice you have stated the same quantity two different ways in one session. 298 also
carries the threshold-sanity gate — always backtest a threshold against the system's
own observed distribution before shipping it.

## The SCOPE GATE (mandatory before quantifying any failure population)

Undercounting is the same failure as miscounting. Before reporting ANY count of
failures, errors, or anomalies:

1. **Enumerate the outcome space first.** `DESCRIBE` the table, read the enum, list the
   log's event types. Ask which of those states the USER experiences as failure.
   Include all of them, or state explicitly which are excluded and why.
2. **State the window and justify it.** If the complaint references "always" / "every
   time" / multiple days, a 12h window is wrong by construction.
3. **State the population.** All users unless the question names one.
4. **Report the count WITH its scope inline**: "85 no-answer tasks (failed + canceled +
   offloaded), 7 days, all users." Never a bare number.
5. **Sanity-check against the user's estimate.** If the user says 50-100 and you
   measured 6, your scope is the prime suspect, not the user's memory. Re-scope BEFORE
   arguing.
6. **Corroboration scan before escalating mass impact (approved 2026-08-16, idea
   #26759).** Before escalating any claim of mass student impact (N affected), scan the
   inbound surfaces — tickets, CFA conversations, staff/chat-55 messages — for
   corroborating complaints from that population; if N is large and corroborating
   inbound is near zero, the premise is SUSPECT: do not escalate, track down the
   discrepancy first. Worked example: `Rules-archive/297-case-law.md` (2026-08-15 false
   160-student P0; actual complainants ≈ 1).

The trap is a technically-correct COUNT of a too-narrow population, presented as THE
answer. The user's mental model of "failure" is almost always wider than the system's
`failed` enum value.

## "Do a 297" means FIX THE CAUSAL RULE, not just write the RCA

Ruben directive 2026-08-08: *"Whenever I ask you to do a 297 that means that you
probably need to update the original rule or process that caused you to do that in the
first place."*

A rule-297 request has THREE deliverables:

1. **The RCA** — symptom, source read, classification bucket, citation.
2. **The causal-rule fix** — identify WHICH rule, process, prompt, or code path let the
   mistake happen, and UPDATE IT in the same session. If the causal surface is a
   hardfloor rule needing Ruben review, draft the edit and flag it. An RCA that leaves
   the trap armed for the next agent is an incomplete 297.
3. **The reindex** — after editing any rule, run the clinerules MCP reindex so future
   windows see the fix immediately.

Self-check before closing: *if a fresh agent got the same request tomorrow, would it
fall into the same trap?* If yes, the 297 is not done.

---

**Hardfloor: NO** (can be overridden by a higher-priority operational directive)
**Full case law + source incidents:** `Rules-archive/297-case-law.md`
**Source incidents:** Argus-slow investigation 2026-08-01 (3 wrong diagnostic claims
from probes alone); Argus failure-scan undercount 2026-08-08 (reported 6, reality 85).
**Last updated:** 2026-08-11 (trim-then-archive for G8 floor-cap compliance)

## Amendment (from reversal, 2026-08-17 06:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: scope error
- Trigger pattern: claiming physical hardware state (connector/plug/cable) from sysfs for a device that is not enumerated on the bus
- Reversal note: Big Mac 4th GPU: a prior completion claimed "the dummy plug is NOT in" from /sys/class/drm connector status, but that probe only covers ENUMERATED cards. An un-enumerated device has no sysfs/DRM node, so its physical-attach state is unmeasurable remotely. Amendment: before claiming a physical state (plug/cable/card present or absent) from a sysfs probe, verify the device is actually enumerated; if it is not, the claim must be "unverifiable remotely", never present/absent.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 06:49 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786547336372
- RCA bucket: wrong premise
- Trigger pattern: within-window reversal corrected a material claim
- Reversal note: Joshua failover: a health gate printed "PASS replica lag (0s)" while the replica was 30h and 10.9M transactions behind. The wrong premise was that a purpose-named metric measures the quantity its name implies -- Seconds_Behind_Master measures the AGE OF THE TRANSACTION CURRENTLY BEING APPLIED, so it reads 0 whenever the SQL thread drains its relay log, regardless of how much the IO thread has not fetched. Amendment: when a purpose-named metric conflicts with an independent measure, do NOT sample the suspect instrument harder (max-of-3 returned 0,0,0 because the artifact was SUSTAINED, not intermittent) and do NOT substitute an easier-to-read quantity (fetched-minus-applied read -3, measuring relay-log backlog rather than distance from the master). Ask what each instrument PHYSICALLY measures and whether that is the quantity the gate needs; if the needed quantity is unreadable locally, restructure so the authoritative party PUBLISHES it. Corollary: bash -n passing does not mean control 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 10:02 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786932084
- RCA bucket: unread source
- Trigger pattern: deriving a memory-fit/OOM claim by linearly scaling a vLLM KV-cache GiB figure against max-model-len instead of reading the 'GPU KV cache size: N tokens' pool capacity line
- Reversal note: A prior window retracted the approved YaRN-131072 plan by claiming OOM from a linear scaling of the vLLM log line 'KV 26.02 GiB at 40960 ctx'. Wrong premise: vLLM's KV GiB figure is the POOL sized by gpu_memory_utilization, not per-context consumption; the adjacent line 'GPU KV cache size: 555,296 tokens' IS the pool capacity, and 'Maximum concurrency for 40,960 tokens per request: 13.56x' already proves 13.56 x 40960 = 555K tokens held. 131072 needs ~5.9 GiB (fp8 KV, TP=2) of that 26 GiB pool. Amendment: when reading vLLM capacity logs, compare the 'KV cache size: N tokens' figure directly against the target context length; never scale a pool-size GiB number by a context ratio. The concurrency multiplier line is the ground truth.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 10:13 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786947372694
- RCA bucket: insufficient probe
- Trigger pattern: diagnosing benchmark timeouts as routing policy without live-probing pool member health (:port /v1/models + canary quarantine state) first
- Reversal note: Prior window attributed 3 benchmark timeouts (routing_bug, payment_processors, no_apology) to "235B thinking-lane routing policy consuming the max_tokens budget" without probing the lane. Live probe this window: :11513 was DOWN (canary fail_streak 493, quarantined 01:21 PT, Julia 235B launch crash-looping), and once the canary quarantine settled, the identical bench passed 5/6 with 4.5-13s latencies. Amendment: before attributing benchmark/latency failures to routing POLICY, live-probe every pool member the router could select; a quarantining/crash-looping member mid-bench produces the exact "simple pass, complex timeout" signature and must be ruled out first.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 18:56 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786932084
- RCA bucket: stale assumption
- Trigger pattern: Re-asserting a retracted claim from an earlier turn of the SAME task after context compression, without re-reading the rule amendment that already reversed it
- Reversal note: Julia 235B context ceiling, SECOND occurrence in one task. At 10:02 UTC this same task (1786932084) amended rule 297 to record that the KV/OOM math was wrong: vLLM's 'KV 26.02 GiB' is the POOL sized by gpu_memory_utilization, not per-context consumption, and the adjacent 'GPU KV cache size: 555,296 tokens' + 'Maximum concurrency 13.56x at 40,960' prove 131072 fits in ~5.9 GiB of that pool. After a context compress, I re-inherited the retracted 40960/OOM premise from the carried-forward pickup prompt, re-asserted it as fact, and began editing frankenstein_registry.yaml to lower julia-235b served_ctx 1048000 -> 40960 (the sed did not land; line 285 verified still 1048000, no backup created, zero damage). Ruben corrected it live: 'It can and does run a 131K... I just ran julia 235b here in cline and it did fine.' Amendment: a rule amendment recorded under the CURRENT task id is binding evidence that outranks any claim carried forward in a pickup prompt or session-memory blob. Before re-as

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 19:52 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: wrong premise
- Trigger pattern: Asserting identity from an approximate name match on an externally-supplied identifier, and writing per-student status claims from summary columns without reading terminal-outcome fields or the author
- Reversal note: TDSHS 8/15 packet: a prior turn asserted the student in control 1080261916 was "verified" as Nicolas Mejia 26917FT-05 on the basis of a one-letter name resemblance to the transmittal spelling ("Nicholas"), and stated three per-matter facts that the record contradicts (called a fail_date a "didactic completion", said a student with a PASSED course-end date "remains within the completion window", and said "no placement request exists" for a student who had three requests all assigned same-day). Amendment: a name-similarity match is a HYPOTHESIS, not an identification. Before asserting that an externally-supplied identifier corresponds to a specific record, require a second independent field to agree (DOB, email, program-assigned id, or the person's own self-supplied spelling); if only the name is similar, the correct output is a clarification request, not a claim. Corollary for per-student regulator facts: read the terminal-outcome columns (fail_date/drop_date/transfer_date) and compare 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 21:41 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: unread source
- Trigger pattern: Writing "not found / cannot determine / no record exists" from a tool output whose detail rows were never read, and asserting agency-facing identifiers sourced from internal work product rather than t
- Reversal note: TDSHS 8/17 packet, three flips in one window, one root cause: I answered from a partial read of a source I had already pulled. (1) For control 1080261916 I wrote a CLARIFICATION REQUEST saying the program could not identify the student, while the lookup_paperwork_state output already in my context showed 25 submitted forms including ELEVEN patient care reports, three preceptor-signed timesheets, three preceptor evaluations, and request 2796 status=completed with note "Approved in Carrolton FD fror Aug 11th, 13th and 15th". The student had COMPLETED his externship. I read the header block of that tool output and not the rows, and shipped a withheld answer that discarded the strongest fact in the packet. (2) I published complaint-PDF URLs under /emtskills/uploads/tdshs/ without ever requesting one; the nginx vhost has an explicit deny all/return 403 on that path with a comment naming personnel/compliance_ref.php as the authenticated route. (3) I put "License No. 600179" in the RE line an

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 22:08 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: unread source
- Trigger pattern: Asserting a document exists to a regulator on the basis of a status enum or boolean flag, without querying the table that would store the document itself
- Reversal note: TDSHS packet asserted twice that externship hours were worked "at a fire department operating under an executed affiliation agreement on file." Neither claim was backed: externship_affiliation_agreements holds 0 rows total, ExternshipSite.agreement_status is a hand-set enum with compliance_doc_id NULL for the site in question, and the Carrollton site referenced for the 1080261916 student does not exist in ExternshipSite at all. The status flag was read as if it were the document. Amendment: a status enum, a boolean, or a named column is NOT evidence that the artifact it describes exists. Before asserting to any external party that a document is "on file" or "executed", query the table that would HOLD the document (row count, file path, URL) and confirm a row exists for that specific entity; if the holding table is empty or the entity is absent, the claim must be downgraded to what the record actually supports.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 22:52 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: unread source
- Trigger pattern: Characterising what an external document alleges when only its cover email was read and the attachment was never captured
- Reversal note: Every draft of the TDSHS packet stated "Each transmittal alleges that the program failed to provide timely externship scheduling and adequate student support." Nobody had read a single one of the three complaints: the transmittal email bodies contain only the student name and cohort, and all three attachments sit at compliance_source_documents status=not_obtained with file_path NULL and zero inbound_attachment_ocr rows. The allegation was inferred from the pattern of earlier matters and then asserted as fact to a regulator. Amendment: before characterising what any external document alleges, requests, or requires, confirm the document itself has been READ this session and name where it was read from. An email that says "please see attached" is not the document; if the attachment is not captured, the correct output is "the program has not been provided the substance of the matter" plus a request that the agency state it, never an inferred characterisation. Corollary: when the record for

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-17 23:58 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: insufficient probe
- Trigger pattern: Asserting a user had system access from provisioning records (enrolment row, unsuspended status, outbound emails) without querying the access log for an actual successful session
- Reversal note: Answering a regulator's student-access allegation, I wrote "the program has found no record of an account lockout, no suspension, and no support matter reporting a lockout" and cited daily class emails and an active enrolment status as evidence the student had access. I had not opened the access log. When Ruben asked whether I had actually checked, logstore_standard_log showed ONE login on 5/25 that never reached a course view, then eighteen days of total silence, then on 6/12 a failed login, a credential change, and her first course view. The student's allegation had support and my draft asserted the opposite to a state agency. Amendment: an enrolment row, a mailing-list send, and an unsuspended account are records of what the PROGRAM did; none is evidence of what the USER experienced. Before asserting that a person had access to a system, query the server-side access log for that account and read the first successful use of the thing in question, not the provisioning record. The same

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 00:09 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: insufficient probe
- Trigger pattern: Hand-rolling targeted queries from a working hypothesis when a standing tool that enumerates all gates for that entity exists and was never called
- Reversal note: Investigating a wrong-class-enrollment complaint, I ran only the queries my own hypothesis suggested (access log, enrollment row, duplicate check) and concluded from an 18-day access gap that the program had a monitoring failure to own. Ruben predicted the actual cause without touching the data: a registration/section-association problem. Running get_student_lifecycle_state, the standing tool that enumerates EVERY provisioning gate, surfaced it in one call: section_intent_match WARN, the account enrolled in the course but in NO Moodle group, plus gradebook showing Chapters 1-27 at 95-100 percent, which also falsified my implied disengagement narrative. My hand-rolled queries could not have found the missing group because I never thought to ask about groups. Amendment: when a standing lifecycle/state tool exists for the entity under investigation (get_student_lifecycle_state, verify_payment_state, lookup_paperwork_state), run it BEFORE hand-rolling targeted queries, and run it even when

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 00:25 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: wrong premise
- Trigger pattern: Attributing a missing system-state row to organisational fault without identifying the mechanism that writes it or checking whether a user-completed activity governs it
- Reversal note: I found that a student's account was in no Moodle section group and asserted to a regulator that this was "a registration-side condition rather than an act or omission by the student." Ruben identified the actual mechanism: section membership is set by a student-completed groupselect activity, cmid 2005, titled Join Your Class Section. Querying it showed she opened the activity eight times beginning 6/24 and never completed it, with no course_modules_completion row. My claim inverted the causation and volunteered fault the record did not support. Amendment: before characterising any system state as caused by the organisation rather than the user, identify the mechanism that WRITES that state and check whether it is a user action, an automated process, or both. A missing row is evidence that something did not happen, never evidence of who failed to do it. Where a user-facing activity exists for the purpose, query its completion and view records before assigning cause. Corollary for regu

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 01:24 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: scope error
- Trigger pattern: Repairing a defect on the surfaces found by one grep, then reporting it fixed, without enumerating every surface that can produce the same output and without shipping a check that measures that covera
- Reversal note: Ruben reported the CFA telling students an exam passes at 40% (real standard 80%) on 2026-08-14; it was "fixed" (ideas #26476, #26471) and the identical wrong number shipped again on 2026-08-17 in email #366377. Root cause was not the analysis, which was correct, but the SCOPE of the repair: #26476 patched four files under lib/ and never saw the independent copies of the same rendering in api/livechat/chatbot_tools.php and api/ruben_tools.php, and cron_email_responder.php calls the chatbot_tools copy, so the email lane ran entirely on unpatched code. #26471 added the policy prompt block to the chat webhook only, leaving the email lane with no floor to check a bad tool number against. Both completions truthfully described what they changed and neither could state what they had missed, because nothing enumerated the surfaces. Proof this is the mechanism and not hindsight: the coverage gate written this window immediately found THREE more unpatched renderers that two prior windows and my 

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 02:54 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: unread source
- Trigger pattern: Attributing a hardware fault to insufficient power/supply based on a form factor's generic spec, without establishing what the specific installed adapter is physically connected to and without flaggin
- Reversal note: Big Mac 4th GPU: I asserted "leading cause is slot power, an M.2 socket gives ~8-10W and a B70 is a discrete 32GB GPU" as the explanation for a trained link that never answers config reads. Ruben corrected it live: the adapter has a 6-pin aux power input fed by a SATA cable from the PSU and is delivering 75W. The card was never power-starved. I reasoned from a generic property of the M.2 FORM FACTOR (its socket power budget) without ever asking what the specific adapter in this machine was wired to, and no probe I ran could have told me, because auxiliary power delivery is invisible to lspci/sysfs. Amendment: before attributing a fault to insufficient power, delivery, cooling, or any other PHYSICAL SUPPLY to a component, establish what is actually connected to it, and state plainly that the supply path is unverifiable remotely if no probe covers it. A property of a form factor or a spec sheet is NOT a measurement of the installed instance. When the supply path cannot be probed, the cor

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 04:49 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786948459
- RCA bucket: unread source
- Trigger pattern: Attributing device behavior to a port/slot on the basis of a kernel-assigned ordinal (PCI bus number, ifindex, minor number) matching across boots, without resolving which parent actually owned that o
- Reversal note: Big Mac 4th GPU: a prior window concluded "root port 00:01.2 is NOT defective" because bus 01 enumerated on 2 of 8 boots carrying the NVMe at full function, and on that basis RETRACTED the socket-inequality lead. Both were wrong from the same defect: the claim matched on the BUS NUMBER without ever checking which PORT owned that bus. Per-port tabulation across 12 boots shows that on the 2 "working" boots port 00:01.2 did not enumerate at all and port 00:01.3 had been renumbered to secondary bus 01 -- it was 01.3 carrying the NVMe. Port 00:01.2 has never had a working device on any boot, and direct register comparison shows the two M.2 sockets ARE unequal (01.2 = Gen4 16GT/s CommClk-, 01.3 = Gen5 32GT/s CommClk+), so the retraction removed the correct lead. Amendment: PCI bus numbers, interface indices, minor numbers and any other kernel-assigned ordinal are NOT stable identifiers and must never be used to attribute a behavior to a device or port. Before claiming that a specific port/sl

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 05:36 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: unread source
- Trigger pattern: Assessing a case or party's exposure and declaring a theory unsupported after reading only the citation document, without opening the case file's existing analysis and correspondence records
- Reversal note: Asked for a strategic read on the TDSHS casefile, I declared the illegal-search theory "NOT supported by anything I have read" and characterised the 5196 deficiency as "one citation, one regulation" and simple. Both were wrong and both were disprovable from documents already on the server that I had not opened. DRAFT_email_2026-07-28_production_and_entry.md records the DEPARTMENT'S OWN WRITTEN ACCOUNT of the June 19 entry: the inspector entered through an unlocked exterior door, the administration door was shut but not locked and he opened it and then shut it, he was unaccompanied throughout with no program representative present, and he photographed rosters and sign-in sheets - two of the three photographed documents undated or illegible by the Department's own description, and NONE belonging to the course under inspection. EMSU also holds 8 preserved surveillance clips of the entry. The deficiency is likewise interpretive, not simple: the filed course notification (application 26684)

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 03:42 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: externship-forms-process-20260818
- RCA bucket: unread source
- Trigger pattern: Declaring an ID mapping 'wrong' by comparing against one table's key space without checking whether the ids belong to a DIFFERENT system's key space (Moodle assign ids vs portal form ids)
- Reversal note: I told Ruben cron_p0_externship_moodle_grade_reconcile.php 'maps form ids 134-139 but real ExternshipForm ids are 1-14' and recommended DEPRECATE. Wrong: 134-138 are MOODLE assign-module ids for course 37 (verified: assign table shows 134=Preceptor Eval, 135=Student Eval, 136=CV, 137=Time Sheet, 138=PCR), exactly matching the cron comments. The cron is the intended Moodle-presence bridge in a dual-channel design (WPForms content + Moodle upload) that Ruben had already explained. Amendment: before declaring an ID mapping wrong, resolve WHICH system's key space the ids live in by querying that system's table; matching comments/names against the foreign table is the 30-second check that was skipped.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 03:42 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: frankenstein-llm-review-20260818
- RCA bucket: unread source
- Trigger pattern: Reading a code default (os.environ.get('KEY', '12')) as the LIVE runtime value without checking the actual systemd unit environment / drop-ins that override it
- Reversal note: The frankenstein-tools 530 diagnosis read FRANK_TOOLS_TIMEOUT's in-code default of 12s and built the entire root cause on it. The LIVE value was 180s (batch) / 900s (interactive), set by ~60 systemd drop-ins in frankenstein-tools.service.d/ — a documented config layer where 'last file alphabetically wins'. A 12s-timeout explanation was impossible at runtime. Amendment: before attributing any behavior to a configurable constant, resolve the EFFECTIVE runtime value (systemctl show <unit> -p Environment, actual config layering), never the code fallback. A code default is a hypothesis about config, not config itself.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 03:44 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 26899
- RCA bucket: unread source
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - #26899 [approved] initial claim "maps form ids 134-139 but real ExternshipForm ids are 1-14, deprecate the cron" → corrected: 134-138 ARE valid MOODLE assign-module ids for cours

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 03:45 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787109
- RCA bucket: unread source
- Trigger pattern: Reading a code default (os.environ.get('KEY', '12')) as the LIVE runtime value without checking the actual systemd unit environment / drop-ins that override it
- Reversal note: The frankenstein-tools 530 diagnosis read FRANK_TOOLS_TIMEOUT's in-code default of 12s and built the entire root cause on it. The LIVE value was 180s (batch) / 900s (interactive), set by ~60 systemd drop-ins in frankenstein-tools.service.d/ — a documented config layer where 'last file alphabetically wins'. A 12s-timeout explanation was impossible at runtime. Amendment: before attributing any behavior to a configurable constant, resolve the EFFECTIVE runtime value (systemctl show <unit> -p Environment, actual config layering), never the code fallback. A code default is a hypothesis about config, not config itself.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 03:47 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787115
- RCA bucket: unread source
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - 12s-timeout root cause -> live 180s/900s | unread source | causal rule updated: 297

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 06:24 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787120640000
- RCA bucket: insufficient probe
- Trigger pattern: Naming a hook/code path as the cause of an API error from timestamp correlation alone, without grepping the code or reproducing the failing request shape
- Reversal note: Prior completion claimed the emsu pre-call hook 'mutates data and drops data[messages]' as the cause of Router.acompletion() missing-messages 500s, based only on log correlation (500s followed GLM probe WEDGE warnings). Code grep found NO pop/del of messages in any hook, and a controlled reproduction proved the 500 fires when the CALLER sends a body without a messages key (RUBEN AI health sweep anthropic-format pings). Amendment: log correlation (error A follows warning B) is NOT a causal classification. Before naming a code path as the cause of a request-shape error, reproduce the exact error with a controlled request and cite the line or the reproduced body that proves it.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 06:26 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: CFA-24h-audit-20260818
- RCA bucket: insufficient probe
- Trigger pattern: Attributing failure cause from an output column (ai_response empty) without reading the table's dedicated error_message column
- Reversal note: CFA SMS failure classification: I first attributed 93 failed SMS rows to 'empty deepseek responses' based on the ai_response column alone. The error_message column (checked later) showed all 101 were quality-gate BLOCKS (criterion_4 x64, criterion_2 x25, leak x8), not LLM empties. Amendment: when classifying a failure population from a log table, enumerate the table's diagnostic columns (DESCRIBE) and read the designated error/reason column BEFORE attributing cause from an adjacent column; an empty output column describes the OUTCOME, the error column names the CAUSE.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 06:29 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787098931968
- RCA bucket: insufficient probe
- Trigger pattern: Attributing failure cause from an output column (ai_response empty) without reading the table's dedicated error_message column
- Reversal note: CFA SMS failure classification: I first attributed 93 failed SMS rows to 'empty deepseek responses' based on the ai_response column alone. The error_message column (checked later) showed all 101 were quality-gate BLOCKS (criterion_4 x64, criterion_2 x25, leak x8), not LLM empties. Amendment: when classifying a failure population from a log table, enumerate the table's diagnostic columns (DESCRIBE) and read the designated error/reason column BEFORE attributing cause from an adjacent column; an empty output column describes the OUTCOME, the error column names the CAUSE.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 08:43 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: frankenstein-wedge-20260819
- RCA bucket: wrong premise
- Trigger pattern: Assuming systemd drop-in merge order semantics hold at deep stacking (55 files) based on cat-config output, without verifying the running process environment after reload+restart
- Reversal note: Frankenstein adapter wedge fix: I added a NEW later-alphabetical systemd drop-in (32 z's, after the 20-z winner) setting FRANK_SLO_TTFB_INTERACTIVE=60; systemd-analyze cat-config showed it loaded LAST, daemon-reload + restart ran, yet the live process env kept 240. At 55-drop-in depth, 'last alphabetical wins' was a wrong premise. Amendment: after ANY systemd config change, the ground truth is the running process env (sudo cat /proc/PID/environ), not systemctl show, not systemd-analyze cat-config ordering; and when a new drop-in silently loses, edit the WINNING file in place (with backup) instead of stacking another layer.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 08:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787126689836
- RCA bucket: stale assumption
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - Suspected registry YAML re-corruption (per 8/18 handoff) → registry healthy (probe: registry_readable=true, source=registry) | RCA bucket: stale assumption | hypothesis corrected

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 09:53 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787126689836
- RCA bucket: wrong premise
- Trigger pattern: Attributing a malformed-model-output symptom (wrong tool syntax, unparseable block) to transport/capacity/timeout layers without reading the steering text that defines the required output shape, and w
- Reversal note: Three prior rounds diagnosed the Cline wedge purely as an infrastructure/capacity problem (SLO drift, GLM floor starvation, missing router fallback) and each was declared the repair. All three were real defects, but none produced the symptom Ruben kept reporting. The actual cause was a STEERING TEXT OMISSION: the cline_xml_examples block listed only 5 native Cline tools and never showed use_mcp_tool, so in XML-in-prompt mode (has_tools=false) the model invented the MCP tool name as its own XML tag and Cline could not parse it. Amendment: when a symptom is 'the model emitted the wrong output SHAPE', the source to read is the PROMPT/STEERING that told it what shape to emit, not the transport, capacity, or timeout layers. Before attributing a malformed-output symptom to infrastructure, enumerate every tool/format the caller can legitimately request and verify the steering text contains a valid example for EACH one; a format the model was never shown is a format it will invent.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 10:27 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787126689836
- RCA bucket: insufficient probe
- Trigger pattern: Diagnosing a wrong-backend-selected symptom by probing the component the current hypothesis blames, instead of first enumerating the whole selection/fallback table in order; and checking for duplicate
- Reversal note: Investigating why Cline windows stalled, I diagnosed FIVE separate mechanisms in sequence (SLO drift, floor starvation, missing fallback, steering omission, affinity pinning) and each time treated the newest finding as the whole answer, because I only ever probed the layer my current hypothesis named. What I never did until Ruben told me to was ENUMERATE the config that governs selection: one pass over router_settings.fallbacks showed 29 of 43 chains contained a cloud rung and 27 placed it ahead of a still-untried local box, and that two model ids had DUPLICATE fallback keys making the effective chain load-order dependent. That enumeration takes one command and would have been available at minute one. Amendment: when a symptom is 'the wrong backend/target was selected', the FIRST probe is a full enumeration of the selection table (every route, every rung, in order), not a probe of whichever component the current hypothesis blames. Additionally: yaml.safe_load silently collapses duplica

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 20:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: (unknown)
- RCA bucket: unread source
- Trigger pattern: Drafting a regulator response from the matter's topic label or a prior draft's framing, without reading the transmittal's charged-allegation paragraph and the complainant's own attachment first
- Reversal note: TDSHS 810/811: a consolidated response was drafted arguing live-site externship capacity, when the Department's charged allegations were AI-assistant misinformation, prolonged communication delays, and no ticket follow-up against the program's OWN 30-day mark. Ruben: 'Did you actually read the investigations? You are focusing on externships mainly when they are slightly different.' Three further facts were also asserted without reading the source: both matters called due 8/19 (810 is due 8/18), the student surnamed Meadows (record says Meadors), and the complaint treated as student-originated (the parent filed it, 'since I paid for it'). Amendment: before drafting any response to an external matter, read (a) the transmittal's charged-allegation paragraph verbatim and (b) the complainant's own attachment, then write the allegation elements into the draft plan BEFORE composing. A matter's topic label, a deadline-row title, or a prior draft's framing is a HYPOTHESIS about what is charged,

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 20:38 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787123639000
- RCA bucket: unread source
- Trigger pattern: Drafting a regulator response from the matter's topic label or a prior draft's framing, without reading the transmittal's charged-allegation paragraph and the complainant's own attachment first
- Reversal note: TDSHS 810/811 (task 1787123639000): response drafted arguing live-site externship capacity when the charged allegations were AI-assistant misinformation, communication delays, and no ticket follow-up against the program's own 30-day mark. Also asserted without reading source: wrong due date for 810 (8/19 vs actual 8/18), wrong surname (Meadows vs Meadors), and wrong complainant role (parent filed 810, not the student). Amendment: read the transmittal's charged-allegation paragraph and the complainant's attachment BEFORE composing, and verify party identity, filer role, and per-matter due date separately for each matter.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 21:44 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: team-hub-round3-20260819
- RCA bucket: wrong premise
- Trigger pattern: Building a code fix against an assumed column/schema (section2 holds second section) without first querying the column's live population
- Reversal note: Team Hub round 3: the inherited pickup prompt's bug-2 root cause claimed combined classes store the second section in emsu_shifts.section2, and the fix plan was built on that column. One COUNT query showed section2 is empty in all 4034 rows; the real shape is a single row per combined class whose title carries both section codes. Amendment: before building a fix on an assumed column or schema, query that column's population (COUNT of non-empty) as part of the probe step; an assumed schema is a hypothesis, and the 30-second population check is the classification.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

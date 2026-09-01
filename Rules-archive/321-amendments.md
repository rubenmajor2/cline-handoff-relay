Rule 321 - Amendment trail (auto-maintained by clinerules_amend_rule)

Rule 321 is always-loaded, so amendment prose may not live in its tail (rule 317 clause 11).
Every reversal amendment for this rule is appended HERE. A DURABLE fix still requires a hand edit to a
numbered clause in the live rule file: /Users/rubenmajor/Documents/Cline/Rules/321-gaslighting-rule.md

---

## Trimmed from the always-loaded rule 2026-08-28 (rule 317 clause 11: 7 amendment(s))

## Amendment (from reversal, 2026-08-20 03:35 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787138864086
- RCA bucket: stale assumption
- Trigger pattern: completion re-lists an already-approved idea with approval-seeking language instead of executing it
- Reversal note: 2026-08-19 false-gate incident: agent re-presented ideas #27524/#27531 for approval AFTER Ruben's approve actions had already landed at 17:04 PT, treating the DB 'awaiting_review' workflow stage as a re-approval queue. Amended behavior: an idea with a recorded human approve action is EXECUTED, never re-presented for approval; the reconcile 'awaiting_review' tag means the executor's written record sits at review stage, not that the human decision is pending. Executing approved work never requires asking again.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-20 04:39 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787191612298
- RCA bucket: insufficient probe
- Trigger pattern: Claiming deployed/shipped based on stamping the idea row status, without a separate read-back of the actual file/view/script
- Reversal note: 2026-08-19 deploy-claim reversal: completion claimed 3 mechanisms deployed and stamped orchestrator_ideas status=deployed, but read-back verify found the drift-detector script + scoreboard view NEVER existed on disk/DB (only the truth index existed, under a different name than claimed). Amended behavior: a [deployed] tag or status=deployed stamp REQUIRES a separate read-back probe of the ACTUAL artifact (file on disk via ls/find, or DB object via information_schema) in the same window. An idea-row status stamp is NOT evidence the artifact exists. G5 premature-completion now explicitly covers 'stamped the idea deployed but never built/verified the artifact.'

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-22 21:00 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787121837052
- RCA bucket: wrong premise
- Trigger pattern: detection-only gate presented as 'by design'; presenting options instead of acting on a false gate
- Reversal note: 2026-08-22 VERITAS reversal: a detection-only truth gate and a trigger that blocks all repair are both false gates (G6 hidden gate). Truth that can detect but not repair is decorative. Amended behavior: when a truth/verification system finds a provably-false state (e.g. status=deployed with no artifact and no build history), the repair path must exist and be acted on, not just logged. Presenting options A/B/C instead of acting on a structural blocker is inaction; after human approval of the approach, act immediately.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-22 21:04 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787430120000
- RCA bucket: wrong premise
- Trigger pattern: approved buildable work dispositioned as human-only decision instead of being built in-window
- Reversal note: Within-window reversal: first completion dispositioned approved RUBEN issue 3952 as '(human-only decision — no idea)' — a post-completion deferral of ALREADY-APPROVED work. Ruben: 'Why is this a human decision? This was already approved. This should be built and shipped.' Corrected same window: diagnosed, built, and shipped all three fixes (heartbeat rows, delivery-watchdog run definition, phantom-column repair), verified live, marked the issue resolved. Reinforces existing 321 text: approved = deploy; deferring approved buildable work to a human is a G6 hidden gate.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 04:11 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: argus-repairs-20260825c
- RCA bucket: scope error
- Trigger pattern: work routed to a team that structurally lacks the authority or tooling to resolve it, creating a ticket that can never be actioned
- Reversal note: 2026-08-25: a window escalated 35 stranded exam-override decisions to Customer Service as ticket 27843. Ruben: 'Escalating an override as a ticket to customer service is a false gate and it is gaslighting' — CS has no authority or tooling to resolve overrides (argus_role_permissions: CustomerService tier=0, read_only=1), so the ticket could never be actioned by its recipient. Amended behavior (G6 hidden gate): before routing ANY item to a team or role, verify that role actually has the authority AND the tooling to resolve it — check the permissions/role table, not the item's topic. Routing work to a recipient who structurally cannot act on it is a false gate even when the ticket is real and well-documented; the correct move is to resolve it yourself per rule 29 or route to the role that holds the capability.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-26 07:41 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787697242661
- RCA bucket: scope error
- Trigger pattern: override/mercy decision routed to a role (CS) that structurally lacks the authority; disposition owner not checked against the permissions table
- Reversal note: 2026-08-25: a completion open thread routed the mercy-override decision for 3 course-failed students to Customer Service ('CS grants extension via exam_override.php'). Live probes: argus_role_permissions CustomerService tier=0 read-only; exam_override.php force-approve restricted to MasterAdmin/ITAdmin/jthompson (lines 8, 101-109). CS structurally cannot adjudicate overrides; routing it there is a G6 false gate. Amended behavior: any disposition naming who can override genuine exam enforcement must name Jon/MasterAdmin/ITAdmin (or the AI-validated documented-excuse path), never CS; CS intent is intake, SLS-grounded fault classification, comms, and our-fault standard remedies only. Filed #28241 to codify the split in emsu://reference/exam-retake-policy.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-29 06:24 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787981000000
- RCA bucket: insufficient probe
- Trigger pattern: within-window reversal logged a causal-rule update without repairing it; clinerules_validate_completion auto-repaired the cited rule on behalf of the window
- Reversal note: - initial: reconcile_ideas returned a done tag for the Exam 5 monitor idea -> corrected: artifact read-back showed a 63-line truncated stub with no crontab entry, no registry entry

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

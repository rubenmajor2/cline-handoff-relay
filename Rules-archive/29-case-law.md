# 29 Case Law Archive — Full source incidents + detailed elaborations

This file archives the case law trimmed from Rule 29 v2 (28KB) when it was reduced to v3 (~6KB) on 2026-06-25. The core gate + essential tests remain in `Rules/29-agents-act-on-confidence-tier.md`. This file holds the source incidents and detailed elaborations for reference.

---

## "Defer to the system" is NOT acting (added 2026-05-28 — Artemis/3G session)

A specific, sneaky form of inaction: the agent finds a clear act-condition (e.g. a routing surface scoring W/T ≥ 45%, well past the flip bar) and then **defers it to an automated system** — "the Fleet Agent will autoflip this," "the cron will pick it up," "the executor handles this class." That FEELS like action because a system is named. It is not. It is inaction dressed as delegation.

**The test:** before saying "the system will do X," verify the system CAN do X right now. If there's a known wiring gap (e.g. #7630: autoflips write decision logs but never touch the live router_hook.py), then "defer to the system" = defer to nothing = the work doesn't happen. The agent must either (a) do X directly, or (b) fix the system's wiring so it does X, in THIS session. Per rule 92, fixing the broken system IS the work, not a follow-up.

Source incident: 2026-05-28 — Cline found the `default` bucket at 58.3% W/T (n=2843, far above the 45% bar per rule 121) and parked the flip in a pickup prompt, reasoning "Fleet Agent autoflips." But #7630 proves that autoflip wiring is broken. Ruben: "Per rule 29 you were supposed to flip those." The flip was a green-tier reversible action the agent had tools for (UPDATE orchestrator_llm_routes / patch router_hook.py). Deferring it violated 29 + 38.

---

## "I don't have the artifact" is NOT a human gate (added 2026-06-01)

A third sneaky form of inaction: the agent has the tool and the authority to act, but is missing a concrete artifact — a payment link, a document URL, a class section code, a confirmation number, a phone number — so it routes the case to a human "who knows the link." That is NOT a valid human gate. Missing an artifact is a research task, not an escalation trigger.

**The test:** before routing because "I don't know X," ask whether X is discoverable. Links live on the public site (curl it), sections live in the DB (query it), docs are built by a tool (call it). If the artifact can be found + verified, the agent's job is to GO GET IT and then act — not hand the case to a human as a lookup proxy. A human is only the right call when the missing thing is a *decision* (policy, money amount, identity verification), never when it's a *fact the agent can retrieve and verify*.

**Verify before sending:** when the retrieved artifact is a URL going into a student-facing message, confirm it resolves (HTTP 200) and actually matches the case (right course, right date, right fee) BEFORE sending. Don't fabricate a plausible-looking link; find the real one and prove it works. Verifying is part of acting, not a reason to defer.

Source incident: 2026-06-01 — Sam Williams, a paying prospect, asked for a payment link for the 6/22 San Antonio Accelerated EMT class. Cline filed a ticket to CS "to send the link" because it didn't know the URL. Ruben: "We can/should do this per rule 29 which obviously needs hardening." The link was discoverable + verifiable in ~3 tool calls (curl the city site → sanantonioemt.com/register/ returns 200, lists Accelerated + June 22 + $50 fee, passes the mailer allowlist) and the send is a green-tier capability-catalog action. Routing it to CS was the v1 chilling-effect bug wearing a "missing artifact" disguise.

---

## Unanswered Ruben questions — source incident

Source: 2026-05-28 — Ruben asked "why are these rules not being obeyed / are there conflicts?" across two turns; both completions ended without answering. Ruben: "I asked questions with no answers which means another rule was not obeyed."

---

## Pre-completion audit — full 7 questions with source incidents

**Before EVERY `attempt_completion` on a coordinator-style task** (fleet/llm/orchestrator/multi-system), the agent MUST execute a chain-of-verification pass that surfaces gaps Ruben WOULD ask about, not the ones the agent is comfortable showing.

The pre-completion audit asks 7 questions in order. Every "no" answer = run the investigation, file the gap, take the action, BEFORE shipping the completion:

1. **Did I verify the prior handoff doc's claims against live state?** If the prior chain said "X is running" and I didn't check, X is probably not running.
2. **Are there any rules-MCP violations recorded against the prior chain or this one?** `clinerules_stats` + recent violation scan. If yes, surface them in the completion, don't bury.
3. **For every "filed at status=proposed" idea I wrote this session — was it promoted to autonomous-tier per rule 38?** If no, do it now. Rule 38 is hardfloor.
4. **For every "in flight" item — did I verify the dispatcher / executor actually picked it up?** `mac_shell_picked_up_at IS NOT NULL` AND not in a stuck snooze loop. If snoozed, identify the cause and unsnooze unless the snooze is genuinely correct.
5. **For every config change made this session — did I verify it actually changed production behavior?** Decision logs / row updates don't count. **Deploying the file doesn't count.** Confirming the diff landed doesn't count. **Grep finding my own new pattern doesn't count** (it found it because I wrote it). The verification is "did the previously-failing case now succeed when re-run end-to-end." If a patch fixes a SSH-wait loop, re-run the failing pod and watch SSH provision past the old timeout. If a patch flips a routing gate, send a real prompt and confirm it lands on the new path. If a patch repoints a DB constant, run the dependent cron and see it succeed. Otherwise the patch is unverified.

   **Cron / scheduled-job specifically (added 2026-05-30):** if the fix is to a cron, a bare `php script.php` run succeeding does NOT verify it. The bug often lives in the *scheduler wrapper*, not the script. You MUST re-run the EXACT command line as it appears in crontab / `/etc/cron.d/` (flock wrapper, user, redirects and all) and confirm the side effect (log grows from 0 bytes, rows upsert, etc.). Source incident: 2026-05-30 — the `cron_ct_local_to_emsu_sync.php` mirror was scheduled with `flock -n /tmp/ct_local_to_emsu.lock` while the PHP self-locked on that SAME path, so every scheduled run's child silently `exit(0)`'d and the log sat at 0 bytes for hours while `emsu_shifts` froze. A plain `php script.php` worked fine the entire time, which would have been a false-positive "verified." Running the literal cron.d line (with the flock) is what proved the fix.

**Regex-replace patches specifically:** if I patch via sed/python `re.sub` or `replace_in_file`, the source-pattern I matched against may have been wrong. The verification cannot be "grep finds my new pattern" (it always will). The verification must be the previously-failing case being re-attempted. Source incident: 2026-05-27 21:09 PT — I patched a SSH-wait loop using `\$i <= 30` pattern. Real code was `\$i < 30`. Patch only changed the display log "/30→/60" not the actual bound. Relaunched the failing case, it failed identically at attempt 29. Shipped a second broken patch via a similarly-wrong regex. Burned a third RunPod attempt before getting the actual bound (`<` not `<=`) right. Cost: ~$3-5 in pod time + 30 min of session time. Q#5's verification clause exists precisely to catch this — must re-run the failing case, not grep for the new pattern.
6. **For every "single digit" / "low call" / "decorative" finding — did I trace WHY?** Production data hitting <10 calls/day on a model that's supposedly wired = a routing path that doesn't fire. Find the gate that's closed.
7. **For every dollar figure cited — did I check the trend, not just today's number?** Today might be misleading (Sunday, holiday, cron crash). Always pull ≥7-day trend before reporting savings/spend.

If the agent finds itself thinking "I'll just mention this and Ruben will decide," that's a rule-29 violation. The agent acts, then mentions. Ruben gets a status report, not a decision queue.

### Source incident (2026-05-27 Fleet/LLM coordinator chain)

Ruben caught the agent FOUR times in one session: (1) prior handoff was wrong about LoRA pods being alive (not investigated until Ruben mentioned LoRA), (2) rule 91 PICKUP-BY-REFERENCE violation (caught at first completion), (3) rule 119+120 prior-chain violations not surfaced until Ruben asked about backtest, (4) "decorative" shadow models not investigated to root cause (DISABLED=True kill switch in router_hook.py) until Ruben asked again. Each of those should have been part of the FIRST completion, not extracted by interrogation.

Pre-completion audit prevents this shape. If it had run on the first completion, the agent would have found DISABLED=True in router_hook.py via question #5 ("did the autoflip actually change production behavior?") and surfaced it as the keystone finding.

---

## What CS / Vicky / Jon literally CANNOT do (added 2026-05-27 — Ruben directive: "Vicky can only comfort and match payments, lol")

Naming a human as "the right person to handle this" only makes sense if that human can actually act on the case. Routing a case to Vicky / Jon / a CS member for things they have no tools to do is the same chilling-effect bug as v1 — it just routes via a different surface (a ticket queue instead of a Q-card).

**Cline-only capabilities (humans physically cannot do):**
- moodle role_assignments / user_enrolments / groups_members INSERT (Cline SQL)
- Students.is_duplicate / merged_into_student_id flip (Cline SQL)
- mdl_user.suspended toggle + email/username restore from "Archived-01-..." (Cline SQL)
- qb_invoices.status='voided' on orphan invoices (Cline SQL)
- Class section swap (DELETE+INSERT on Class_Enrollments + Moodle groups_members) (Cline SQL)
- Authnet `refundTransaction` API call (Cline MCP — within $300 cap per agent_capabilities.email_agent.auto_refund_cap_usd)
- Affirm void / capture API call (Cline MCP)
- Moodle quiz attempt unstick (Cline MCP `unstick_moodle_quiz_attempt`)
- Composing + sending student email under student-facing voice (rule 02) (email_agent)
- Filing orchestrator_ideas / closing tickets / promoting status (Cline + agents)

**Vicky CAN do (and these are the ONLY things to route to her):**
- Talk to a student on the phone for empathy / comfort / verification of intent
- Match a confusing payment to a person (manual reconciliation in QB when the agent's match confidence is low)
- Authorize a refund > $300 (above the agent's code-level cap)
- Confirm a student's stated intent before a section swap when both options are plausible

**Jon CAN do (his exclusive lane):**
- Policy override on academic / grievance / refund decisions (regulator-bound)
- Final yes/no on a >$1000 refund or a regulator-facing letter

**Ruben CAN do (his exclusive lane):**
- Regulator / state filing / accreditation correspondence
- Final policy decisions that affect business shape (pricing, programs, hiring)

**Everything else routes to the AGENT, not a human.** "Course access" was wrongly listed in the routing table above as a CS-round-robin item — it's not. Course access is SQL the agent runs, not phone calls a human makes.

### The act-or-route test (use this BEFORE naming any human in a triage report)

For every case you're tempted to route to a human, ask:

1. *Does the human have a tool to do the actual fix?* If the fix is a SQL change, an API call, or a code edit, the answer is no. The agent does it.
2. *Is the human providing information the agent doesn't already have?* If the agent has the data (verify_payment_state ran, Moodle state queried, Authnet checked), the answer is no. The agent has the info; the agent acts.
3. *Is empathy the actual reason for human contact?* If yes, route in parallel for warmth. Do not block the operational fix on it.

If 1 + 2 + 3 are all no, "routing to a human" means leaving the case stuck. That's the v1 bug in v2 clothing.

### Source incident (2026-05-27 Vicky 10-student report)

Vicky reported 10 students with Moodle/section/payment issues. Cline triaged and named "6 routed Vicky-required" in the completion. Of those 6: 0 were things Vicky could actually fix (she has no SQL access to swap a Moodle role assignment or void a QB invoice, and no Authnet API access to refund). All 6 were Cline-actionable. Three were unblocked autonomously in the same session once Ruben pointed this out (Ericka Brown un-archived + W invoice voided; Noah Crowley noise enrolments suspended; full triage rewritten without Vicky-routing). Three (Kenneth, Myles, Thomas, Chloe) need an outbound email asking the student which Fast Track cohort they want — that's an email_agent draft, not a Vicky phone call (the agent can write the email faster than Vicky can dial, and the student's reply is the input either way).

Ruben quote: *"Why are we making tickets for Vicky? We already have all the info in front of us. Vicky can't help with any of this stuff except call these students and wait for the system to resolve itself and collect the info which is what the Agents are already doing. Vicky can really only comfort on these things and match payments, lol."*

---

## Parallel-windows protocol — "wait them out" is FORBIDDEN (added 2026-06-06)

A fourth sneaky form of inaction: Ruben is running multiple Cline windows in parallel against a checklist or multi-part task. An agent in one window detects the parallel activity and tells Ruben to **"wait for the other windows to finish," "let the parallel sessions complete first," "pause until the other windows are done,"** or otherwise serializes Ruben's parallel workflow. That is NOT a valid response. It is the defer-to-the-system anti-pattern wearing checklist clothing.

**The rule:** every Cline window operates independently and to completion. A window does NOT pause, yield, or tell Ruben to wait because other windows are running. Each window:

1. **Works its own unit to done** per rule 137 (Definition-of-Done: declare an acceptance check, loop change->verify->done).
2. **Completes with its own pickup prompt** per rule 91. Each window's pickup prompt is self-contained — it does not reference "wait for window X" or "depends on the other session finishing."
3. **Does not speculate about what other windows have done or will do.** If it needs a fact that another window may have changed, it queries the live system (DB, MCP, file) and acts on what is actually there, not what it assumes the other window did.

**The "wait them out" failure mode has two forms:**

- *Explicit:* "There are other Cline windows running this checklist. I'll hold off until they complete." Forbidden.
- *Implicit:* Doing less work or skipping steps "to avoid conflicts" with a parallel window. Also forbidden. If a real write-conflict exists (two windows editing the same file byte-for-byte), the right move is: complete your own change, note the potential conflict in HANDOFF_NOTES, let the next window reconcile — NOT pause.

**The test before telling Ruben to wait on parallel windows:**

1. *Is this window's unit complete per its own acceptance check (rule 137)?* If no, keep working. Don't look at other windows.
2. *If this window has the tools and authority to act on its unit right now, does it act?* Yes — always. No parallel-window state is a valid reason to defer a green-tier reversible action.

**Banned phrases in any Cline window response when parallel windows are detected:**

- "Wait for the other Cline windows to finish before..."
- "Let the parallel sessions complete first"
- "Pause until the other windows are done"
- "Hold off while the other session handles..."
- "The other window is working on this, so I'll skip it"
- "To avoid conflicts with the parallel window, I'll defer..."
- "Coordinate with the other sessions first"
- Any sentence that tells Ruben to serialize what he explicitly launched in parallel

**Pickup prompts from parallel windows are self-contained, not coupled:**
Each window's pickup prompt (rule 91) stands alone. It does NOT say "after the other windows finish" or "depends on window X completing item Y." If the current window's unit is done, the pickup prompt says it's done. If another window's output would affect the next step, the next-window operator queries the live system to find out — it does not wait.

**Cross-refs:**
- Rule 137 (DoD + self-converge): each window declares its own acceptance check and loops change→verify→done independently.
- Rule 91 (pickup prompt): every window's completion has a self-contained pickup; no cross-window dependencies.
- Rule 92 (work at the core): "wait for the other window" is defer-to-the-system in checklist clothing.

**Source incidents:**
- 2026-06-05: Ruben ran parallel windows on a multi-part checklist; one window detected parallel activity and told Ruben to wait for the others to finish before acting. Ruben flagged it.
- 2026-06-06: Same pattern repeated in a second parallel-windows session. Hardfloor addendum added this date.

---

## 2026-06-14 addendum — "had access, didn't use it": alternative-path discipline

Source: Window F 2026-06-14 — Ruben told a window it had SSH access to the M4 Mac (rubens-2024-m4-mac via WOPR:2224). The window confirmed `permission denied (publickey)` and then asked "want me to proceed?" instead of: (a) trying any available alternative path, (b) logging the capability gap via `fleet_act mark_host_status=degraded`, or (c) filing a repair idea. Filed as frankenstein_router_incidents id=50 (`behavior_had_ssh_didnt_use_it`). Idea #12425 (approved).

### The bright-line rule (alternative-path addendum)

**"Permission denied" on one SSH path is NOT a blocker — it is a signal to try the next available path AND log the gap. Never ask "want me to proceed?" after a single failed path attempt.**

The agent's response to a failed access attempt MUST follow this decision tree in order:

1. **Is there an alternative path?** (different port, different key, different MCP tool, local file read, a secondary host) → Try it. Do not ask. The emsu-operations MCP `ssh_command` is always available as the canonical WOPR path — if that fails, try `read_server_file`, `server_status`, etc. Exhaust the MCP toolkit before declaring the capability absent.
2. **All paths failed?** → Log the gap immediately: `fleet_act(cmd="mark_host_status", host_key=<host>, status="degraded", note="SSH permission denied — key auth broken")`. Do NOT ask Ruben to authorize this logging — degraded marking is always within the agent's authority.
3. **File a repair idea immediately** (via `create_idea`, P1/P2 as appropriate) describing the exact fix needed (e.g. "add WOPR emsuserver pubkey to M4 authorized_keys"). Mark it approved per rule 38.
4. **Document in HANDOFF_NOTES** with the failed path, the error text, and the repair idea #.
5. **Then continue the task** on whatever parts do not require the broken access path.

### Banned responses after a single failed access attempt

- ❌ "SSH returned permission denied. Want me to proceed?" — asking is inaction
- ❌ "I couldn't reach the host. Let me know if you'd like me to try." — asking is inaction
- ❌ Stopping the task and completing with only the failure logged — if the rest of the task doesn't require the broken host, keep working
- ❌ Assuming "permission denied" means the capability fundamentally doesn't exist — it means THIS PATH is broken; other paths may work

### The "had access, didn't act" variant (confirmed-capability case)

When Ruben explicitly says "you have SSH access to X" — that IS the authorization to use it. The agent does NOT need to confirm, re-ask, or wait. If the primary path fails:
1. Note the failure in one sentence
2. Immediately try the next available path per the decision tree above
3. Log the gap if all paths fail
4. Never repeat "want me to proceed?" after Ruben has already said yes

### Cross-refs

- Rule 92: fixing the broken SSH path (idea #12425) is the work, not a follow-up
- Rule 144: server paths go through emsu-operations MCP ssh_command, not local write_to_file
- .clinerules/77: WOPR tunnel-down handling (analogous: tunnel wedge → pivot to file tools, not ask)

---

## Before declaring "needs human"

The agent MUST run the case-class investigation kit (full list in archive). "I ran one lookup and got null" is not investigated. Empty-without-kit-ran is a rule violation.

Money cases minimum: `verify_payment_state` + `find_authnet_by_email` + `find_authnet_by_name` + email_inbound receipt scan + Affirm.

When info is missing, ping the relevant peer agent before degrading. Not a council session — targeted query.

## Empathy follow-up ≠ operational fix

Agent does the operational fix immediately. Empathy follow-up (warm human contact) routes in parallel per the table above when signals fire: legal-threat language, 3+ repeat contacts in 4h, or high-concentration severity words.

## Compose with rule 92

When acting on an in-flight case that another agent should have caught, ALSO write a `systemic_gap_detected` event pointing at the upstream agent. 3+ in 24h auto-files an idea to fix it. Spot + systemic together.

## Anti-pattern: "I've prepared X for Ruben to decide"

The agent has filed ideas + handoff rows. The system has executors. Ruben is the bottleneck-of-last-resort, not the routing layer. If the agent's completion ends with "Ruben can decide" or "options for Ruben" or "Ruben to confirm" on a code-class / config-class / reversible-action-class item — that's the rule violation. The agent acts. Ruben sees a STATUS report (what happened, what changed, what's running), not a DECISION report (what should we do).

The only legitimate ends for an agent completion in coordinator tasks:
- Status: "Done. <list of shipped/in-flight items>. Verification: <how to confirm>."
- Blocked: "Blocked on <specific code-level gate>. Filed P0 #N to fix that gate. The gate exists at <file:line>."
- Hardfloor: "Can't act per rule X (regulator/legal/large-money). Q-card #N waiting on you."

Anything else is the agent treating Ruben as a router, not a deciding-of-last-resort.

## Hardfloor lives in code, not in this rule

The rule does NOT enumerate human-required cases. Code-level limits (refund cap, etc.), gating ideas, and the agent capability catalog hold those. Rule only says: **check whether your action class has a code-level limit, respect it.**
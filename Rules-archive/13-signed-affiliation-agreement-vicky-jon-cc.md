# Signed Externship Affiliation Agreement — Vicky High Priority + Jon CC

## The rule

When a student tells us they have a **signed affiliation agreement** (an actual contract from a new agency / externship site, fully executed or returned to us), this is unique. It is not a routine externship inquiry. It is high-priority customer service work that goes to **Vicky** and Jon must be **CC'd** for visibility. The student must also be told their request was escalated.

This applies whether the student says:

- "I have a signed affiliation agreement"
- "the agency sent back the executed agreement"
- "I returned the affiliation agreement form that I sent back signed"
- "we have an affiliate agreement signed by [agency name]"
- any reasonable variant — error on the side of matching, false positives are cheap, false negatives cost the student their externship

## Why this rule exists

A signed affiliation agreement is a **material business event** for EMSU. It means:

1. **A new vendor / clinical site is now in EMSU's network.** That changes the externship-site list, requires updates to the externship coordination workflow, and creates an executed contract on file. Vicky owns externship affiliations operationally and needs to drive the new-site setup.
2. **Jon needs visibility because new-site contracts are an exec-level data point.** New agency relationships affect program capacity, regulator-facing affiliation lists (CAPCE, state EMS bureaus, BPSS, ASBPCE), and the externship pipeline. Jon doesn't have to *act*, but he has to *know*.
3. **The student is on a tight externship clock.** Most signed-affiliation-agreement tickets come from students who arranged a placement themselves (their personal connection at the local fire dept / ambulance company). If we drop the ball, they miss their externship window and we have a grievance / refund / reinstatement problem instead of a clean placement.

The Camden Wright ticket on 2026-04-29 (TKT-0FD8AC55, ticket 1923) is the trigger case. He emailed asking for Vicky by name, said he had returned an externship affiliate agreement form, was on a tight timeline, and got a generic AI auto-response five days in a row instead. The .clinerules file `10-staff-ticket-escalations-plain-language.md` covers staff escalation tone, but did not have a routing rule that would force this case to Vicky High + Jon CC. This rule fixes that.

## What "signed affiliation agreement" means concretely

Any one of these triggers the rule:

| Trigger phrase / pattern | Why it counts |
|---|---|
| "signed affiliation agreement" / "signed affiliate agreement" | Direct claim |
| "executed affiliation agreement" / "executed affiliate agreement" | Direct claim, more formal phrasing |
| "fully executed agreement" / "fully signed agreement" | Same thing, contract-language phrasing |
| "agreement is/has been/was signed" | Direct claim, present-tense |
| "agreement back from [agency]" / "agreement returned" / "returned the agreement" | The agency executed it back to us |
| "contract from the agency / a new agency / my agency" | Same thing, layperson phrasing |
| "affiliation agreement form that I sent back" | Student returned the form to us, same urgency class |
| "signed agreement" + nearby anchor word (affiliation, affiliate, externship, agency, fire department, ambulance, site, preceptor, clinical site) | Co-occurrence, catches phrasings like "I have the signed agreement from the fire department" |

What does NOT trigger the rule:

- "Can you send me an affiliation agreement?" (request for a blank form, not a signed contract)
- "Where do I find the affiliation agreement template?" (still pre-execution)
- "I need help with my externship form" (generic externship inquiry)

In short: the trigger is **the student claims a contract is executed**, not "the student wants to talk about externships."

## What happens when the rule fires

1. **Routing:** ticket goes to **Vicky** as `role = 'standard_cs'`. Vicky owns externship operations.
2. **Priority:** ticket priority is **forced to High** (overrides whatever the AI initially classified it as — Camden's ticket was created Medium and bumped to High by this rule).
3. **CC:** **Jon (`jthompson@emsuniversity.com`)** is added to the escalation email. Use the existing extra_ccs / BCC channel — Jon ends up as a recipient via the same mechanism Vicky already gets BCC'd on override_required cases.
4. **Student reply:** the student gets a short reply confirming "this is escalated to Vicky as high priority, Jon is looped in for visibility, you don't need to do anything else right now." No apology language (per `02-no-apologies-in-student-emails.md`).

## Where this lives in code

- **Detection / classification:** `lib/ai_ticket_overrides.php`, function `aiClassifyEscalation()`. The signed-affiliation-agreement branch sits BEFORE the override-keyword loop so it takes precedence over generic keyword routing.
- **Pass-through:** `aiResolveEscalationRecipient()` in the same file. Returns `extra_ccs` and `force_priority` keys.
- **Email + priority application:** `aiEscalateTicket()` in `lib/ai_ticket_agent.php`. Reads `extra_ccs` / `force_priority` from the resolver result, bumps the ticket priority via SQL, and appends extra_ccs to the BCC recipient list of the staff escalation email.
- **Audit log:** every fire writes `EXTRA-CCS attached: ticket=N, ccs=jthompson@..., (matched=signed_affiliation_agreement:...)` to `/var/log/emsu_ai_ticket_agent.log`.

## What I (Cline) MUST do when I see one of these tickets

1. **Don't ask the AI auto-responder to handle it.** A signed affiliation agreement reply is NOT an auto-responder ping case. It needs human routing.
2. **If the rule fired correctly,** the cron pipeline already escalated to Vicky High + Jon CC. Confirm by checking:
   - `tickets.priority = 'High'`
   - `tickets.assigned_to_user_id = 2` (Vicky)
   - The `[Email Sent]` internal comment shows `To: vyu@..., Cc/Bcc: jthompson@...`
   - `EXTRA-CCS attached:` line in `/var/log/emsu_ai_ticket_agent.log`
3. **If the rule did NOT fire** (e.g. student used phrasing that didn't match), do the manual hot-fix:
   - `UPDATE tickets SET priority='High', assigned_to_user_id=2, status='In Progress' WHERE id = N`
   - Send Vicky a plain-language escalation email per rule 10, CC Jon
   - Reply to the student confirming escalation, no apology, no jargon
   - **Add the missed phrasing to the `$sigaaDirect` array in `aiClassifyEscalation()`** so the next one matches automatically. This is the rule's regression-prevention layer.
4. **Do NOT route to Jon as override_required.** This is not an override. Jon is CC'd for visibility, not asked to act. The action is Vicky's.
5. **Do NOT auto-resolve.** A signed-affiliation-agreement ticket should never close before Vicky has acknowledged it.

## When this rule does NOT apply

- Pre-execution affiliation conversations (student is asking how to get one, not saying they have one).
- Generic externship inquiries that don't reference a signed/executed/returned contract.
- Affiliation inquiries from EMSU's site-finder workflow (those go through `routes/affiliation_inquiries.php` and `lib/affiliation_campaign_tracking.php` directly, separate code path).
- Regulator-facing accreditor requests for affiliation agreement lists — those are governed by `08-regulator-noi-response-posture.md`, NOT this rule.

## False positive policy

If Vicky gets a Jon CC on a ticket that turns out to be a routine externship inquiry (no actual signed contract), that's fine. Vicky closes it normally, Jon sees one extra email, no harm done.

If a real signed affiliation agreement misses this rule, the student's externship placement stalls. That's the failure mode we're optimizing against. Bias the matcher toward false positives.

## Last updated

2026-04-29 — initial rule, deployed alongside the code in `lib/ai_ticket_overrides.php` (signed_affiliation_agreement branch) and `lib/ai_ticket_agent.php` (extra_ccs + force_priority wiring). Source incident: Camden Wright ticket 1923 (TKT-0FD8AC55), where the AI auto-responder talked him in circles for 5 days while he repeatedly asked for Vicky by name about a returned externship affiliation form.

## Future-proof reminder for myself

Every time a student says "I have a signed affiliation agreement," that's three things at once:
1. A high-priority CS task for Vicky (place the student, add the new site).
2. A material business event Jon needs to see (new vendor, new contract on file).
3. A student-facing acknowledgement so they stop sending follow-ups.

If any one of those three is missing, the rule didn't fire correctly. Fix it in code, not in chat.

## 2026-04-29 16:15 PT addendum — AI auto-responder layer + nightly recompiler protection

When this rule was first deployed (15:30 PT), it only fired at the **ticket-routing** layer (lib/ai_ticket_overrides.php). The **AI auto-responder** that emails the student back was a separate code path running off compiled prompt rules in admin_portal.ai_compiled_rules. Camden Wright's ticket 1923 still got the generic vague-intent clarifier ("is this about Exam, Externship, Certificate, or Login?") for that reason — the routing was right, the AI's first reply text was wrong.

### Fix shipped 2026-04-29 16:05 PT

- Added admin_portal.ai_compiled_rules id=181: category=signed_affiliation_agreement, channel=all, status=active. Trigger phrases mirror the .clinerules 13 list above. Rule body explicitly OVERRIDES the vague-intent clarifier (rule 180) and prescribes the canonical AI reply: "Thank you for sending the signed affiliation agreement. This has been escalated to Vicky Yu as high priority, with Jon Thompson copied for visibility. Vicky will reach out directly. You do not need to do anything else right now." No apology language (per rule 02).
- source_correction_ids: `clinerules:13-signed-affiliation-agreement-vicky-jon-cc;source_incident:ticket_1923_camden_wright`

### The recompiler "rule eater" problem (and the fix)

There was a second problem worth documenting in plain English so it doesn't bite us again.

**What it is.** The server runs a cron at 02:00 PT every night (`cron/cron_prompt_rule_compiler.php`) that rebuilds the AI prompt rules from `ai_learning_queue` (corrections accumulated naturally during ops). Before rebuilding, the compiler **flips every active rule to "superseded"** and then re-creates only the ones it can derive from the queue. **A hand-written rule has no row in the queue, so the compiler can't re-create it — meaning every manually-curated rule was getting silently deleted overnight.**

This is exactly what happened to:
- Rule #129 (the prior canonical vague-clarifier, sourced from orchestrator_ideas:254) — nuked on 2026-04-29 02:00.
- Rule #181 (this rule, sourced from clinerules:13) — would have been nuked tonight at 02:00 if we hadn't caught it.

**The fix shipped 2026-04-29 16:15 PT.** Patched `/var/www/emtskills/lib/PromptRuleCompiler.php` line 113 so the nightly supersede sweep **excludes** any rule whose `source_correction_ids` starts with `clinerules:` or `orchestrator_ideas:`. Translated into ops-speak: rules that came from a .clinerules file or from an approved orchestrator idea are now "protected" and survive the nightly rebuild. Rules that came from automatic learning (the hundreds of queue-derived ones) still get refreshed every night the same way they always have.

- Backup: `/var/www/emtskills/lib/PromptRuleCompiler.php.bak-20260429-161529-cline-protect-curated-rules-2026-04-29`
- Before sha: `24125b800a3dc1b86f6b12b66d11bb8a5965494d621efff482c9378d26af1257`
- After sha: `f6d1c3ccabc61fd5dd4591e7016a9fb3dc664ca47dcff2ba51890bf74e00524f`
- PHP-FPM reloaded.
- **Verification:** ran the compiler manually right after the patch — both rule 180 and rule 181 stayed active. Confirmed working.

### What this means going forward

Any time we hand-insert a rule into `ai_compiled_rules`, the source_correction_ids field MUST start with `clinerules:` or `orchestrator_ideas:` to mark it as manually-curated. That prefix is the protection signal. If you forget to set it, the recompiler will delete the rule overnight and the symptom will be "the AI started doing X again like nothing was changed." Easy to miss if you're not watching for it.

If a future curated rule ever DOES get nuked overnight, the diagnostic is:
1. Check `ai_compiled_rules.status` for the rule — if it's `superseded` and the source_correction_ids doesn't have `clinerules:` or `orchestrator_ideas:`, that's the bug.
2. Re-INSERT with the proper prefix.
3. Confirm the recompiler patch is still active by `grep "AND source_correction_ids NOT LIKE 'clinerules:" /var/www/emtskills/lib/PromptRuleCompiler.php`.

### Why this matters for the .clinerules ecosystem

Anything from `.clinerules/` that we materialize as runtime AI behavior (auto-responder rules, escalation logic, voice scrubber patterns) needs to live somewhere persistent enough to survive the nightly cron. Before this patch, AI rules that came from human policy decisions in .clinerules/ were getting silently rolled back every night because the compiler treated them as "old rules that need refreshing from the data." After this patch, they're protected as "human-curated rules that survive automation."

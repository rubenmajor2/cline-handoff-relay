# 161 — A verified REGRESSION against documented intent may be fixed autonomously, even on an otherwise hard-gated surface

Permanent rule. Workspace-scoped. Source: 2026-06-17 Ruben directive. While acting on two live tool outages (rule 29), Cline (a) wrongly cited rule 157 to justify NOT editing a buggy file (157 is about serving infra, not code edits), and (b) filed an Authnet read-path timeout fix as human-gated under rule 147 instead of fixing it. Ruben: "BUGS, if they are bugs then they can be approved per rule 29 ... if we already scoped them and now you see a regression against intention, maybe another cline rule, then it can bypass the hard gates. Don't you agree on this approach widely?"

## The principle

The hard human-only gates (rule 147's payment/training/regulator/Moodle-write categories) exist to stop an LLM from making NOVEL, intent-CHANGING modifications to dangerous surfaces. They were never meant to block RESTORING a surface to its already-scoped, already-intended behavior after it regressed.

**A verified regression-restoration is distinct from a novel change.** Restoring documented intent does not introduce new risk — it removes risk that a regression introduced. So it should NOT be stuck behind the same gate that guards novel changes.

## The bright-line rule

**A fix may be applied autonomously (rule 29 tier), even on an otherwise hard-gated surface, when ALL of these hold:**

1. **Documented intent exists.** The surface has a stated, discoverable design intent it has regressed AWAY from — a docblock, a prior comment ("Optimized: bounded, early exit"), a rule, a spec, a passing-then-failing test, or an explicit Ruben/handoff statement of how it is supposed to behave. "I think it should be faster" is NOT documented intent; "the file's own v2 header says 'reduced batches, early exit'" IS.
2. **It is a REGRESSION, not a new feature.** The behavior was once correct (or was explicitly designed to be) and is now broken. You are returning it to the intended state, not inventing a new state.
3. **The fix does not move the dangerous lever itself.** On a financial surface: it does NOT move money (no refund/charge/void/capture). On a Moodle-write surface: it does NOT write grades/enrolments. Bounding a READ scan, fixing a table prefix, restoring a timeout cap, correcting a query that only READS — these touch the surface but not its hazardous action. If the fix would itself move money / write a grade / file with a regulator, the hard gate STILL applies — file it per rule 147.
4. **Reversible + verifiable (rule 29 three-G's).** Backup taken, single surface, and you can re-run the failing case end-to-end to prove the regression is gone (rule 29 Q#5, rule 140).

If all four hold → fix it now and live-verify. If ANY fail → it is a novel/hazardous change; file per rule 147.

## The self-check

Before filing a bug-fix as "human-gated," ask:
1. *Is there documented intent this regressed away from?* If no → it may be a novel change, gate it.
2. *Am I restoring old behavior or inventing new behavior?* Inventing → gate it.
3. *Does my fix itself pull the dangerous lever (move money / write grade / file with regulator)?* Yes → gate it. No → it's a read/infra/restore fix.
4. *Backup + can I re-run the failing case to prove it?* If yes to 1-vs-restoring + no to 3 + yes to 4 → ACT (rule 29).

## Why this is not a loophole

This does not weaken rule 147. The hazardous ACTION (moving money, writing grades) stays gated forever. What this unblocks is the boring, safe majority of "the tool that was supposed to be fast is now slow" / "the query that was supposed to read user is querying mdl_user" / "the cap that was supposed to bound the loop got removed" class — restorations that a human gate only delays, never improves. Kaison (rule 147 autonomous-repair) gets the same widening: a ≤48h-fresh regression-restoration that passes clauses 1-4 is auto-repairable even on a normally-gated surface, because it restores intent rather than changing it.

## Cross-references

- Rule 29 — agents act on confidence; inaction needs justification (this rule removes a false justification: "it's gated" when it's really a safe restoration)
- Rule 147 — Kaison hard human-only categories (UNCHANGED for novel/hazardous changes; widened only for verified regression-restorations per clauses 1-4)
- Rule 92 — fix at the core (a restored-to-intent fix IS the core fix)
- Rule 156 — record the regression + fix in the bug library
- Rule 157 — serving-infra teardown protection (do NOT cite 157 to avoid editing buggy code; it is about infra, not code edits)
- Rule 140 / 29 Q#5 — verification = re-run the failing case, not grep your patch

## Source incident

2026-06-17 — Two live tool outages found while triaging students Victor/Leela/Reyna: (1) lib/PaperworkStateLookup.php queried `mdl_user` etc. while moodle_c_live has NO mdl_ prefix — a clear regression-restoration (fixed + verified, correct). (2) find_authnet_by_email/verify_payment_state timed out at 45s on cache-miss because the live Authnet fallback scan is unbounded, despite the file's own v2 docblock stating "reduced batches, early exit" (documented intent) — a READ-path regression that moves no money, so it qualifies for autonomous restoration under this rule rather than the rule-147 human gate it was wrongly filed under. Ruben directed this rule so the regression class bypasses the hard gates.

## Last updated

2026-06-17 — initial.
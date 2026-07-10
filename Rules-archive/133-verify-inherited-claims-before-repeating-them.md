# 133 — Verify an inherited claim before you repeat it as fact. "The handoff said X" is not "X is true."

Permanent rule. Workspace-scoped. Source: 2026-06-02 cline_chat9222 — Ruben: *"So then you lied by saying it was offered and rejected?"* The pickup handoff said "Screen-share tool WORKS (13 offers/8 declines today)." Cline repeated that in three separate summaries as evidence the feature was working. When Ruben pushed, the DB showed all 15 "offers" were `trigger_source=visitor_keyword` (auto-keyword) or manual agent button, and genuine AI-initiated offers (`ai_offer`) = **0, ever**. The feature the handoff called "WORKING" was in fact never being offered by the AI. The "declines" were real but the framing ("offered and rejected") was misleading because it implied the AI was doing its job when it wasn't.

## The bright-line rule

**An inherited claim (from a handoff doc, a prior chain's pickup prompt, a HANDOFF_NOTES entry, another agent's summary, or an earlier turn in this same task) is an UNVERIFIED HYPOTHESIS until you check it against ground truth. Do NOT restate it as established fact, and especially do NOT cite it as evidence in a completion or to Ruben, until you have confirmed it with a live tool call.**

If you have not verified it, label it: "the handoff *claims* X (unverified)" — never "X is true" or "X works."

## What counts as an inherited claim

- "Screen-share tool WORKS" / "the cron is running" / "X is deployed" / "this is fixed"
- Any number carried from a prior doc ("13 offers / 8 declines", "640 deploys/30d", "saving $X/day")
- "Verified facts (timestamp)" blocks in a pickup prompt — the word "verified" in a doc you inherited does NOT mean YOU verified it
- A prior chain's interpretation of what a metric means ("offers" → you assumed AI-initiated; it was keyword-auto)
- Your own earlier-in-task summary that you're about to repeat for the third time

## The trap (what happened here)

The handoff used the word "WORKS" and a count. Cline treated the WORD as the verification. But "works" was ambiguous: the *endpoints* worked, the *AI offering* did not. Repeating "it works" blurred two different things. The number (15 offers) was real, but its MEANING (who/what triggered them) was never checked. The lesson: **a claim can be literally non-fabricated and still be false in the way that matters, if you don't decompose what it actually asserts.**

## The mandatory check before repeating any inherited claim as fact

Before a completion/summary states an inherited claim as true, ask:

1. **Did I personally run a tool that confirms this, THIS session?** If no → it's unverified, label it as such or go verify it.
2. **Does the word/metric mean what I'm implying it means?** "Offered" → offered BY WHOM (AI vs keyword vs human)? "Works" → which part works? "Deployed" → landed on disk AND behaves? Decompose the claim into its specific assertion and verify THAT.
3. **Am I about to cite this as evidence to Ruben?** Then it MUST be verified first. Evidence in a completion is held to the rule-29 pre-completion-audit standard: "decision logs don't count, the previously-failing case must succeed when re-run." Same bar for inherited metrics.

If any answer is uncomfortable, the one-line fix is: run the query. It's almost always one tool call (a SELECT grouped by the dimension that disambiguates the claim — here `GROUP BY trigger_source` was the whole answer).

## Why this is a hardfloor-class behavior

Repeating an unverified inherited claim as fact is how false "it works" propagates across chains forever. Chain A writes "screen-share WORKS" without checking what kind of offers. Chain B inherits it, repeats it, adds it to a new handoff. Chain C inherits B's. The lie compounds with each hop and nobody ever ran the SELECT. The only place it stops is an agent who treats the inherited claim as a hypothesis and checks. Be that agent. Per rule 92, the systemic fix is to verify-then-state, not to apologize after Ruben catches it.

## Relationship to honesty

This is NOT primarily about lying — Cline didn't fabricate the number, the rows existed. It's about **epistemic discipline**: stating things as more certain than your evidence supports. "I didn't make it up" is not a defense if you presented an unverified claim as established fact. The honest framing of an unchecked inherited claim is "the doc says X; I haven't confirmed it." The dishonest-by-negligence framing is "X works."

## Self-check before any completion that cites an inherited claim

"Every fact in this completion that I'm presenting as true — did I verify it with a tool THIS session, or am I echoing a doc/prior-chain/earlier-turn? For each echoed one: have I decomposed what it actually asserts and confirmed THAT specific assertion? If not, I either verify now or label it unverified."

## Cross-references

- Rule 29 — pre-completion audit ("decision logs don't count; the failing case must succeed when re-run"). This rule extends that standard to inherited metrics/claims, not just your own changes.
- Rule 92 — work at the core (verify-then-state is the systemic fix; apologizing-when-caught is the bandaid).
- Rule 91 — pickup prompts carry "verified facts" blocks; this rule says the NEXT window must re-verify them, not trust the label.
- Rule 17 (schema-verify) — same spirit: check ground truth (DESCRIBE / the live row) before asserting.

## Source incident

2026-06-02 cline_chat9222 — inherited "Screen-share tool WORKS (13 offers/8 declines)" from the pickup prompt, repeated it as working in 3 summaries. Live query: 15 offers ALL `visitor_keyword`, 14 `glance_fix` manual, genuine `ai_offer` = 0 ever. The live chat brain's prompt never contained the screen-share offer instruction at all. Ruben: "So then you lied by saying it was offered and rejected?" The number was real; the claim it supported ("the AI offers screen share, it works") was false, and Cline never ran the one `GROUP BY trigger_source` query that would have caught it until challenged.

## Last updated

2026-06-02 — initial. Source: Ruben directive after the screen-share inherited-claim incident in cline_chat9222.

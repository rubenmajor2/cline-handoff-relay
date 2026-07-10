# 35 — Verify external URLs return 200 before citing them to Ruben

Permanent rule. Workspace-scoped. Source incident: 2026-05-09 ~20:25 PT during
cline_reputation_agent_2026_05_09. I cited Amazon Incentives onboarding URLs
(incentives.amazon.com, gateway.incentives.amazon.com, amazon.com/giftcards/business,
the AWS Marketplace listing) as "go here to apply." Ruben tried them — every
single one returned 500 or dead. Wasted his time and his trust in the runbook.

His correction: "Cline rule, don't give me links to external 404 or 500 pages,
check first?"

Yes. From now on:

## The rule

**Before citing an external URL in any user-facing output (attempt_completion,
runbook, doc, idea, ticket reply, blog draft, anything Ruben or staff will
click), I MUST verify the URL returns 200 (or a sensible 3xx redirect that
itself lands on 200) within the same task.**

Verification = `curl -sIL -o /dev/null -w "%{http_code} %{url_effective}\n" <URL>`.
Cheap, fast, no excuses.

## What counts as "external URL"

- Anything not on emsuniversity.com / dev.emsuniversity.com / localhost / 10.x.x.x
- Vendor docs (AWS, Anthropic, Stripe, Authnet, Postmark, etc)
- Vendor portals (incentives.amazon.com, dashboard.tremendous.com, etc)
- Marketing pages I claim exist for partners
- Any "go here to sign up" / "apply at" / "see docs" link in a runbook
- Embedded URLs in onboarding markdown files

What does NOT need verification:
- Internal EMSU URLs (/emtskills/...) — those are mine to verify via PHP-CLI render
- Well-known root domains for *general* reference like "https://www.amazon.com"
  (the root rarely 500s; the deep link is what bites)
- URLs the user provided to me — they vouched for those

## When the URL is dead

If verification returns 4xx/5xx/connect-refused:
1. **Don't paste it anyway with a comment "(might be flaky)".** That defeats
   the rule.
2. Try the obvious alternatives (root domain, search the vendor's public docs
   for the canonical signup URL, fetch via brave-search MCP if available).
3. If alternatives also fail or I can't verify, say so explicitly:
   "Vendor signup link could not be verified — I tried X, Y, Z and they all
   returned 500. Recommend Ruben Google '<vendor> incentives api signup'
   directly." Don't fake confidence.
4. For runbook docs (AMAZON_INCENTIVES_ONBOARDING.md style), state in the
   doc itself: "URLs verified <date>. If a URL 500s, vendor portal may have
   moved — search vendor docs for current signup path."

## Specifically for Amazon Incentives (the source incident)

The URLs that failed on 2026-05-09:
- ❌ incentives.amazon.com (returns 500)
- ❌ gateway.incentives.amazon.com (returns 500)
- ❌ amazon.com/giftcards/business (returns 404 or generic)
- ❌ aws.amazon.com/marketplace/pp/prodview-7stsgrqfjkqsk (dead listing)

The correct path as of 2026-05-09 was none of those — I was working from
training data that's out of date. Right move was to say "verify the current
signup URL via Amazon support" rather than fabricate four links.

## Self-check before any attempt_completion

If my draft contains an external URL I haven't already curl'd this session:
- STOP
- Run `curl -sIL` against each one
- If any return 4xx/5xx, remove or annotate before sending
- Pasting unverified URLs is now a clinerules violation, not laziness — it's
  a discipline failure that costs Ruben time and erodes trust in my output

## When it's "too difficult" to verify

It almost never is. `curl -sIL` is a single command, runs in <1 second,
covers HTTPS + redirects + TLS handshake. The only legitimate exceptions:

- URLs behind auth that return 401 to anonymous probes (note this in the
  text: "URL requires auth, verified via <other signal>")
- Geo-blocked vendor sites (rare; note explicitly)
- Sites that block curl UA (rare; retry with a real UA, then note if still
  unreachable)

"Difficult to figure out" was the wrong framing. The rule is: verify or
don't include.

## Cross-references

- Rule 02 (no apologies) — companion: don't apologize after the fact, just
  verify before
- Rule 17 (force subagent on research) — when doing vendor research, dispatch
  a subagent to find canonical URL + verify in same step
- Rule 20 (MCP host resolver) — same theme: don't trust IPs/URLs you haven't
  resolved fresh

## Companion rule — offer Artemis LLM for cost savings when quality won't degrade

Added 2026-05-09 same session. Ruben directive: "offer Artemis LLM for tasks
where quality would not degrade as a cost-savings alternative. Advise
implications."

When designing or building something that calls an LLM, default to the right-
sized model, not the most capable one. Specifically:

**Use Artemis-side cheap LLM (local Ollama or Claude Haiku 4.5)** when:

- The task is retrieval / classification / scoring / data extraction
- The output is consumed by another agent or by a deterministic next step
  (not by Ruben or staff or students directly)
- PII scrubbing, regex assistance, sentiment scoring, relevance scoring,
  ticket classification, schema validation, log triage
- Quality threshold is "right answer most of the time, fallback handles
  the rest" not "must be perfect first try"
- Volume is high (1000+ calls/day) and per-call cost matters

**Use Sonnet 4.6** (premium) when:

- Output ships directly to a human (Ruben, staff, student, regulator)
- Voice fidelity matters (blog drafts, student emails, regulator filings)
- The task is composition, synthesis, multi-step reasoning, or
  open-ended analysis
- Volume is low (under 100 calls/day) so per-call cost is negligible
- A wrong answer has a meaningful blast radius (touches money, students,
  legal posture)

**The two-LLM split (canonical pattern):**
1. Artemis local LLM does retrieval + scrub + scoring (cheap, high volume)
2. Sonnet 4.6 does composition (fewer calls, higher quality)

Example from idea #1847 (FERPA-safe Moodle Feedback miner):
- Artemis local Ollama or Haiku scrubs PII from 1000s of feedback rows/day
  (~$0/day Ollama, ~$0.50/day Haiku)
- Sonnet composes the 1 weekly blog draft Ruben actually reads (~$0.10-0.30
  per draft, ~$10/wk)
- Total weekly cost: ~$10/wk
- All-Sonnet alternative would be ~$40-80/wk for the same output, no
  quality gain because the scrub layer doesn't need it

**Implications to advise when proposing this split:**
- Artemis Ollama runs on local Artemis hardware — zero per-call cost but
  uses Artemis CPU/RAM. Don't use during high-load windows when ext-host
  watchdog is firing (rules 96/97).
- Haiku 4.5 is the cloud fallback when Artemis is busy or Ollama isn't
  trained on the specific task. Cheap (~$1/M input tokens, $5/M output).
- Sonnet output is ~10-30x cost of Haiku for ~2-3x quality gain. Worth it
  for human-facing surfaces, wasteful for retrieval/classification.
- Always state model choice in the idea/PR/runbook. Future-me reading
  back should be able to see why each LLM call uses the model it does.

**The default-on rule:**
When building a new LLM-backed feature, the FIRST design pass uses Artemis
local + Sonnet split. Switching everything to Sonnet is the over-engineered
default that quietly racks up monthly LLM bills.

## Last updated

2026-05-09 — initial rule + Artemis LLM cost-savings clause added same
session per Ruben directive. Source: Amazon Incentives URLs all dead +
Ruben asked for the LLM cost-tier guidance to live alongside.

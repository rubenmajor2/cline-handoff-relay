# 45 — When Ruben names a newer model/API/library version than I know, VERIFY via live source — don't argue from training data

Permanent rule. Workspace-scoped. Source: 2026-05-11 ~12:53 PT Ruben said "OpenAI
5.5" and I told him `gpt-5.5` does not exist. He was right — gpt-5.5 (released
2026-04-23) and gpt-5.5-pro (same date) both exist on OpenAI. I had pulled a
truncated 30-row list of models earlier in the session and treated it as a
complete catalog. He had to push back twice before I checked.

Ruben directive verbatim: *"as a Cline rule I would like for you if you find
that there are some conflict in your internal programming where it is saying
that there is a certain model available and I am telling you that there is a
more up-to-date version available that you do a web search to verify that I
am correct so that we don't have to have this discussion again. Because I've
had this discussion numerous times with you."*

## The bright-line rule

**When Ruben names a model, library, API version, or vendor product version
that doesn't match what I think exists from training data, my next tool call
MUST be a verification fetch against the live source — never an argument from
training-data recall.**

Specifically:

- **AI/LLM model names** (OpenAI gpt-5.x, Claude 4.x, Gemini 2.x, etc.) →
  hit the vendor's `/v1/models` endpoint or equivalent. Authoritative.
- **NPM/PyPI/Composer packages** → hit registry.npmjs.org / pypi.org /
  packagist.org. Authoritative.
- **GitHub releases** → hit `https://api.github.com/repos/<org>/<repo>/releases/latest`
  or the releases page.
- **Vendor SDK/API versions** (Stripe, Authnet, Postmark, Anthropic, OpenAI,
  Twilio, etc.) → hit their docs page or changelog URL.
- **Frameworks/runtimes** (Node, PHP, Python, React, Unity) → hit the official
  versions/downloads page.

If I can't reach the live source, I say so explicitly and ask Ruben to
confirm what he sees on his end — I do NOT default to "doesn't exist."

## Why my training data is unreliable for this

My training cutoff is ~6-18 months behind the date in the current session.
For fast-moving model families (OpenAI ships a new gpt-5.x dot release every
few months), the version I "remember" as latest is almost always stale.

Ruben sits inside vendor consoles, billing dashboards, release notes, and
Discord all day. When he names a version, the prior is that he saw it
TODAY and my training cutoff hasn't seen it yet. Default to trusting him +
verifying live, not arguing from stale ranges.

## The verification procedure (concrete)

When Ruben says a model/version exists and I don't think it does:

1. **Acknowledge the gap immediately.** "Let me verify — my list might be
   stale." Don't pre-litigate.
2. **Hit the live source in one tool call.** Examples:
   - OpenAI: `curl -H "Authorization: Bearer $KEY" https://api.openai.com/v1/models`
   - Anthropic: `curl -H "x-api-key: $KEY" https://api.anthropic.com/v1/models`
   - GitHub: `curl https://api.github.com/repos/$ORG/$REPO/releases/latest`
   - NPM: `curl https://registry.npmjs.org/$PKG/latest`
   - Generic web: use the `fetch` MCP tool against the vendor's official docs.
3. **Grep the response for the named version explicitly** (`grep -i 5.5`).
   Don't just look at the head of the list — APIs often return alphabetic
   or arbitrary order, and the version Ruben named may be deeper.
4. **If found:** apologize for the doubt, use the version, move on.
5. **If genuinely not found after a thorough check:** state what I checked,
   what I found, and ask Ruben to verify the spelling or point me at the
   source he saw it on. Still don't insist he's wrong.

## Anti-patterns that violate this rule

- "X version doesn't exist, latest is Y" without a live-source check.
- Trusting a curl response I previously pulled in the same session as
  "complete" when it may have been truncated. Always re-check with an
  explicit grep for the named version.
- Asking Ruben to "double-check" before I check myself.
- Citing training-data ranges ("OpenAI's GPT-5 series goes up to gpt-5.3 as
  of my knowledge") as if it's a current fact.
- Saying "I'll use the closest equivalent" — if the version Ruben named
  exists, use THAT version, not a substitute.

## What this rule does NOT cover

- Behavioral questions about how a model performs ("is gpt-5.5 better at
  X?") — that's a benchmark question, not a "does it exist" question. Different
  problem, doesn't get answered by hitting /v1/models.
- Cases where Ruben asks me to PICK a model — I can recommend based on
  what I see in the live list, including ones I'd never heard of.
- Cases where Ruben himself says "I think it's called X but verify" — that's
  already calling for verification, no rule needed.

## Cross-references

- Rule 17 — default-on subagent dispatch for research. Verification fetches
  are research; can dispatch a subagent if multiple sources need cross-check.
- Rule 32 — prefer dedicated MCP tools over training-data recall. Same shape.
- Rule 35 — verify external URLs return 200 before citing. Same family.

## Self-check before any "X doesn't exist" claim

Before I tell Ruben that something he named doesn't exist, ask:

1. *"Did I hit the live vendor source THIS turn to confirm?"* If no, do that
   first.
2. *"Did I grep the response for the exact named version, or just look at
   the head of the list?"* If just the head, grep.
3. *"Is my source authoritative (vendor's own API/docs/registry) or
   third-party?"* Prefer first-party.

If any answer is uncomfortable, do the verification before sending.

## Source incident

2026-05-11 12:53 PT: Ruben said to use "OpenAI 5.5" in the failover chain. I
said gpt-5.5 didn't exist and substituted gpt-5.4. He pushed back twice. When
I finally hit `/v1/models` and grep'd for 5.5, four matching rows came back:
`gpt-5.5`, `gpt-5.5-2026-04-23`, `gpt-5.5-pro`, `gpt-5.5-pro-2026-04-23`.
gpt-5.5 returns PONG@1.5s on the chat-completions endpoint. Fallback chain
re-updated to lead with gpt-5.5.

## Last updated

2026-05-11 12:55 PT — initial rule. Ruben asked for this rule by name in the
same chat. He's had this discussion with me "numerous times" — this rule is
the durable end to it.

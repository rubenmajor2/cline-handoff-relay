# 112 — When asked for an executor ETA, query the actual data — never guess from queue depth alone

Permanent rule. Workspace-scoped. Source: 2026-05-24 00:18 PT directive verbatim:

> "And then whenever i ask you an ETA for executor completion, make a cline rule to check the actual ETA like you just did."

The triggering incident in that same session:
- Cori sent 8 screenshots to chat 84 at 22:24-22:39 PT 2026-05-23
- Filed 5 ideas + chained as session_handoffs at autonomous tier
- Ruben asked for an ETA so he could tell Cori
- First answer (Cline): "1-2 days easy stuff, 5-7 days for Schedule calendar." Based on the naive "91 chains ahead" queue count.
- Ruben pushed back: "7 days will not cut it. Research a more realistic ETA considering how quickly RUBEN Executor works and where these are at."
- Real research: 91-ahead number was mostly **zombie chains 22,000-33,000 minutes old (15-23 days)** that weren't actually competing for capacity. Today alone, 24 ideas deployed. Many went proposed→deployed in 17 minutes to 4 hours (e.g. #6171 ~1h, #6192 ~17min, #6053 ~4h). The real bottleneck wasn't queue depth — it was per-item complexity.

## The bright-line rule

**When Ruben (or anyone) asks "how long until X deploys" or "what's the ETA on this idea" or any variant — DO NOT guess from queue depth, gut feel, or naive math. Run the queries below FIRST, then synthesize an ETA grounded in live throughput numbers.**

## The mandatory 3-query check

Before any ETA reply:

### Query 1 — Live throughput (last 7 days)
```sql
SELECT DATE(implemented_at) AS day, COUNT(*) AS deployed
FROM orchestrator_ideas
WHERE implemented_at >= NOW() - INTERVAL 7 DAY
GROUP BY day ORDER BY day DESC;
```
This gives the **real shipping rate**. Today's number is the leading indicator. A 7-day rolling average smooths out weekends + outages.

### Query 2 — Same-day deployments (gauge complexity-vs-time)
```sql
SELECT id, title, status,
       TIMESTAMPDIFF(MINUTE, created_at, implemented_at) AS minutes_to_deploy,
       created_at, implemented_at
FROM orchestrator_ideas
WHERE implemented_at >= NOW() - INTERVAL 48 HOUR AND status='deployed'
ORDER BY implemented_at DESC LIMIT 20;
```
This shows which kinds of ideas land fast (single-file patches, schema changes, log-suppressions) and which take longer (multi-file UI builds, calendar integrations). Compare the TYPE of the target idea against the sample.

### Query 3 — Real queue depth (filter out zombies)
```sql
SELECT COUNT(*) AS active_p1_queue
FROM session_handoffs
WHERE status='in_progress'
  AND approval_tier IN ('autonomous','approved')
  AND priority_hint='P1'
  AND id < <target_handoff_id>
  AND updated_at >= NOW() - INTERVAL 7 DAY;  -- exclude zombies
```
The naive `COUNT(*)` returns dozens of zombies that haven't progressed in weeks. Filter by `updated_at >= NOW() - INTERVAL 7 DAY` (or similar window) to get the **actually-competing** depth.

For the target idea itself:
```sql
SELECT i.id, i.title, i.status, i.dev_stage, s.eligibility_hold_reason,
       s.consecutive_empty_plans, s.last_empty_plan_at, s.updated_at
FROM orchestrator_ideas i
JOIN session_handoffs s ON s.idea_id = i.id
WHERE i.id IN (...);
```
If `consecutive_empty_plans >= 2` or `eligibility_hold_reason` is set, that chain is stuck — the ETA is "unknown until unblocked," not the throughput-divided number.

## Synthesize the ETA

After the queries:

1. **Today's throughput** sets the upper bound for "today + tomorrow"
2. **Sample of same-day deployments** tells you whether the target idea looks like a fast one (single sed-fix → <1h) or a slow one (multi-file UI → 1-3 days)
3. **Real queue ahead** divides by throughput
4. **Per-target stuck status** is the override — a stuck chain doesn't get a "X hours" ETA, it gets a "needs manual unblock" caveat

## Three ETA buckets to report

Report in tiers, not single numbers:

- **Likely landing within 24h:** items that match the same-day pattern (single-file patch, schema seed, lib method add, log fix)
- **24-72h:** items needing 2-3 file edits across coupled subsystems
- **3-7 days:** items needing real UI work (calendar libraries, modal infrastructure, new admin routes) — these legitimately need a dedicated subagent build session, not just executor cron ticks

If the ETA crosses 7 days, default position should be **ship in-session via Cline rather than wait for executor** (per .clinerules/38: Ruben-asked + can't-wait → ship now). Don't quote a 2-week ETA — at that point you're misusing the executor for work that belongs in a build session.

## What this rule does NOT do

- Does not require the queries before Cline gives a "ship right now" estimate for own-session work — that's just Cline's plan ETA, not the executor's
- Does not apply to questions like "is this idea filed?" or "what's the status?" — those are status checks, not ETAs
- Does not require running the queries if the answer is obvious from context (e.g. Ruben just filed it 30 seconds ago and the queue has 5 active chains — saying "next tick or two" is fine)

## Forbidden ETA shapes

Banned answers when asked for an executor ETA:

- ❌ "A few days" (no data)
- ❌ "1-2 weeks" (almost certainly wrong AND if accurate, means Cline should ship in-session instead)
- ❌ "RUBEN is queued up so it'll get there" (no number, useless to Ruben)
- ❌ "It depends" (yes, on numbers you should look up)
- ❌ Naive "X ideas ahead / Y per day = Z days" without the zombie filter

## Required ETA shape

After running the queries, the answer must include:

- The actual throughput number used ("24 deployed today, ~19/day 7-day avg")
- The fast-sample baseline ("similar one-file patches landed in 17 min to 4 hours today")
- The slow-sample baseline if applicable ("the calendar/UI ones take 2-3 days even when fast")
- Per-idea breakdown if multiple ideas: don't lump them
- The 24h / 24-72h / 3-7d bucket with named items in each
- An explicit recommendation to **ship in-session** for anything that would otherwise quote >7 days

## Source incidents

2026-05-23 23:54 PT → 24 00:04 PT — Cori screenshot rebase session. First ETA was naive (91-queue / 19-per-day = ~5 days everything). Pushback led to real data check. Real picture: 4 of 5 ideas shippable same-session (and Cline shipped them right then), 1 needed a dedicated build slot. The rule encodes "always run the queries" as the default move on any ETA ask.

## Self-check before any ETA answer

Before pressing send on an ETA reply:

1. Did I run query 1 (throughput)?
2. Did I look at recent same-day deployments to gauge complexity?
3. Did I filter zombies from queue depth?
4. Did I check if the target chain itself is stuck?
5. Did I tier my answer by 24h / 24-72h / 3-7d buckets?
6. If the slowest bucket exceeds 7 days, did I instead recommend in-session shipping?

If any answer is no → don't ship the ETA. Run the missing check first.

## Cross-references

- .clinerules/29 (act-on-confidence — same posture: don't guess, check)
- .clinerules/38 (Ruben-asked → autonomous OR shipped now — the >7-day fallback)
- .clinerules/85 (systemic fix not bandaid — relates to "if it's 2-week ETA, you're using the wrong tool")
- .clinerules/91 (every completion needs pickup prompt — ETA + pickup prompt usually paired)
- HANDOFF entry: 2026-05-24 00:12 PT — Cori 8-screenshot rebase

## Last updated

2026-05-24 00:18 PT — initial rule per Ruben directive at end of Cori rebase session.

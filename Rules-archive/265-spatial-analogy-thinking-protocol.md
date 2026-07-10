# 265 — Spatial/Analogy Thinking Protocol: when stuck, reframe and think sideways

Permanent rule. Source: 2026-07-10 Ruben directive: "you need to think more spatially... if you can't resolve an issue head on, what other analogous things would resolve the problem... when you get stuck or really stuck, rather than giving up."

## When to fire

When you have exhausted linear/sequential approaches to a problem AND you feel stuck or about to give up. This is the "try a different wall" protocol — not "beat your head against the same wall harder."

## The protocol (6 steps)

### 1. Reframe the problem SPATIALLY

Stop thinking "what config var do I try next" and instead DRAW the physical/logical topology:
- What are the physical components?
- How are they connected?
- WHERE is the actual blockage?
- What is physically happening in the system?

**Example:** Instead of "what NCCL env var fixes the QP hang," draw the ring topology and see that Cato port0 and Cesar port0 share a subnet but are on different physical cables. The blockage is at the L2 layer — they're same-subnet but not same-link.

### 2. Think ANALOGOUSLY

What other systems have solved this same CLASS of problem? Brainstorm analogies:
- **Phone switchboard:** multiple lines to different people, need an operator to route correctly
- **Postal sorting:** multiple mailboxes to different neighborhoods, need correct zip codes (subnets!)
- **Network bonding:** multiple NICs to different switches, need LACP or explicit per-destination routing
- **Airport hub-and-spoke:** connecting flights through intermediate nodes
- **Plumbing:** multiple pipes to different rooms, need correct valve routing
- **Traffic intersection:** multiple roads crossing, need traffic lights or roundabouts

### 3. APPLY the analogy

Can the analogous solution be implemented here? What would it look like?

**Example:** The postal analogy says "give each route its own zip code." Applied to networking: give each CABLE its own /30 subnet so NCCL can match NIC-to-peer correctly (like zip codes matching postal routes).

### 4. Acquire information until you KNOW

If you don't understand something, RESEARCH IT. Do NOT guess:
- Read the source code (grep the actual implementation)
- Read the documentation (official docs, not just blog posts)
- Read community discussions (GitHub issues, Stack Overflow, forums)
- Run diagnostic commands to observe actual behavior
- "I don't know" is the START of investigation, not the end

### 5. PERSEVERE at the precipice

The breakthrough often comes right after the point where you want to give up. One more attempt, approached from a new angle, can crack it.

This is NOT "beat your head against the wall" — it's "try a different wall." Each attempt must approach the problem from a NEW angle, not repeat the same failed approach.

### 6. Think in PARALLEL, not just sequence

What can be done simultaneously?
- What dependencies can be broken?
- What can be prepped while waiting?
- Can you dispatch subagents to research multiple angles in parallel?
- Can you test multiple hypotheses at once?

## When this rule fires alongside others

- **Rule 262** (consult bug library + community): fires FIRST — check if the problem is already solved
- **Rule 265** (this rule): fires WHEN 262 doesn't yield a solution — reframe spatially + think analogously
- **Rule 29** (act on confidence): once you have a spatial/analogous insight, ACT on it — don't just analyze
- **Rule 264** (The Foreman): uses this protocol as part of the Worker's persistence pattern

## Self-check before giving up

Before calling `attempt_completion` with "I'm stuck" or "this approach didn't work":

1. Have I drawn the physical/logical topology of the problem? (Step 1)
2. Have I brainstormed at least 3 analogous systems? (Step 2)
3. Have I applied at least one analogy to a concrete fix? (Step 3)
4. Have I read the actual source code or docs for the failing component? (Step 4)
5. Am I approaching from a NEW angle, or repeating the same failed approach? (Step 5)

If you answer "no" to any of these, you are NOT actually stuck — you have more work to do.

## Source incidents

- **2026-07-10 GLM-5.2 RoCE QP hang:** After 4 linear attempts (MERGE_NICS, rail-optimized HCA, NET_MERGE_LEVEL, patched NCCL) all failed, spatial analysis revealed the root cause: all port0 interfaces shared one subnet (10.100.1.0/24) despite being on different physical cables. Fix: unique /30 subnet per cable (postal zip code analogy). This broke through after the "give up" point.

## Cross-references

- Rule 262: consult bug library + community before recycling approaches
- Rule 264: The Foreman (persistent dual-window pattern that uses this protocol)
- Rule 29: act on confidence tier (once you have the insight, act)
- Rule 00: subagent dispatch (research multiple angles in parallel)

## Last updated

2026-07-10 — initial. Extracted from Rule 264 (The Foreman) as a standalone protocol that fires on ANY stuck situation, not just Foreman tasks.
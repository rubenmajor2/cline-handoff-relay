# 121 — The 3Gs + catabolize: free/cheap model wins at W/T ≥ 45%, break apart the expensive buckets

Permanent rule. Workspace-scoped. This is the findable home for the Fleet Agent
routing-economics doctrine that was previously scattered across ideas #7629,
#6723, #7630, #4974 and rule 119. If you are routing LLM traffic or evaluating a
cheaper model, start here.

## The 3Gs (the goal of all Fleet Agent routing work)

Every routing/flip decision optimizes three things at once. Ruben framing 2026-05-28:

1. **G1 — maintain quality.** The cheaper/free model must be same-or-better. Measured as Win+Tie (W/T) rate against the current primary, cross-family judge per .clinerules/88.
2. **G2 — less expensive.** Shift volume off the most expensive model (Sonnet/Opus) onto free local (7b-lora, 14b, 32b on Artemis/Joshua) or cheap cloud.
3. **G3 — increase capacity.** More traffic served per dollar/hour = more total throughput. Distributing off the paid frontier also frees rate-limit headroom.

A flip is correct only when it holds G1 while improving G2 and/or G3.

## The bright-line mechanic: W/T ≥ 45% = flip

**When a cheaper/free model scores Win+Tie ≥ 45% against the current primary on a surface (n ≥ threshold), route that surface to the cheaper model.** The cost delta of free-vs-paid justifies the swap the moment quality crosses coin-flip-ish parity. This is the gate, not a suggestion. Source: idea #6723, #4974, Ruben 2026-05-24 "if our LLM has 45% W/T quality then we'd want ours."

The 45% bar is deliberately below 50% because the loser (paid) costs real money every call and the free model costs nothing — so "loses a bit more than half the time but free" still wins on total value for most non-critical surfaces.

## Catabolize: don't evaluate the whole bucket, break it apart

The big expense is the **`default` Sonnet bucket** — callers that didn't declare a `task_kind` so the router fell through to the most expensive option. Don't ask "can a cheap model replace Sonnet everywhere" (it can't). Ask:

**"Where inside this bucket is Sonnet winning, and where is it only tying?"** Break (catabolize) the bucket into segments. For each segment where the cheap model already hits W/T ≥ 45%, flip THAT segment. Leave the segments where Sonnet genuinely wins on Sonnet.

Example: if Sonnet wins 80% overall, that 80% is not uniform. It might be 95% on code-patch and 55% on ticket-triage. Flip ticket-triage to the cheap model, keep code-patch on Sonnet. Net: most of the volume moves, quality holds. This is per-`task_kind` / per-segment routing, already proven in `/var/www/emtskills/_scripts/llm_backtest/findings.md`.

## How you get a model to flip-ready (rule 119 priority order)

1. **Backtest first** — n≥50 controlled replay against current primary. Fastest defensible W/T number.
2. **Train second** — if close-but-not-quite, LoRA-train on RunPod, re-backtest. EMSU corpus moves models from sub-20% to 60%+.
3. **Shadow last resort** — only when the surface can't be backtested offline.

Fleet Agent v23 **autoflips the moment the gate clears** (cost-down × W/T ≥ current × n≥threshold × blast ≤ $10/hr × surface allowlist × reversible). No supervised-approval dwell. The gate IS the safety rail.

## Why "flip automatically if rule 29 + 3G apply" did NOT happen yet (the actual gap)

A clean backtest at W/T ≥ 45% on a non-hardrail surface SHOULD autoflip with no human. If it isn't flipping, the cause is almost always one of these — check them in order:

1. **Shadow-not-backtest:** v3 router runs with `EMSU_ROUTER_SHADOW=1` (default), so v3 only logs, v2 ships. "Agreement %" between v2 and v3 is NOT a quality signal — ignore it. The flip criterion is the **backtest W/T**, never v2/v3 agreement.
2. **Decision-log-only flips (#7630):** `cron_fleet_dynamic_rebalancer.php` writes `fleet_decision_log` + `lora_fleet_routing_state` rows on a flip, but actual production routing lives in `/etc/litellm/router_hook.py` `TIER_TO_MODEL` — which the flip code does NOT touch. So flips "fire" but traffic doesn't move. This is the keystone bug.
3. **No routing rows for the surface:** `lora_fleet_routing_state` only has rows for `emsu-qwen2.5-coder:7b-lora`, not for sms_ai/ticket_ai/default/etc, so the UPDATE no-ops.

So the answer to "what are we dealing with" is: **the gate logic and the 45% doctrine are correct and approved; the wiring from a cleared gate to the live router_hook.py is the missing piece (#7630).** Fix that and the autoflips become real.

## Hard rails (never auto-flip, regardless of W/T)

Per .clinerules/119 `fleet_v23_excluded_surfaces_csv`: grievance_response, refund_decision, regulator_outbound, payment_outreach, affirm_dispute, student_email_compose. These need explicit Ruben yes + Q-card + compliance review.

## Where the pieces live

- **This rule** — the doctrine + the 3Gs + catabolize framing (findable home).
- **Idea #7629** (P0 approved) — catabolize the default Sonnet bucket.
- **Idea #6723** (P1 approved) — auto-flip at W/T ≥ 45%, per-surface overrides.
- **Idea #7630** (P0 approved) — the decision-log-vs-real-routing wiring gap (the keystone fix).
- **Idea #7505** (P1) — active load-distribution across Ollama hosts (G3 capacity).
- **Rule 119** — backtest-first, train-second, shadow-last + autoflip-no-dwell.
- **Rule 87** — opportunity-cost-of-delay math (every day unflipped = burn).
- **Rule 88** — cross-family judge for backtests.
- `/var/www/emtskills/_scripts/llm_backtest/findings.md` — the per-task_kind decision matrix (catabolize in practice).
- `/etc/litellm/router_hook.py` — `TIER_TO_MODEL` is what actually routes; flips must land here.

## Self-check before any routing/flip work

1. Am I measuring W/T from a backtest (correct) or from v2/v3 agreement (wrong)?
2. Am I evaluating a whole bucket, or did I catabolize it into segments first?
3. If a gate cleared but nothing moved, did I check that router_hook.py `TIER_TO_MODEL` actually changed (#7630)?
4. Is this a hard-rail surface? If yes, no autoflip.
5. Does the flip hold G1 (quality) while improving G2 (cost) and/or G3 (capacity)?

## Source

2026-05-28 — Ruben directive to consolidate the scattered catabolize/45%/3G doctrine into one findable place "so I don't have to re-invent the wheel." Concept origin: ideas #4974 (2026-05-18), #6723 (2026-05-24), #7629 + #7630 (2026-05-27), rule 119 (2026-05-26).

## Last updated

2026-05-28 — initial consolidation.

# 138 — The W/T deployment gate is a FLOOR to go live, never a training target. Keep improving after deploy (3G capacity).

Source: 2026-06-05 Ruben question during the Frankenstein B200 babysit: *"wondering if training to W/T % of 45% is best practice or if we continue after we are 45% because we can only increase quality, right and that's a 3G principle to increase capacity. If the LLM is free and we can be higher than 45% even better, so why not continue AFTER deployment?"*

## The bright-line rule

**The gate percentage (e.g. 45% W/T per rule 121) is the bar at which a free local model is good enough to START taking traffic from paid frontier models. It is NOT the point at which training stops.** Two orthogonal decisions:

1. **Routing decision (the gate):** at W/T ≥ 45% vs the shipped frontier output, route the free model. Rationale: free + "as good as the frontier 45% of the time on win-or-tie" is already a net win because inference is ~$0. The gate answers "deploy now? yes/no."
2. **Quality decision (training):** uncapped. A free local model only gets better, and there is no marginal inference cost to higher quality. So you keep raising W/T after deployment via more epochs, better/larger corpus, cleaner data, and re-mints.

These never collapse into one number. The gate gates *routing*; it never caps *training*.

## Why "continue after deployment" is correct (the 3G capacity principle)

3G = increase capacity. A deployed free model at 55% W/T serves better answers than the same model at 46% at the SAME zero marginal cost. There is no quality/cost tradeoff to balance once the model is free and self-hosted — higher quality is pure upside. Therefore:

- **Deploy at the gate** (don't wait for perfection — 45% already beats paying for the frontier on cost).
- **Keep improving after deploy** (more training, better data, re-mint) because every point of W/T above the gate is free quality.
- **Hot-swap the adapter** when a higher-scoring one clears: gate-eval the new adapter, and if it beats the live one, route it in (rule 118 safe restart) and retire the old.

Stopping training the moment you hit 45% leaves free quality on the table. That is the anti-pattern this rule kills.

## What this means operationally

- **Don't tune `num_train_epochs` / `max_steps` to "just barely clear the gate."** Train to a sensible convergence point (e.g. 2-3 epochs), gate at 45% to deploy, then schedule continued-improvement re-mints as a background loop.
- **The gate-eval is a recurring check, not a one-time pass/fail.** Re-run it on each new adapter; promote the winner.
- **A model already live above the gate is still a training candidate.** Being deployed does not mean "frozen." Keep a backlog idea to push its W/T higher.
- **Never report "training done, hit 45%" as a terminal state.** Report "deployed at gate, W/T=X%, continued-improvement re-mint queued."

## What the gate is genuinely FOR

The gate exists to answer the binary "is it safe/worth it to stop paying the frontier for this task_kind and use the free model instead." 45% is deliberately low because the cost arbitrage is huge (paid frontier → $0). It is not a quality bar in the absolute sense — it's a *break-even-on-cost* bar. Quality continues upward independently.

## Self-check

When working any free-model / LoRA / catabolism task, ask:
1. *Am I treating the gate % as a stop-training signal?* → Wrong. It's a deploy signal. Keep a re-improve loop.
2. *Did I tune epochs/steps just to scrape past the gate?* → Wrong. Train to convergence; gate only decides routing.
3. *Is a deployed model being treated as frozen?* → Wrong. Deployed models above the gate are still improvement candidates — file the re-mint.

## Cross-references

- .clinerules/121 — the 45% W/T catabolism gate (free model replaces Sonnet/Opus at W/T ≥ 45%). THIS rule clarifies that 121's number is a floor, not a target.
- .clinerules/92 — work at the core (the continued-improvement loop is the real system, not a one-shot train).
- .clinerules/29 — agents act (deploy at the gate, don't wait for perfection).
- .clinerules/118 — litellm safe restart (used when hot-swapping a better adapter in).
- Frankenstein ideas #9687/#9688/#9689/#9728/#9933/#9934/#9935.

## Last updated

2026-06-05 — initial. Source: Ruben's question during the Frankenstein B200 fleet babysit — correctly identified that gating at 45% and then stopping leaves free quality on the table, and that continuing to improve after deployment is the 3G capacity principle.

# 141 — Ruben runs multiple Cline windows SIMULTANEOUSLY by design. Never treat it as a collision or a problem to flag.

Permanent rule. Workspace-scoped. Source: 2026-06-05 Ruben directive (repeated, then escalated): "it's a cline rule that I run these windows simultaneously so harden that rule or whatever."

## The bright-line rule

**When Ruben runs multiple Cline windows at the same time, that is the INTENDED operating mode, not a bug, not a risk, not something to warn about.** Cline must NOT:

- Flag "windows may be colliding" as a problem.
- Tell Ruben to run them sequentially / one at a time.
- Spend a completion explaining collision risk between his windows as if it were news.
- Treat "all 5 are running simultaneously" as a finding worth surfacing.

It is the default. He parallelizes on purpose to go faster (3Gs / opportunity-cost, rule 87). The agent's job is to MAKE simultaneous windows safe by DESIGN, then shut up about it.

## How to make simultaneous windows safe (the design, not a warning)

When producing copy-paste windows meant to run at once, bake in non-collision by construction:

1. **Single-writer per shared mutable surface.** Exactly ONE window edits the live router (`router_hook.py` / LiteLLM / `config.yaml`). Others hand work to it via flag files (`ROUTE_READY_<kind>.txt`), never by editing the shared file themselves.
2. **Each pod-owning window mints its OWN GPU pods.** Multiple pods simultaneously = the GOAL (faster training/gating), not a conflict.
3. **Driver model = Anthropic Opus direct, never LiteLLM :4000** — because the router-owner window restarts LiteLLM (rule 118) and that would drop the connection for sibling windows. (This is the ONE real interaction to design around, and it's handled by model choice, not by serializing windows.)
4. **Infra/local work (babysitter, MCP reindex, orchestrator drain)** is its own window, touches no shared GPU/router surface.

If those four hold, the windows are collision-free by construction and Cline should present them as "run these simultaneously" with zero hand-wringing.

## What Cline SHOULD do when checking on running windows

Report STATE and BLOCKERS, not the fact that they're parallel:
- ✅ "classify merge is in a failure loop (GGUF EOF), needs a fix — it won't self-complete."
- ✅ "broken pod C still alive, $X/hr."
- ❌ "the 5 windows are running simultaneously without colliding" — Ruben already knows; this is noise.
- ❌ "running them at once risks YOLO trips" — only true if you violated design point #3; fix the design, don't warn.

## Self-check

Before surfacing anything about Ruben's multiple windows, ask: "Am I telling him something is wrong because he's running them in parallel?" If yes — delete it. Parallel is the spec. Surface only concrete per-task blockers (a dead merge, a wasted pod, a failed gate), and design the windows so parallelism is safe without comment.

## Source incident

2026-06-05 — Cline produced 5 simultaneous windows, Ruben ran them all at once (as he always does), and Cline's status check led with "the windows ARE running simultaneously without colliding" as if it were a finding. Ruben: "it's a cline rule that I run these windows simultaneously so harden that rule or whatever." The real deliverable was the one actual blocker (classify GGUF merge dead loop) + fresh windows, not commentary on parallelism.

## Cross-references

- .clinerules/118 — LiteLLM restart drops :4000 (why driver windows use Opus direct, not the router)
- .clinerules/87 — opportunity-cost (why Ruben parallelizes)
- .clinerules/137 — don't collide with a parallel window (the single-writer design that makes 141 safe)
- .clinerules/91 — pickup prompts (each parallel window is a self-contained lane)

## Last updated

2026-06-05 — initial. Source: Ruben directive to harden the simultaneous-windows expectation after Cline flagged parallelism as a concern.

# 137 — No LLMs idling on the 2026 M5 workstation. It is Ruben's clean dev box, not a serving node.

Source: 2026-06-04 Ruben directive. During Project Frankenstein, Cline left a tuned-70B `mlx_lm server` (PID 17687, :8081) running on the M5 across many windows. Ruben: "There are no LLMs on this 2026 M5 ... no LLMs need to be hanging out on this computer."

## The rule

The **2026 M5 Max 128GB (`Rubens-MacBook-Pro-2`)** is Ruben's clean workstation. It hosts **NO long-running LLM servers**. Per FLEET_MAC_HARDWARE.md it is explicitly "Cline dev host; NO dedicated LLMs."

- **Serving nodes** (where LLMs live): SMS Mac 2021 (:11455 base-70B), 2024 Mac M4 (:11505 qwen-coder), WOPR GPU (:11434), Artemis (CUDA, when up).
- **One-time jobs are FINE on the M5** (Ruben: "I'm fine with one time things like this and clean up"): LoRA training, MLX→GGUF conversion, fuse/dequant. These run, finish, and the process EXITS. The M5 has the most headroom (128GB) so it's the right box for the heavy one-time builds.
- **What's banned: a persistent LLM SERVER process** — `mlx_lm server`, `ollama serve` (as a service), any `--port` model server left running after the task. If you start an `mlx_lm server` on the M5 for a backtest/gate, you MUST `kill` it in the same session when done.

## Self-check before any attempt_completion on an M5 model task

1. Did I start any `mlx_lm server` / model server on the M5 this session? → `pgrep -fl "mlx_lm server"`. If alive → `kill` it before completing.
2. Is the only thing left a finished one-time job (training/conversion) whose process has EXITED? → fine.
3. Pickup prompts that say "server still up on :8081 for follow-up" are a violation — kill it and note it's killed.

## Cross-references

- `docs/FLEET_MAC_HARDWARE.md` — M5 = workstation, no dedicated LLMs; serving topology
- `.clinerules/91` — pickup prompts must not leave idle servers as "open threads"
- `.clinerules/29` — clean up is part of the action, not a deferred item

## Last updated

2026-06-04 — initial. Source: tuned-70B mlx_lm server left idling on the M5 across a multi-window Frankenstein session until Ruben caught it.

# 137 — ZERO LLMs on the 2026 M5 workstation. Not servers, not one-time jobs. RunPod first by opportunity cost, then a serving node — never Ruben's Mac.

Source: 2026-06-04 Ruben directives, two escalating steps in one Frankenstein session:
1. First: "There are no LLMs on this 2026 M5 ... no LLMs need to be hanging out on this computer." (banned persistent servers)
2. Then, after catching a multi-hour `mlx_lm lora` 70B train pinning the box: "if it's going to take more than 5-10 minutes on my Mac here on the M5, the answer is no always ... It eats up my windows and can jack up all my work. In fact, always consider the runpod first because of opportunity cost. Then some other machine we have."
3. Final: "On second thought just don't run any LLMs on this workstation."

The final word is absolute. This rule reflects #3 and supersedes the earlier "one-time jobs are fine" carve-out.

## The rule (absolute)

The **2026 M5 Max (`Rubens-MacBook-Pro-2`)** runs **NO LLM workloads. Period.** No persistent model servers AND no one-time jobs. Not `mlx_lm server`, not `mlx_lm lora` training, not GGUF/MLX conversion, not fuse/dequant, not a quick local inference "just to test." If a process loads model weights and runs compute on this Mac, it does not belong here.

Why: it is Ruben's live dev box. A heavy LLM job eats RAM + GPU, makes Cline windows time out (observed: `tail` and `ps` timing out on the Mac while a 70B QLoRA ran), and can jack up everything else he's doing. The opportunity cost of pinning his workstation dwarfs the few dollars of a RunPod pod.

## Where LLM work goes instead (the hierarchy — in order)

1. **RunPod FIRST, by opportunity cost.** Per .clinerules/84 (default-on) + .clinerules/114 (B200-first GPU chain, never pin) + .clinerules/138 (LoRA >7B → cloud). For ANY model job — training, conversion, batch eval, gate eval, quant — the default is: mint a pod (B200 first), do the work there, rsync the artifact back, terminate. The pod's $3-6/hr is nothing against an hour of Ruben's blocked workstation. Don't ask under the rule-84 cost lanes; ship.
2. **Then a dedicated serving node** if a pod is genuinely wrong (e.g. needs WG-local network access per rule 84's exception, or the model is already warm there): SMS Mac 2021 (:11455 base-70B), 2024 Mac M4 (:11505 qwen-coder), WOPR GPU (:11434), Artemis (CUDA, when up). These are the boxes built to host models.
3. **The M5: never.** There is no job small enough or "one-time" enough to run an LLM on the M5. If you catch yourself about to run `mlx_lm`/`ollama run`/`vllm`/`llama.cpp` on `Rubens-MacBook-Pro-2`, STOP and route to (1).

## The 5-10 minute tripwire (Ruben's words)

Even before "never," Ruben drew the line at: *"if it's going to take more than 5-10 minutes on my Mac, the answer is no always."* The final directive removed even the under-10-min exception. So the operating rule is simpler than the tripwire: **no LLM compute on the M5 at all.** The tripwire is kept here only as the rationale — anything that would pin the box is exactly what he doesn't want.

## Self-check before any model-related command

1. *Is the target host `Rubens-MacBook-Pro-2` / the local M5?* If the command is `mlx_lm ...`, `ollama run/serve`, `python -m vllm`, `llama-cli`, `./main -m model.gguf`, or any weights-loading process AND it would run locally → **STOP. Route to RunPod (rule 114 mint, B200-first) or a serving node.**
2. *Did I (or a prior window) leave an LLM running on the M5?* → `pgrep -fl "mlx_lm|ollama|vllm|llama.cpp"`. If anything is alive on the M5 → `kill` it this session and note it killed. (Checkpoint-resumable training: save/note the checkpoint, kill, relaunch on cloud.)
3. *Pickup prompts must not leave any LLM process on the M5* as an "open thread." Kill first, hand off second.

## What the M5 IS for

Cline dev host: editing files, running the MCP client, git, builds, orchestration of REMOTE compute (ssh to pods/nodes, scp, rsync, curl to RunPod API). All the babysitting of a RunPod eval/train is fine here — that's just ssh + polling, not LLM compute. The model itself runs elsewhere.

## Cross-references

- `docs/FLEET_MAC_HARDWARE.md` — M5 = workstation, NO LLMs; serving topology (SMS/M4/WOPR/Artemis)
- `.clinerules/84` — use RunPod to save time (default-on for long parallel work)
- `.clinerules/114` — RunPod GPU selection: B200 first, opportunity-cost-weighted, never pin to one type
- `.clinerules/138` — LoRA/QLoRA training of >7B defaults to RunPod
- `.clinerules/91` — pickup prompts must not leave idle servers/jobs as open threads
- `.clinerules/29` — cleanup is part of the action, not a deferred item

## Source incidents

- 2026-06-04 (a) — tuned-70B `mlx_lm server` (PID 17687, :8081) left running on the M5 across windows. Ruben: "no LLMs need to be hanging out on this computer."
- 2026-06-04 (b) — a multi-hour `mlx_lm lora` 70B QLoRA train (PID 78797, 1200 iters) was pinning the M5 (~39GB RAM + GPU), causing Cline `tail`/`ps` to time out. Cline killed it (iter 0, no checkpoint lost) and Ruben set the line: ">5-10 min on the M5 = always no; consider RunPod first for opportunity cost, then another machine."
- 2026-06-04 (c) — Ruben's final simplification: "just don't run any LLMs on this workstation." This rule rewritten to absolute.

## Last updated

2026-06-04 — v2 rewrite to ABSOLUTE (zero LLMs, no one-time-job carve-out) + added the RunPod-first → serving-node → never-the-M5 hierarchy. Supersedes v1 which allowed one-time training/conversion jobs on the M5.

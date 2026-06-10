# 147 — Every training run must checkpoint at least every 30 minutes, and resume from the last checkpoint.

Permanent rule. Workspace-scoped. Source: 2026-06-09 Ruben directive verbatim:

> *"Cline rule, when you are training using RunPods or any other training, you should have 30 minute checkpoints minimum."*

## The bright-line rule

**Any training run (RunPod, cato/cesar, any box, any model size) MUST write a checkpoint at least every 30 minutes, AND the trainer MUST resume from the latest checkpoint on restart.** A reclaim, crash, or OOM must cost at most ~30 minutes of compute, never the whole run. Pair this with the durable-pull hardfloor (rule 138): checkpoints live on the pod, the final adapter is pulled to WOPR.

## Why this rule exists

RunPod spot/secure pods get reclaimed mid-run (3 B200s reclaimed in a row on 2026-06-09). Without checkpoints, every reclaim throws away ALL progress and the next pod starts from step 0. With 30-min checkpoints + resume, a reclaim at step 800/907 restarts at the last checkpoint (~780), not at zero. The checkpoint cadence is the difference between losing 30 min and losing 6 hours.

## How to set it (compute save_steps from the measured step time)

`save_steps` is in STEPS, not minutes, so convert from the run's seconds-per-iteration:

```
save_steps ≈ floor( (30 * 60) / seconds_per_step )
```

- B200/H200 gpt-oss-120b distill is ~26 s/it → 30*60/26 ≈ 69 → use **save_steps=60** (comfortably under 30 min).
- A faster 7B/14B run at ~2 s/it → 30*60/2 = 900 → use save_steps≈800.
- If you don't know the step time yet, start conservative (save_steps=50) and tune after the first few steps log.

In TRL `SFTConfig`: `save_strategy="steps", save_steps=<N>, save_total_limit=4` (keep a few, don't fill the disk). Make `save_steps` overridable via an env var (`SAVE_STEPS`) so it can be tuned without editing the trainer.

## Resume is mandatory, not optional

The trainer MUST detect existing checkpoints and resume:

```python
import glob, os
_ckpts = sorted(glob.glob(os.path.join(OUT, "checkpoint-*")),
                key=lambda p: int(p.split("-")[-1]) if p.split("-")[-1].isdigit() else 0)
trainer.train(resume_from_checkpoint=bool(_ckpts))
```

When you re-mint a pod after a reclaim, if you preserved the OUT dir (or pull-then-restore checkpoints), the run continues. At minimum, the SAME pod restarting (process killed but disk intact) resumes correctly.

## Self-check before launching any training run

1. *Is `save_strategy="steps"` with `save_steps` set so a checkpoint lands ≤30 min apart?* If no → compute it from the step time and set it.
2. *Does the trainer `resume_from_checkpoint` if checkpoints exist?* If no → add the glob+resume block.
3. *Is `save_total_limit` set so checkpoints don't fill the disk?* (4 is fine.)
4. *Is the durable-pull watcher armed (rule 138)?* Checkpoints on the pod + final adapter pulled to WOPR.

## Cross-references

- `.clinerules/146` — consult the training runbook before training (this rule is part of that runbook)
- `.clinerules/138` — fast-train levers + durable-storage hardfloor (pull weights before gate)
- `.clinerules/145` — RunPod train-pod registry lifecycle
- `.clinerules/114` — GPU mint chain
- `FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md` — the canonical procedure (add the checkpoint cadence there too)

## Source incident

2026-06-09 — during the 120B distill retrain, three B200 spot pods were reclaimed mid-run, each starting over from step 0 because the trainer had no time-based checkpointing (only save_steps=50 with no resume). Ruben: "when you are training using RunPods or any other training, you should have 30 minute checkpoints minimum." The trainer was updated to save_steps=60 (~26 min on a B200) + resume_from_checkpoint.

## Last updated

2026-06-09 — initial.

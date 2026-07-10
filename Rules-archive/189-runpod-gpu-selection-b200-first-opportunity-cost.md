# 114 — RunPod GPU selection: B200 first, opportunity-cost-weighted, never pin to one type

Permanent rule. Workspace-scoped. Source: 2026-05-24 21:32 PT Cline minted an
8xH100 pod for the #6276 LoRA training retrain (per Ruben's "Option A" on idea
#6722) using an ad-hoc `curl https://rest.runpod.io/v1/pods` with
`gpuTypeIds=['NVIDIA H100 80GB HBM3']` ONLY. Should have used Fleet's existing
`fa_mint_pod()` helper OR specified the full fallback chain (B200 → H200 →
H100 → A100). Pod killed 30 sec later ($0.30 burn) to avoid worse outcome.

## The bright-line rule

**When minting any RunPod pod (training, inference benchmark, GGUF
conversion, batch eval, etc.), pick the GPU by highest throughput per dollar
of opportunity cost, NOT by lowest per-hour sticker price.** And in the
`gpuTypeIds` array passed to RunPod's `/v1/pods` API, ALWAYS list the FULL
fallback chain (newest first, oldest last) — never pin to a single type.

## The GPU chain (current as of 2026-05-24)

The chain hardcoded in `cron_fleet_agent.php::fa_mint_pod()` is correct:

```
NVIDIA B200             (192 GB HBM3e, ~$5.99/hr secure, ~2.5x H100 throughput)
NVIDIA H200             (141 GB HBM3e, ~$3.99/hr secure, ~1.7x H100 throughput)
NVIDIA H100 80GB HBM3   (80 GB HBM3,   ~$3.29/hr secure, baseline)
NVIDIA H100 NVL
NVIDIA H100 SXM 80GB
NVIDIA A100 80GB PCIe   (80 GB HBM2e,  ~$1.89/hr secure, ~0.4x H100 throughput)
```

For compute-bound work (LoRA training, full fine-tunes, mlx_lm.convert quant
passes, RAG embedding fine-tunes, large-batch inference benchmarks) B200 wins
on BOTH wall-clock AND total cost despite higher per-hour rate:

- 8xB200 for ~12h LoRA train ≈ **$575**
- 8xH100 for ~30h same train ≈ **$790** (longer wall because slower)
- 8xA100 for ~80h same train ≈ **$1,200** (much longer wall, much higher total)

## Opportunity-cost evaluation (when newer GPUs appear)

If a newer GPU appears (B300, MI400, next-gen Blackwell, etc.) at higher
sticker price, evaluate the throughput-per-dollar ratio. **Trigger to swap
in:**

- New GPU is faster per-hour throughput by at least 1.3x AND
- Total-job-cost (per-hour × hours) is ≤1.2x current best, OR strictly
  cheaper
- AND availability is decent (>= 1 hr of zero-queue wait time across the
  day)

If those are met, prepend the new GPU to the chain. Otherwise leave the
chain as-is.

## How to actually mint

### Preferred (PHP, server-side)

```php
require __DIR__ . '/lib/db.php';
require_once __DIR__ . '/config/runpod_secrets.php';
require_once __DIR__ . '/cron/cron_fleet_agent.php';  // for fa_mint_pod
$mint = fa_mint_pod(
    'fleet-idea-XXXX-name',
    'idea_XXXX',
    150,  // disk GB
    [
        'IDEA_ID'    => 'XXXX',
        'IDEA_TITLE' => 'short title',
        'BUDGET_USD' => '500',
    ]
);
if (!$mint['ok']) { /* handle no-capacity / no-key etc */ }
$podId = $mint['pod_id'];
$gpu   = $mint['gpu'];
$perHr = $mint['per_hr'];
```

### Acceptable (ad-hoc curl, only when scripting from Cline)

ALWAYS specify the full chain:

```php
'gpuTypeIds' => [
    'NVIDIA B200',
    'NVIDIA H200',
    'NVIDIA H100 80GB HBM3',
    'NVIDIA H100 NVL',
    'NVIDIA H100 SXM 80GB',
    'NVIDIA A100 80GB PCIe',
],
```

### FORBIDDEN

```php
// DO NOT DO THIS
'gpuTypeIds' => ['NVIDIA H100 80GB HBM3'],  // single type, no fallback
```

Pinning to one GPU type means: (a) miss B200/H200 availability that would
finish the work faster + cheaper, (b) on no-capacity in that one type, mint
fails entirely instead of falling through.

## The mint+forget anti-pattern (also from 2026-05-24)

Tangential lesson: **never mint a pod without an immediate auto-bringup
plan.** A pod minted at 21:32 PT with no training script to push burns
$26-$32/hr while waiting for a human to catch up. Cost of a 12h idle gap =
~$300-400.

Per .clinerules/29 act-on-confidence + opportunity cost: if you can't push
the training script + nohup the run within ~5 min of pod RUNNING state,
DON'T MINT YET. File the bringup work as an idea, ship it in next session
with full context budget, then mint.

## Self-check before any RunPod mint

1. *"Did I specify the FULL gpuTypeIds chain, or pin to one type?"* If
   pinned, fix it.
2. *"Am I using `fa_mint_pod()` helper, or rolling ad-hoc curl?"* If ad-hoc,
   make sure the chain matches the helper's chain.
3. *"Do I have a training script / job-to-run ready to push within 5 min of
   pod RUNNING state?"* If not, file the bringup work as an idea first.
4. *"What's my budget cap? Do I have a daily cap override that justifies
   it?"* Check `fleet_agent_config.auto_pod_mint_daily_limit_usd`.

## Cross-references

- `cron/cron_fleet_agent.php::fa_mint_pod()` — the helper, line 807
- `.clinerules/29` — act-on-confidence-tier (GPU choice IS reversible
  small-blast)
- `.clinerules/91` — rule budget-watchdog (don't mint into a context-RED
  session without a bringup)
- Idea #6722 P0 deployed — "Accelerate #6276 LoRA via Option A bigger GPU"
- Idea #6741 P0 approved — "Proper B200 bringup for #6276 retrain"
- Idea #6716 P1 approved — RunPod pod training-progress watchdog (catches
  wedged / idle / no-progress pods within 1h)

## Last updated

2026-05-24 21:42 PT — initial rule. Source: H100 pod tovot0lzeq1k7s minted
+ killed within 30 sec, $0.30 burn, but the lesson is the rule itself.

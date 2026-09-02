# Rule 326 — GLM Ring Naming: Canonical IDs, No Version Aliases

**Severity: HARD-FLOOR on any new file/unit/lane name touching the GLM ring**
**Created: 2026-09-02** (Ruben directive: "Can you confirm with me we are actually using GLM 5.3 Local and not 5.2. The 5.2 file names are very confusing. I don't like the aliases.")
**Source incident:** During the 2026-09-01/02 Oceanside outage recovery, multiple live-5.3 artifacts still carried glm52 names (fabric guard, ring routes, WOPR systemd units, watchdog scripts, keep-warm crons, the tunnel unit). The 8/28 5.3 upgrade renamed model-specific artifacts but left ring-infrastructure under 5.2 names, and no rule prevented the drift. Future agents reading `glm52_ring_watchdog.sh` could reasonably conclude they are babysitting a 5.2 ring.

## The canonical mapping (what serves what, as of 2026-09-02)

| Artifact | Serves | Note |
|---|---|---|
| `/home/rubenmajor/glm53-nvfp4` | GLM-5.3 weights (nvfp4) | Only weights dir; all glm52-* weight dirs are RETIRED leftovers |
| `glm-5.3-15pct` | The served model id | :8210, 131072 ctx |
| `~/bin/glm53_relaunch_seq128.sh` | 5.3 relauncher | Model-specific: renamed |
| `~/bin/glm53_watchdog_worker_v2.sh` | 5.3 worker watchdog | Model-specific: renamed |
| `glm52_fabric_guard.sh`, `glm52_ring_routes.sh`, `glm52_roce_ring_setup.sh`, `glm52_ring_policy_routes.sh`, `glm52_fabric_up.sh` | 5.3 ring (infrastructure) | MODEL-AGNOSTIC: still glm52-named (renaming them mid-production is a tracked follow-up, not a mid-task action) |
| WOPR `glm52-ring-watchdog.service`, `glm52-tunnel-8210.service`, `/usr/local/bin/glm52_ring_watchdog.sh` | 5.3 ring | MODEL-AGNOSTIC: still glm52-named |
| LiteLLM lanes `glm-5.3-local` etc. | 5.3 | Renamed 8/28; NO glm52 lane ids remain in config |
| GLM53_RING_STATE_TRACKER.md | 5.3 truth | GLM52 tracker is preserved history, read-only |

## The rule (for any NEW name)

1. **Model-specific artifacts carry the model version in the name.** A script, config, unit, cron, or lane that only works for GLM-5.3 MUST be named `glm53_*` (or `glm-5.3-*`). Never name a 5.3-only artifact `glm52_*`.
2. **Model-agnostic ring infrastructure SHOULD be named `glm_ring_*` (no version)** — fabric, routes, tunnels, watchdogs that serve whatever ring is current. Existing glm52-named infra is grandfathered until the tracked rename lands; do not create NEW version-bearing names for infra that would survive a 5.4 upgrade.
3. **Never infer the served model from a filename.** The ONLY source of truth for what the ring serves is the live probe: `curl 127.0.0.1:8210/v1/models` → `id` field (+ weights `root`). A glm53 filename with a 5.2 id in the probe means the config is wrong; a glm52 filename with `glm-5.3-15pct` in the probe means legacy naming (grandfathered infra), not a 5.2 ring.
4. **No aliases.** Do not introduce router/lane aliases that mask the underlying model version (e.g. a `glm-local` lane that silently points at whatever is current). If a handle must be version-agnostic, it must resolve through the registry, which carries the version.
5. **Retired-model artifacts must be tombstoned, not deleted**, and their names must include the retired version (e.g. `glm52_dest_rules.sh.BROKEN-LOOP-20260901.tomestone`) so a future reader cannot mistake them for live.

## Self-check before creating any GLM-ring file/unit/lane name

1. Does this artifact only work for one model version? → version-prefix it (`glm53_`).
2. Would it survive a 5.4 upgrade unchanged? → `glm_ring_` (no version).
3. Am I about to name something based on an existing glm52 file? → STOP: check the live probe first; do not propagate the version confusion.
4. Did I document the name in GLM53_RING_STATE_TRACKER.md if it is part of the recovery chain? → required for watchdogs/relaunchers/guards.

## Cross-references

- Rule 315 (verify before declaring host/model state — the live probe is the only truth)
- Rule 322 (what-was-serving tables: underlying physical LLM, never router handles)
- Rule 317 (claim scope = probe scope: a filename is not a serving claim)
- GLM53_RING_STATE_TRACKER.md §"Canonical mapping" (this table's live home)

## Source

2026-09-02 Ruben feedback on the Oceanside hardening completion: the glm52-prefixed file names made it unclear whether the ring was actually serving 5.3. Live probe confirmed glm-5.3-15pct from glm53-nvfp4; ~40 legacy glm52 names remain (model-agnostic infra + retired backups). This rule prevents the drift class.

## Last updated

2026-09-02 — initial.
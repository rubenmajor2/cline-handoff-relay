# 294 — Re-probe inherited infra facts before acting on them (cross-window split-brain gate)

Archive rule. Workspace-scoped. Source incident: 2026-07-25 — WOPR was cut over from a 915G root disk to a 3.6TB Samsung 9100 PRO mid-session. A sibling Cline window that had gathered its facts BEFORE the cutover kept proposing idea #18985 ("root disk is 93% full, 805G/915G, /mnt/nvme9100 3.6TB is available, move /var/www to free space"). Every one of those facts was TRUE when gathered and FALSE by the time it was repeated: root is now `/dev/nvme0n1p2` at 29% (985G/3.6T) and `/mnt/nvme9100` no longer exists as a mountpoint because it BECAME root. Ruben: "Another window still thinks this which is what i wanted to avoid."

## The gap this closes

Rules 271 / 248 / 252 / 263 are all **write-side or single-window** gates: they stop YOU from writing an unverified claim, or from declaring a box down without probing it. None of them fires on the **read side** — when a window *inherits* a fact (from a pickup prompt, a HANDOFF entry, an idea body, a sibling window's blurb, or its own earlier turn) and simply repeats or acts on it. Inherited facts feel verified because they *were* verified. That is exactly the split-brain vector.

## The bright-line rule

**Any infrastructure fact you did not personally verify THIS session, with a tool call, is a HYPOTHESIS — regardless of who wrote it or how confident they sounded.** Before you act on it, repeat it, or file/keep an idea premised on it, you MUST re-probe it.

Infra facts in scope: disk capacity/usage, mountpoints and devices, box up/down, GPU present/probed, service running/stopped, port listening, cron enabled/disabled, boot time, model serving, tunnel state, file existence on a server.

## The mechanical gate (run before repeating or acting on an inherited infra fact)

1. **Is this fact from THIS session's own tool output?** Yes → OK, proceed. No → continue.
2. **Read the canonical state surface first.** For WOPR: `/var/www/emtskills/docs/WOPR_STATE.json` (regenerated every 5 min by `/usr/local/bin/emsu_host_state.sh` via `/etc/cron.d/emsu-host-state`). It carries `root_device`, `root_size/used/avail/pct`, `boot_time`, `gpu_probe`, `gpu_bar1`, `extra_mounts`.
3. **Freshness check.** If `now - generated_epoch > 600` (10 min), the snapshot is STALE — do not trust it either; run the live probe yourself (`df -h /`, `findmnt -no SOURCE /`, `uptime -s`, `nvidia-smi -L`, etc.).
4. **Does the live state contradict the inherited fact?** Yes → the inherited fact is DEAD. Do not repeat it. Correct the surface it came from (flip the idea to rejected/superseded, fix the HANDOFF line, correct the pickup prompt) in THIS session.
5. **Cannot probe it?** Then you cannot claim it. Mark it `(unverified — inherited from <source>, not re-probed)` or drop it.

## Supersede promptly — a stale idea is a live hazard

An idea whose premise has been invalidated is not harmless backlog: another window will read it and act on it. When a probe disproves an idea's premise, **flip it to rejected/superseded in the same session, with the probe evidence quoted in the note.** "Someone will notice eventually" is how #18985 survived a whole disk cutover.

## Boot-time is the cheapest staleness tripwire

`uptime -s` changing means every in-memory/runtime fact about that host (GPU probe state, service PIDs, tunnel channels, BIOS-staged toggles) is invalid. If the inherited fact predates the current `boot_time`, treat it as expired by default.

## Anti-patterns

- ❌ Repeating a disk/mount/GPU fact from a pickup prompt without a probe this session.
- ❌ "The other window said the box is down" → that is hearsay, not evidence (rules 248/252).
- ❌ Reading `WOPR_STATE.json` but skipping the `generated_epoch` freshness check.
- ❌ Finding a superseded idea and leaving it open "for the owning window to close."
- ❌ Waiting on / deferring to another window (rule 29 forbids this) instead of probing the machine yourself.

## Cross-references

- Rule 271 — verify before WRITING infra claims (write side; this rule is the read side)
- Rule 248 — verify live state before declaring a box/endpoint down
- Rule 252 — stale-info live-probe gate
- Rule 263 — verify before claim, no stale inferences
- Rule 29 — never wait out parallel windows; act on live state yourself
- Rule 91 — pickup prompts are the #1 staleness carrier; a bracketed idea tag inherits its premise too
- Rule 267 — GATE B reconcile returns LIVE executor state, same principle applied to ideas

## Source incident

2026-07-25 — idea #18985 (NVMe migration) survived the very cutover that made it moot; a sibling window re-broadcast "root disk is 93% full (805G/915G)" ~2 hours after root became a 3.6T device at 29%. Live probe (MARKER42, 13:19 PT): `/dev/nvme0n1p2 3.6T 985G 2.5T 29% /`, `uptime -s 2026-07-25 11:26:52`, `/var/www` 74G, `NVRM: BAR1 is 0M @ 0x0` (GPU still unprobed, reboot pending). Fix shipped same session: canonical `WOPR_STATE.json` + 5-min cron + this rule.

## Last updated

2026-07-25 — initial.

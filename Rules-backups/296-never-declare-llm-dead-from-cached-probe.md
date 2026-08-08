# 296 — Never declare an LLM dead from a cached probe field. Run the counter-delta test.

Source incident: 2026-08-05 — an agent read `decode_live=false, tok_s=0, fail_streak=9` out of
`/tmp/frankenstein_canary_health.json` for the GLM PP=6 ring and reported the ring DECODE-DEAD,
recommending a cycle/quarantine. The ring was serving **15 concurrent requests at 12.4 tok/s** at
that moment. Cycling it would have been a self-inflicted production outage. Bug library #2221.

The trap is real in BOTH directions: bug library **#2210** (same day, 01:15 PT) documents a
GENUINE decode-dead zombie on this same ring with the SAME field values. So the field alone can
never separate the two cases.

## THE MECHANICAL GATE (run this, do not reason about it)

**Before ANY claim that an LLM/host/ring is down, dead, stalled, wedged, or decode-dead — and
before ANY recommendation to cycle, restart, quarantine, or relaunch it — you MUST run a
counter-delta probe and paste its output into your claim.**

```bash
# Substitute the endpoint. 10s apart. This is ground truth.
G0=$(curl -s --max-time 8 http://HOST:PORT/metrics | grep '^vllm:generation_tokens_total' | awk '{print $2}')
R0=$(curl -s --max-time 8 http://HOST:PORT/metrics | grep '^vllm:num_requests_running'    | awk '{print $2}')
sleep 10
G1=$(curl -s --max-time 8 http://HOST:PORT/metrics | grep '^vllm:generation_tokens_total' | awk '{print $2}')
R1=$(curl -s --max-time 8 http://HOST:PORT/metrics | grep '^vllm:num_requests_running'    | awk '{print $2}')
echo "gen $G0 -> $G1 delta=$(echo "$G1 - $G0" | bc) running $R0 -> $R1"
```

### Verdict table — the ONLY legal readings

| Observation | Verdict | Action |
|---|---|---|
| `delta > 0` | **ALIVE**, decoding now | **NO ACTION.** Do not cycle. The cached field was stale/transient. |
| `delta == 0` AND `running > 0` | **REAL ZOMBIE** | Apply bug library **#2210** relaunch. The only case that justifies a restart. |
| `delta == 0` AND `running == 0` | **IDLE-ALIVE, NOT DEAD** | **NO ACTION.** Idle is not death. |
| `/metrics` unreachable but `/v1/models` 200 | **presumed ALIVE** | No action. Investigate the metrics path, not the model. |
| both unreachable | **DOWN** | Now you may act. Also check `ss -ltnp | grep PORT` and the tunnel/WG watchdog log. |

`delta > 0` **overrides every cached field, dashboard, canary snapshot, and `error_watchdog`
output.** A counter that moved is proof of life. Nothing outranks it.

## Why the cached field is ambiguous by design (rule 297 classification)

`/usr/local/bin/frankenstein_tools_adapter.py` → `_canary_probe_glm_passive()` deliberately
injects **zero requests** and infers decode from two `/metrics` scrapes ~6s apart. Three exit
branches historically collapsed into the same stored numbers:

- `delta > 0` → alive, real tok/s
- `delta == 0` AND `running > 0` → `DECODE_STALLED` (the real death signal)
- `delta == 0` AND `running == 0` → **idle, explicitly NOT dead**, returns a floor value

A sample taken mid-warmup also lands in the stalled branch before the counter starts moving,
producing a transient false-death that then sits in the JSON until the next probe. `tok_s=0` is
an **ambiguous sentinel**, not a corpse.

## System fix shipped 2026-08-05 (so the file now explains itself)

The adapter now stamps **probe provenance** into `/tmp/frankenstein_canary_health.json`:
`probe_mode`, `probe_reason`, `probe_gen_delta`, `probe_running`, `probe_waiting`.

`probe_reason` values: `DECODE_LIVE` · `DECODE_STALLED_REAL_ZOMBIE` · `IDLE_ALIVE_NOT_DEAD` ·
`METRICS_UNREACHABLE_HTTP_ALIVE` · `UNREACHABLE`.

**Read `probe_reason` first.** Only `DECODE_STALLED_REAL_ZOMBIE` is a death signal.
`IDLE_ALIVE_NOT_DEAD` and a missing/`None` reason are NOT. A `None` reason means the field was
written by a path that does not yet stamp provenance — treat it as **unknown** and run the
counter-delta, never as dead. (Live-verified within minutes of shipping: endpoint `:11513` read
`decode_live=False` with `probe_reason=None`, and the counter-delta proved **IDLE-ALIVE**.)

Backup of the pre-patch adapter: `/usr/local/bin/frankenstein_tools_adapter.py.bak-provenance-*`.

## Banned claims (each is a rule violation)

- "The ring is decode-dead" / "the box is down" / "tok_s=0 so it's dead" citing only a health
  file, dashboard, canary snapshot, or `error_watchdog`.
- Any recommendation to cycle / restart / quarantine / relaunch an LLM host without a pasted
  counter-delta showing `delta == 0` AND `running > 0`.
- Treating `fail_streak > 0` as death. A `fail_streak` that never reached quarantine means the
  system deliberately declined to kill the box — trust that, not the counter.
- Treating a `probe_reason` of `None` as confirmation of death.

## Self-check before shipping any fleet claim

1. Am I asserting something is down/dead/stalled? If no → proceed.
2. If yes: did I run the counter-delta **this session**, against **that** endpoint?
3. Is the raw `gen delta` + `running` output pasted in my claim?
4. Does my verdict match the verdict table exactly?

Any "no" → do not ship the claim. Run the probe.

## Cross-references

- Rule 297 — classify the code before you diagnose (read the probe function, not just its output)
- Rule 263 — verify before claim
- Rules 252 / 271 / 280 — live-probe before declaring a host down; no SSH to the box = no claims
- Bug library: **#2221** (false-positive twin), **#2210** (real zombie repair path)
- Rule 156 — `bug_library_check_before_fix` FIRST on any routing/fleet symptom

## Last updated

2026-08-05 — created from the false decode-dead incident. Added the mechanical counter-delta gate,
the verdict table, and documented the `probe_reason` provenance fields shipped the same session.
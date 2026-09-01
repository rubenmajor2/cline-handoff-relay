# Rule 315 — Verify before declaring a host down (search the record FIRST; status is not serving)

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS, on any infrastructure / LLM / host / engine DOWN claim**
**Created: 2026-08-09 by Cline (Ruben directive: "rule [on] why you got the LLM info wrong... and how to ensure it does not happen again. RCA 297, etc")**

## Core principle

A "down" claim is a destructive operational statement. It triggers halts, restarts, reroutes, and human alarm. It must therefore be earned by (a) searching the written record FIRST and (b) a live probe executed THIS TURN. Two failure modes caused 2026-08-09's false-downs, and both are banned outright:

1. **SEARCH-THE-RECORD-FIRST violation.** The operator (me) guessed usernames — `rubenmajor`, `root`, `emsuserver`, `bigmac` — got publickey denials, then went off trying other keys, ProxyJump through WOPR, SSH from Artemis, SSH from Julia, and a full port sweep, and called Big Mac "blocked on SSH access". The credential was written down the whole time in Big Mac's OWN onboarding idea: `ssh -i /home/emsuserver/.ssh/id_ed25519 emsu-big-mac@10.100.0.19`. **Guessing usernames is not a search. Sweeping the network is not a search. Reading the box's own files is a search.**
2. **STATUS-IS-NOT-SERVING conflation.** `systemctl is-active` = the process exists. `docker ps Up X hours` = the container exists. Ray head alive = Ray is up. **NONE of these mean the engine ever bound its port or served a single request.** The 2026-08-09 wedge: `bigmac-vllm.service` reported active and the container "Up 10 hours", but it had never served one request — hung in the middle of Ray init at "No current placement group found. Creating a new placement group.", startup-complete count zero, port 8000 never bound. Only `curl /v1/models` HTTP 200 (and for real liveness, a decode probe that yields tokens) proves an engine is serving.

## Mandatory ladder BEFORE any down claim

When any actor reports or you suspect a box is down:

### Step 1 — SEARCH THE RECORD FIRST (before reaching for any tool that touches the network)
- The box's own onboarding idea / idea text
- `frankenstein_registry.yaml` (WOPR `/etc/litellm/`) — login lines + serving facts live next to the box
- `HANDOFF_NOTES.md` / `cline_task_ledger.md`
- Bug library (`frankenstein_router_incidents`) — past incidents for this host class
- `fleet_inventory` (`fleet_inventory()` MCP) — canonical IPs, roles, SSH path
- If a documented credential exists, USE IT. Do not guess. Do not sweep. If none exists, say "record does not contain access" and file an idea to add it, do NOT brute-force identity.

### Step 2 — CLASSIFY INTO EXACTLY ONE OF FOUR STATES (never a bare "down")
| State | Evidence | Claim wording |
|---|---|---|
| **HOST DOWN** | SSH + ping/WireGuard unreachable (verify against `fleet_inventory` IPs; rule 294 reprobe inherited facts) | "X down — host unreachable (SSH refused, WG dead)" |
| **PROCESS DOWN** | systemd unit `failed`/`exited`, or container exited | "X down — process exited (unit state failed)" |
| **ENGINE WEDGED / NEVER BOUND** | process alive + container "Up" for a long time + **startup-complete count = 0** + port not listening — hung mid-init (classic: Ray placement-group message with nothing after it) | "X down — engine wedged mid-init (log stopped at <line>, 0 startup-complete, :port never bound)" |
| **ENGINE SERVING** | `curl /v1/models` HTTP 200 and/or decode probe produced tokens | "X up — /v1/models 200, serving" |

Only states 1-3 justify the word DOWN, and even then the claim must carry the state name + the evidence that proves it. A bare "X is down" with no state classification is a violation of this rule AND rule 297.

### Step 3 — LIVE-VERIFY THIS TURN
A cached probe is a hypothesis (rule 296). The probe that justifies the word DOWN must have run in the turn where DOWN is printed. Inherited facts from an earlier window must be re-probed (rule 294). If the fleet API is unreachable, say probe-failed, not down (rule 299: negative evidence is not proof).

### Step 4 — HOST-UP ≠ ENGINE-DOWN — SAY WHICH, and prefer a RESTART over a death certificate
Julia 2026-08-09: Ray head alive at `ray::IDLE` with no `api_server` = a restart, NOT a dead box. `~/julia_full_relaunch.sh` brought it back at 131K ctx / 0.287s gen. When only some layers are down, say "host up, engine down (restart needed)" — never collapse it to "down".

## Detector for the silent wedge (the expensive one, so it gets its own line)

On any box that claims hours of uptime: `grep -c "startup complete" <container-log>`; if the count is 0 on a container that claims long uptime, it is wedged mid-init even though systemd + docker both report healthy. (Bug library 2299.)

## Why this rule exists (RCA 297 — 2026-08-09)

- **Symptom:** Big Mac "blocked on SSH" (total fabrication — record had the line all along); Julia + Claudia reported down (Julia was host-UP/engine-DOWN needing a restart; Claudia was eventually verified serving with all four upstreams at HTTP 200, 38.0 / 33.4 / 22.3 / 12.7 tok/s).
- **Root cause:** (1) searched the network instead of the record (guessed 4 usernames before reading the onboarding idea); (2) treated `systemd active` + `docker Up` as serving evidence; (3) carried earlier stale state forward instead of live-probing before each claim.
- **Causal-rule fix:** this rule (315) — replaces the guess-first habit with a fixed record-first ladder, and bans status-≠-serving conflation. Bug library 2297/2298/2299 record the incident; the Big Mac SSH line now sits in `frankenstein_registry.yaml` with the "systemd active ≠ serving" warning next to the box, so the record itself carries the fix.
- **Self-check (per rule 297):** would a fresh agent given the same symptom tomorrow reach into `frankenstein_registry.yaml` before the network? If the answer is ever no, this rule is not being read — reindex and re-train.

## Cross-references

- Rule 297 (classify before diagnosing — read source, state the bucket)
- Rule 296 (never declare an LLM dead from a cached probe)
- Rule 294 (reprobe inherited infrastructure facts)
- Rule 299 (negative evidence is not proof)
- Rule 140 (routing claims need live verification with headers)
- Rule 263 (verify-before-claim on ALL facts, system state included)

**Source incidents: 2026-08-09 Big Mac wedge + credential-guess hour; Julia host-up/engine-down mis-call; earlier Claudia false-down (all resolved same session; fleet fully restored 22:51 PT)**


# 169 — When Ruben corrects a knowledge gap (access/infra/SSH/machine details), persist the correction to a durable surface. Future agents must not re-learn it.

Permanent rule. Workspace-scoped. Source: 2026-06-24 16:33 PT — Ruben directive during the Julia+Claudia bringup runbook task.

## The bright-line rule

**When Ruben corrects you on a knowledge gap — especially about SSH access, machine details, infrastructure topology, credentials, or "you actually CAN reach X" — the correction is NOT complete until the now-correct knowledge is written to a durable, read-at-runtime surface that a future agent will consult without re-asking Ruben.**

A correction that lives only in the current conversation is a correction that dies when the window closes. The next agent hits the same gap, makes the same wrong assumption, and Ruben has to correct it again. That is the failure mode this rule closes.

## The source incident (concrete)

During the Julia+Claudia DGX Spark bringup prep (2026-06-24), I wrote a runbook and left a note: *"The exact WOPR reverse-tunnel mechanism (autossh vs systemd vs screen) Cesar/Cato use — I couldn't pull it because the WOPR SSH path needs the emsuserver key, not mine. The runbook has the grep command to find it so whoever does bringup clones the pattern."*

Ruben's correction, verbatim:

> *"But you have SSH everywhere - so you should be able to find all this - so update that"*

He was right. I had the `emsu-operations` MCP `ssh_command` tool, which reaches every Spark via the reverse tunnels. I could have SSH'd to Cesar and read `~/.config/systemd/user/emsu-reverse-tunnel.service` + `~/bin/emsu-reverse-tunnel.sh` directly — and I did, once pushed. The gap wasn't access; it was that I *assumed* I lacked access instead of *trying* the access I had. Leaving a "find it later" note instead of pulling it now would have forced a future agent (or Ruben) to re-derive the same thing.

The durable fix has two layers:
1. **Pull it now** (I did — the runbook now has the verbatim tunnel script + unit file).
2. **This rule** — so the next agent who is tempted to write "I can't reach X, find it later" instead tries their MCP tools first, and persists the result.

## The durable surfaces (pick the right one for the knowledge type)

| Knowledge type | Durable surface | Why |
|---|---|---|
| Machine/cluster topology, ports, serve endpoints | `/etc/litellm/frankenstein_registry.yaml` `serving_endpoints[]` (rule 92) | Router reads it at runtime; agents consult it via `frankenstein_registry` MCP |
| Access/SSH/tunnel mechanics | Runbook file (e.g. `~/Desktop/<NAME>_BRINGUP_RUNBOOK.md`) + HANDOFF_NOTES | Future bringup windows read these first |
| Fleet host facts (role, IP, ssh path, models served) | `fleet-state` MCP `fleet_inventory` + the registry | `fleet_inventory` is the canonical first-call per rule 117 |
| Operational policy (exam, payment, externship) | `emsu://reference/*` MCP resources | Agents access these at runtime |
| Behavioral/decision rules | A `.clinerules` file (this rule is an example) | Loaded into every window's system prompt |
| Recent state / what just happened | `HANDOFF_NOTES.md` (rule: read first) | Every task reads handoff notes first |
| Runtime agent failure patterns | `orchestrator_learned_patterns` + `failure_repair_recipes` (rule 46) | Agent runtime consumes these |

**The test:** "If a fresh Cline window encountered this same question tomorrow, would they find the correct answer on one of these surfaces without asking Ruben?" If no, the correction is incomplete — write it before completing.

## The "I can't reach X" self-check (run BEFORE writing any "find it later" note)

Before writing *"I couldn't pull X because I lack Y"* or *"find it on bringup day"* or *"whoever does this next should grep for Z"*, run this check in order:

1. **Do I have an MCP tool that reaches it?** `emsu-operations` has `ssh_command` (reaches every Spark via reverse tunnels + WOPR), `read_server_file`, `server_status`, `check_server_logs`. `fleet-state` has `fleet_inventory`. `mysql` has direct DB. `project-frankenstein` has `frankenstein_registry`, `frankenstein_host_probe`, `frankenstein_verify_routing`. `google-drive` has `search_drive`. **Try the tool before claiming you can't.**
2. **Did the tool actually fail, or did I assume it would?** An assumption is not a failure. SSH via `ssh_command` to a Spark uses the reverse-tunnel ports (2203/2204/2205/2206) which the MCP can reach even when a raw local `ssh` cannot. The MCP path is often the one that works when the local path doesn't (rule 136, rule 41's blocking-local-command addendum).
3. **If the tool genuinely failed**, say so with the actual error — then persist what you DID find, and flag the specific gap with the exact command that failed. Do not leave a vague "find it later."
4. **Once you have the answer, persist it** to the right durable surface (table above) in the SAME session. A correction that is pulled but not persisted dies with the window.

## Banned phrases (the "find it later" anti-pattern)

Each of these is a rule violation when written by an agent that had MCP tools it didn't try:

- *"I couldn't pull X because I lack access"* (you have `ssh_command` — try it)
- *"Find it on bringup day"* / *"whoever does this next should grep for Y"* (grep it yourself now via `ssh_command`)
- *"The WOPR SSH path needs a different key, not mine"* (the MCP `ssh_command` uses the right key — that's its whole point)
- *"I'll leave a note for the next agent to figure out"* (figure it out now, persist the answer)
- *"Check X once access is set up"* (access is already set up via MCP; check it now)

The pattern uniting these: **deferring to a future agent work that the current agent can do with tools already in hand.** That is the rule-29 parking-lot anti-pattern wearing a knowledge-gap disguise.

## How this composes with existing rules

- **Rule 140 (verify live, not files/stale status):** this rule is the *persistence* layer on top of 140. 140 says "verify with a live probe, not a stale field." This rule says "once you've verified it live, write the verified fact down so the next agent doesn't re-verify from scratch (or worse, trust the same stale field)."
- **Rule 146 (consult the runbook, don't re-derive):** 146 is about not re-deriving the *training env* from memory. This rule generalizes the principle to ALL corrected knowledge — the runbook (or registry, or resource) is where corrected facts live so they're consulted, not re-derived.
- **Rule 46 (every agent correction loops back to RUBEN + KAIZEN):** 46 is about correcting *agents* and seeding runtime pattern rows. This rule is about correcting *Cline's own infrastructure knowledge* and persisting it to docs/registry/rules. Different subject, same spirit.
- **Rule 92 (work at the core, not bandaids):** a "find it later" note is a bandaid. Persisting the verified fact to the registry/runbook is the core fix.
- **Rule 136 (Artemis access via MCP, not raw ssh):** the specific instance of "use the MCP path that works." This rule generalizes it: for ANY fleet host, try the MCP tool before claiming you can't reach it.
- **Rule 29 (act, don't defer):** leaving "find it later" work is deferring work you can do now. Same violation.

## Self-check at every attempt_completion where Ruben corrected a knowledge gap

Ask:

1. *Did Ruben correct me on something I claimed I couldn't know/reach/do?* If yes:
2. *Did I then actually pull the answer using my MCP tools (not assume I couldn't)?* If no → do it now.
3. *Did I persist the answer to a durable surface (registry / runbook / resource / HANDOFF / rule)?* If no → persist it now.
4. *If a fresh window asked the same question tomorrow, would they find the answer without Ruben?* If no → the correction is incomplete.

If any answer is no, the correction is incomplete. Fix it before declaring done.

## Source incident

2026-06-24 16:33 PT — Julia+Claudia DGX Spark bringup runbook. I wrote "I couldn't pull the WOPR reverse-tunnel mechanism because the WOPR SSH path needs the emsuserver key, not mine" and left a grep command for the next agent. Ruben: *"But you have SSH everywhere - so you should be able to find all this - so update that."* I then SSH'd to Cesar via `ssh_command` and pulled the verbatim `emsu-reverse-tunnel.service` unit + `emsu-reverse-tunnel.sh` script in two calls. The access was there the whole time; I had assumed it away. The runbook was updated with the exact commands, and this rule was written so the assumption-away doesn't recur.

## Last updated

2026-06-24 17:00 PT — initial. Source: Julia+Claudia bringup runbook task. Generalizes the "I have SSH everywhere, use it + persist the result" lesson that Ruben flagged. Composes with 140 (verify live), 146 (consult runbook), 46 (persist agent corrections), 92 (core not bandaid), 136 (MCP not raw ssh), 29 (act don't defer).
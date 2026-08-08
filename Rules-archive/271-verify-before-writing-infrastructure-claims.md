# 271 — Verify before writing: no unverified infrastructure claims in durable surfaces

Permanent rule. Workspace-scoped. Source: 2026-07-11 Ruben directive — stale claims about Julia ("needs physical reboot," "frozen from TP=1") were written to HANDOFF_NOTES and a pickup prompt WITHOUT any live SSH verification. The box was never frozen (16 days uptime, idle). Existing rules 248/252/263 say "verify before claiming" but agents keep disregarding them because they are advisory, not mechanical. This rule adds the mechanical gate.

## The bright-line rule

**Before writing ANY infrastructure state claim to a durable surface (HANDOFF_NOTES, pickup prompt, runbook, ticket, ops chat), you MUST have a tool result from THIS SESSION that verifies the claim.** "Durable surface" means anything that persists beyond the current turn: HANDOFF_NOTES.md, pickup prompts, FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md, fleet inventory notes, ticket comments, iMessage.

An "infrastructure state claim" is any of:
- "Box X is down/dead/frozen/unreachable"
- "Box X needs physical reboot"
- "Service Y is not running"
- "Script Z does not exist"
- "Port P is not listening"
- "TP=N caused a freeze/crash"
- "The box is in state S" (frozen, saturated, hung, OOM)

## The mechanical gate (run BEFORE update_handoff_notes / write_to_file / attempt_completion)

**Scan your pending write for infrastructure state claims. For EACH claim, ask: "Did I run a tool THIS SESSION that verified this?"**

| Claim type | Required verification tool (run FIRST) |
|---|---|
| "Box is down/frozen/dead" | `ssh_command` to the box: `uptime`, `ps aux`, `nvidia-smi` |
| "Box needs physical reboot" | `ssh_command` to the box: `uptime` (if uptime > 1h, it does NOT need reboot) |
| "Service is not running" | `ssh_command` to the box: `pgrep -f <service>`, `systemctl is-active` |
| "Script does not exist" | `ssh_command` to the box: `ls -la <path>` |
| "Port is not listening" | `ssh_command` to the box: `ss -tlnp | grep :<port>` or `curl` |
| "TP=N caused freeze/crash" | `ssh_command` to the box: check `dmesg`, `uptime`, process state |

**If you CANNOT point to a tool result in this session that verifies the claim → you MUST either (a) run the verification tool NOW, or (b) remove the claim from the write.** There is no option (c) "write it anyway."

## The "no SSH = no claim" sub-rule

**If you have not SSH'd to the box in this session, you CANNOT make ANY claim about that box's state.** Not "it's down," not "it's frozen," not "it needs reboot," not "the script doesn't exist." Zero SSH = zero claims. This is the mechanical enforcement that rules 248/252/263 lack — they say "verify" but don't make the verification a prerequisite for the write.

## The pickup-prompt infection vector

Pickup prompts are the #1 vector for stale-info propagation. An unverified claim written into a pickup prompt becomes the NEXT window's starting assumption. The next window trusts it, repeats it, and may act on it (e.g., telling Ruben a box needs physical reboot when it doesn't).

**Before writing a pickup prompt, scan every infrastructure claim in it.** For each:
1. Did I verify this with a tool THIS SESSION?
2. If no → verify now or remove it.
3. If the claim is about a box state → did I SSH to that box? If no → remove the claim.

## Why existing rules weren't enough

| Rule | What it says | Why it gets disregarded |
|---|---|---|
| 248 | "Verify live state before declaring box down" | Advisory. No mechanical gate before the write. Agent reads the rule, agrees, then writes "Julia needs reboot" to HANDOFF_NOTES anyway because nothing blocks the write. |
| 252 | "Probe first, report second" | Advisory. Says to probe but doesn't block the report if the probe wasn't done. |
| 263 | "Verify before claim" | Advisory. Covers factual claims broadly but doesn't specifically gate the write to durable surfaces. |

**This rule closes the gap:** the verification is a PREREQUISITE for the write, not a recommendation. No verification tool result = no write. The agent must either run the tool or remove the claim.

## The self-check (run BEFORE any write to a durable surface)

1. *Does my pending write contain any infrastructure state claims?* (box down, needs reboot, service not running, script missing, port closed, TP caused crash)
2. *For EACH claim — did I run a tool THIS SESSION that verified it?*
3. *If no → run the verification tool NOW, or remove the claim from the write.*
4. *Am I writing a pickup prompt? → scan every infrastructure claim in it with the same gate.*
5. *Am I about to write "box X needs physical reboot"? → did I SSH to box X and check `uptime`? If no → STOP. You cannot claim a box needs reboot without verifying it's actually unresponsive.*

## Anti-patterns that violate this rule

- Writing "Julia needs physical reboot" to HANDOFF_NOTES without SSH-ing to Julia to check `uptime`
- Writing "the serve script doesn't exist" without `ls -la <path>` on the box
- Writing "TP=1 froze the box" without checking `dmesg`, `uptime`, or process state on the box
- Carrying forward a prior window's infrastructure claim into a new pickup prompt without re-verifying
- Writing "box is down" based on a failed WOPR tunnel probe (tunnels lie — rule 248) without SSH-ing to the box directly
- Writing infrastructure claims to a runbook based on a single session's experience without verification
- **INSTRUMENT MISMATCH (added 2026-08-08):** citing a systemd unit state on host A as evidence about a service that actually runs on host B. `systemctl is-active gptoss-tp2-julia` on WOPR returns `inactive` **by design** — that unit is disabled and Julia's vLLM is launched by cron ON JULIA (`*/2 * * * * tp2_watchdog.sh`, `@reboot julia_unified_tp2.sh`). The WOPR unit is not the instrument for that question and never was.

## The instrument gate (added 2026-08-08)

Before citing ANY status output as evidence, ask: **"Does this instrument actually observe the thing I am claiming about?"** Name the host the process runs on, then name the host you queried. If they differ, you are holding the wrong instrument and the reading is meaningless regardless of what it says.

Mechanical: for a claim about service S,
1. Where does S actually execute? (`ps -eo args` ON that box, or the registry `serves_via` / `ssh_access` fields)
2. Did I query THAT box, or a proxy/tunnel/registry/systemd-unit on a different box?
3. A tunnel listener (`sshd` holding :NNNNN) is NOT the service. `ss -ltnp` showing `sshd` on the port means the tunnel is up and the far end is dead — that is a DIFFERENT claim from "the service is down", and it points at a different box to go fix.


## Cross-references

- Rule 248 — verify live state before declaring box down (this rule makes 248 mechanical: no write without verification)
- Rule 252 — stale-info live-probe gate (this rule makes 252 mechanical: no report without probe)
- Rule 263 — verify before claim (this rule makes 263 mechanical for infrastructure claims specifically)
- Rule 144 — no write_to_file on server paths (use ssh_command for server file edits)
- Rule 91 — pickup prompt shape (pickup prompts are the #1 infection vector for stale claims)
- Rule 29 — act, don't defer (verifying IS the act, not an optional step)
- Rule 169 — persist corrected knowledge to durable surfaces (but only AFTER verification)

## Source incident

2026-07-11 07:18 PT — A Cline session wrote to HANDOFF_NOTES.md: "Julia FROZEN from TP=1 vLLM launch (CPU saturation, SSH timeout from WOPR + Claudia RoCE). Needs PHYSICAL REBOOT." and "julia_serve_v1_lora_cg_65k.sh doesn't exist." Neither claim was verified with SSH. At 09:04 PT, a subsequent session SSH'd to Julia and found: 16 days uptime, 0% GPU util, load avg 0.02, no vLLM processes running, serve script EXISTS at the expected path. The box was never frozen. The stale claims also propagated to FRANKENSTEIN_FAST_TRAIN_RUNBOOK.md (lines 69, 73-74, 86-87) and the task pickup prompt. Ruben: "The stale information needs to be RCA tracked down and reliable information needs to be put in place. I already have rules on this process but for some reason they keep getting disregarded by cline agent. This needs to be bulletproof for even the simplest minded agent."

## Last updated

2026-07-11 — initial. Created per Ruben directive to make verify-before-claim mechanically enforced, not advisory.

2026-08-08 — added the INSTRUMENT GATE. Source incident: an agent reported "julia/claudia :11513 TP=2 cluster services are inactive" in a completion, citing `systemctl is-active gptoss-tp2-julia` on WOPR. That unit is `disabled` by design; Julia's vLLM is cron-launched ON Julia. The reading was real but the instrument did not observe the subject. The cluster WAS in fact down (separate, genuine failure: split-brain Ray, watchdog at MAX_RESTARTS since 14:04 PT), so the conclusion happened to be right for the wrong reason — which is worse than being wrong, because it validates a broken method. Being accidentally correct is not verification. Bug library #2274/#2275.


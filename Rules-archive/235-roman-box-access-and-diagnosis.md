# 148 — Roman/Spark box access + diagnosis: you HAVE direct SSH; check the box (nvidia-smi + container state) BEFORE declaring it dead or killing anything

Source: 2026-06-12 W5 session. Ruben, repeatedly: "I'm on the same network as the Romans, if I have SSH so do you... you need to have full knowledge of where stuff is so you don't make bad decisions and try to kill things that aren't broken." Cline twice mis-diagnosed Cesar from WOPR-side probes (called it "dead" / tried to drop healthy things) instead of SSHing to the box to see the truth.

## The bright-line rule

**You have DIRECT SSH to every Roman/Spark box. Before declaring a Roman "down" or killing/dropping anything, SSH to the box and read its real state (`nvidia-smi` + `docker ps` + the vLLM port). A WOPR-side `curl 127.0.0.1:11506` returning 000 is a SYMPTOM, never the diagnosis.**

### The boxes + how to reach them (from Ruben's Mac)

| Box | Host | vLLM port (on box) | WOPR tunnel | LiteLLM model id |
|---|---|---|---|---|
| Cesar | `ssh cesar` (spark-3b41, via WOPR :2203) | :8000 | :11506→:8000 | cesar-120b |
| Cato | `ssh cato` (spark-2aa8, via WOPR :2204) | :8000 | :11507→:8000 | cato-120b |
| 405B head | spark-e3b2 192.168.1.244 | :11512 | | frankenstein-405b |
| Artemis | 10.100.0.5 (WireGuard) | :11434 ollama | | artemis-* |

The canonical source for this map is the **memory graph** (entities `Cesar (spark-3b41)`, `Cato (spark-2aa8)`, etc.) and the **fleet-state MCP `fleet_inventory`**. Call those FIRST when you need a box's location/access — don't re-derive from grep.

## The diagnosis order (mandatory before any "the box is down" claim or kill)

1. **SSH to the box.** `ssh cesar 'hostname'` — confirms you can reach it.
2. **Read the GPU:** `nvidia-smi --query-compute-apps=pid,used_memory,process_name --format=csv` + `nvidia-smi --query-gpu=memory.used,temperature.gpu,utilization.gpu --format=csv,noheader`. This shows WHAT holds the GPU.
3. **Read the container:** `docker ps -a --format '{{.Names}} {{.Status}}'` + `docker inspect <name> --format 'RestartCount={{.RestartCount}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}}'`. A high RestartCount = crash-loop.
4. **Test the real port:** `curl 127.0.0.1:8000/v1/models` ON the box.
5. **Only now** do you know whether the box is genuinely down, crash-looping, GPU-starved, or fine.

## Do NOT kill what isn't broken

- A WOPR-side 000 does NOT mean the box's vLLM is dead — it can be the reverse tunnel, or vLLM mid-load, or a GPU conflict. SSH and check (steps above) before killing/dropping.
- LiteLLM serving a `cesar-120b` request 200 does NOT mean Cesar is up — it may be a Cato fallback (rule 147 picked-vs-served). Check the served api-base header.
- Before `kill`/`docker stop`/dropping a member: confirm via steps 2-4 that the thing is actually broken AND that stopping it won't take down a healthy serve.

## The known Roman failure mode (rule 146 says one box never stops Frankenstein — this is WHY a box dies)

**ollama + vLLM GPU conflict on a GB10:** if a Roman runs BOTH ollama and vLLM, ollama loading a big model (70b ≈ 45GB) starves the unified memory the vLLM 120B needs → vLLM OOM-exits on load → docker `--restart unless-stopped` crash-loops it (seen: RestartCount=108) → the box's :8000 returns 000. Detection: `nvidia-smi` shows an ollama `llama-server` holding tens of GB while the `gptoss` container has a high RestartCount. Durable fix (idea #11977): don't co-run ollama + vLLM on the 120B Romans; or cap ollama keep_alive. See memory entity `Frankenstein ollama-vLLM GPU conflict`.

## Sudo caveat

Cline does NOT have passwordless sudo on the Roman boxes. Killing a root-owned stuck process (e.g. ollama llama-server) or `systemctl restart ollama` needs Ruben. When blocked on that, stop the part you CAN (e.g. `docker stop` the crash-loop to stop GPU thrashing), write the exact root-fix commands to a note on the box, and put them in the pickup prompt — do not pretend it's fixed.

## What "self-heal going forward" looks like (the durable answer to Ruben's "is this automatic?")

The WOPR-side self-heal daemon (`emsu-frank-member-rotation.py`) auto-drops a 000/dead member from the fallback chains and auto-re-adds it on recovery (rule-140 served-header check, fixed 2026-06-12). But it canNOT fix an ON-BOX crash-loop or kill a root process. The complete self-heal needs an **on-Roman watchdog** (idea to file) that: detects the ollama/vLLM GPU conflict (nvidia-smi + RestartCount), frees the GPU, and relaunches vLLM — running as a box-local systemd service with the privileges to do so. Until that exists, the on-box repair is a human (sudo) step surfaced in the pickup prompt.

## Cross-references

- Rule 146 — frankenstein-llm routes the whole fleet; one box down never stops it
- Rule 147 — llm_router_live shows PICKED not SERVED (verify served via header)
- Rule 141 — call the project-frankenstein MCP first for architecture truth
- Rule 136 — Artemis Arc box access via the emsu-operations MCP ssh_command
- fleet-state MCP `fleet_inventory` + memory entities `Cesar (spark-3b41)` / `Cato (spark-2aa8)` — the canonical box map
- idea #11977 — durable fix: stop co-running ollama + vLLM on the Romans

## Last updated

2026-06-12 — initial. Source: Cline mis-diagnosed Cesar from WOPR probes twice; Ruben: "you have SSH, check the box, don't kill things that aren't broken, and put this somewhere you read it instantly."

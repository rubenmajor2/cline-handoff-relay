# 166 — A proxy signal (error text, probe, config file, log table, status page, sibling-window note) is a HYPOTHESIS, not ground truth. Verify live before you state it or act on it.

Permanent rule. Workspace-scoped. Source: 2026-06-20 — Ruben, after a window mis-diagnosed `Invalid JSON argument` as "WOPR tunnel wedged" (rule 165): *"Anything else like this validating false information we need to be looking at?"* Yes — it is a whole class. This rule catalogs the known false-validation traps and the one discipline that defeats all of them.

## The class (the thing to recognize)

An agent reads a SIGNAL that *stands in for* reality — an error string, a health probe, a config line, a log/DB row, a status dashboard, a note another window wrote — and treats it as if it WERE reality. The signal is stale, narrow, mislabeled, or measuring the wrong thing, so the agent confidently states (or acts on) a false fact. The cure is never "be more careful"; it is a hard habit: **the signal is a hypothesis; confirm it against the live system before you speak or act.**

## The known traps (each really happened — do not re-fall for them)

| Proxy signal | False conclusion it produced | Ground truth | Verify with |
|---|---|---|---|
| `Invalid JSON argument` MCP error | "WOPR tunnel wedged" | tunnel fine; command-shape bad | rule 165: `echo OK && uptime` |
| Health probe `/v1/models` HTTP 0 / "Connection refused" | "the box / 405B / Joshua is DOWN" | box serving live (router audit shows `picked=X`) | rule 140/146: `/tmp/emsu_router_audit.log` recent `picked=`, live header probe |
| `host_gen_probe` 8-token tok/s | "Artemis is slow / 22 tok/s" | ~2x higher sustained (44-55) | run a 200-token completion, divide tokens/time |
| `cato :11507` HTTP 000 / canary "down" | "Cato is down, fix it" | BY DESIGN — TP=2 Ray worker (rule 157) | registry `cluster_topology`; never probe/restart |
| `admin_portal.llm_call_log` spend | "frankenstein-llm cost $12" | real ~$700; gateway spend not logged there | rule 158 D1: `/tmp/emsu_router_audit.log` + live cost header |
| `fleet_inventory` free-text note ("M4 = 16GB, excluded by design") | repeated as hardware fact | WRONG (64GB) — a sibling window's guess stamped as durable metadata | rule 146: hardware specs only true from a LIVE probe or from Ruben |
| registry/`PROJECT_FRANKENSTEIN.md` documents ladder X | "the spill ladder is X" | code path skips members; doc is a hypothesis | rule 158 D4 / rule 140: confirm the live spill function + audit log |
| stale subagent doc-scrape ("reconstructed from Desktop files, MCP unavailable") | repeated as current state | a reconstruction, not live state | rule 141: call the MCP / live-probe load-bearing claims |
| bug-library read returns "#PAGER set to stdout" / "undefined" | "novel symptom, no prior fix" | a read-layer bug poisoned the result | check the MCP read path before trusting an empty/garbage result |

## The universal discipline (run before stating OR acting on any proxy signal)

1. **Read the LITERAL signal.** What exactly does the error/probe/row/note say? (Not what you assume it implies.)
2. **Ask: is this signal a stand-in, or the thing itself?** An error STRING, a /v1/models GET, a config line, a log row, another window's note — all stand-ins. The thing itself is: what the live system does RIGHT NOW when you exercise it end-to-end.
3. **Confirm the load-bearing claim live.** The cheapest real check:
   - "X is down/up?" → live request + response header (rule 140), or recent `picked=X` in the router audit log (rule 146), not a `/v1/models` GET.
   - "X is slow?" → a real sustained generation, not an 8-token probe.
   - "spend was $N?" → the authoritative meter (router audit / LiteLLM SpendLogs), not `llm_call_log`.
   - "the tunnel is wedged?" → a trivial `echo OK && uptime` (rule 165).
   - "the hardware is Y / excluded by design?" → a live probe or Ruben's word, never a sibling note (rule 146).
   - "the code does X?" → read/exercise the live code path, not the doc that describes it (rule 158 D4).
4. **Only then state it or act.** If you cannot verify live, SAY SO explicitly ("unverified, signal-only") rather than asserting it as fact. An unverified proxy claim presented as truth is the violation.

## Ruben's correction OVERRIDES a stored note on the FIRST turn (rule 146 generalized)

If Ruben states a fact that contradicts a stored note/config/doc, RUBEN WINS immediately. Stop re-citing the note, correct the data at its source, and act. Re-asserting a contradicted stored signal is both a rule-140 violation (signal = hypothesis) and a rule-29 violation (arguing instead of acting).

## Self-check before any "X is down / slow / costs $N / is by-design / the doc says" statement

1. *Is my source a proxy signal (error/probe/config/log/note) or the live system itself?*
2. *Did I confirm the load-bearing claim with a live exercise (header probe / audit row / real generation / echo), not just the proxy?*
3. *Am I about to write a confident fact I only have signal-level evidence for?* → Verify, or label it "unverified."

## Cross-references

- Rule 165 — `Invalid JSON argument` ≠ tunnel wedged (the instance that prompted this consolidation)
- Rule 140 — verify LLM routing from live headers, not file-reads (the canonical "prove it live" rule)
- Rule 141 — call the project-frankenstein MCP first; never declare a box dead from one tunnel probe
- Rule 146 — fleet notes are hypotheses; a probe-fail is "endpoint down," not "box dead"; Ruben's correction overrides a stored note
- Rule 158 D1/D4 — `llm_call_log` doesn't capture gateway spend; registry text ≠ implemented code
- Rule 92 — fix at the core (the discipline, not a one-off correction)
- Rule 29 — act on verified evidence; don't argue a contradicted note

## Source incident

2026-06-20 — rule 165 (`Invalid JSON argument` mis-read as tunnel wedged) was one instance. Ruben asked what else validates false information. The pattern spans error strings, health probes, perf probes, cost tables, config/registry docs, and sibling-window notes — all proxy signals that were trusted over the live system. This rule names the class and makes "verify the load-bearing claim live before stating or acting" the standing habit.

## Last updated

2026-06-20 — initial.
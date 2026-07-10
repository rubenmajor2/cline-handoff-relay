# 104 — Verify Artemis learner-pipeline freshness before starting a non-trivial Cline task

Permanent rule. Workspace-scoped. Source: 2026-05-19 cline_learner_report.php findings — `artemis_freshness=stale` pattern matched **6,915 times** in `admin_portal.orchestrator_learned_patterns` at confidence 0.99, auto_enabled=0. **Loudest signal in the entire learner database** — more matches than every other cline_* pattern combined. This rule converts that signal into a pre-flight check so Cline does not start non-trivial work against a degraded learning loop.

## The bright-line rule

**Before the FIRST non-trivial tool call of any new Cline task, run the freshness self-check below.** If anything trips a stale threshold, do ONE of:

1. Kick the offending launchd job (commands in self-healing section), wait one cycle, re-check, then proceed
2. Tell Ruben in plain text that artemis_freshness=stale, list which leg failed, and ASK before continuing
3. If the user already said "just run it" / "yolo" / equivalent in the same turn, log a one-line WARN to the task and proceed

Never silently proceed on a stale pipeline. The whole point of the 6,915-match signal is that we kept doing exactly that.

## What counts as "non-trivial"

This rule fires for tasks that:
- Touch RUBEN orchestrator (executor, ideas, scanners, KAIZEN)
- Touch student-facing data (Students, tickets, communication_log, payments)
- Write to production (safe_deploy_file, INSERT/UPDATE on admin_portal)
- Span multiple subsystems
- Will close with attempt_completion at the end (anything that needs a Resume Kit)

Skip the check for: single-line edits to local Mac files, status-only questions, mid-conversation continuations where the pipeline was already verified earlier in the thread.

## What "stale" means in numbers

The learning pipeline has three legs. Each has a freshness window:

| Leg | What it does | Stale if mtime > |
|---|---|---|
| `~/Library/LaunchAgents/com.emsu.cline-learner.plist` last run | Mac → Artemis Cline conversation scanner | 4h |
| `/tmp/cline-router-tunnel-health.log` mtime | Mac→Artemis WireGuard + cline-router tunnel | 30 min |
| Mac yolo_learner heartbeat (last entry in `~/Documents/Cline/yolo_learner/patterns.json`) | YOLO trip classifier | 3h |
| `~/Documents/Cline/cline_task_ledger.md` mtime | Local task ledger / open-task surface | 24h (informational only — older than 24h means a quiet day, not stale) |

If ANY of the first three exceed their threshold during business hours (08:00-22:00 PT), the pipeline is stale and this rule fires.

## Detection algorithm (commands to run)

```bash
# Check launchd cline-learner — last run via plist exit history
launchctl list | grep com.emsu.cline-learner || echo "MISSING — launchd job not loaded"

# More specific: when did the python script last log to its log file?
LEARNER_LOG=$(ls -t ~/.ruben-ai/cline_learner_*.log 2>/dev/null | head -1)
if [ -n "$LEARNER_LOG" ]; then
  AGE_HOURS=$(echo "($(date +%s) - $(stat -f %m "$LEARNER_LOG")) / 3600" | bc)
  echo "cline-learner log age: ${AGE_HOURS}h"
fi

# Tunnel healthcheck
if [ -f /tmp/cline-router-tunnel-health.log ]; then
  AGE_MIN=$(echo "($(date +%s) - $(stat -f %m /tmp/cline-router-tunnel-health.log)) / 60" | bc)
  echo "tunnel-health age: ${AGE_MIN}min"
fi

# yolo_learner heartbeat
if [ -f ~/Documents/Cline/yolo_learner/patterns.json ]; then
  AGE_HOURS=$(echo "($(date +%s) - $(stat -f %m ~/Documents/Cline/yolo_learner/patterns.json)) / 3600" | bc)
  echo "yolo_learner age: ${AGE_HOURS}h"
fi
```

Each command returns in <1s. Total wall-clock budget for the check: under 3 seconds.

## Self-healing — which launchd to kick

If a leg is stale:

```bash
# cline-learner stale → kick the plist
launchctl kickstart -k gui/$(id -u)/com.emsu.cline-learner

# tunnel healthcheck stale → kick the tunnel job
launchctl kickstart -k gui/$(id -u)/com.ruben.cline-router-tunnel-healthcheck

# yolo_learner stale → kick the trip scanner
launchctl kickstart -k gui/$(id -u)/com.ruben.cline.yolo-learner
```

Wait 30-60 seconds, re-run the detection commands. If still stale, that's a real outage — surface to Ruben with the specific failure (not just "stale").

## Specifically: when this rule does NOT apply

- Pure Q&A or single-tool-call tasks (rule 17 trivial-exception list applies — these aren't worth the 3s pre-flight)
- The user just told you the pipeline is stale and asked you to work anyway
- Already-checked in this same task (don't re-run the check more than once per task — it's a pre-flight, not a heartbeat)
- Mac just rebooted in the last 10 minutes (launchd jobs haven't had time to catch up yet; wait 10 min or kick them manually)
- The task itself IS fixing the pipeline (don't gate the fix on the thing being broken)

## What goes wrong without this rule

The 6,915-match signal is what happens at scale. Every time Cline starts a task while the learner is stale:

1. Cline doesn't know which patterns RUBEN has been classifying
2. KAIZEN recipe lookups return stale results
3. The yolo_learner doesn't see the new failure mode, so rule 99 doesn't regenerate
4. Idea-counting and "ruben_questions" surfaces lag reality
5. The same problem gets re-solved manually next session

That's the cost. Three seconds of pre-flight prevents hours of re-derivation.

## Self-check before any non-trivial first tool call

Ask: *"Is the learner pipeline fresh?"* If unsure, run the detection block above. If you find yourself about to call a non-trivial tool (RUBEN, MCP, SSH to WOPR, safe_deploy) without having checked, abandon and check first.

## Cross-references

- `.clinerules/16` — yolo threshold + dual-path state.vscdb (this rule is its sibling on the freshness side)
- `.clinerules/89` — Ollama cold-load timeout (related: don't assume the model is warm just because the pipeline is)
- `.clinerules/95` — Cline 30s tool wall + MCP-missing-at-startup (this rule's check is itself a "verify before working" pattern in the same spirit)
- `.clinerules/99` — auto-generated yolo prevention (the rule that goes stale when this rule's pipeline does)

## Last updated

2026-05-19 — initial rule. Source incident: cline_learner_report.php top finding. Filed at status=approved per .clinerules/38 (Ruben-asked = autonomous tier minimum) + .clinerules/93 (Ruben-directed = approved-tier).

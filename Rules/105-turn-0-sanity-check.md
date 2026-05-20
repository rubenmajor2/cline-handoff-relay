# 105 — Turn-0 sanity check: verify session prerequisites BEFORE first non-trivial tool call

Permanent rule. Workspace-scoped. Source: 2026-05-19 cline_learner_report.php — **27% of YOLO trips occur at turn 0** (126/467 cumulative), **54.6% within 2 turns** (255/467). More than half of all YOLO trips on this stack land in the first two turns, and just over a quarter land literally on the first tool call. That's not a model-quality issue. That's a session-prerequisites issue, and it's fixable with a checklist.

## The bright-line rule

**Before the first non-trivial tool call of any session, run the turn-0 sanity check below. If any check fails, STOP and surface the failure to Ruben in plain text.** Do not "degrade and proceed" on turn 0. The whole point of this rule is that turn-0 degradation is exactly what produces the 27% trip rate. Once we're past turn 2 with green checks, normal degrade-and-note rules from .clinerules/95 resume.

## Mandatory turn-0 checks

Run all of these. Each is cheap. Combined budget under 10s on a warm machine — well inside the 30s tool wall.

- **MCP roster present.** Check `<functions>` block of the system prompt at session start. Does it include the MCPs the task will need? Most common task surface = emsu-operations (`cv30BN0mcp0*` or equivalent). If task touches EMSU and the MCP is missing → STOP and recommend window reload per .clinerules/95 line 129 addendum. Do NOT silently fall back to SSH for every operation.

- **call_ollama reachable** (if task is EMSU-policy-flavored per .clinerules/40 v2 + v3). One probe call:
  ```
  call_ollama(model="emsu-qwen2.5-coder:7b-lora", prompt="OK", system="probe")
  ```
  Should return in <20s warm, <60s cold. If timeout at 60s, 7B-LoRA is genuinely down — fall back to Haiku subagent per .clinerules/89 + 40 (NOT silently to inline Sonnet).

- **cline-router tunnel up** (only if the session is going to use router-mediated routing). Quick local probe:
  ```
  curl -sS --max-time 3 http://127.0.0.1:8787/health/readiness
  ```
  Should return `healthy`. If timeout, kick `com.ruben.cline-router-tunnel` per .clinerules/77.

- **Task ID known.** If this is a pickup-from-prior-task or YOLO resume, the task_id is in the system prompt. Confirm it before any append to cline_task_ledger.md per .clinerules/07 (no composite IDs).

- **Rule freshness.** `.clinerules/99` should not be older than 90 minutes during business hours. Stale means the yolo_learner cron hasn't run — see .clinerules/104 (pipeline freshness).

- **maxConsecutiveMistakes setting matches expectation.** Quick check that the runtime budget is what we think it is:
  ```
  sqlite3 "$HOME/Library/Application Support/Code/User/globalStorage/state.vscdb" "SELECT value FROM ItemTable WHERE key='maxConsecutiveMistakes';"
  ```
  Should return 15 (per current cline_settings.json). If 10 or NULL, session is at default — bump it before risky work per .clinerules/16.

- **State.vscdb dual-path** — if the session is on Artemis Remote-SSH, check both Mac AND Artemis state.vscdb files agree on settings (rule 16's dual-path issue).

## What "non-trivial" means

Trivial (skip the check): single-file edit, single read, status query, pure conversation reply.

Non-trivial (run the check):
- Anything that writes to production (safe_deploy, sql_execute, send_email, send_sms)
- Anything that requires MCP tools
- Anything that calls call_ollama or routes through cline-router
- Anything that closes with attempt_completion (real task — needs Resume Kit)
- Anything spanning multiple subsystems
- Verification or backtest tasks per .clinerules/75

If unsure, run the check. The cost of false positive (one extra 10s pre-flight) is much lower than false negative (turn-0 YOLO).

## What to do if a check fails

| Failing check | Action |
|---|---|
| MCP missing | STOP. Recommend Cmd+Shift+P → "Developer: Reload Window". Do not SSH-grind around it. |
| call_ollama timeout | Fall back to Haiku subagent for EMSU lookups. Surface to Ruben that 7B-LoRA is down. |
| cline-router tunnel down | Kick `com.ruben.cline-router-tunnel`. Wait 5s. Re-probe. If still down, .clinerules/77 recovery. |
| task_id unknown for pickup | Ask Ruben for the task ID before any ledger writes |
| .clinerules/99 stale | Trigger yolo_learner manually: `bash ~/Documents/Cline/yolo_learner/run.sh` |
| maxConsecutiveMistakes=10 | Bump to 15 via apply script |
| state.vscdb disagreement | Run `~/Documents/Cline/cline_settings_apply.sh` |

## Self-healing exit

If all checks green, post nothing — proceed silently. If any check failed AND auto-healed, post a one-line WARN in chat: "Turn-0 check: kicked tunnel, all green now." Don't bury this in attempt_completion — surface it before any real work.

## When this rule does NOT apply

- Continuing a task that already passed turn-0 (don't re-check mid-conversation)
- Ruben explicitly says "skip the preflight" / "yolo" / "just run it"
- Task is rule-29 green-tier act-now (single SQL UPDATE on a known row, etc.)
- Already-dispatched per .clinerules/53 (subagent context, not main agent)

## Why turn 0 specifically

Turn 0 is the highest-leverage failure point on the stack because:
1. The MCP roster is decided at session start — if it's wrong, every subsequent call fails
2. Cold-load latency (7B-LoRA, cline-router proxy) is at its worst
3. Mac → Artemis tunnel state is least predictable
4. .clinerules just loaded — Cline hasn't yet been "trained" by mid-task context

Per .clinerules/95 addendum, the 30s tool wall + MCP-missing addendum each catch a slice of this. This rule wraps them into one explicit pre-flight.

## Self-check before any non-trivial first tool call

Ask: *"Did I run the turn-0 sanity check this session?"* If no, do it now. If I'm about to call MCP / SSH / call_ollama / safe_deploy / send_email without having checked, abandon and check first.

## Cross-references

- `.clinerules/16` — yolo threshold + dual-path state.vscdb (this rule checks freshness of those)
- `.clinerules/32` — prefer MCP wrappers over raw SQL/SSH (this rule verifies MCPs are there to be used)
- `.clinerules/40` — Artemis Ollama is analysis baseline (this rule verifies 7B-LoRA reachable)
- `.clinerules/75` — verification tasks default to MCP + subagents + 7B (this rule's check IS a verification)
- `.clinerules/89` — Ollama cold-load timeout (informs the call_ollama probe budget)
- `.clinerules/95` — Cline 30s tool wall + MCP-missing-at-startup addendum (this rule operationalizes it)
- `.clinerules/99` — auto-generated yolo prevention (this rule prevents the trip class)
- `.clinerules/104` — Artemis learner-pipeline freshness (sibling check)

## Last updated

2026-05-19 — initial rule. Source: 27% turn-0 YOLO trip rate from cline_learner_report.php. Filed at status=approved per .clinerules/38 + 93.

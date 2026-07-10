# 65 — When ≥3 simultaneous file/service failures hit, dispatch Opus immediately for root cause

Permanent rule. Workspace-scoped. Source: 2026-05-13 — Ruben directive verbatim:
*"I felt a bit frustrated that you were not investigating this properly here in cline. I think the second you noticed there were 79 files involved, instinct would need to turn to what is the root cause and then that would give us the best playbook for resolution."*

## The bright-line rule

**When any of these signals fire, the NEXT tool call MUST be `use_subagents` with `prompt_N_model="claude-opus-4-7"` for root cause synthesis.**

### The trigger signals (any one = immediate Opus dispatch)

1. **≥3 production failures reported simultaneously** — user says "X is broken, Y is broken, Z is broken" in the same message. Three concurrent failures almost always have one shared root cause. Solo investigation from this thread will miss it.

2. **Multiple files show the same symptom pattern** — N files all have the same class of bug (same truncation, same missing guard, same wrong content). When you see "79 files" or "96 files" or "5 files all broken the same way" — that's a generator-level problem, not an instance-level problem. Stop fixing instances.

3. **A file has changed without explanation** — wrong content, wrong size, no safe-deploy bak, no git commit, no orchestrator log entry. A "ghost write" that can't be attributed is always a systemic issue. Don't investigate solo.

4. **Cross-subsystem failure** — executor broken AND nginx 403s AND zoom routing AND CNA page all at once. These subsystems don't fail together by accident. One actor touched multiple things.

5. **"This is always happening"** — user says this isn't the first time. That means there's a pattern. Patterns need Opus cross-system synthesis, not another one-off fix.

## What to dispatch (canonical Opus root cause pattern)

```
Dispatching Opus 4.7 for prompt 1 (cross-system root cause synthesis across all failure vectors),
Haiku 4.5 for prompt 2 (check file timestamps + bak files for each affected file),
Haiku 4.5 for prompt 3 (check cron logs + orchestrator_execution_log for agent activity in the window),
Haiku 4.5 for prompt 4 (check nginx error/access logs + auth log for any external vectors).
```

Opus synthesizes across all 4 returns and identifies the single most likely common cause with evidence to confirm it.

## Why this rule exists (the May 13 incident)

On 2026-05-13 Ruben reported 6 simultaneous failures (Zoom routing, executor 500, reports.php 403, 79-site 403s, CNA page, instructor_resources). The investigation took ~30 minutes of serial SSH forensics before identifying the root cause (cron_ruben_implement.php file_put_contents without safe-deploy CAS). 

The correct first move would have been: see "6 simultaneous failures" → immediately dispatch 4-subagent Opus root cause fan-out → Opus synthesizes the Birth timestamp pattern + bak file evidence + executor log → root cause identified in 5-7 minutes instead of 30.

The "79 files" signal in particular was visible early. That number alone screams "generator-level problem, not instance-level." A generator-level problem needs Opus synthesizing across nginx logs + executor logs + file system evidence simultaneously — not serial grep commands.

## Self-check before any forensics tool call

Ask: *"Am I seeing ≥3 concurrent failures OR a repeated pattern across N files?"*

If yes → my next tool call MUST be `use_subagents` with Opus on prompt 1. Not a single SSH grep. Not reading one log file. Fan-out first, synthesize, THEN execute targeted fixes.

## What NOT to do

- Start grepping one file at a time when 6 things are broken simultaneously
- Fix instance-level bugs (this _view_ file, that routes file) before finding the generator
- Read nginx logs without simultaneously checking executor logs and file timestamps
- Spend 5 turns on "what's in the cron table" before dispatching Opus to synthesize all signals

## The playbook once Opus identifies root cause

1. **Block the attack vector first** — kill switch / sentinel / config gate before any repair
2. **Audit blast radius** — how many files? Are other files also affected?
3. **Repair affected files** — restore from bak or re-implement
4. **Build permanent guard** — so it can't happen again
5. **Seed KAIZEN pattern** — so RUBEN learns from it
6. **File proactive ideas** — per .clinerules/42

## Cross-references

- .clinerules/17 — default-on subagent dispatch (this rule is the specific trigger for multi-failure incidents)
- .clinerules/53 — subagent narration + model selection (Opus for cross-system synthesis)
- .clinerules/42 — offer proactive systemic solutions after any incident
- .clinerules/46 — every agent correction loops back to RUBEN + KAIZEN

## Last updated

2026-05-13 — initial rule. Source: Ruben directive after the May 13 morning incident where 6 simultaneous production failures were investigated serially instead of via parallel Opus fan-out. Investigation took ~30 min; should have taken ~7 min with proper subagent dispatch.

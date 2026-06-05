# 137 — Definition-of-Done gate: every build window declares an objective acceptance check FIRST, then loops change→verify→done. No subjective "research enough."

Permanent hardfloor rule. Workspace-scoped. Source: 2026-06-04 — Ruben drove 7 Cline windows building EMSU Team Hub for hours; they went rogue: "they just iterate and research forever." Router forensics: 300 prompts = 119 execute_command + 62 ssh + 11 subagent reads, **0 deploys**. Ruben rejected a read-count cap as a band-aid: "I need something that makes them actually work on the work I need, but not keep recycling." This rule is the durable, research-backed fix.

## Why they recycle (the actual mechanism — fix this, not the symptom)

An autonomous build window loops forever because its stopping condition is **subjective**: "have I read enough? am I sure enough? could one more file matter?" That question has no floor — every extra file *might* hold the missing detail, so a risk-averse policy keeps reading. Reading is also the **safe action**: a read never fails, while a write can break tests/build/render and produce an explicit failure signal. So the agent sits in the read basin because it has no failure mode and no terminating predicate. Capping reads (a band-aid) just cuts the symptom mid-thought without ever answering "is the task done?"

**The cure is to replace the subjective stop with an OBJECTIVE one.** Give the window a concrete pass/fail check it can run. Then "am I sure enough" becomes "does the check pass" — a question with a real answer that terminates the loop.

## The bright-line rule

**No build window may make changes until it has written down its Definition-of-Done: a concrete, runnable acceptance check. Then it runs a tight loop: smallest change → run the check → pass = done, fail = one more change. Research is allowed only in service of the next change, never as the activity itself.**

### Step 1 — Declare the acceptance check BEFORE touching code (mandatory first artifact)

The window's FIRST output on a build task is a Definition-of-Done block, stated as an objective signal it can actually run. For EMSU Team Hub (PHP routes/*.php + JS), valid done-checks are lightweight and concrete:

- `curl -s -o /dev/null -w "%{http_code}" <route>` returns 200 (page renders, no fatal)
- the rendered HTML contains a specific marker (`grep -q 'id="shift-pickup-btn"'` on the curl output)
- no new PHP fatal in the error log after hitting the route (`tail php-fpm log | grep -c "PHP Fatal"` unchanged)
- a specific behavior visible in output (the new column/button/filter appears in the HTML)
- for JS: the bundle loads + the new element/handler is present in the served file

If the window cannot name a runnable check, the task is under-specified — it must ask Ruben for the acceptance criterion, NOT research its way to certainty. "I'll know it when I see it" is the rogue trigger.

### Step 2 — Loop: smallest change → verify → done/next

1. Make the **smallest change** that could move the check from fail→pass (one file, minimal diff). `replace_in_file`/`write_to_file` → `safe_deploy_file` (reloads FPM per rule 42).
2. **Run the acceptance check** (the curl/grep/log command from Step 1). This is the terminating predicate.
3. **Pass** → the unit is DONE. Stop or take the next unit. **Fail** → read ONLY what the failure points at, make the next smallest change, re-run. The failure output tells you exactly what to look at — that replaces open-ended exploration.

### Step 3 — Research is subordinate to the next change, never the activity

You may read a file, but only to make the very next change you've already decided to make. Banned: reading "to understand the codebase better," dispatching subagents "to gather more context," or re-reading a file you've already seen (`[DUPLICATE READ]` = you have it). If you can't say which concrete change your next read enables, you're recycling — stop and make a change against your acceptance check instead.

## Decompose vague goals into claimable, verifiable units (the parallel-window fix)

"Build EMSU Team Hub" is unbounded — that's why 7 windows all circled the same files. A goal with no acceptance criteria has no done-state, so it research-loops by construction. The fix: break it into discrete units, each with its OWN runnable acceptance check, that a window CLAIMS and owns end-to-end:

- Unit = "shift-pickup button renders on team_hub.php and POSTs to the right route" → check: curl shows the button + a test POST returns 200.
- One window owns one unit (its file scope), builds it to green, marks done, takes the next. Windows don't all re-read connecteam_schedules.php independently because each owns a different unit with a different check.

When Ruben (or the orchestrator) launches parallel build windows, each one gets a SCOPED unit + its acceptance check, not the whole vague goal. A window without a unit+check should get one before it starts, not research toward one.

## The self-check (run before every read / cat / ssh / subagent on a build task)

1. *Have I written my Definition-of-Done acceptance check yet?* If no → write it first (or ask Ruben for the criterion). Do not read code yet.
2. *Does this read enable a specific change I've already decided to make?* If no → I'm recycling. Make a change against my check instead.
3. *Have I deployed a change and run my check since the last time I read 3+ files?* If no → stop reading, make the smallest change, run the check.
4. *Did the check just pass?* → DONE. Stop or take the next unit. Don't keep polishing.

## Why this is durable (and the read-cap was not)

A read-cap is arbitrary (why 5? why 20?), brittle to task size, and stops the agent mid-thought in an undefined state. An acceptance check is **derived from the task itself**, scales naturally (small task = quick check, big task = decompose into many checked units), and gives a real terminating predicate. The agent stops because the work is *verifiably done*, not because it ran out of an arbitrary budget. That's the difference between fixing the recycling and clipping it.

## Rogue-window recovery (drop-in directive for a window already circling)

Paste into any window that has researched a lot and deployed nothing:

> STOP. Per .clinerules/137: you have no Definition-of-Done, so you're recycling. Do not read another file or dispatch a subagent. Write your acceptance check now (a runnable curl/grep/log command that is true when this unit works). Then make the smallest change toward it, safe_deploy, and run the check. Pass = done. Fail = fix the one thing the failure points at. Loop change→verify, never read→read.

## How this composes with rule 00

Rule 00 makes `use_subagents` the opening research move to MAP the problem — that's fine as the first shot. This rule governs everything after: once you're building, you operate on Definition-of-Done + change→verify loops, and subagents are not a recurring "read more" habit. Rule 00 starts you; rule 137 makes you converge.

## Source incident

2026-06-04 — 7 windows building EMSU Team Hub for hours, 0 deploys across 300 router prompts despite 119 execute_command + 62 ssh + 11 subagent dispatches; connecteam_schedules.php re-read 18×. Ruben rejected a read-count cap as a band-aid and directed a durable, productive fix. Research (Aider/SWE-agent/OpenHands/test-driven agent loops) converged on the same answer: subjective stop conditions cause infinite research; objective acceptance checks (verification-driven convergence) are the durable cure; scope caps are band-aids.

## Last updated

2026-06-04 — v2 rewrite. Replaced the v1 "≤5 files before first write" cap (Ruben correctly called it a band-aid) with verification-driven convergence: declare a runnable Definition-of-Done first, then loop smallest-change→verify→done. The acceptance check is the terminating predicate that ends research-forever; decomposition into checked units is the parallel-window fix.

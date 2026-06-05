# 142 — Every completion ends with a one-line WINDOW DISPOSITION so Ruben can close-vs-keep at a glance (companion to rule 91)

Permanent rule. Workspace-scoped. Companion/extension to .clinerules/91 (every completion needs a pickup prompt). Source: 2026-06-05 Ruben — "I usually work more recent windows first but then realize I lose older work at times... any cline rule you can make to append to rule 91 to help me on this?"

## The problem this solves

Cline windows are a STACK (newest grabs attention); work is a QUEUE (oldest lane is usually closest to done). So Ruben works newest-first and older near-finished lanes scroll out of sight and rot. Rule 91 gives every completion a PICKUP PROMPT, but a pickup prompt doesn't tell Ruben the ONE thing he needs to triage 20 windows fast: **can I close this window right now, or does it still need a driver?**

## The bright-line rule

**Every `attempt_completion` MUST include a single explicit WINDOW DISPOSITION line, placed immediately BEFORE the `═══ PICKUP PROMPT ═══` block.** It is one of exactly three shapes:

- `WINDOW DISPOSITION: ✅ SAFE TO CLOSE — <why>. Server-side work (if any): <none | what's running + who owns it>.`
- `WINDOW DISPOSITION: ⏳ KEEP OPEN — this lane is still active: <the next action this same window should take>.`
- `WINDOW DISPOSITION: 🔁 HAND OFF — close this window, the work continues in <other window/lane/pod/cron>; nothing is lost because <where the state lives>.`

The line must be literally scannable: the emoji + the 3-word verdict (SAFE TO CLOSE / KEEP OPEN / HAND OFF) is what Ruben reads when triaging a wall of windows.

## What each disposition means

- **✅ SAFE TO CLOSE** — the lane reached a clean stop: a ledger row was written (rule 07), no detached server-side work depends on this window, and the pickup prompt is purely optional/future. Ruben can close it and lose nothing.
- **⏳ KEEP OPEN** — this same window has an immediate next action (waiting on a poll, a gate result imminent, a deploy to verify). Name the action so Ruben knows WHY to keep it.
- **🔁 HAND OFF** — the work moved elsewhere (another window owns it, a pod is training, a cron will pick it up). State WHERE the durable state lives (adapter on disk, pod id, ledger row, idea #) so "close this" never means "lose this."

## The server-side truth clause (always include when relevant)

If the task launched ANY detached/server-side work (RunPod pod, nohup/at/setsid script, cron, training run), the disposition line MUST say so explicitly, because closing the window does NOT stop it. Format: `Server-side: <pod id / script / cron> still running (~$X/hr if billable), owned by <window/babysitter/none>.` This is what prevents the "$27/hr bleeding while I reorganize windows" surprise.

## Self-check before every attempt_completion

1. Did I put a WINDOW DISPOSITION line right before the pickup prompt? If no → add it.
2. Is it one of the three shapes with the scannable emoji+verdict? If no → rewrite.
3. Did this task spawn any pod/detached script/cron? If yes → did I name it + who owns it + $/hr in the disposition? If no → add it.
4. Is the verdict honest? (Don't say SAFE TO CLOSE if a pod is bleeding with no babysitter — that's HAND OFF with a named owner, or KEEP OPEN to clean it up.)

## How this composes with rules 91 + 07 + 141

- **91** — the pickup prompt (the HOW-to-resume). 142 adds the WHETHER-to-close verdict on top.
- **07** — the ledger row IS the "reached a clean stop" signal that justifies ✅ SAFE TO CLOSE.
- **141** — Ruben runs many windows simultaneously by design; 142 is how he prunes them back down without losing anything.
- Tool: `~/Desktop/cline_window_triage.sh` lists every task with age + ledger-status; the disposition line is the per-window version of that same triage.

## Source incident

2026-06-05 — Ruben had 20+ Frankenstein windows open, worked newest-first, and kept losing track of older near-done lanes. He asked for a rule to append to 91. The fix: every completion states, in one scannable line, whether the window is safe to close — turning "20 confusing windows" into "20 windows each telling me close/keep/handoff."

## Last updated

2026-06-05 — initial. Source: Ruben directive to extend rule 91 with a window-disposition aid.

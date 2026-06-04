# 136 — When Ruben asks for "copy windows" / multiple copy prompts: make them run-to-completion AND parallel-safe

Source: 2026-06-03 Ruben directive verbatim: *"Give copy windows to knock this all out right now!! I also don't want to keep having to keep iterating in those windows. I want them to go until completed and ran simultaneously. When I ask for multiple copy windows this will be a cline rule of what I want."*

## The rule

When Ruben asks for "copy windows," "copy prompts," or "prompts to push this," each prompt I produce MUST be:

1. **Run-to-completion (no iteration).** The prompt is written so the receiving Cline window can build, deploy, AND verify the whole piece end-to-end WITHOUT coming back to ask Ruben anything. That means:
   - State the full objective + acceptance criteria + verification step inline.
   - Pre-resolve every artifact the window needs: exact file paths, sha-read instruction, table/column names, course/enrol/ctx constants, cron schedule, the proven repair pattern to mirror. Do NOT make the window "go research what X is" if I already know it — hand it over.
   - Bake in the standing constraints so the window never stops on them: emsu-operations MCP only (never raw local ssh, per .clinerules/29 addendum), `emsu-safe-deploy` for server files, `php -l` before deploy, NO manual FPM (rule 42), audit to orchestrator_event_log with reversal (rule 29), no apologies in student email (rule 02), end with a rule-91 pickup prompt.
   - Tell the window to ACT, not ask: per .clinerules/29 + /38 the work is autonomous-tier; the window should self-verify and finish, only stopping for a genuine code-level human gate (refund > cap, regulator, integrity decision).
   - Include the verification that PROVES done (rule 29 q5: re-run the previously-failing case, run the literal cron.d line, confirm the gate flips), not just "deployed."

2. **Parallel-safe (run simultaneously).** Multiple windows will run AT THE SAME TIME, so they must not collide:
   - **No two windows edit the same file.** Partition by file. If two pieces both need the same file, either merge them into one window or sequence them explicitly and say so.
   - If a window depends on an artifact another window is building (e.g. a not-yet-built facade), write it to build against the EXISTING source of truth instead (e.g. call the already-deployed lib directly), so it does not block on a sibling window. Note the later "re-point to the facade" as a cheap follow-up, don't gate on it.
   - `emsu-safe-deploy` already enforces flock + compare-and-swap per file, so distinct-file windows are safe to fire together. Same-file windows are NOT — that's a sha-drift collision and a wasted window.
   - Call out the partition explicitly at the top: "These N windows touch disjoint files and can run simultaneously."

## The shape of each copy window

```
<one-line objective + idea number>. <full context: what's broken, where>.
Build: <exact files to create/edit, with the pattern to mirror>.
Constraints: emsu-operations MCP only (never raw local ssh); emsu-safe-deploy + php -l; NO FPM (rule 42); audit + reversal (rule 29); act autonomously, do NOT stop to ask (rules 29/38) unless a hard human gate (money>cap/regulator/integrity).
Verify (rule 29 q5 — must PROVE done): <the previously-failing case re-run / literal cron line / gate flip to confirm>.
Finish: write HANDOFF entry + ledger row + a rule-91 pickup prompt. Run order 66.
```

## Self-check before handing Ruben multiple copy windows

1. Could each window finish WITHOUT pinging Ruben? If it would need to ask something, I under-specified it — add the missing artifact.
2. Do any two windows write the same file? If yes, repartition or sequence.
3. Does each window contain its own verification that proves done?
4. Did I say explicitly which windows are parallel-safe?

## Cross-references

- .clinerules/29 — act on confidence, don't defer; q5 verification
- .clinerules/38 — Ruben-asked = autonomous-tier minimum
- .clinerules/41 / 42 — post-deploy tool call; safe-deploy reloads FPM
- .clinerules/91 — every completion needs a pickup prompt
- .clinerules/92 — fix at the core

## Last updated

2026-06-03 — initial. Source: Ruben directive during the SLS build hand-off — wants copy windows that run to completion autonomously and in parallel, not iterative back-and-forth.

# The Foreman — Persistent dual-window autonomous engineering pattern

Permanent hardfloor rule. Source: 2026-07-10 Ruben directive.

## The pattern

When a critical engineering task needs relentless pursuit to completion (e.g., "22 tok/s or bust"), deploy TWO persistent Cline windows that don't close until the task is done or they genuinely error out:

| Window | Model | Role | Cadence |
|---|---|---|---|
| **The Worker** (Frankenstein-LLM) | Free local model (120B/70B fleet) | Babysits issues, fixes what it can, tenacious, pushes toward the goal | Continuous — works nonstop |
| **The Supervisor** (Cloud direct — e.g., GLM-5.2, Claude) | Paid cloud model | Checks progress every ~30 min, course-corrects, modifies crons/scripts, guides the Worker | Every 30 min |

## The Worker window (Frankenstein-LLM)

- Uses `frankenstein-llm` (free local fleet) — costs $0
- **NEVER GIVES UP.** If one approach fails, try the next. If all known approaches fail, use analogous/spatial thinking to generate new approaches.
- Consults community (Rule 262), bug library, documentation EVERY time it gets stuck
- Files ideas, updates bug library, updates HANDOFF_NOTES after each attempt
- When stuck: applies the **Spatial Thinking Protocol** (below)
- **MUST read `/tmp/foreman_directives.md` before launching containers or making changes.** If the Foreman has written directives, the Worker follows them. It does NOT replace running containers with its own config without reading the directives first.
- Target: the specific goal (e.g., "22-25 tok/s") — works toward it or bust

## The Supervisor window (Cloud direct model)

- Uses a paid cloud model (GLM-5.2 direct, Claude, etc.)
- Runs every ~30 min (or on-demand)

### THE SLEEP-CHECK CYCLE (mandatory — this IS the supervisor pattern)

The Supervisor does NOT stay active continuously. The Supervisor does NOT call `attempt_completion` to end the session while the Worker is still running. The Supervisor follows this cycle:

1. **Work phase (5-10 min):** Check Worker progress, course-correct, apply fixes, write directives. Do whatever is needed to stabilize the course.
2. **Sleep phase (30 min):** Once everything is stabilized and the Worker is doing its job, run `sleep 1800` in a background terminal. The Supervisor STOPS iterating during this time. It does not keep polling. It sleeps.
3. **Wake phase:** After the 30-min sleep completes, the Supervisor wakes and checks:
   - What did the Worker do while I was sleeping?
   - Is the task done? (e.g., 22+ tok/s achieved)
   - Did the Worker go in circles? (course-correct needed)
   - Did the Worker break anything? (fix needed)
4. **Repeat:** Work phase → Sleep 30 min → Wake → Check → Work phase → Sleep → ...

### CRITICAL: The Supervisor NEVER calls `attempt_completion` while the Worker is still running

Calling `attempt_completion` ends the session, which means the Supervisor STOPS supervising. This defeats the entire purpose of The Foreman pattern. The Supervisor only calls `attempt_completion` when:
- The task is TRULY DONE (e.g., 22+ tok/s achieved and verified)
- A genuine error requires Ruben's intervention (not just "I'm stuck")
- Ruben explicitly tells the Supervisor to stop

If the Supervisor feels the urge to "wrap up" while the Worker is still running, that is a RULE VIOLATION. The correct action is to run `sleep 1800` and check back later.

### Other Supervisor duties
- Checks the Worker's progress: reads HANDOFF_NOTES, bug library, logs
- Course-corrects: if the Worker is going in circles, the Supervisor identifies the pattern and redirects
- Can create/modify cron jobs, scripts, and configuration that the Worker monitors
- Writes course-correction notes to a shared file (e.g., `/tmp/foreman_directives.md`) that the Worker reads on each loop
- Ensures rules are followed: community consulted, bug library updated, runbook maintained

## Spatial Thinking Protocol (when stuck)

When linear/sequential approaches have been exhausted, apply SPATIAL/ANALOGOUS thinking:

1. **Reframe the problem spatially.** Draw the physical/logical topology. Where is the actual blockage? Not "what config var do I try next" but "what is physically happening in the system?"

2. **Think analogously.** What other systems have solved this same class of problem?
   - Phone switchboard: multiple lines to different people, need an operator to route
   - Postal sorting: multiple mailboxes to different neighborhoods, need correct labeling
   - Network bonding: multiple NICs to different switches, need LACP or explicit routing
   - Airport hub-and-spoke: connecting flights through intermediate nodes

3. **Apply the analogy.** Can the analogous solution be implemented here? What would it look like?

4. **Acquire information until you know.** If you don't understand something, research it. Read source code. Read docs. Read community posts. Do NOT guess — KNOW.

5. **Persevere at the precipice.** The breakthrough often comes right after the point where you want to give up. One more attempt, approached from a new angle, can crack it. This is not "beat your head against the wall" — it's "try a different wall."

6. **Think in parallel, not just sequence.** What can be done simultaneously? What dependencies can be broken? What can be prepped while waiting?

## Communication protocol

- **Shared state**: `/tmp/foreman_directives.md` (Supervisor writes, Worker reads)
- **Worker progress**: HANDOFF_NOTES.md + bug library (Worker writes, Supervisor reads)
- **Status files**: `/tmp/foreman_status.txt` (Worker writes current state each loop)
- **Goal file**: `/tmp/foreman_goal.txt` (the specific target, set by Supervisor)

## When to use The Foreman

- Critical performance targets (tok/s, latency, throughput)
- Complex multi-system debugging that has resisted multiple attempts
- Tasks where giving up is not an option
- Tasks that require relentless iteration with course correction

## Cross-references

- Rule 00: subagent dispatch (Worker can dispatch subagents for research)
- Rule 29: act on confidence tier (Worker acts, doesn't just analyze)
- Rule 91: pickup prompt at every completion (both windows use this — but Supervisor only when task truly done)
- Rule 119/120: context management (compress, don't shortcut)
- Rule 143: prose-loop circuit breaker (both windows must emit tools)
- Rule 262: consult bug library + community before recycling approaches

## Source

2026-07-10 — Ruben directive: "I would like to have a different window that babysits the issues and fixes what it can continuously... The idea is to get the model to 20 to 25 tokens per second or bust... I think we should call it 'The Foreman'... you need to think more spatially... if you can't resolve an issue head on, what other analogous things would resolve the problem... we are at the precipice and to give up now would be tragic, we need to cross the Rubicon."

## Last updated

2026-07-10 — initial.

2026-07-10 — update: Added THE SLEEP-CHECK CYCLE (mandatory), CRITICAL: no `attempt_completion` while Worker running, and Worker obedience (must read foreman_directives.md before launching containers). Source: Ruben feedback — "The foreman does not really want to supervise which is annoying... the foreman rules need to be updated... shouldn't the foreman just put self to sleep for 30 minutes and stop iterating for 30 minutes after everything is stabilized the course? Then come back and check after the 30 minutes?"
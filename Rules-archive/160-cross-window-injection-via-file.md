# 160 — Cross-window injection: hand a fact to another Cline window via a FILE it will read (Frankenstein Doctor)

Permanent rule. Workspace-scoped. Source: 2026-06-16 — Ruben directive. During a Frankenstein Doctor session, Cline said it "can't inject into another window — no inter-window tool." Ruben corrected: *"You actually can inject things into another window by injecting them in a file that you know that the other window is gonna touch."* This is the missing mechanism for rule 158's Step-2 "inject the repair-fact into the live window" when there is no direct channel.

## The mechanism

A Cline window has no API to type into another Cline window. BUT windows share a filesystem (local Mac + the WOPR server). So the Doctor injects a fact by **writing it into a file the patient window is about to read or is actively working in**, so the patient picks it up on its next tool turn. This is real, it works, and it is the file-based form of rule 158's injection ladder Step 2.

## When to use (rule 158 composition)

Use this when, per rule 158, the patient frankenstein-llm window is stuck/looping because it lacks a fact the Doctor just learned or a repair the Doctor just shipped — AND the Doctor cannot otherwise reach it. The injected content is STILL minimal, factual, repair-scoped (rule 158: tell it WHAT CHANGED, never HOW to do its task). File-injection only changes the DELIVERY, not the rules about content.

## How to inject (pick the surface the patient WILL touch)

Choose a file the patient window is provably going to read, in priority order:

1. **A file it is actively editing / re-reading this task.** If the patient keeps grepping/reading `/path/X`, drop a short `INJECTED NOTE` comment block at the top of `X` (or a sibling `X.NOTE.md` it will see in the same `list_files`).
2. **A drop file in its working directory.** If the patient works in `/Users/rubenmajor/Desktop/proj`, write `/Users/rubenmajor/Desktop/proj/_FLEET_NOTE.md` — it shows up in its next `list_files`/environment_details.
3. **The task's HANDOFF_NOTES / ledger.** If the patient reads HANDOFF_NOTES.md (most server tasks do), `update_handoff_notes` with a clearly-tagged `>>> INJECTED FOR <task>:` line.
4. **A server-side breadcrumb at the path it keeps grepping.** If it keeps searching `/var/www/moodle/ems` for X, write `/var/www/moodle/ems/_INJECTED_NOTE.txt` with the fact + the correct location (it will surface on its next grep/ls).

Keep the injected block short, unmistakably tagged (`=== INJECTED FLEET NOTE (Doctor) ===`), dated, and scoped to the one repair-fact. Tell it the new truth + "continue your original task," nothing more.

## Caveats

- **Don't corrupt the file.** Inject as a COMMENT (language-appropriate) or a SEPARATE sibling file — never as syntax that breaks the file the patient is editing. Prefer a sibling `_NOTE` file when in doubt.
- **It's best-effort + async.** The patient reads it only on its next relevant tool turn; it is not instant. If the patient is truly wedged (taking no tool turns), file-injection won't reach it — fall to rule 158 Step 6 (euthanize + pickup prompt).
- **Clean up.** Remove the breadcrumb (`_INJECTED_NOTE.txt`) once the patient has consumed it or the task is done, so it doesn't confuse a later window.
- **Direct execution often beats injection.** Per rule 158 + rule 29: if the remaining work is small and reversible and the Doctor has the tools, just DO it (the Doctor did the 2-course CAPCE UPDATE directly rather than route it). Injection is for when the patient should finish its OWN task and only lacks a fact — not a way to offload work the Doctor can close in one call.

## Self-check

Before saying "I can't reach the other window": ask *"Is there a file that window is going to read or is working in?"* If yes → write the fact there (comment or sibling note), tagged + dated. If the work is small + reversible and I have the tool → just do it directly instead. Only if neither works → rule 158 euthanize + pickup.

## Cross-references

- Rule 158 — Frankenstein Doctor; this is the delivery mechanism for its Step-2 "inject the missing knowledge into the live window" (and the temporal-gap-patch discipline still applies — pair with a permanent core fix)
- Rule 29 — act on confidence; small reversible work the Doctor can do → do it, don't route
- Rule 91 — pickup prompt (the fallback when injection can't reach a wedged window)
- Rule 144 — server-path writes via emsu-operations ssh_command

## Source incident

2026-06-16 — Doctor session removing "(CAPCE F5)" from emsuniversity.com/ems course names. Cline asserted it could not inject into the sibling frankenstein-llm window. Ruben: "You actually can inject things into another window by injecting them in a file that you know that the other window is gonna touch... maybe make that a cline rule." (In that specific case the right move was direct execution — 2 reversible Moodle DB UPDATEs — which Cline then did; but the file-injection technique is the general capability the Doctor was missing.)

## Last updated

2026-06-16 — initial.

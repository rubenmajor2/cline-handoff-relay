# Rule 325 — Forward-only repair: never revert a page or design, never lose function

**Severity: HARD-FLOOR / TRIPWIRE**
**Applies: ALWAYS, on any change to a page, design, layout, template, config, or behaviour**
**Created: 2026-09-01 (Ruben directive: "I do not want to be reverting pages / designs to older pages / that's annoying. I do not want any loss of function. I feel like there should be some sort of rule for this.")**

## Core principle

A repair moves FORWARD. Restoring an older page, an older design, or an older
config in order to make a problem go away is not a fix — it is a trade that pays
for one bug with the loss of every improvement made since that backup was taken.
Ruben experiences that as the site going backwards, and it is annoying precisely
because the regression is invisible to the agent that caused it: the agent sees
"error gone", the human sees "my page is old again".

**The bright line: fix the defect in the CURRENT artifact. Do not swap the
current artifact for an older one.**

## The three banned moves

1. **Revert-to-backup as a fix.** `cp file.bak-<date> file`, `git checkout <old>`,
   restoring a `.bak` drop-in, or re-pointing a route at a previous template,
   because the current one has a bug. The bug is the thing to fix.
2. **Silent feature removal.** Deleting a button, tab, field, column, filter,
   endpoint, or code path to resolve an error, a lint failure, or a conflict.
   If it worked yesterday it must work today.
3. **Downgrade-as-repair.** Reverting a model, a library, a schema, or a config
   to an older value to dodge a failure, without naming the defect that made the
   newer value fail.

## The one legal exception, and its cost

A revert is legal ONLY as an **emergency stop on a live outage**, and only when
all four hold:

1. Production is actively broken for users RIGHT NOW.
2. The forward fix is not available within the outage window.
3. The revert is announced as **temporary**, in the completion, in plain words.
4. A real idea `#NNNN` is filed IN THE SAME SESSION to restore the lost function,
   listing every capability the revert removed.

A revert without item 4 is a permanent regression wearing the costume of a
rollback. If you cannot enumerate what was lost, you do not yet know what you
reverted, and you must not ship it.

## Pre-change gate (run BEFORE any edit that touches a page, design, or config)

1. **Am I replacing content wholesale, or repairing a defect in place?**
   Wholesale replacement from an older copy → STOP, this is rule 325.
2. **Does the version I am about to write contain every feature the live version
   has?** Diff it. `diff <(current) <(proposed)` and read what disappears.
   Anything that disappears must be intentional and stated.
3. **Am I about to restore a `.bak`?** Then name the defect in the CURRENT file
   and fix that instead. A `.bak` is a safety net for MY change, not a
   destination.
4. **Would Ruben notice this page looks like it did last month?** If yes, the
   change is a revert regardless of what I call it.

## Post-change gate (before attempt_completion)

State explicitly, in the completion, one of:

- **"No loss of function."** — and mean it: every prior capability still present
  and exercised, and say how you checked (a probe, a diff, a render).
- **"Function removed: X, Y."** — with the filed idea `#NNNN [tag]` restoring it.

A completion that changed a page and says NEITHER has not been audited against
this rule. "It works now" is not the same claim as "nothing was lost", and only
the second one is what Ruben is asking for.

## Backups are for rollback of MY OWN change, not for design decisions

Taking a `.bak` before an edit is correct and expected (rule 42, rule 144). What
this rule forbids is treating that backup, or somebody else's month-old backup,
as a legitimate FINAL STATE. The backup exists so a bad edit can be undone within
minutes; it does not exist so an agent can escape a hard bug by time-travelling
the file.

## Why this is hardfloor

The failure is self-concealing. Every other gate in the system checks that the
change works, and a revert always works — that is its entire appeal. Nothing in
the completion validator, the truth judge, or the deploy path can tell that the
artifact that now works is an older, smaller artifact than the one it replaced.
Only an explicit forward-only rule catches it, and only if it is loaded in every
window.

## Cross-references

- Rule 300 — end-to-end delivery: a revert is the deferral of the real fix
- Rule 321 — the gaslighting taxonomy: reverting and reporting "fixed" is G5
  (premature completion) plus an undisclosed regression
- Rule 317 — claim scope equals probe scope: "no loss of function" is a CLAIM and
  needs a probe (a diff, a render, an endpoint check), not an assumption
- Rule 301 — if Ruben's steer named a target, restoring the previous thing is not
  the target (R301_ABANDONED_DIRECTIVE blocks exactly this at completion time)
- Rule 42 / 144 — how to take and deploy backups correctly

## Source incident

2026-09-01, Ruben, verbatim: "I do not want to be reverting pages / designs to
older pages / that's annoying. I do not want any loss of function. I feel like
there should be some sort of rule for this." Raised while approving throughput
work, in the context of repeated agent behaviour where a page regression was
resolved by restoring an earlier copy rather than repairing the current one.

## Last updated

2026-09-01 — created.

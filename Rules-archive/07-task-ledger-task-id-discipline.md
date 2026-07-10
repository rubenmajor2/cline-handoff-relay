# Task Ledger — task_id Discipline

## The rule

When you append a row to `~/Documents/Cline/cline_task_ledger.md`, the `task_id` field MUST be a single canonical identifier — NOT a composite phrase.

The portal at https://emsuniversity.com/emtskills/routes/ruben_open_tasks.php collapses rows by `task_id` so a chain of `open → open → done` for the same task ID renders as a single row showing the latest status. If your `task_id` doesn't match a previous row's `task_id` exactly (modulo the canonical normalization below), the portal treats it as a NEW task and the old `open` row stays "open" forever.

## Canonical task_id format

Pick ONE of these (in this order of preference):

1. **The Cline thread ID.** When the row is closing or updating a Cline task, use the literal task folder name from `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/<id>/`. Format: `#1776957222780`. The `#` prefix is canonical for Cline thread IDs.
2. **A stable kebab-case slug.** When there is no Cline thread (ad-hoc work, ops events), use a kebab-case slug like `#vr-skills-quest-avp-cross-platform`, `#chief-mobley-spam-loop`, `#cori-overwhelm-triage`. The `#` prefix is optional but recommended for consistency.
3. **A session_handoffs slug.** When the work is owned by a chain on the EMSU portal, use the slug from `session_handoffs.slug`. Same kebab-case shape: `#email-wrapper-fix-bug-hunter-api`.

**Never use:**
- Composite phrases joined by `+` or `,` like `#1776957222780 + #1776987409962` or `#1172,#1173,#1174,#1175 + idea #659 expanded`. These are different strings every time you write them and never collapse.
- Free-form English phrases like `#chief-dobson-external-tone-fix` (kebab is fine but verify it matches the originating row).
- Trailing spaces, double-`#`, mixed case, or whitespace inside the ID.

## Canonical normalization (what the system does for you)

As of 2026-04-26, both the Mac pusher and the EMSU server normalize task_id at write time AND at display time:
- Strip whitespace
- Drop ALL leading `#` chars
- Collapse inner whitespace to single spaces
- Lowercase

So `"#1070"`, `"1070"`, `"#1070 "`, and `"# 1070"` all collide on collapse — but `"#1070 + #1119"` does NOT collide with `"#1070"`. Composite IDs are still poison.

## When you're closing multiple related task_ids in one sweep

Append ONE row PER task_id you want to close, with that exact ID. Do not concatenate them. Example — wrong vs right:

**Wrong (creates a new uncollapsable row):**
```
- 2026-04-25 18:50 PT | #1070 + #1119 + .clinerules | channel-match closed | done | ...
```

**Right (closes 3 distinct rows on the portal):**
```
- 2026-04-25 18:50 PT | #1070 | personnel-cert-ocr — superseded, see #1070 + #1119 child rows | done | parked, idea #653 ready
- 2026-04-25 18:50 PT | #1119 | cori agent phase 2 — chain in_progress | done | RUBEN dispatcher will pick up
- 2026-04-25 18:50 PT | channel-match-rule | rule codified, chains 1187/1188/1189 promoted | done | idea #673 P2 ready
```

If you genuinely have multiple Cline threads that closed together, write one row per thread.

## Session_handoffs chain IDs vs Cline thread IDs

These are different namespaces and should NOT share a task_id:
- Cline thread: `#1776957222780` (numeric, ~13 digits, the timestamp-based folder name)
- session_handoffs row: chain ID like `1093` or slug like `email-wrapper-fix-bug-hunter-api`
- orchestrator_ideas row: `idea #553`

If you need to reference a chain inside a Cline-thread row, put it in the `cue` field, not the `task_id` field.

## Why this rule exists

On 2026-04-25 a sweep of the open-tasks portal closed 14 chains autonomously, but the ledger close-rows used composite task_id strings like `#1776957222780 + #1776987409962` and `#1070 + #1119 + .clinerules`. None of those strings matched the original open rows, so the portal kept showing 14 stale-open entries even though the underlying chains were already done.

The hot-fix was appending fresh-dated done-rows with task_id strings that EXACTLY matched the original open rows. The systemic fix (deployed 2026-04-26) is task_id normalization at all three layers (Mac pusher, server API, server display) so cosmetic differences don't break collapse. This rule prevents the same human mistake from re-introducing the bug.

## Quick check before committing a ledger append

Before pasting a row into cline_task_ledger.md, ask:
- "Does this `task_id` string appear in an earlier row for the same topic?"
  - If yes, copy that string EXACTLY.
  - If no, you're starting a new task — pick a canonical ID per the format rules above.
- "Does my `task_id` contain `+`, `,`, `&`, or `and`?" If yes, stop and split into multiple rows.
- "Is this an ad-hoc closing summary covering multiple tasks?" If yes, append ONE row per closed task_id, plus optionally one summary row with a NEW unique task_id like `#sweep-2026-04-25-summary`.

## Scope

Applies to: every append to `~/Documents/Cline/cline_task_ledger.md`, including by Cline, by Ruben directly, and by the YOLO-learner bridge.

Does NOT apply to: ad-hoc per-event ledgers (RUBEN orchestrator's `orchestrator_event_log`, EMSU `tickets`, etc.) — those have their own primary keys.

## Verification

After any sweep that touches >3 ledger rows, run this check:

```sh
python3 -c "
import re, collections
rows = []
with open('/Users/rubenmajor/Documents/Cline/cline_task_ledger.md') as f:
  for line in f:
    m = re.match(r'^-\s+(\S[^|]*)\|\s*(#?\S[^|]*)\s*\|\s*([^|]+?)\s*\|\s*(\S+?)\s*\|\s*(.+)\$', line.rstrip())
    if not m: continue
    rows.append({'when': m.group(1).strip(), 'task_id': m.group(2).strip(), 'status': m.group(4).strip().lower()})
# composite check
bad = [r for r in rows if any(c in r['task_id'] for c in ['+', ','])]
print(f'{len(bad)} composite task_ids (should be 0 going forward)')
for r in bad[-5:]: print(f'  {r[\"when\"]} | {r[\"task_id\"]}')
"
```

If the count is non-zero on rows newer than 2026-04-26, those are bugs to clean up.

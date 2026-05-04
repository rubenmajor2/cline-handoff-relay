## Learned: [2026-04-29 09:46 PT] — Cross-chain policy questions go on `ruben_questions`, not just inline chat

> **Flagged by Ruben 2026-04-29 09:44 PT.** During the VR project I asked 3 high-impact policy questions inline in chat (Y/Y/Y on Mac→WOPR chain audit, Cpp2IL pivot A/B/C/D, sudo-wall A/B/C). Each one affected 4-7 chains. Ruben's correction: *"if we're talking policy questions affect a lot of chains, that also need to be put in this project like we see for RUBEN questions and calculated in the same manner."*
>
> The infrastructure exists: `admin_portal.ruben_questions` table + `/var/www/emtskills/routes/ruben_questions.php` portal page. RUBEN scanner already files Q-cards there for cross-chain decisions ("Approve unknown tool: get_location_pricing_combo (3/3 fails)?", "Unblock chain X?", etc.). Cline should file the same way for any policy decision that affects more than one chain or recurs.

### The rule

When a policy question affects **2+ chains** OR is **likely to recur** (will hit again on the next similar task), file it on `admin_portal.ruben_questions` instead of asking inline in chat.

**File on the portal when:**
- The decision affects 2+ chains today (e.g. "should we move all 4 chains to WOPR?")
- The decision is a recurring pattern that will hit again (e.g. "how should Cline drive macOS dev installs going forward?")
- The decision is high-impact + needs a record for future agents (e.g. tooling pivot like Cpp2IL Unity 6 dead-end)
- The question has 3+ options and you want Ruben to weigh them at his pace
- You answered it inline already but realize it should have been a Q-card (file retroactively as `status='answered'` with the answer captured)

**Keep inline in chat when:**
- One specific chain only, no recurring pattern
- Pure read-only question Ruben is actively waiting on
- Simple yes/no on a single concrete next step
- Mid-dialogue back-and-forth that's not really a policy

### How to file (the exact INSERT shape)

```sql
INSERT INTO ruben_questions (
  title, body, context_json, source, source_ref,
  category, priority, question_type, status,
  answer, answered_at  -- only if filing retroactively-answered
) VALUES (
  'VR-POLICY: <plain-English topic> — <unlocks N chains> <(settled YYYY-MM-DD HH:MM PT) if retroactive>',
  '### What yes/no/A/B/C unlocks
   ...rule-05 card body: what yes does, what no does, scope, risk, rollback, options...
   ### Affected chains
   - chain-slug-1 (id 1234) — short reason
   - chain-slug-2 (id 1235) — short reason
   ### Recommendation
   ...one-line my-pick + why...',
  '{"affected_chain_ids": [1234, 1235], "affected_chain_count": N,
    "task_origin": "<umbrella task slug>", "umbrella": true,
    "options": ["A_label", "B_label", ...], "default": "<recommended>"}',
  'cline_<task_slug>',  -- source: identifies who filed it
  '<umbrella task slug>',  -- source_ref: points back to the parent topic
  'system',
  'medium' | 'high' | 'critical',  -- priority
  'choice' | 'yes_no' | 'freetext',  -- question_type
  'pending' | 'answered',
  '<answer text>',  -- only when retroactively-answered
  '<YYYY-MM-DD HH:MM:SS>'  -- only when retroactively-answered
);
```

**source naming:** `cline_<task_slug>` (e.g. `cline_vr_task`, `cline_personnel_cert_ocr`). This makes it greppable per-task and tells the next agent which Cline window flow originated it.

**source_ref:** the umbrella task slug (e.g. `vr-skills-quest-avp-cross-platform`). Lets the portal display rows clustered by parent topic.

**category:** `system` for cross-cutting platform decisions, `ops` for student-facing operational decisions, `dev` for build-tooling decisions.

**priority:** `medium` for most. `high` if 5+ chains affected OR it changes timeline by >2 days. `critical` only for student-visible blocking issues.

**question_type:** `choice` if 3+ options (most policy questions), `yes_no` for binary, `freetext` for open-ended.

### When to file retroactively (status='answered')

If you already asked inline and Ruben answered, file the Q-card anyway with `status='answered'` + `answer` text + `answered_at` timestamp. Reasons:

1. Future agents see the rationale + options that were considered (not just the answer)
2. The chain effects are visible on the portal next to the chains themselves
3. If a similar question comes up next time, the agent can find the precedent via `SELECT * FROM ruben_questions WHERE source LIKE 'cline_%' AND title LIKE 'VR-POLICY%'`
4. Ruben gets a clean record of "this is what Cline asked + what I picked" without scrolling through chat history

### Example: filed on 2026-04-29 09:46 PT (this rule's source incident)

Filed 4 Q-cards on the VR project retroactively + one new pending:

| ID | Title | Status | Affected chains |
|---|---|---|---|
| 1472 | VR-POLICY: Mac sudo wall — how should Cline drive macOS dev installs? | pending | 1741, 1273, 1277 + future Mac dev classes |
| 1474 | VR-POLICY: Cpp2IL Unity 6 path — body recovery | answered | 1266, 1271, 1275, 1276, 1273, 1277 |
| 1475 | VR-POLICY: Move 4 P0 chains from Mac-side to WOPR-autonomous | answered | 1266, 1271, 1275, 1276, 1273, 1277 |
| 1476 | VR-POLICY: Watchdog notifications — SMS vs email digest | answered | 1266, 1271, 1275, 1276, 1273, 1741, 1277 |

Portal view: https://emsuniversity.com/emtskills/routes/ruben_questions.php

### Red-flag patterns that mean I'm violating this rule

- Asking 2+ inline yes/no's in one turn that each affect multiple chains → those are Q-cards
- Saying "let me know your preference" on tooling/pivot/cost decisions → Q-card
- Building a fix that depends on a policy decision but never recording the policy itself → Q-card retroactively
- Cross-task patterns like "how should Cline handle X going forward?" → Q-card with `umbrella:true` in context_json

### Does NOT replace .clinerules

This rule is about decision LOGS (per-task, per-chain). Once a pattern is settled enough to be the default for ALL future tasks, it goes in `.clinerules` (this file) too. Q-cards are the medium-term records; `.clinerules` is the long-term policy.


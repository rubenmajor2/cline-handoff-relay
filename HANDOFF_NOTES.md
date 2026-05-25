# Mac-side HANDOFF_NOTES

Lives at `/Users/rubenmajor/Documents/Cline/HANDOFF_NOTES.md`. Mac-only operational notes
that don't belong in the WOPR-side server `HANDOFF_NOTES.md`. Newest at top.

**Instant-recall reference: `/Users/rubenmajor/Documents/Cline/ARTEMIS_FACTS.md`** — read FIRST before any Artemis-related diagnosis. Contains WG IP, ProxyJump path, Cox router model/creds, login mechanism caveats, out-of-band path priority, UPS clarification, common failure modes.

---

## 2026-05-16 12:25 PT — Artemis WG-down + Cox router enumeration + ARTEMIS_FACTS.md created (task #1778916427107)

Artemis has been off WG since ~01:56 PT. Cox router (Netgear Nighthawk RS300 at https://68.227.47.137, admin/qefru3-cocnyf-xuxnoP) IS reachable. `DEV_show_device.htm` basic view shows 9 devices, none labeled Artemis — but that view is incomplete (no static reservations / VLAN-tagged / aggregation-LAN hosts). The router uses a JS-form login (NOT HTTP Basic), so `curl -u admin:pw` returns the login form for every page. Real enumeration requires browser-login + cookie capture. Ledger row at 11:53 PT corrected (12:20 PT) to reflect this limitation. Until Artemis is back, idea #4671 (VNC over WG, approved autonomous) is the durable console-level path queued to ship.

UPS at Tempe: Ruben asked if it can serve as a KVM. Answer in ARTEMIS_FACTS.md "UPS at Tempe" section. Short version: NOT a KVM (no video/keyboard passthrough), but if the UPS is "smart" with managed outlets AND we plug its ethernet in, we get remote outlet cycling — that IS valuable for "Artemis is hung" recovery without anyone physically there. Real KVM-over-IP options: PiKVM (~$200, DIY) or JetKVM (~$70).

---


## 2026-05-06 12:53 PT — Bug-hunter LaunchAgent alerts: BOTH PLISTS UNLOADED, hot-fix below

**WHAT WE WERE DOING / DEFERRED**
Bug-hunter triage (cline_bug-hunter-triage-2026-05-06). Three of four alerts handled on
Artemis. Two Mac-side LaunchAgent alerts (`Cline MCP Auto-Reconnect Heartbeat`,
`MCP Reaper Heartbeat`) needed local discovery — done now. Findings inlined so the
next Mac session can fix in 30 seconds.

**CURRENT STATE — diagnosis complete, both unloaded**

| Component | Plist on disk | Script on disk | Loaded in launchctl | Heartbeat file |
|---|---|---|---|---|
| `com.emsu.cline-mcp-auto-reconnect` | YES (`~/Library/LaunchAgents/com.emsu.cline-mcp-auto-reconnect.plist`, 926 B, mtime Apr 18 22:38) | YES (`~/bin/cline-mcp-auto-reconnect.sh`, 9900 B, executable) | **NO** | MISSING (`/tmp/cline-mcp-auto-reconnect.heartbeat`) |
| `com.emsu.mcp-reaper` | YES (`~/Library/LaunchAgents/com.emsu.mcp-reaper.plist`, 906 B, mtime Apr 19 15:23) | YES (`~/bin/emsu-mcp-reaper.py`, 7284 B, executable) | **NO** | MISSING (`/tmp/mcp-reaper.heartbeat`) |

`launchctl list | grep -iE 'cline-mcp-auto-reconnect|mcp-reaper'` returns 0 rows. Both
were authored Apr 18-19 and likely got booted out by a code-server / VS Code restart
storm somewhere around the 2026-05-02 Mac panic + Artemis storm event (rule 96).

The watchdog stack on the Mac never re-bootstrapped them because `mcp-self-heal.sh`
only kickstarts MCPs that are loaded-but-flapping, not ones that are unloaded entirely.
That's the systemic gap, but the immediate fix is a one-liner.

**TO RESUME — paste this in a fresh Cline window on the Mac OR a terminal**

```bash
# Verify they're still missing (should print 0 0)
launchctl list | grep -c com.emsu.cline-mcp-auto-reconnect
launchctl list | grep -c com.emsu.mcp-reaper

# Bootstrap both. -k forces kickstart in case launchd has a stale entry.
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.emsu.cline-mcp-auto-reconnect.plist
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.emsu.mcp-reaper.plist

# Confirm they're loaded
launchctl list | grep -E 'cline-mcp-auto-reconnect|mcp-reaper'

# Within 60-120s the heartbeat files should appear:
ls -la /tmp/cline-mcp-auto-reconnect.heartbeat /tmp/mcp-reaper.heartbeat

# Re-run bug hunter to confirm both alerts go green:
/usr/bin/python3 ~/.ruben-ai/bug_hunter.py --category self_heal --dry-run 2>&1 \
  | grep -iE 'auto-reconnect|reaper' | head -5
```

**OPEN THREADS / NEXT MOVES**

1. **Why did they unload?** Probably the rule-96 storm event (2026-05-02 19:14-19:22 PT
   Mac panic + Artemis ext-host balloon). When a Mac panics, all GUI-domain
   LaunchAgents are stopped; ones with `RunAtLoad=true` come back on next login,
   but if the plist was modified during the crash window or the user-domain re-login
   missed them, they stay unloaded. Worth a postmortem if it happens again.
2. **Systemic gap:** `mcp-self-heal.sh` doesn't detect "completely unloaded"
   LaunchAgents — only flapping ones. File an idea to extend it: every cron tick,
   compare `launchctl list` against the canonical list of `com.emsu.*` agents and
   `bootstrap` any that are missing. Low-risk addition (read + bootstrap is idempotent).
3. **Detector signal:** The bug-hunter detectors at `bug_hunter.py:1740-1838` for
   auto-reconnect and `~1845-1930` for mcp-reaper correctly fire `fail/high` when the
   plist exists but the heartbeat is missing. They're working as designed; the
   underlying problem is just the unloaded plist.

**FILES TOUCHED (this session — none on Mac)**

The Q1 fix today was on Artemis at `/Users/rubenmajor/.ruben-ai/bug_hunter.py` (added
`AND notes NOT LIKE 'Retroactively%'` to the email_ai_leak_log SQL). Q2 was already
shipped at 12:22 PT today by another agent (`cron_harvest_cline_corrections.php`
on WOPR — `$VOICE_PATTERNS` refreshed with directive-style regexes; manual run inserted
11 new rows). This handoff entry is the only Mac-side write.

**Cross-references**
- Rule 03 — Resume Kit format (this entry follows it)
- Rule 25 — Mac-side discipline for LaunchAgent / Chrome / swap issues
- Rule 96 — Mac panic + Artemis storm post-mortem (probable root cause)
- `~/.ruben-ai/bug_hunter.py` lines 1740-1930 — the two detectors that flagged this

---

## 2026-05-25 01:13 PT — STARRED: grv-status-drift / wrap-up scanner

Ruben said "star this task" at 01:13 PT but emsu-operations + ruben-orchestrator MCPs both returned "Not connected" / "fetch failed" twice in a row. WOPR tunnel wedged per rule 77. Could not INSERT into ruben_task_stars from this window.

**For next window: STAR THIS first.** Run via MCP once tunnel is back:
```
INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_empINSERT INTO ruben_task_stars (task_id, task_topic, sies same as rule 17.INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, INSERT INTO*AlINSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starre status + disposition_decision both backfilled to 'approved'
- Status_history + internal comments stamped
- Both ideas filed and bumped to status=approved
- Ledger rows: 12:03 (grievance fix), 12:06 (scanner investigation), 01:13 (star marker)

**Not touched:** GRV-2026-0056 / Cannon Lammons (id 57) — genuine pending_review, separate triage for Vicky.

**Full PICKUP PROMPT** is in the 12:06 PT attempt_completion message of this task.

## 2026-05-25 01:13 PT — STARRED: grv-status-drift / wrap-up scanner

Ruben said "star this task" at 01:13 PT but emsu-operations + ruben-orchestrator MCPs both returned "Not connected" / "fetch failed" twice in a row. WOPR tunnel wedged per rule 77. Could not INSERT into ruben_task_stars from this window.

**For next window: STAR THIS first.** Run once tunnel is back:
```
INSERT INTO ruben_task_stars (task_id, task_topic, starred_at, starred_by, note) VALUES ("grv-status-drift-2026-05-24", "wrap-up scanner gap + grievance status enum drift", NOW(), "Ruben", "Ship idea #6440 first then #6435. Four consecutive thin Cline wrap-ups motivated the star.");
```

**Parent ideas (both status=approved autonomous):**
- #6440 P0 technical — extend scan.py + write_rule.py to detect rule_91/109/38/order_66, stamp LIVE COUNTERs like rule 17.
- #6435 P1 technical — patch applyAgentProposal in grievance_api.php to write canonical "approved" not "approval", plus drift watchdog.

**Already shipped (do NOT redo):**
- Grievance rows 43, 44 backfilled status + disposition_decision to "approved"
- status_history + internal comments stamped
- Both ideas filed and bumped to status=approved autonomous
- Ledger rows 12:03, 12:06, 01:13

**Not touched:** GRV-2026-0056 / Cannon Lammons (id 57) pending_review for Vicky.

Full PICKUP PROMPT is in the 12:06 PT attempt_completion of this task.

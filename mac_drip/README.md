# mac_drip — drip dispatcher for the Mac-Side Queue panel

Surfaces ONE Mac-side chain at a time on the Mac-Side Queue panel of
https://emsuniversity.com/emtskills/routes/ruben_executor_live.php so the
queue keeps moving instead of sitting as a wall of equally-urgent rows.

## What it does

Every hour:

1. SSH into WOPR via the existing `wopr` host alias.
2. Look at `admin_portal.session_handoffs` for any row whose `whats_pending`
   already contains a `[MAC-DRIP ACTIVE since ...]` tag.
3. If a row is tagged AND its status is still `resting`/`in_progress` AND
   the tag is less than 48h old → no-op (Ruben is presumably on it).
4. Otherwise, drop the tag and pick the highest-priority next row to surface:
   `approval_tier` rank (approved first), then `in_progress` over `resting`,
   then most-recently-updated.
5. Stamp the new row with `[MAC-DRIP ACTIVE since YYYY-MM-DD HH:MM PT] ...`
   at the top of `whats_pending`.

That's it. It does NOT execute Cline, does NOT auto-resolve chains, does NOT
modify anything else. It's just a "next one up" surfacer.

## Why a surfacer instead of an executor

Mac-side chains need a Cline window on the Mac with file system access to
`/Users/rubenmajor/Documents/Projects/...`, `~/.ruben-ai/...`, Unity, Xcode,
launchd plists, etc. WOPR's autonomous executor cannot do any of that. The
human-at-keyboard step is non-removable. What was missing was a
queue-ordering signal — when there are 30+ resting chains, opening the
panel and picking what to do is itself friction. The drip removes that
friction without trying to remove the human.

## Files

- `drip.py` — the dispatcher (Python 3, stdlib only, no deps)
- `run.sh` — launchd wrapper, always exits 0
- `README.md` — this file
- (launchd plist lives at `~/Library/LaunchAgents/com.ruben.cline.mac-drip.plist`)

## Logs

- `/tmp/cline-mac-drip.log` — the canonical log (drip.py writes this)
- `/tmp/cline-mac-drip.stdout`, `/tmp/cline-mac-drip.stderr` — launchd capture

`tail -f /tmp/cline-mac-drip.log` to watch live.

## Kill switch

```sh
touch /tmp/cline-mac-drip.disable    # next tick no-ops
rm /tmp/cline-mac-drip.disable       # resumes
```

## Schedule

Every 3600 seconds (1 hour) via launchd `StartInterval`. `RunAtLoad` is true
so it fires once on login/boot.

## Footprint

Each tick is 1-2 short SSH commands to WOPR. ~5 KB of traffic per hour.
Negligible by every measure.

## Manual operations

```sh
# fire one tick now
/usr/bin/python3 /Users/rubenmajor/Documents/Cline/mac_drip/drip.py

# see what's currently surfaced
ssh wopr "mysql -N -B admin_portal -e \"
  SELECT id, slug, status, approval_tier, LEFT(whats_pending, 80) AS head
  FROM session_handoffs WHERE whats_pending LIKE '[MAC-DRIP ACTIVE %'\""

# release the current tag manually (e.g. you want a different chain surfaced)
ssh wopr "mysql admin_portal -e \"
  UPDATE session_handoffs SET whats_pending = TRIM(SUBSTRING_INDEX(whats_pending, '\\n', -GREATEST(1, LENGTH(whats_pending) - LENGTH(REPLACE(whats_pending, '\\n', ''))))) WHERE id = NNNN\""
# (or just edit the row in the portal directly)

# reload the launchd agent after editing the plist
launchctl unload ~/Library/LaunchAgents/com.ruben.cline.mac-drip.plist
launchctl load   ~/Library/LaunchAgents/com.ruben.cline.mac-drip.plist
```

## How to tune

- **Slower** (less drip pressure): bump the plist `StartInterval` to 7200
  (2 hours) or 14400 (4 hours).
- **Faster** (more aggressive surfacing): drop to 1800 (30 min). I would
  not go below that; the goal is "background tide", not "constant churn".
- **Longer hold before auto-release**: change `AUTO_RELEASE_HOURS` in
  `drip.py`. Default 48h. Bump to 72h for chains that legitimately need
  multi-day soak (Unity 6 package iteration, Cpp2IL workflows).
- **Different priority order**: edit the `next_candidate` SQL inside
  `PHP_BRIDGE` in `drip.py`. Defaults to (approval_tier, in_progress over
  resting, most-recent). For example to drip oldest-first instead, flip
  `updated_at DESC` to `updated_at ASC`.

## Why the tag does NOT bump `updated_at`

The PHP bridge writes `updated_at = updated_at` so adding/removing the
[MAC-DRIP ACTIVE] tag is invisible to the "chain Ruben last touched"
signal that drives the panel's secondary sort. That way the tag is
informational, not destructive.

## Last updated

2026-05-06 01:17 PT — initial deploy. Surfaced #2507
chat-widget-ai-deflect-when-kb-has-answer-detector as the first row.

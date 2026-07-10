#!/usr/bin/env python3
"""
mac_drip/drip.py — Mac-side drip dispatcher for the Mac-Side Queue panel
on https://emsuniversity.com/emtskills/routes/ruben_executor_live.php

WHAT THIS DOES (and what it does NOT)

The panel reads `admin_portal.session_handoffs` rows where
`target_runtime='mac_only' AND status IN ('resting','in_progress')`. As of
2026-05-06 there are ~30 such rows. They cannot run on WOPR's autonomous
executor — they need a Cline window on this Mac (Unity, Xcode, Cpp2IL,
PolySpatial, ~/.ruben-ai/ files, /Users/rubenmajor/Documents/Projects/...).

Without a dispatcher it's a wall of equally-urgent rows. With this dispatcher
exactly ONE row at a time gets visibly tagged "[MAC-DRIP ACTIVE since HH:MM
PT]" in its `whats_pending`. It then sorts to the top of the panel, so when
Ruben (or Cline) opens the portal there's a clear "next one" to pick up.

This is a SURFACER, not an executor. The script never opens Cline windows,
never SSHes into a Cline session, never types into Ruben's keyboard. The Mac
side of these tasks needs a human (Ruben) at the keyboard. What the
dispatcher buys us is forward motion through the queue: each hour, if no row
is currently surfaced, surface the next one. If progress is made (Ruben
updates whats_pending or status flips), great. If not, after 48h auto-release
and pick a new one so the queue keeps moving.

CADENCE / FOOTPRINT

- Runs every hour via launchd (com.ruben.cline.mac-drip).
- Each tick: 1-2 short SSH commands (read tagged + maybe write a release/surface).
- A few KB of SSH traffic per tick. Negligible.
- Held by /tmp/cline-mac-drip.lock; if a previous tick is still running, exit.
- Logs to /tmp/cline-mac-drip.log.
- Always exits 0 so launchd never stops scheduling.

PRIORITY ORDER

1. `approval_tier` rank: approved < autonomous < supervised < human_required
   (approved chains drip first; human_required last)
2. `status='in_progress'` over `status='resting'` (finish before start)
3. Most-recently-updated first (recent context is freshest in Ruben's head)

So if there are 7 in_progress + 24 resting rows, the 7 in_progress drip
through first one at a time, then we move to resting.

SAFETY / IDEMPOTENCY

- Holds at most ONE [MAC-DRIP ACTIVE] tag at any time across the entire table.
- If a row was tagged but its status has flipped to completed/archived/blocked,
  the tag is dropped and a new row is picked next tick.
- If a row was tagged and 48h+ have passed since the tag was applied, auto-release
  and pick a new one so the queue doesn't stall on a stuck chain.
- The tag is a single line at the top of whats_pending. We strip + re-add,
  never duplicate.
- All DB access goes through PHP-via-SSH using the canonical lib/db.php on
  WOPR. We never embed credentials in this script.

KILL SWITCH

  touch /tmp/cline-mac-drip.disable      → script no-ops on next tick
  rm /tmp/cline-mac-drip.disable         → resumes
"""
from __future__ import annotations

import datetime
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

LOCK = Path("/tmp/cline-mac-drip.lock")
LOG = Path("/tmp/cline-mac-drip.log")
DISABLE = Path("/tmp/cline-mac-drip.disable")

# Auto-release a tagged row this many hours after the tag was applied.
# We parse the timestamp out of the tag line itself, NOT from updated_at,
# because we want a stable clock. (Ruben editing whats_pending will still
# preserve the tag's age.)
AUTO_RELEASE_HOURS = 48

TAG_RE = re.compile(
    r"^\[MAC-DRIP ACTIVE since (?P<when>[^\]]+)\][^\n]*\n?",
    re.MULTILINE,
)


def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S %Z")
    line = f"[{ts}] {msg}\n"
    try:
        with LOG.open("a") as f:
            f.write(line)
    except Exception:
        pass
    sys.stdout.write(line)


def acquire_lock() -> bool:
    if LOCK.exists():
        try:
            old_pid = int(LOCK.read_text().strip() or "0")
            if old_pid > 0:
                try:
                    os.kill(old_pid, 0)
                    log(f"another drip running (pid={old_pid}), exit")
                    return False
                except ProcessLookupError:
                    log(f"stale lock pid={old_pid}, taking over")
        except Exception:
            pass
    LOCK.write_text(str(os.getpid()))
    return True


def release_lock() -> None:
    try:
        if LOCK.exists():
            LOCK.unlink()
    except Exception:
        pass


# All DB access goes through this PHP bridge running on WOPR. The bridge
# uses /var/www/emtskills/lib/db.php — we don't embed credentials here.
PHP_BRIDGE = r"""<?php
require_once '/var/www/emtskills/config/config.local.php';
require_once '/var/www/emtskills/lib/db.php';
$pdo = db('portal');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$req = json_decode(stream_get_contents(STDIN), true);
$out = ['ok' => false];
try {
  switch ($req['action'] ?? '') {
    case 'list_tagged': {
      $st = $pdo->query("SELECT id, slug, status, approval_tier, whats_pending, updated_at FROM session_handoffs WHERE whats_pending LIKE '[MAC-DRIP ACTIVE %' ORDER BY updated_at DESC LIMIT 10");
      $out = ['ok' => true, 'rows' => $st->fetchAll(PDO::FETCH_ASSOC)];
      break;
    }
    case 'next_candidate': {
      $st = $pdo->query("SELECT id, slug, status, approval_tier, whats_pending, updated_at FROM session_handoffs WHERE target_runtime='mac_only' AND status IN ('resting','in_progress') AND (whats_pending IS NULL OR whats_pending NOT LIKE '[MAC-DRIP ACTIVE %') ORDER BY FIELD(approval_tier,'approved','autonomous','supervised','human_required','blocked') ASC, FIELD(status,'in_progress','resting') ASC, updated_at DESC LIMIT 1");
      $r = $st->fetch(PDO::FETCH_ASSOC);
      $out = ['ok' => true, 'row' => $r ?: null];
      break;
    }
    case 'update_whats_pending': {
      // Use a self-equating updated_at so we don't bump the timestamp just
      // for adding/removing the tag. That preserves the "real" updated_at
      // signal that Ruben uses to see which chain he last touched.
      $st = $pdo->prepare("UPDATE session_handoffs SET whats_pending=?, updated_at=updated_at WHERE id=?");
      $ok = $st->execute([(string)$req['whats_pending'], (int)$req['id']]);
      $out = ['ok' => $ok, 'rows_affected' => $st->rowCount()];
      break;
    }
    default:
      $out = ['ok' => false, 'error' => 'unknown_action'];
  }
} catch (Throwable $e) {
  $out = ['ok' => false, 'error' => $e->getMessage()];
}
echo json_encode($out);
"""


def php_call(action: str, **kwargs) -> dict:
    """Invoke the PHP bridge over SSH. Returns parsed JSON or {} on error."""
    payload = json.dumps({"action": action, **kwargs})
    # Strategy: write the PHP source to a tmp file on WOPR via heredoc,
    # then run `php $f` with our JSON request on its stdin. Heredoc avoids
    # shell-quoting hell for the PHP source AND for the JSON.
    wrapper = (
        "set -e\n"
        "f=$(mktemp /tmp/cline-mac-drip-bridge.XXXXXX.php)\n"
        "cat > \"$f\" <<'__DRIP_PHP_EOF__'\n"
        + PHP_BRIDGE
        + "\n__DRIP_PHP_EOF__\n"
        "php \"$f\" <<'__DRIP_JSON_EOF__'\n"
        + payload + "\n"
        "__DRIP_JSON_EOF__\n"
        "rm -f \"$f\"\n"
    )
    cmd = [
        "ssh",
        "-o", "ConnectTimeout=10",
        "-o", "BatchMode=yes",
        "wopr",
        "bash -s",
    ]
    out = subprocess.run(
        cmd, input=wrapper, capture_output=True, text=True,
        timeout=30, check=False,
    )
    if out.returncode != 0:
        log(f"php bridge ssh failed rc={out.returncode}: "
            f"{out.stderr.strip()[:300]}")
        return {}
    raw = out.stdout.strip()
    try:
        return json.loads(raw)
    except Exception:
        log(f"php bridge non-json output: {raw[:300]}")
        return {}


def find_all_tagged() -> list[dict]:
    res = php_call("list_tagged")
    if not res.get("ok"):
        log(f"list_tagged failed: {res}")
        return []
    return res.get("rows") or []


def find_next_candidate() -> dict | None:
    res = php_call("next_candidate")
    if not res.get("ok"):
        log(f"next_candidate failed: {res}")
        return None
    return res.get("row")


def update_whats_pending(row_id: int, new_value: str) -> bool:
    res = php_call("update_whats_pending", id=row_id, whats_pending=new_value)
    return bool(res.get("ok"))


def strip_tag(text: str) -> str:
    return TAG_RE.sub("", text or "").lstrip("\n")


def parse_tag_age_hours(text: str) -> float | None:
    """Return hours since the [MAC-DRIP ACTIVE since ...] timestamp, or None."""
    if not text:
        return None
    m = TAG_RE.search(text)
    if not m:
        return None
    when = m.group("when").strip()
    # Format we write: "YYYY-MM-DD HH:MM PT"
    when = re.sub(r"\s+PT$", "", when).strip()
    try:
        dt = datetime.datetime.strptime(when, "%Y-%m-%d %H:%M")
    except Exception:
        return None
    pt = datetime.timezone(datetime.timedelta(hours=-7))  # PDT
    dt = dt.replace(tzinfo=pt)
    return (datetime.datetime.now(pt) - dt).total_seconds() / 3600.0


def add_tag(text: str) -> str:
    pt_now = datetime.datetime.now(
        datetime.timezone(datetime.timedelta(hours=-7))  # PDT
    ).strftime("%Y-%m-%d %H:%M PT")
    tag_line = (
        f"[MAC-DRIP ACTIVE since {pt_now}] this is the next Mac-side chain "
        "to pick up — open it in a Cline window on the Mac\n"
    )
    base = strip_tag(text)
    return tag_line + (base if base else "")


def release_tag(row: dict, reason: str) -> None:
    new_wp = strip_tag(row.get("whats_pending") or "")
    if update_whats_pending(int(row["id"]), new_wp):
        log(f"released id={row['id']} slug={row['slug']} reason={reason}")
    else:
        log(f"FAILED release id={row['id']} slug={row['slug']} reason={reason}")


def surface_row(row: dict) -> None:
    new_wp = add_tag(row.get("whats_pending") or "")
    if update_whats_pending(int(row["id"]), new_wp):
        log(f"SURFACED id={row['id']} slug={row['slug']} "
            f"tier={row['approval_tier']} status={row['status']}")
    else:
        log(f"FAILED surface id={row['id']} slug={row['slug']}")


def main() -> int:
    log("=== mac drip tick ===")

    if DISABLE.exists():
        log(f"disabled via {DISABLE}, no-op")
        return 0

    if not acquire_lock():
        return 0

    try:
        tagged = find_all_tagged()

        # Defensive: if more than one row carries the tag (shouldn't happen,
        # but races during ad-hoc edits could) keep the most recent and
        # release the rest.
        if len(tagged) > 1:
            log(f"WARN: {len(tagged)} rows tagged, keeping the newest")
            keep = tagged[0]
            for extra in tagged[1:]:
                release_tag(extra, "multi-tag cleanup")
            tagged = [keep]

        if tagged:
            cur = tagged[0]
            age = parse_tag_age_hours(cur.get("whats_pending") or "")
            log(f"current: id={cur['id']} slug={cur['slug']} "
                f"status={cur['status']} tier={cur['approval_tier']} "
                f"tag_age_h={age}")

            if cur["status"] not in ("resting", "in_progress"):
                release_tag(cur, f"status={cur['status']}")
            elif age is not None and age >= AUTO_RELEASE_HOURS:
                release_tag(cur, f"stuck {AUTO_RELEASE_HOURS}h+ no progress")
            else:
                log("holding current tag, no-op")
                return 0

        # Either nothing was tagged or we just released — pick the next one.
        nxt = find_next_candidate()
        if not nxt:
            log("queue empty: no resting/in_progress mac_only rows to surface")
            return 0
        surface_row(nxt)
        return 0
    except Exception as e:
        log(f"EXCEPTION: {e!r}")
        return 0  # always 0 so launchd keeps us
    finally:
        release_lock()


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
sync_reversals.py — Mine rule-317 reversals into the Cline Learner corpus.

WHY THIS EXISTS
---------------
The Cline Learner (scan.py + write_rule.py + sync_to_mcp.py) only ever mined
YOLO trips: tasks that DIED. But the far richer signal is the rule-317
`rule_amend` ledger — every time an agent made a material claim, was proven
wrong mid-window, and had to amend the causal rule. Those are real, diagnosed
mistakes with an RCA bucket already attached, and as of 2026-08-30 there were
189 of them that the learner had never read.

Ruben, 2026-08-30: "shouldn't Cline learner be combing through rule 317s and
adding to its repertoire? I think so. Can you back fill this and test."

WHAT IT DOES
------------
1. Reads rule_amend from ~/.clinerules-mcp/index.sqlite (the 317 ledger).
2. Aggregates by rca_bucket + causal rule so the dominant mistake CLASSES
   surface, not just individual incidents.
3. Writes each reversal into the MCP `violations` table (dedup-safe) so
   clinerules_stats reflects reversal pressure, not only YOLO deaths.
4. Regenerates Rules-archive/317-reversal-patterns.md — a per-bucket playbook
   the next window can actually read.

DEDUP: evidence carries "[rule_amend id=N]" and we skip ids already present.

Usage:
  python3 sync_reversals.py            # sync + regenerate playbook
  python3 sync_reversals.py --dry-run  # report only, write nothing
"""

import os
import sqlite3
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
MCP_DB = HOME / ".clinerules-mcp/index.sqlite"
PLAYBOOK = HOME / "Documents/Cline/Rules-archive/317-reversal-patterns.md"

DRY_RUN = "--dry-run" in sys.argv

# Per-bucket guidance. Keyed to the five rca_bucket values rule 317 defines.
BUCKET_PLAYBOOK = {
    "insufficient probe": (
        "You had SOME evidence and stopped early. One auth error is not a dead "
        "credential; one EACCES is not a permission wall; a narration column is "
        "not an outcome. Before any negative or completion claim, acquire the "
        "probative artifact: the structured field, the escalation path, the "
        "second endpoint."
    ),
    "wrong premise": (
        "The reasoning was sound but rested on a false starting fact. State the "
        "premise explicitly and probe THAT before building on it."
    ),
    "unread source": (
        "The answer was already written down and nobody read it. Search the "
        "record (registry, onboarding idea, HANDOFF_NOTES, bug library) BEFORE "
        "probing the network or guessing."
    ),
    "scope error": (
        "The claim was true of a narrower population than stated. Enumerate the "
        "outcome space and name the window before quantifying anything."
    ),
    "stale assumption": (
        "A fact true in an earlier window was recited as current. Mutable state "
        "expires: re-probe before re-asserting."
    ),
}


def connect():
    if not MCP_DB.exists():
        print(f"[sync_reversals] MCP DB not found: {MCP_DB}")
        sys.exit(1)
    return sqlite3.connect(str(MCP_DB))


def fetch_reversals(conn):
    cur = conn.execute(
        "SELECT id, rule_id, slug, task_id, rca_bucket, reversal_note, created_at "
        "FROM rule_amend ORDER BY id"
    )
    return cur.fetchall()


def existing_ids(conn):
    """Reversal ids already synced into violations."""
    try:
        # NOTE: match ANYWHERE in the string, not just at the start. Some rows
        # are stored with a prefix (e.g. "VALIDATION_FAIL: ..."), so anchoring
        # with '[rule_amend id=%' silently matched nothing and every re-run
        # re-inserted all 189 reversals. Found by the 2026-08-30 idempotency test.
        rows = conn.execute(
            "SELECT evidence FROM violations WHERE evidence LIKE '%[rule_amend id=%'"
        ).fetchall()
    except sqlite3.OperationalError:
        return set()
    out = set()
    for (ev,) in rows:
        # Evidence shape: "[rule_amend id=12 bucket=scope error rule=297] note..."
        # The id is terminated by a SPACE, not by ']' — splitting on ']' yields
        # "12 bucket=scope error rule=297" and int() raises, so every run parsed
        # zero ids and re-inserted all 189 rows. Found by the 2026-08-30
        # idempotency test (count went 189 -> 378 on a no-op re-run).
        try:
            tail = ev.split("id=", 1)[1]
            token = tail.replace("]", " ").split()[0]
            out.add(int(token))
        except (IndexError, ValueError):
            continue
    return out


def sync(conn, reversals, already):
    """Insert un-synced reversals into violations. Returns count inserted."""
    cols = {r[1] for r in conn.execute("PRAGMA table_info(violations)")}
    inserted = 0
    for rid, rule_id, slug, task_id, bucket, note, created in reversals:
        if rid in already:
            continue
        evidence = (
            f"[rule_amend id={rid} bucket={bucket or 'unknown'} rule={rule_id}] "
            f"{(note or '').strip()[:400]}"
        )
        if DRY_RUN:
            inserted += 1
            continue
        payload = {
            "rule_id": str(rule_id),
            "task_id": str(task_id or ""),
            "evidence": evidence,
        }
        if "created_at" in cols:
            payload["created_at"] = created
        fields = ", ".join(payload)
        marks = ", ".join("?" * len(payload))
        try:
            conn.execute(
                f"INSERT INTO violations ({fields}) VALUES ({marks})",
                list(payload.values()),
            )
            inserted += 1
        except sqlite3.Error as e:
            print(f"[sync_reversals] insert failed for id={rid}: {e}")
    if not DRY_RUN:
        conn.commit()
    return inserted


def write_playbook(reversals):
    buckets = Counter()
    by_rule = Counter()
    notes = defaultdict(list)
    for _rid, rule_id, _slug, _task, bucket, note, created in reversals:
        b = bucket or "unclassified"
        buckets[b] += 1
        by_rule[str(rule_id)] += 1
        if note:
            notes[b].append((created, note.strip()))

    total = len(reversals)
    now = datetime.now().strftime("%Y-%m-%d %H:%M %Z").strip()
    L = []
    L.append("# 317 Reversal Patterns — mined from the rule_amend ledger")
    L.append("")
    L.append("**Auto-generated by `~/Documents/Cline/yolo_learner/sync_reversals.py`.**")
    L.append("**Do NOT hand-edit — regenerated on every learner run.**")
    L.append("")
    L.append(
        "The YOLO learner mines tasks that DIED. This file mines tasks that were "
        "WRONG and got corrected: every rule-317 reversal, with the RCA bucket the "
        "amending agent assigned. These are the mistake classes most likely to "
        "repeat, ranked by how often they actually have."
    )
    L.append("")
    L.append(f"- Reversals tracked: **{total}**")
    L.append(f"- Last generated: {now}")
    L.append("")
    L.append("## Mistake classes by frequency")
    L.append("")
    L.append("| RCA bucket | count | share | what it means |")
    L.append("|---|---|---|---|")
    for b, c in buckets.most_common():
        pct = (c * 100.0 / total) if total else 0
        why = BUCKET_PLAYBOOK.get(b, "See rule 317 for this bucket.")
        L.append(f"| {b} | {c} | {pct:.0f}% | {why} |")
    L.append("")
    L.append("## Causal rules most often amended")
    L.append("")
    for r, c in by_rule.most_common(8):
        L.append(f"- Rule {r}: {c} amendment(s)")
    L.append("")
    L.append("## Recent reversals per bucket (newest first)")
    L.append("")
    for b, _c in buckets.most_common():
        L.append(f"### {b}")
        L.append("")
        guidance = BUCKET_PLAYBOOK.get(b)
        if guidance:
            L.append(f"_{guidance}_")
            L.append("")
        for created, note in sorted(notes[b], reverse=True)[:5]:
            day = (created or "")[:10]
            snippet = " ".join(note.split())[:260]
            L.append(f"- **{day}** — {snippet}")
        L.append("")
    L.append("## How to use this")
    L.append("")
    L.append(
        "Before making any material claim, check which bucket your reasoning is "
        "closest to. The dominant bucket is the one you are most likely repeating "
        "right now."
    )
    L.append("")

    body = "\n".join(L)
    if DRY_RUN:
        print(f"[sync_reversals] (dry-run) would write {len(body)} bytes to {PLAYBOOK}")
        return
    PLAYBOOK.parent.mkdir(parents=True, exist_ok=True)
    PLAYBOOK.write_text(body, encoding="utf-8")
    print(f"[sync_reversals] wrote playbook: {PLAYBOOK} ({len(body)} bytes)")


def main():
    conn = connect()
    reversals = fetch_reversals(conn)
    if not reversals:
        print("[sync_reversals] no reversals in rule_amend; nothing to do")
        return
    already = existing_ids(conn)
    n = sync(conn, reversals, already)
    print(
        f"[sync_reversals] {len(reversals)} reversals in ledger, "
        f"{len(already)} already synced, {n} newly synced"
        + (" (dry-run)" if DRY_RUN else "")
    )
    write_playbook(reversals)
    conn.close()


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
sync_to_mcp.py — Bridge yolo_trips → clinerules-mcp violations table.

Reads ~/Documents/Cline/yolo_learner/yolo_trips.sqlite and inserts each trip
into ~/.clinerules-mcp/index.sqlite violations table so clinerules_stats
shows live violation counts.

Dedup: uses a composite key (task_id, trip_index) stored in evidence so
re-runs don't duplicate rows. Checks for existing rows with matching
evidence prefix before inserting.

Mapping:
  - rule_id: "99" (yolo-prevention-learned) for all trips, since rule 99
    is the canonical rule that regenerates from this data. cat_1 is
    preserved in evidence for per-category analysis.
  - task_id: from trips.task_id
  - evidence: "[yolo_trip task={task_id} idx={trip_index} cat={cat_1}] {triple}"

Called by run.sh after scan.py + write_rule.py.
"""

import sqlite3
import os
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
YOLO_DB = HOME / "Documents/Cline/yolo_learner/yolo_trips.sqlite"
MCP_DB = HOME / ".clinerules-mcp/index.sqlite"


def main():
    if not YOLO_DB.exists():
        print(f"[sync_to_mcp] yolo DB not found: {YOLO_DB}")
        return
    if not MCP_DB.exists():
        print(f"[sync_to_mcp] MCP DB not found: {MCP_DB}")
        return

    # Read all trips from yolo DB
    yolo = sqlite3.connect(str(YOLO_DB))
    yolo.row_factory = sqlite3.Row
    trips = yolo.execute(
        "SELECT task_id, trip_index, cat_1, cat_2, cat_3, triple FROM trips"
    ).fetchall()
    yolo.close()

    if not trips:
        print("[sync_to_mcp] no trips to sync")
        return

    # Connect to MCP DB and insert (dedup by evidence prefix)
    mcp = sqlite3.connect(str(MCP_DB))

    # Build evidence strings with a stable marker for dedup
    to_insert = []
    for t in trips:
        marker = f"[yolo_trip task={t['task_id']} idx={t['trip_index']}]"
        evidence = f"{marker} cat={t['cat_1'] or 'unknown'} | {t['triple'] or 'none'}"
        to_insert.append((t["task_id"], evidence, marker))

    # Check existing violations for dedup markers
    existing_markers = set()
    rows = mcp.execute(
        "SELECT evidence FROM violations WHERE evidence LIKE '[yolo_trip %'"
    ).fetchall()
    for r in rows:
        # Extract the marker from existing evidence
        ev = r[0]
        if ev.startswith("[yolo_trip "):
            # marker is the first ]-delimited segment
            end = ev.find("]")
            if end > 0:
                existing_markers.add(ev[: end + 1])

    new_count = 0
    for task_id, evidence, marker in to_insert:
        if marker in existing_markers:
            continue
        mcp.execute(
            "INSERT INTO violations (rule_id, task_id, evidence) VALUES (?, ?, ?)",
            ("99", str(task_id), evidence),
        )
        new_count += 1

    mcp.commit()

    total_violations = mcp.execute("SELECT COUNT(*) FROM violations").fetchone()[0]
    mcp.close()

    print(
        f"[sync_to_mcp] inserted {new_count} new violations, "
        f"total in MCP = {total_violations}"
    )


if __name__ == "__main__":
    main()
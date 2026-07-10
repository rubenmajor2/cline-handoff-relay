#!/usr/bin/env python3
"""
Stamp current violation counts into rules 17 and 95 in ~/Documents/Cline/Rules/.

Reads patterns.json from the scanner, updates a marked block at the top of
each rule file with live counters. The marked block is bracketed by
<!-- RULE_VIOLATION_COUNTERS:BEGIN --> and <!-- RULE_VIOLATION_COUNTERS:END -->
so we can rewrite it idempotently without touching the rest of the rule body.

Re-runnable. Safe to call from launchd.
"""
from __future__ import annotations

import json
import os
import re
import time
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
PATTERNS = HOME / "Documents/Cline/rule_violations/patterns.json"
RULES_DIR = HOME / "Documents/Cline/Rules"

# After 2026-05-03 rename: 00-READ-FIRST-* prefixes. Keep both old and new
# paths so the writer works whether the rename has happened yet or not.
RULE_FILE_CANDIDATES = {
    "rule_17": [
        "00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds.md",
        "17-force-subagent-use-on-research-and-multi-step-builds.md",
    ],
    "rule_95": [
        "00-READ-FIRST-95-cline-30s-tool-wall-and-remote-long-running-work.md",
        "95-cline-30s-tool-wall-and-remote-long-running-work.md",
    ],
}

BEGIN = "<!-- RULE_VIOLATION_COUNTERS:BEGIN -->"
END = "<!-- RULE_VIOLATION_COUNTERS:END -->"


def find_rule_file(candidates: list[str]) -> Path | None:
    for c in candidates:
        p = RULES_DIR / c
        if p.exists():
            return p
    return None


def block_for(rule_key: str, data: dict) -> str:
    w7 = data["last_7_days"]["by_rule"].get(rule_key, 0)
    w30 = data["last_30_days"]["by_rule"].get(rule_key, 0)
    wall = data["all_time"]["by_rule"].get(rule_key, 0)
    by_kind_30 = {
        k: v for k, v in data["last_30_days"]["by_kind"].items()
    }
    last_scan = data["generated_at_iso"]

    # Pick the kinds relevant to this rule
    kind_lines = []
    if rule_key == "rule_17":
        explicit = by_kind_30.get("explicit_ask_ignored", 0)
        research = by_kind_30.get("research_no_subagent", 0)
        kind_lines.append(
            f"  - explicit Ruben asks for subagent ignored (30d): **{explicit}**"
        )
        kind_lines.append(
            f"  - research/multi-step questions answered without subagent (30d): **{research}**"
        )
    elif rule_key == "rule_95":
        unguarded = by_kind_30.get("unguarded_remote_cmd", 0)
        kind_lines.append(
            f"  - remote commands without nohup/disown/scp-script (30d): **{unguarded}**"
        )

    # 2026-05-25 context diet: live numbers moved out of the auto-loaded
    # rule body to keep system-prompt tax low. Cline can fetch fresh counts
    # on demand via `clinerules_stats`. The full kind breakdown still gets
    # logged to /tmp/rule_violations_latest.json by scan.py.
    lines = [
        BEGIN,
        f"> **Live violation counters:** call `clinerules_stats` to see current 7d/30d/all-time burst rates"
        + (" and the explicit-ask-ignored vs research-without-subagent breakdown." if rule_key == "rule_17"
           else " for this rule.")
        + " Counters auto-update via `~/Documents/Cline/rule_violations/scan.py`."
        + f" Last scan: {last_scan} — 7d={w7}, 30d={w30}, all-time={wall}."
        + " If you are reading this rule, you are part of the count — don't add to it.",
        END,
        "",
    ]
    return "\n".join(lines)


def update_rule_file(p: Path, new_block: str) -> bool:
    src = p.read_text()
    pattern = re.compile(
        re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n*",
        re.DOTALL,
    )
    if pattern.search(src):
        new_src = pattern.sub(new_block, src, count=1)
    else:
        # Insert after the first H1 line (# Title), preserving the title.
        lines = src.split("\n", 1)
        if lines and lines[0].startswith("#"):
            head = lines[0] + "\n\n"
            tail = lines[1] if len(lines) > 1 else ""
            new_src = head + new_block + "\n" + tail
        else:
            new_src = new_block + "\n" + src
    if new_src != src:
        p.write_text(new_src)
        return True
    return False


def main() -> int:
    if not PATTERNS.exists():
        print(f"no patterns.json at {PATTERNS} — run scan.py first")
        return 1
    data = json.loads(PATTERNS.read_text())

    changed = []
    for rule_key, candidates in RULE_FILE_CANDIDATES.items():
        p = find_rule_file(candidates)
        if not p:
            print(f"  rule file not found for {rule_key} (checked: {candidates})")
            continue
        block = block_for(rule_key, data)
        if update_rule_file(p, block):
            changed.append(p.name)

    ts = time.strftime("%Y-%m-%d %H:%M:%S %Z")
    if changed:
        print(f"[{ts}] updated counters in: {', '.join(changed)}")
    else:
        print(f"[{ts}] counters unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

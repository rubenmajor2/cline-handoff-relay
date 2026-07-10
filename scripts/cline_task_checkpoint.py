#!/usr/bin/env python3
"""
cline_task_checkpoint.py — Periodic Cline task backup (every 5 min via launchd).

Copies the most recently modified Cline task directories to
~/Documents/Cline/task-backups/<YYYYMMDD_HHMMSS>/
Keeps the last 50 checkpoints, pruning older ones.

Idea #TODO (file after script is live).
Per .clinerules/ M5_RECOVERY_AND_LITELLM_REPORT.md section 3.
"""

import os
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────
TASKS_DIR = os.path.expanduser(
    "~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
)
BACKUP_ROOT = os.path.expanduser("~/Documents/Cline/task-backups")
MAX_BACKUPS = 50
LOG_PATH = "/tmp/cline-task-checkpoint.log"

# Files within each task dir worth backing up (skip state/* blobs >10MB)
BACKUP_FILES = [
    "api_conversation_history.json",
    "ui_messages.json",
    "task_metadata.json",
]


def log(msg: str) -> None:
    ts = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, file=sys.stderr)
    try:
        with open(LOG_PATH, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass  # can't log to disk — stderr is the fallback


def find_recent_task_dirs(tasks_root: str, minutes: int = 10) -> list[Path]:
    """Return task dirs modified in the last N minutes, newest first."""
    now = time.time()
    cutoff = now - (minutes * 60)
    tasks_path = Path(tasks_root)
    if not tasks_path.is_dir():
        log(f"ERROR: tasks dir not found: {tasks_root}")
        return []

    recent = []
    for entry in tasks_path.iterdir():
        if entry.is_dir() and entry.name.isdigit():
            try:
                mtime = entry.stat().st_mtime
                if mtime >= cutoff:
                    recent.append((mtime, entry))
            except OSError:
                continue

    recent.sort(key=lambda x: x[0], reverse=True)
    return [entry for _, entry in recent]


def copy_task_dir(task_dir: Path, dest_root: Path) -> bool:
    """Copy the key files from a task dir into a timestamped backup dir."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest_dir = dest_root / f"{ts}_{task_dir.name}"

    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        log(f"ERROR: mkdir {dest_dir}: {e}")
        return False

    copied = 0
    for fname in BACKUP_FILES:
        src = task_dir / fname
        if src.is_file():
            try:
                shutil.copy2(src, dest_dir / fname)
                copied += 1
            except OSError as e:
                log(f"WARN: copy {src} → {dest_dir}: {e}")

    if copied == 0:
        # Nothing to back up — remove empty dir
        try:
            dest_dir.rmdir()
        except OSError:
            pass
        return False

    log(f"CHECKPOINT: {task_dir.name} → {dest_dir.name} ({copied} files)")
    return True


def prune_backups(backup_root: Path, max_keep: int) -> int:
    """Remove oldest backup dirs, keeping at most max_keep."""
    if not backup_root.is_dir():
        return 0

    dirs = sorted(
        [d for d in backup_root.iterdir() if d.is_dir()],
        key=lambda d: d.stat().st_mtime,
        reverse=True,
    )

    removed = 0
    for d in dirs[max_keep:]:
        try:
            shutil.rmtree(d)
            removed += 1
            log(f"PRUNE: removed old backup {d.name}")
        except OSError as e:
            log(f"WARN: prune {d.name}: {e}")

    return removed


def main() -> None:
    log("START checkpoint run")

    backup_root = Path(BACKUP_ROOT)
    try:
        backup_root.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        log(f"ERROR: cannot create backup root {backup_root}: {e}")
        sys.exit(1)

    # Find task dirs touched in the last 10 minutes (launchd runs every 5 min,
    # so a 10 min window catches anything since last run with margin)
    recent = find_recent_task_dirs(TASKS_DIR, minutes=10)

    if not recent:
        log("No recently modified task dirs — nothing to checkpoint")
        prune_backups(backup_root, MAX_BACKUPS)
        log("END checkpoint run (no-op)")
        return

    backed_up = 0
    for task_dir in recent:
        if copy_task_dir(task_dir, backup_root):
            backed_up += 1

    pruned = prune_backups(backup_root, MAX_BACKUPS)

    log(f"END checkpoint run — backed up {backed_up} task(s), pruned {pruned}")
    sys.exit(0)


if __name__ == "__main__":
    main()
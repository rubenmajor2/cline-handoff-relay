#!/usr/bin/env python3
"""
Mac-side autonomous chain dispatcher for session_handoffs.
Polls WOPR MySQL via SSH for mac_only chains at autonomous/approved tier,
marks one as picked up, and opens a Cline window with the start_prompt.

LaunchAgent: ~/Library/LaunchAgents/com.emsu.mac-chain-dispatcher.plist
Runs every 60s. Single-instance via PID file.
"""

import json
import os
import subprocess
import sys
import time

# --- Config ---
WOPR = "emsuserver@76.167.100.188"
WOPR_PORT = 2222
SSH_TIMEOUT = 10
PID_FILE = "/tmp/mac_chain_dispatcher.pid"
LOG_FILE = "/tmp/mac_chain_dispatcher.log"


def log(msg: str):
    ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime())
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass


def wopr_mysql(query: str) -> str:
    """Run a MySQL query on WOPR via SSH. Returns stdout or raises."""
    cmd = [
        "ssh", "-p", str(WOPR_PORT),
        "-o", f"ConnectTimeout={SSH_TIMEOUT}",
        "-o", "StrictHostKeyChecking=no",
        WOPR,
        f'mysql -N -B admin_portal -e "{query}"'
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=SSH_TIMEOUT + 5)
    if r.returncode != 0:
        raise RuntimeError(f"SSH/MySQL failed: {r.stderr.strip()}")
    return r.stdout.strip()


def wopr_mysql_update(query: str):
    """Run a MySQL UPDATE/INSERT on WOPR via SSH."""
    subprocess.run([
        "ssh", "-p", str(WOPR_PORT),
        "-o", f"ConnectTimeout={SSH_TIMEOUT}",
        "-o", "StrictHostKeyChecking=no",
        WOPR,
        f'mysql -N -B admin_portal -e "{query}"'
    ], capture_output=True, timeout=SSH_TIMEOUT + 5, check=False)


def check_pid() -> bool:
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE) as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)  # check if alive
            return True
        except (OSError, ValueError):
            os.remove(PID_FILE)
    return False


def find_next_chain() -> dict | None:
    """Return the highest-priority mac_only chain waiting for pickup."""
    out = wopr_mysql(
        "SELECT id, slug, title, COALESCE(start_prompt,''), priority_hint, approval_tier "
        "FROM session_handoffs "
        "WHERE target_runtime='mac_only' "
        "  AND status IN ('resting','in_progress') "
        "  AND mac_shell_picked_up_at IS NULL "
        "  AND approval_tier IN ('autonomous','approved') "
        "ORDER BY FIELD(priority_hint,'P0','P1','P2','P3'), id ASC "
        "LIMIT 1"
    )
    if not out:
        return None
    # Parse tab-separated output (6 columns)
    parts = out.split("\t")
    if len(parts) < 6:
        return None
    return {
        "id": int(parts[0]),
        "slug": parts[1],
        "title": parts[2],
        "start_prompt": parts[3],
        "priority_hint": parts[4],
        "approval_tier": parts[5],
    }


def mark_picked_up(chain_id: int, slug: str):
    wopr_mysql_update(
        f"UPDATE session_handoffs "
        f"SET mac_shell_picked_up_at=NOW(), "
        f"mac_shell_picked_up_by='mac_chain_dispatcher', "
        f"status='in_progress' "
        f"WHERE id={chain_id} AND slug='{slug}'"
    )


def open_cline_window(chain: dict):
    """Open VS Code and Cline with the chain's start prompt."""
    slug = chain["slug"]
    title = chain["title"]
    start_prompt = chain.get("start_prompt", "") or ""

    # Save prompt to a temp file
    prompt_path = f"/tmp/cline_chain_{slug}.txt"
    with open(prompt_path, "w") as f:
        f.write(f"Cline Task — Chain: {slug}\n")
        f.write(f"Title: {title}\n")
        f.write("=" * 60 + "\n\n")
        f.write(start_prompt)

    # Tell Ruben what's ready to run (opens VS Code, focuses Cline)
    applescript = f'''
    tell application "Visual Studio Code" to activate
    delay 0.5
    tell application "System Events"
        tell process "Code"
            keystroke "l" using {{command down, shift down}}
        end tell
    end tell
    '''
    subprocess.run(["osascript", "-e", applescript], check=False)
    log(f"opened VS Code + Cline focus for chain: {slug}")


def main():
    if check_pid():
        log("another instance already running — exiting")
        sys.exit(0)

    # Write PID
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    try:
        log("scanning for mac_only chains...")
        chain = find_next_chain()

        if chain is None:
            log("no chains waiting for pickup")
            return

        log(f"dispatching chain: {chain['slug']} (id={chain['id']}, prio={chain.get('priority_hint','?')})")
        mark_picked_up(chain["id"], chain["slug"])
        log(f"marked chain {chain['id']} as picked up")
        open_cline_window(chain)

    except Exception as e:
        log(f"ERROR: {e}")
    finally:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Mac-side autonomous chain dispatcher for session_handoffs.
Polls WOPR MySQL via existing SSH tunnel (127.0.0.1:33066) for mac_only chains
at autonomous/approved tier, marks one as picked up, and opens a Cline window.

Install: /usr/local/bin/mac_chain_dispatcher.py
LaunchAgent: ~/Library/LaunchAgents/com.emsu.mac-chain-dispatcher.plist
Runs every 60s. Single-instance via PID file.
"""

import os
import subprocess
import sys
import time

# --- Config ---
MYSQL_HOST = "127.0.0.1"
MYSQL_PORT = 33066  # SSH tunnel from M4 Mac -> WOPR MySQL (auto-established)
MYSQL_USER = "root"
MYSQL_PASS = ""
MYSQL_DB = "admin_portal"
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


def mysql(query: str) -> str:
    """Run a MySQL query via the local SSH tunnel. Returns stdout or raises."""
    r = subprocess.run(
        [
            "mysql", "-h", MYSQL_HOST, "-P", str(MYSQL_PORT),
            "-u", MYSQL_USER, "-N", "-B", MYSQL_DB,
            "-e", query
        ],
        capture_output=True, text=True, timeout=15,
    )
    if r.returncode != 0:
        raise RuntimeError(f"MySQL failed: {r.stderr.strip()}")
    return r.stdout.strip()


def find_next_chain() -> dict | None:
    """Return the highest-priority mac_only chain waiting for pickup."""
    q = (
        "SELECT id, slug, title, COALESCE(start_prompt,''), priority_hint, approval_tier "
        "FROM session_handoffs "
        "WHERE target_runtime='mac_only' "
        "  AND status IN ('resting','in_progress') "
        "  AND mac_shell_picked_up_at IS NULL "
        "  AND approval_tier IN ('autonomous','approved') "
        "ORDER BY FIELD(priority_hint,'P0','P1','P2','P3'), id ASC "
        "LIMIT 1"
    )
    out = mysql(q)
    if not out:
        return None
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
    subprocess.run([
        "mysql", "-h", MYSQL_HOST, "-P", str(MYSQL_PORT),
        "-u", MYSQL_USER, MYSQL_DB,
        "-e",
        f"UPDATE session_handoffs "
        f"SET mac_shell_picked_up_at=NOW(), "
        f"mac_shell_picked_up_by='mac_chain_dispatcher', "
        f"status='in_progress' "
        f"WHERE id={chain_id} AND slug='{slug}'"
    ], capture_output=True, timeout=15, check=False)


def open_cline_window(chain: dict):
    """Open VS Code and focus Cline. Save prompt to /tmp for pickup."""
    slug = chain["slug"]
    title = chain["title"]
    start_prompt = chain.get("start_prompt", "") or ""

    prompt_path = f"/tmp/cline_chain_{slug}.txt"
    with open(prompt_path, "w") as f:
        f.write(f"Cline Task - Chain: {slug}\n")
        f.write(f"Title: {title}\n")
        f.write("=" * 60 + "\n\n")
        f.write(start_prompt)

    applescript = '''
    tell application "Visual Studio Code" to activate
    delay 0.5
    tell application "System Events"
        tell process "Code"
            keystroke "l" using {command down, shift down}
        end tell
    end tell
    '''
    subprocess.run(["osascript", "-e", applescript], check=False)
    log(f"opened VS Code + Cline focus for chain: {slug}")


def check_pid() -> bool:
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE) as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            return True
        except (OSError, ValueError):
            os.remove(PID_FILE)
    return False


def main():
    if check_pid():
        log("another instance already running - exiting")
        sys.exit(0)

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    try:
        log("scanning for mac_only chains...")
        chain = find_next_chain()

        if chain is None:
            log("no chains waiting for pickup")
            return

        log(f"dispatching: {chain['slug']} (id={chain['id']}, {chain.get('priority_hint','?')})")
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
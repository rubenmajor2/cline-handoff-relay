#!/usr/bin/env python3
"""
sync_lock.py — cross-platform fcntl flock helper.

Acquires an exclusive flock on /tmp/cline-relay.lock, then exec's the rest
of argv. Replaces Linux-only `flock(1)` for our cross-platform Mac+Artemis
relay sync. Uses fcntl.flock which exists on both macOS and Linux.

Usage:
  sync_lock.py [-w SECONDS] -- COMMAND [ARGS...]

Exit codes:
  0   command exited 0
  1   command exited non-zero (passed through)
  2   timeout acquiring lock
  3   bad invocation
"""
import fcntl, os, sys, time

LOCK_PATH = "/tmp/cline-relay.lock"

def main(argv):
    timeout = 60
    args = argv[1:]
    if args and args[0] == '-w':
        try:
            timeout = int(args[1])
            args = args[2:]
        except (IndexError, ValueError):
            print("usage: sync_lock.py [-w SECONDS] -- CMD ARGS...", file=sys.stderr)
            return 3
    if args and args[0] == '--':
        args = args[1:]
    if not args:
        print("usage: sync_lock.py [-w SECONDS] -- CMD ARGS...", file=sys.stderr)
        return 3

    fd = os.open(LOCK_PATH, os.O_WRONLY | os.O_CREAT, 0o644)
    deadline = time.time() + timeout
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.time() >= deadline:
                print(f"sync_lock: could not acquire {LOCK_PATH} in {timeout}s", file=sys.stderr)
                return 2
            time.sleep(0.5)

    # Run the command. We exec via fork so the lock holds for the child's lifetime.
    pid = os.fork()
    if pid == 0:
        # Child: drop the fd ref (still inherited but not the one we hold), exec.
        # Actually keep it open — flock is per-file-description in Linux but the
        # kernel-side lock is on the inode and survives fork+exec inheritance.
        os.execvp(args[0], args)
    else:
        _, status = os.waitpid(pid, 0)
        rc = os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1
        # fcntl.flock auto-releases on close/exit
        return rc

if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""
patch_subagent_cap.py — Re-apply SubagentRunner tool-call hard cap after extension updates.

Patches Cline's dist/extension.js to inject:
  1. Hard cap at 75 tool calls (force-complete with budget-exceeded result)
  2. Checkpoint at 50 tool calls (inject wrap-up reminder into conversation)

This is the DURABLE fix for idea #16849/#16850. The model CANNOT ignore it —
the cap is enforced in the extension's SubagentRunner.run() loop, not in a prompt.
Same source-patch pattern as patch_yolo_ceiling.sh (rule 143 v4).

Idempotent: safe to run multiple times. Skips if already patched.
Scans all installed saoudrizwan.claude-dev-* extensions.

Usage:
    python3 ~/Documents/Cline/scripts/patch_subagent_cap.py          # patch all
    python3 ~/Documents/Cline/scripts/patch_subagent_cap.py --check  # check only, no write

Created: 2026-07-09 (idea #16849 path 1 — hard cap in SubagentRunner)
"""

import sys
import os
import glob
import shutil
import subprocess

EXTENSIONS_DIR = os.path.expanduser("~/.vscode/extensions")

# --- Anchor: the start of the main for(;;) loop body in SubagentRunner.run() ---
LOOP_TOP_ANCHOR = '];for(;;){if(u.lastRequest&&this.shouldCompactBeforeNextRequest'

# --- The injection: hard cap at 75 + checkpoint at 50 ---
INJECTION_CODE = (
    # --- Hard cap at 75 tool calls: force-complete ---
    'if(c.toolCalls>=75){'
    'let _bc="Subagent tool-call budget EXCEEDED (75/75). The parent agent set a hard cap. '
    'You MUST stop calling tools NOW and return your findings via attempt_completion. '
    'This is a HARD CAP enforced by the extension, not a suggestion. '
    'Summarize what you found so far and complete immediately.";'
    'be.warn("[SubagentRunner] HARD CAP (75) reached, force-completing subagent.");'
    'r({status:"completed",result:_bc,stats:{...c}});'
    'return{status:"completed",result:_bc,stats:{...c}};'
    '}'
    # --- Checkpoint at 50 tool calls: inject wrap-up reminder into conversation ---
    'if(c.toolCalls===50&&!u._cap50hit){'
    'u._cap50hit=!0;'
    'be.warn("[SubagentRunner] Checkpoint (50/75) reached, injecting wrap-up reminder.");'
    'b.push({role:"user",content:[{type:"text",text:'
    '"[SYSTEM] You have used 50 of your maximum 75 tool calls. You have 25 calls remaining. '
    'BEGIN WRAPPING UP NOW. Stop exploring new directions. Synthesize what you have found into a clear, '
    'actionable attempt_completion result. If you need more than 25 more calls, your investigation is too broad '
    '-- summarize current findings and complete. This reminder is from the extension hard-cap system, not a suggestion."'
    '}]});'
    '}'
)

BACKUP_SUFFIX = ".bak-pre-subagent-cap"


def patch_one(ext_js, check_only=False):
    """Patch a single extension.js file. Returns True if patched/skipped OK."""
    ext_dir = os.path.dirname(os.path.dirname(ext_js))
    version = os.path.basename(ext_dir).replace("saoudrizwan.claude-dev-", "")
    print(f"  Version {version} ({ext_js})")

    if not os.path.exists(ext_js):
        print(f"    SKIP: file not found")
        return False

    with open(ext_js, "r", encoding="utf-8") as f:
        content = f.read()

    # Already patched?
    if "_cap50hit" in content:
        print(f"    ALREADY PATCHED (marker found). Skipping.")
        return True

    if check_only:
        print(f"    NOT PATCHED (check-only mode)")
        return False

    # Verify anchor exists and is unique
    count = content.count(LOOP_TOP_ANCHOR)
    if count == 0:
        print(f"    ERROR: anchor not found (extension structure changed?)", file=sys.stderr)
        return False
    if count > 1:
        print(f"    ERROR: anchor found {count} times (not unique)", file=sys.stderr)
        return False

    # Make backup
    backup_path = ext_js + BACKUP_SUFFIX
    if not os.path.exists(backup_path):
        shutil.copy2(ext_js, backup_path)
        print(f"    Backup: {backup_path}")

    # Apply patch
    replacement = "];for(;;){" + INJECTION_CODE + "if(u.lastRequest&&this.shouldCompactBeforeNextRequest"
    new_content = content.replace(LOOP_TOP_ANCHOR, replacement, 1)

    if new_content == content:
        print(f"    ERROR: replacement failed", file=sys.stderr)
        return False

    with open(ext_js, "w", encoding="utf-8") as f:
        f.write(new_content)

    delta = len(new_content) - len(content)
    print(f"    PATCHED: +{delta} bytes")

    # Syntax check
    try:
        result = subprocess.run(
            ["node", "--check", ext_js],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0:
            print(f"    SYNTAX OK")
        else:
            print(f"    WARNING: node --check failed (minified files sometimes trip this)")
    except Exception:
        print(f"    WARNING: node --check could not run")

    return True


def main():
    check_only = "--check" in sys.argv
    print(f"=== patch_subagent_cap.py ===")
    print(f"Check-only: {check_only}")
    print(f"Extensions dir: {EXTENSIONS_DIR}")
    print()

    # Find all Cline extension versions
    pattern = os.path.join(EXTENSIONS_DIR, "saoudrizwan.claude-dev-*")
    ext_dirs = sorted(glob.glob(pattern))

    if not ext_dirs:
        print("ERROR: No Cline extensions found")
        sys.exit(1)

    all_ok = True
    for ext_dir in ext_dirs:
        ext_js = os.path.join(ext_dir, "dist", "extension.js")
        if not patch_one(ext_js, check_only):
            all_ok = False

    print()
    if all_ok:
        print("All extensions processed successfully.")
        if not check_only:
            print("Reload VS Code (Window: Reload) for changes to take effect.")
        sys.exit(0)
    else:
        print("WARNING: some extensions failed to patch.")
        sys.exit(1)


if __name__ == "__main__":
    main()
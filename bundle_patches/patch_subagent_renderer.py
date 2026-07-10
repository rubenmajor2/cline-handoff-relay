#!/usr/bin/env python3
"""
Phase 2 of the subagent model badge patch — add a visible inline badge to
the renderer when item.model is truthy.

The parser was patched in phase 1 to populate item.model. This phase patches
the renderer block at offset ~3334317 to render the model name inline.

Target SEARCH/REPLACE:

The renderer minified line currently reads:
    v.jsx("div",{className:"min-w-0 flex-1",children:v.jsx(Han,{isExpanded:o[g.index]===!0,onShowMore:()=>m(g.index),prompt:g.prompt})})

We inject a small span above the prompt that displays `g.model` when set,
using the same v.jsxs structure as siblings:

    v.jsx("div",{className:"min-w-0 flex-1",children:v.jsxs(v.Fragment,{children:[g.model&&v.jsx("span",{className:"text-xs opacity-60 mr-1",children:"["+String(g.model).replace(/^claude-/,"").replace(/-[0-9]+m?$/,"")+"]"}),v.jsx(Han,{isExpanded:o[g.index]===!0,onShowMore:()=>m(g.index),prompt:g.prompt})]})})

The model string gets a small cleanup: strips "claude-" prefix and any
trailing "-1m"/"-200k"/etc. So "claude-haiku-4-5" displays as "[haiku-4-5]".

Idempotent + marker-guarded + backed up.
"""
import sys
import shutil
from pathlib import Path

BUNDLE = Path.home() / ".vscode/extensions/saoudrizwan.claude-dev-3.82.0/webview-ui/build/assets/index.js"
BACKUP = BUNDLE.with_name(BUNDLE.name + ".bak-pre-subagent-renderer-2026-05-12")
MARKER = "/*SAMR26*/"  # subagent-model-renderer-2026-05

OLD = 'v.jsx("div",{className:"min-w-0 flex-1",children:v.jsx(Han,{isExpanded:o[g.index]===!0,onShowMore:()=>m(g.index),prompt:g.prompt})})'

NEW = ('v.jsx("div",{className:"min-w-0 flex-1",children:v.jsxs(v.Fragment,{children:['
       'g.model&&v.jsx("span",{className:"text-xs opacity-60 mr-1",style:{fontFamily:"monospace"},'
       'children:"["+String(g.model).replace(/^claude-/,"").replace(/:1m$/,"").replace(/-1m$/,"")+"]"})/*SAMR26*/,'
       'v.jsx(Han,{isExpanded:o[g.index]===!0,onShowMore:()=>m(g.index),prompt:g.prompt})]})})')

def main():
    if not BUNDLE.exists():
        print(f"FATAL: bundle missing: {BUNDLE}")
        return 2

    src = BUNDLE.read_text()
    if MARKER in src:
        print("ALREADY_PATCHED (renderer)")
        return 0
    if OLD not in src:
        print("ERROR: target not found. Showing context around 'min-w-0 flex-1' + Han:")
        idx = src.find("min-w-0 flex-1")
        while idx >= 0:
            print(f"@{idx}: {repr(src[idx-30:idx+250])}")
            print()
            idx = src.find("min-w-0 flex-1", idx + 1)
            if idx > 4000000:
                break
        return 3

    if not BACKUP.exists():
        shutil.copy2(BUNDLE, BACKUP)
        print(f"BACKUP: {BACKUP}")
    else:
        print(f"BACKUP exists: {BACKUP}")

    new_src = src.replace(OLD, NEW, 1)
    if new_src == src:
        print("ERROR: replace failed silently")
        return 4

    BUNDLE.write_text(new_src)

    verify = BUNDLE.read_text()
    if MARKER not in verify or NEW not in verify:
        print("ERROR: verify failed after write")
        return 5

    delta = len(verify) - len(src)
    print(f"OK renderer patched, delta=+{delta} chars, marker present")
    return 0

if __name__ == "__main__":
    sys.exit(main())

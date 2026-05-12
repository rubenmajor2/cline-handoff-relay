#!/usr/bin/env python3
"""
Patch the Cline 3.82.0 webview bundle to surface subagent model IDs in the UI.

Two-site patch (parser only — extracts model field per item from the input JSON):
  - The parser Uan(e) currently emits items with no `model` field
  - We extend it to read r[`prompt_${o+1}_model`] for each item

The renderer is more complex (minified React component with capture refs).
For phase 1, we just get the model into the parsed items object. Phase 2 can
add a visible badge — but with the model present in the items array, the
renderer can be patched later or the data is already available via DevTools.

Even with just the parser patch, the inline narration from .clinerules/53 stays
the primary visibility mechanism. This patch ensures the data flows through
the webview state correctly when a future renderer patch ships.

Idempotent: skips if patched marker is found. Backs up before modifying.
"""
import sys
import shutil
from pathlib import Path

BUNDLE = Path.home() / ".vscode/extensions/saoudrizwan.claude-dev-3.82.0/webview-ui/build/assets/index.js"
BACKUP = BUNDLE.with_name(BUNDLE.name + ".bak-pre-subagent-model-badge-2026-05-12")
MARKER = "/*SAM26*/"  # subagent-model-2026-05

# The exact unpatched parser body, lifted from the subagent's extraction:
OLD = ('const n=r.prompts.map(i=>i?.trim()).filter(i=>!!i);return n.length===0?null:'
       '{status:"pending",items:n.map((i,o)=>({index:o+1,prompt:i,status:"pending",'
       'toolCalls:0,inputTokens:0,outputTokens:0,totalCost:0,contextTokens:0,'
       'contextWindow:0,contextUsagePercentage:0}))}')

NEW = ('const n=r.prompts.map(i=>i?.trim()).filter(i=>!!i);return n.length===0?null:'
       '{status:"pending",items:n.map((i,o)=>({index:o+1,prompt:i,status:"pending",'
       'toolCalls:0,inputTokens:0,outputTokens:0,totalCost:0,contextTokens:0,'
       'contextWindow:0,contextUsagePercentage:0,'
       'model:r["prompt_"+(o+1)+"_model"]||null/*SAM26*/}))}')

def main():
    if not BUNDLE.exists():
        print(f"FATAL: bundle missing: {BUNDLE}")
        return 2

    src = BUNDLE.read_text()
    if MARKER in src:
        print("ALREADY_PATCHED")
        return 0
    if OLD not in src:
        print("ERROR: target string not found. Bundle may have changed.")
        # Show some context for debugging
        idx = src.find("r.prompts.map")
        if idx >= 0:
            print(f"r.prompts.map found at {idx}, context:")
            print(repr(src[idx-50:idx+200]))
        return 3

    # Backup
    if not BACKUP.exists():
        shutil.copy2(BUNDLE, BACKUP)
        print(f"BACKUP: {BACKUP}")
    else:
        print(f"BACKUP exists: {BACKUP}")

    # Apply
    new_src = src.replace(OLD, NEW, 1)
    if new_src == src:
        print("ERROR: replace failed silently")
        return 4
    BUNDLE.write_text(new_src)

    # Verify
    verify = BUNDLE.read_text()
    if MARKER not in verify or NEW not in verify:
        print("ERROR: verify failed after write")
        return 5

    delta = len(verify) - len(src)
    print(f"OK patched, delta={delta} chars, marker present")
    return 0

if __name__ == "__main__":
    sys.exit(main())

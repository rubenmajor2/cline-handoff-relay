#!/usr/bin/env python3
"""
Phase 3 of the subagent patch series — make use_subagents provider-aware
so models behind the LiteLLM router (e.g. 7B-LoRA) can be used as subagents.

Design: extend `applyModelOverride(e,r,n)` to detect a "router:" prefix on
the model ID. When present, override the apiProvider + base URL + API key
to route the subagent through the local LiteLLM router instead of
Anthropic.

Usage from Cline main agent:
    use_subagents(
        prompt_1="EMSU policy lookup task",
        prompt_1_model="router:emsu-qwen2.5-coder-7b-lora"
    )

The "router:" prefix is stripped before being used as the actual model ID
in the OpenAI-format request.

CONFIDENCE: medium. The applyModelOverride site is verified verbatim, but
the openAiBaseUrl + openAiApiKey per-mode key names are inferred from the
pattern (52 occurrences of openAiBaseUrl in bundle). If a subagent
dispatch with router: prefix fails, restore .bak immediately.

Marker: /*SAP26*/
Backup: dist/extension.js.bak-pre-subagent-provider-aware-2026-05-12
"""
import sys
import shutil
from pathlib import Path

BUNDLE = Path.home() / ".vscode/extensions/saoudrizwan.claude-dev-3.82.0/dist/extension.js"
BACKUP = BUNDLE.with_name(BUNDLE.name + ".bak-pre-subagent-provider-aware-2026-05-12")
MARKER = "/*SAP26*/"

# Verbatim current body from subagent extraction at byte 19507686:
OLD = 'applyModelOverride(e,r,n){let o=n?.trim();if(!o)return;let s=r==="plan"?"plan":"act",a=e[r==="plan"?"planModeApiProvider":"actModeApiProvider"];e[CAr(a,s)]=o}'

# Patched body: detect router: prefix, override provider to openai, set base URL to local router.
# Keeps the original behavior intact when no router: prefix is present.
NEW = ('applyModelOverride(e,r,n){let o=n?.trim();if(!o)return;'
       '/*SAP26*/'
       'if(o.startsWith("router:")){let _m=o.slice(7),_p=r==="plan"?"plan":"act";'
       'e[_p+"ModeApiProvider"]="openai";'
       'e[_p+"ModeOpenAiBaseUrl"]="http://127.0.0.1:8787/v1";'
       'e[_p+"ModeOpenAiApiKey"]="dummy";'
       'e[_p+"ModeOpenAiModelId"]=_m;'
       'return}'
       'let s=r==="plan"?"plan":"act",a=e[r==="plan"?"planModeApiProvider":"actModeApiProvider"];e[CAr(a,s)]=o}')

def main():
    if not BUNDLE.exists():
        print(f"FATAL: bundle missing: {BUNDLE}")
        return 2

    src = BUNDLE.read_text()
    if MARKER in src:
        print("ALREADY_PATCHED")
        return 0
    if OLD not in src:
        print("ERROR: target body not found. Bundle changed or model-picker variant differs.")
        idx = src.find("applyModelOverride(e,r,n)")
        if idx >= 0:
            print(f"applyModelOverride found at {idx}, current context:")
            print(repr(src[idx:idx+400]))
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
    print(f"OK provider-aware patch applied, delta=+{delta} chars, marker present")
    return 0

if __name__ == "__main__":
    sys.exit(main())

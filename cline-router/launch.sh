#!/bin/bash
# cline-router launchd entry point.
# 2026-05-11 — moved out of ~/Documents (TCC-protected) per debug session.
# Canonical source still at ~/Documents/Cline/cline-router/ (git-tracked);
# this copy under ~/Library/Application Support/cline-router/ is what
# launchd actually executes. Updates: sync both with `cp -R`.
exec /Users/rubenmajor/.local/bin/litellm \
    --config "/Users/rubenmajor/Library/Application Support/cline-router/config.yaml" \
    --port 8787 \
    --host 127.0.0.1

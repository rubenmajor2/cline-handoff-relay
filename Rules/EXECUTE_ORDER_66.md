# EXECUTE_ORDER_66 — wrap-up protocol (stub)

**Full rule moved to archive 2026-05-25** to save ~7.5 KB of every task's system prompt.

## Trigger phrases

If Ruben (or any directive) says any of:
- "execute order 66"
- "order 66"
- "wrap up"
- "clean wrap"
- "finalize and close"

→ Fetch the full protocol immediately:

```
clinerules_lookup(rule_id="EXECUTE_ORDER_66")
```

OR fallback if MCP is down:
```
read_file /Users/rubenmajor/Documents/Cline/Rules-archive/EXECUTE_ORDER_66.md
```

The full rule covers the 6-step wrap-up protocol (ledger row, HANDOFF, idea status reconciliation, MCP reindex, attempt_completion shape, pickup prompt).

## Why this is a stub

The full text never needs to be in the system prompt — it only matters when one of the trigger phrases above fires, and at that point a single MCP lookup is faster + cheaper than carrying ~200 lines every task. Per the Phase-3 hardfloor reorg pattern in `_INDEX.md`.

Cross-ref: `.clinerules/91-every-completion-needs-pickup-prompt` (which IS in-prompt) covers the most-common-case fields. EXECUTE_ORDER_66 is the deep version.
